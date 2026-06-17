import 'package:flutter/material.dart';

import '../models/user.dart';
import '../platform.dart';
import '../services/sign_network_gate.dart';
import '../services/sign_run_console.dart';
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
    BuildContext? context,
    SignRunConsoleController? console,
    SignNetworkGate? networkGate,
    bool Function()? isContextMounted,
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      context: context,
      console: console,
      networkGate: networkGate,
      isContextMounted: isContextMounted,
      signTypeLabel: '扫码签到',
      signAction: (user) => KTSignApi.scanToSignResult(scanUrl, user.token),
    );
  }

  static Future<KtFollowSignResult> signByNumber({
    required String code,
    required String signId,
    required List<User> users,
    required String courseName,
    Map<String, bool>? tokenHealthHint,
    BuildContext? context,
    SignRunConsoleController? console,
    SignNetworkGate? networkGate,
    bool Function()? isContextMounted,
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      context: context,
      console: console,
      networkGate: networkGate,
      isContextMounted: isContextMounted,
      signTypeLabel: '数字签到',
      signAction: (user) => KTSignApi.numberSignResult(
        code: code,
        token: user.token,
        signId: signId,
      ),
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
    BuildContext? context,
    SignRunConsoleController? console,
    SignNetworkGate? networkGate,
    bool Function()? isContextMounted,
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      context: context,
      console: console,
      networkGate: networkGate,
      isContextMounted: isContextMounted,
      signTypeLabel: 'GPS签到',
      signAction: (user) => KTSignApi.gpsSignResult(
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
    BuildContext? context,
    SignRunConsoleController? console,
    SignNetworkGate? networkGate,
    bool Function()? isContextMounted,
  }) {
    return _execute(
      users: users,
      courseName: courseName,
      tokenHealthHint: tokenHealthHint,
      context: context,
      console: console,
      networkGate: networkGate,
      isContextMounted: isContextMounted,
      signTypeLabel: '签入签出',
      signAction: (user) => KTSignApi.checkInOutSignResult(
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
    required Future<KetangpaiSignResult> Function(User user) signAction,
    Map<String, bool>? tokenHealthHint,
    BuildContext? context,
    SignRunConsoleController? console,
    SignNetworkGate? networkGate,
    bool Function()? isContextMounted,
  }) async {
    final failedAccounts = <String>[];
    var successCount = 0;
    final logStore = SignRecordStore();

    for (final user in users) {
      console?.add(
        platform: '课堂派',
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.sessionCheck,
        message: '检查课堂派 token',
      );

      final token = user.token.trim();
      if (token.isEmpty) {
        console?.add(
          platform: '课堂派',
          accountName: user.name,
          accountId: user.uid,
          stage: SignRunStage.signFailure,
          message: 'token为空',
        );
        failedAccounts.add('${user.name} (token为空)');
        await logStore.append(
          platform: '课堂派',
          platformType: PlatformType.ketangpai,
          courseName: courseName,
          account: user.name,
          status: '失败',
          detail: 'token为空',
        );
        continue;
      }

      final tokenHealthy =
          tokenHealthHint?[user.uid] ??
          await KTLoginApi.checkTokenStatus(token);
      if (!tokenHealthy) {
        console?.add(
          platform: '课堂派',
          accountName: user.name,
          accountId: user.uid,
          stage: SignRunStage.signFailure,
          message: 'token失效，请重新登录',
        );
        failedAccounts.add('${user.name} (token失效)');
        await logStore.append(
          platform: '课堂派',
          platformType: PlatformType.ketangpai,
          courseName: courseName,
          account: user.name,
          status: '失败',
          detail: 'token失效，请重新登录',
        );
        continue;
      }

      try {
        final gate = networkGate ?? SignNetworkGate();
        final KetangpaiSignResult signResult;
        if (context != null && console != null) {
          if (!context.mounted ||
              (isContextMounted != null && !isContextMounted())) {
            failedAccounts.add('${user.name} (页面已关闭)');
            await logStore.append(
              platform: '课堂派',
              platformType: PlatformType.ketangpai,
              courseName: courseName,
              account: user.name,
              status: '失败',
              detail: '页面已关闭',
            );
            continue;
          }
          final gateResult = await gate.run<KetangpaiSignResult>(
            context: context,
            platformLabel: '课堂派',
            user: user,
            console: console,
            action: () => signAction(user),
          );
          if (gateResult.skipped) {
            final reason = gateResult.reason ?? '用户跳过';
            failedAccounts.add('${user.name} ($reason)');
            await logStore.append(
              platform: '课堂派',
              platformType: PlatformType.ketangpai,
              courseName: courseName,
              account: user.name,
              status: '失败',
              detail: reason,
            );
            continue;
          }
          signResult =
              gateResult.value ?? KetangpaiSignResult.failure('???????');
        } else {
          signResult = await signAction(user);
        }

        if (signResult.success) {
          successCount++;
          console?.add(
            platform: '课堂派',
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.signSuccess,
            message: '$signTypeLabel 成功',
          );
          await logStore.append(
            platform: '课堂派',
            platformType: PlatformType.ketangpai,
            courseName: courseName,
            account: user.name,
            status: '成功',
            detail: signResult.message.isNotEmpty
                ? '$signTypeLabel: ${signResult.message}'
                : signTypeLabel,
          );
        } else {
          final reason = signResult.message.isNotEmpty
              ? signResult.message
              : '$signTypeLabel 失败';
          console?.add(
            platform: '课堂派',
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.signFailure,
            message: reason,
          );
          failedAccounts.add('${user.name} ($reason)');
          await logStore.append(
            platform: '课堂派',
            platformType: PlatformType.ketangpai,
            courseName: courseName,
            account: user.name,
            status: '失败',
            detail: reason,
          );
        }
      } catch (e) {
        console?.add(
          platform: '课堂派',
          accountName: user.name,
          accountId: user.uid,
          stage: SignRunStage.aborted,
          message: '$signTypeLabel 异常',
          detail: e.toString(),
        );
        failedAccounts.add('${user.name} (异常：$e)');
        await logStore.append(
          platform: '课堂派',
          platformType: PlatformType.ketangpai,
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
