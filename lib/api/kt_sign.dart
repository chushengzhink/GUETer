import 'api_service.dart';
import 'ketangpai_response.dart';
import 'ketangpai_service.dart';
import '../models/ketangpai_sign.dart';

class KetangpaiSignResult {
  const KetangpaiSignResult({
    required this.success,
    this.message = '',
    this.code,
    this.state,
    this.raw,
  });

  final bool success;
  final String message;
  final int? code;
  final int? state;
  final dynamic raw;

  static KetangpaiSignResult failure(String message, {dynamic raw}) {
    return KetangpaiSignResult(success: false, message: message, raw: raw);
  }

  factory KetangpaiSignResult.fromResponse(
    dynamic data, {
    bool Function(Map<String, dynamic> map)? successWhen,
  }) {
    final map = asKetangpaiMap(data) ?? const <String, dynamic>{};
    final dataMap = asKetangpaiMap(map['data']);
    final state = _intOrNull(dataMap?['state']);
    final code = _intOrNull(map['code']);
    final success = successWhen?.call(map) ?? isKetangpaiSuccess(map);
    return KetangpaiSignResult(
      success: success,
      message: ketangpaiMessageOf(map),
      code: code,
      state: state,
      raw: data,
    );
  }

  static int? _intOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  KetangpaiSignOutcome toOutcome() {
    return KetangpaiSignOutcome(
      success: success,
      message: message,
      code: code,
      state: state,
      raw: raw,
    );
  }
}

class KTSignApi {
  @pragma('vm:prefer-inline')
  static Map<String, String> extractScanParams(String rawUrl) {
    return KetangpaiService.extractScanParams(rawUrl);
  }

  static KetangpaiScanSignPayload parseScanPayload(String rawUrl) {
    return KetangpaiScanSignPayload.fromMap(
      extractScanParams(rawUrl),
      raw: rawUrl,
    );
  }

  static Future<bool> scanToSign(String params, String token) async {
    try {
      final result = await KetangpaiService.scanSign(
        rawQr: params,
        token: token,
      );
      KetangpaiService.logResult('二维码签到', result);
      return result.success;
    } catch (e) {
      ApiService.appendExternalConsoleLog('课堂派', '二维码签到异常: $e');
      return false;
    }
  }

  /// Fetch the number code for a sign-in task
  static Future<String?> getNumberCode({
    required String token,
    required String signId,
  }) async {
    try {
      final result = await KetangpaiService.getNumberCode(
        token: token,
        signId: signId,
      );
      if (!result.success) {
        KetangpaiService.logResult('获取数字签到码', result);
        return null;
      }
      final code = result.data?['data']?['code']?.toString();
      if (code != null && code.isNotEmpty) {
        KetangpaiService.logResult('获取数字签到码', result);
        return code;
      }
      return null;
    } catch (e) {
      ApiService.appendExternalConsoleLog('课堂派', '获取数字签到码失败: $e');
      return null;
    }
  }

  /// Check-in/check-out sign-in (type 4)
  static Future<bool> checkInOutSign({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
  }) async {
    try {
      final result = await KetangpaiService.gpsSign(
        token: token,
        signId: signId,
        latitude: latitude ?? '',
        longitude: longitude ?? '',
        accuracy: accuracy ?? '100',
      );
      KetangpaiService.logResult('签入签出', result);
      return result.success;
    } catch (e) {
      ApiService.appendExternalConsoleLog('课堂派', '签入签出异常: $e');
      return false;
    }
  }

  static Future<bool> numberSign({
    required String code,
    required String token,
    required String signId,
  }) async {
    try {
      final result = await KetangpaiService.numberSign(
        token: token,
        signId: signId,
        code: code,
      );
      KetangpaiService.logResult('数字签到', result);
      return result.success;
    } catch (e) {
      ApiService.appendExternalConsoleLog('课堂派', '数字签到异常: $e');
      return false;
    }
  }

  static Future<bool> gpsSign({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
    String? courseId,
  }) async {
    // 优先使用传入的坐标，否则尝试从课程设置读取
    String finalLatitude = latitude ?? '';
    String finalLongitude = longitude ?? '';
    String finalAccuracy = accuracy ?? '100';

    if (finalLatitude.isEmpty || finalLongitude.isEmpty) {
      if (finalLatitude.isEmpty || finalLongitude.isEmpty) {
        finalLatitude = '25.3';
        finalLongitude = '110.4';
        ApiService.appendExternalConsoleLog(
          '课堂派',
          'GPS签到: 使用默认坐标 lat=$finalLatitude lng=$finalLongitude',
        );
      }
    }

    try {
      final result = await KetangpaiService.gpsSign(
        token: token,
        signId: signId,
        latitude: finalLatitude,
        longitude: finalLongitude,
        accuracy: finalAccuracy,
      );
      KetangpaiService.logResult('GPS签到', result);
      return result.success;
    } catch (e) {
      ApiService.appendExternalConsoleLog('课堂派', 'GPS签到异常: $e');
      return false;
    }
  }

  static Future<KetangpaiSignResult> scanToSignResult(
    String params,
    String token,
  ) async {
    try {
      final result = await KetangpaiService.scanSign(
        rawQr: params,
        token: token,
      );
      return KetangpaiSignResult(
        success: result.success,
        message: result.message,
        code: result.code,
        state: result.state,
        raw: result.raw,
      );
    } catch (e) {
      return KetangpaiSignResult.failure('二维码签到异常: $e');
    }
  }

  static Future<KetangpaiSignResult> numberSignResult({
    required String code,
    required String token,
    required String signId,
  }) async {
    if (code.trim().isEmpty) {
      return KetangpaiSignResult.failure('签到码为空');
    }
    try {
      final result = await KetangpaiService.numberSign(
        token: token,
        signId: signId,
        code: code,
      );
      return KetangpaiSignResult(
        success: result.success,
        message: result.message,
        code: result.code,
        state: result.state,
        raw: result.raw,
      );
    } catch (e) {
      return KetangpaiSignResult.failure('数字签到异常: $e');
    }
  }

  static Future<KetangpaiSignResult> checkInOutSignResult({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
  }) async {
    try {
      final result = await KetangpaiService.gpsSign(
        token: token,
        signId: signId,
        latitude: latitude ?? '',
        longitude: longitude ?? '',
        accuracy: accuracy ?? '100',
      );
      return KetangpaiSignResult(
        success: result.success,
        message: result.message,
        code: result.code,
        state: result.state,
        raw: result.raw,
      );
    } catch (e) {
      return KetangpaiSignResult.failure('签入签出异常: $e');
    }
  }

  static Future<KetangpaiSignResult> gpsSignResult({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
    String? courseId,
  }) async {
    if ((latitude?.trim().isEmpty ?? true) ||
        (longitude?.trim().isEmpty ?? true)) {
      return KetangpaiSignResult.failure('GPS 经纬度不能为空');
    }
    try {
      final result = await KetangpaiService.gpsSign(
        token: token,
        signId: signId,
        latitude: latitude!,
        longitude: longitude!,
        accuracy: accuracy ?? '100',
      );
      return KetangpaiSignResult(
        success: result.success,
        message: result.message,
        code: result.code,
        state: result.state,
        raw: result.raw,
      );
    } catch (e) {
      return KetangpaiSignResult.failure('GPS签到异常: $e');
    }
  }
}
