import '../models/user.dart';
import '../session/sign_record_store.dart';
import 'kt_sign.dart';
import 'login.dart';

class KtFollowSignResult {
  const KtFollowSignResult({
    required this.successCount,
    required this.totalCount,
    required this.failedAccounts,
  });

  final int successCount;
  final int totalCount;
  final List<String> failedAccounts;
}

class KtFollowSignExecutor {
  static Future<KtFollowSignResult> signByScan({
    required String scanUrl,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      signTypeLabel: '扫码签到',
      signAction: (user) => KTSignApi.scanToSign(scanUrl, user.token),
    );
  }

  static Future<KtFollowSignResult> signByNumber({
    required String code,
    required String signId,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      signTypeLabel: '数字签到',
      signAction: (user) =>
          KTSignApi.numberSign(code: code, token: user.token, signId: signId),
    );
  }

  static Future<KtFollowSignResult> signByGps({
    required String signId,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
    String? latitude,
    String? longitude,
    String? accuracy,
    String? courseId, // 新增：用于从课程设置读取坐标
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      signTypeLabel: 'GPS签到',
      signAction: (user) => KTSignApi.gpsSign(
        token: user.token,
        signId: signId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        courseId: courseId,
      ),
    );
  }

  static Future<KtFollowSignResult> signByCheckInOut({
    required String signId,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
    String? latitude,
    String? longitude,
    String? accuracy,
    String? courseId, // 新增：用于从课程设置读取坐标
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      signTypeLabel: '签入签出',
      signAction: (user) => KTSignApi.checkInOutSign(
        token: user.token,
        signId: signId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      ),
    );
  }

  static Future<KtFollowSignResult> _execute({
    required List<User> users,
    required String courseName,
    required String signTypeLabel,
    required Future<bool> Function(User user) signAction,
    Map<String, bool>? tokenHealthHint,
  }) async {
    final failedAccounts = <String>[];
    var successCount = 0;
    final logStore = SignRecordStore();

    for (final user in users) {
      final token = user.token.trim();
      if (token.isEmpty) {
        failedAccounts.add('${user.name} (token为空)');
        await logStore.append(
          platform: '课堂派',
          courseName: courseName,
          account: user.name,
          status: '失败',
          detail: 'token为空',
        );
        continue;
      }

      final tokenHealthy =
          tokenHealthHint?[user.uid] ?? await KTLoginApi.checkTokenStatus(token);
      if (!tokenHealthy) {
        failedAccounts.add('${user.name} (token失效)');
        await logStore.append(
          platform: '课堂派',
          courseName: courseName,
          account: user.name,
          status: '失败',
          detail: 'token失效，请重新登录',
        );
        continue;
      }

      try {
        final ok = await signAction(user);
        if (ok) {
          successCount++;
          await logStore.append(
            platform: '课堂派',
            courseName: courseName,
            account: user.name,
            status: '成功',
            detail: signTypeLabel,
          );
        } else {
          failedAccounts.add('${user.name} (签到失败)');
          await logStore.append(
            platform: '课堂派',
            courseName: courseName,
            account: user.name,
            status: '失败',
            detail: '$signTypeLabel 失败',
          );
        }
      } catch (e) {
        failedAccounts.add('${user.name} (异常：$e)');
        await logStore.append(
          platform: '课堂派',
          courseName: courseName,
          account: user.name,
          status: '失败',
          detail: '$signTypeLabel 异常: $e',
        );
      }
    }

    return KtFollowSignResult(
      successCount: successCount,
      totalCount: users.length,
      failedAccounts: failedAccounts,
    );
  }
}
