import 'package:get/get.dart';

import '../api/ketangpai_service.dart';
import '../models/ketangpai_sign.dart';
import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/sign_record_store.dart';

enum SignStatus { idle, loading, success, failed }

class KtSignRecord {
  const KtSignRecord({
    required this.type,
    required this.signId,
    required this.courseName,
    required this.account,
    required this.status,
    required this.message,
    required this.time,
    this.raw,
  });

  final String type;
  final String signId;
  final String courseName;
  final String account;
  final SignStatus status;
  final String message;
  final DateTime time;
  final dynamic raw;

  bool get success => status == SignStatus.success;

  factory KtSignRecord.fromOutcome({
    required String type,
    required String signId,
    required String courseName,
    required String account,
    required KetangpaiSignOutcome outcome,
    DateTime? time,
  }) {
    return KtSignRecord(
      type: type,
      signId: signId,
      courseName: courseName,
      account: account,
      status: outcome.success ? SignStatus.success : SignStatus.failed,
      message: outcome.message,
      time: time ?? DateTime.now(),
      raw: outcome.raw,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'signId': signId,
    'courseName': courseName,
    'account': account,
    'status': status.name,
    'message': message,
    'time': time.toIso8601String(),
    'raw': raw,
  };
}

typedef KetangpaiSignRequest =
    Future<KetangpaiServiceResult<Map<String, dynamic>>> Function({
      required String token,
      required String signId,
      required String rawQr,
      required String code,
      required String latitude,
      required String longitude,
      required String accuracy,
    });

typedef KetangpaiAccountProvider = User? Function();
typedef KetangpaiSignNotifier =
    void Function(String title, String message, bool success);
typedef KetangpaiRecordAppender = Future<void> Function(KtSignRecord record);

class SignController extends GetxController {
  SignController({
    KetangpaiSignRequest? scanSignRequest,
    KetangpaiSignRequest? gpsSignRequest,
    KetangpaiSignRequest? numberSignRequest,
    KetangpaiAccountProvider? accountProvider,
    KetangpaiSignNotifier? notifier,
    KetangpaiRecordAppender? recordAppender,
  }) : _scanSignRequest = scanSignRequest ?? _scanSign,
       _gpsSignRequest = gpsSignRequest ?? _gpsSign,
       _numberSignRequest = numberSignRequest ?? _numberSign,
       _accountProvider =
           accountProvider ?? (() => AccountManager.currentAccount),
       _notifier = notifier ?? _defaultNotifier,
       _recordAppender = recordAppender ?? _appendToRecordStore;

  final Rx<SignStatus> signStatus = SignStatus.idle.obs;
  final RxList<KtSignRecord> records = <KtSignRecord>[].obs;
  final RxString error = ''.obs;

  KetangpaiLocationPayload locationPayload = const KetangpaiLocationPayload(
    latitude: '25.3',
    longitude: '110.4',
    accuracy: '100',
  );

  final KetangpaiSignRequest _scanSignRequest;
  final KetangpaiSignRequest _gpsSignRequest;
  final KetangpaiSignRequest _numberSignRequest;
  final KetangpaiAccountProvider _accountProvider;
  final KetangpaiSignNotifier _notifier;
  final KetangpaiRecordAppender _recordAppender;

  void setLocation(KetangpaiLocationPayload payload) {
    locationPayload = payload;
  }

  Future<KtSignRecord> scanSign(String rawQr) async {
    final payload = KetangpaiScanSignPayload.fromMap(
      KetangpaiService.extractScanParams(rawQr),
      raw: rawQr,
    );
    if (!payload.isValid) {
      return _fail(
        type: '扫码签到',
        signId: payload.ticketId,
        message: '二维码参数缺失：${payload.missingKeys.join(', ')}',
      );
    }

    return _runSign(
      type: '扫码签到',
      signId: payload.ticketId,
      request: (token) => _scanSignRequest(
        token: token,
        signId: payload.ticketId,
        rawQr: rawQr,
        code: '',
        latitude: '',
        longitude: '',
        accuracy: '',
      ),
    );
  }

  Future<KtSignRecord> gpsSign(String signId) async {
    final trimmedSignId = signId.trim();
    if (trimmedSignId.isEmpty) {
      return _fail(type: 'GPS签到', signId: signId, message: '签到 ID 不能为空');
    }
    if (!locationPayload.isValid) {
      return _fail(type: 'GPS签到', signId: signId, message: 'GPS 经纬度不能为空');
    }

    return _runSign(
      type: 'GPS签到',
      signId: trimmedSignId,
      request: (token) => _gpsSignRequest(
        token: token,
        signId: trimmedSignId,
        rawQr: '',
        code: '',
        latitude: locationPayload.latitude,
        longitude: locationPayload.longitude,
        accuracy: locationPayload.accuracy,
      ),
    );
  }

  Future<KtSignRecord> numberSign(String signId, String code) async {
    final trimmedSignId = signId.trim();
    final trimmedCode = code.trim();
    if (trimmedSignId.isEmpty) {
      return _fail(type: '数字签到', signId: signId, message: '签到 ID 不能为空');
    }
    if (trimmedCode.isEmpty) {
      return _fail(type: '数字签到', signId: signId, message: '签到码不能为空');
    }

    return _runSign(
      type: '数字签到',
      signId: trimmedSignId,
      request: (token) => _numberSignRequest(
        token: token,
        signId: trimmedSignId,
        rawQr: '',
        code: trimmedCode,
        latitude: '',
        longitude: '',
        accuracy: '',
      ),
    );
  }

  Future<KtSignRecord> _runSign({
    required String type,
    required String signId,
    required Future<KetangpaiServiceResult<Map<String, dynamic>>> Function(
      String token,
    )
    request,
  }) async {
    final account = _accountProvider();
    final token = account?.token.trim() ?? '';
    if (token.isEmpty) {
      return _fail(type: type, signId: signId, message: '未登录课堂派账号');
    }

    signStatus.value = SignStatus.loading;
    error.value = '';
    try {
      final result = await request(token);
      final record = KtSignRecord.fromOutcome(
        type: type,
        signId: signId,
        courseName: type,
        account: account?.name ?? account?.uid ?? '',
        outcome: KetangpaiSignOutcome(
          success: result.success,
          message: result.message,
          code: result.code,
          state: result.state,
          raw: result.raw,
        ),
      );
      await _finish(record);
      return record;
    } catch (e) {
      return _fail(type: type, signId: signId, message: '$type异常: $e');
    }
  }

  Future<KtSignRecord> _fail({
    required String type,
    required String signId,
    required String message,
  }) async {
    final account = _accountProvider();
    final record = KtSignRecord(
      type: type,
      signId: signId,
      courseName: type,
      account: account?.name ?? account?.uid ?? '',
      status: SignStatus.failed,
      message: message,
      time: DateTime.now(),
    );
    await _finish(record);
    return record;
  }

  Future<void> _finish(KtSignRecord record) async {
    signStatus.value = record.status;
    error.value = record.success ? '' : record.message;
    records.insert(0, record);
    await _recordAppender(record);
    _notifier(record.type, record.message, record.success);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> _scanSign({
    required String token,
    required String signId,
    required String rawQr,
    required String code,
    required String latitude,
    required String longitude,
    required String accuracy,
  }) {
    return KetangpaiService.scanSign(rawQr: rawQr, token: token);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> _gpsSign({
    required String token,
    required String signId,
    required String rawQr,
    required String code,
    required String latitude,
    required String longitude,
    required String accuracy,
  }) {
    return KetangpaiService.gpsSign(
      token: token,
      signId: signId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> _numberSign({
    required String token,
    required String signId,
    required String rawQr,
    required String code,
    required String latitude,
    required String longitude,
    required String accuracy,
  }) {
    return KetangpaiService.numberSign(
      token: token,
      signId: signId,
      code: code,
    );
  }

  static Future<void> _appendToRecordStore(KtSignRecord record) {
    return SignRecordStore().append(
      platform: '课堂派',
      platformType: PlatformType.ketangpai,
      platformKey: 'ketangpai',
      courseName: record.courseName,
      account: record.account,
      status: record.success ? '成功' : '失败',
      detail: record.message,
      signTime: record.time,
    );
  }

  static void _defaultNotifier(String title, String message, bool success) {
    Get.snackbar(
      title,
      message.isEmpty ? (success ? '操作成功' : '操作失败') : message,
    );
  }
}
