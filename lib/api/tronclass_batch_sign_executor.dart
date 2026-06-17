import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/user.dart';
import '../platform.dart';
import '../services/session_health_service.dart';
import '../services/sign_network_gate.dart';
import '../services/sign_platform_context.dart';
import '../services/sign_run_console.dart';
import '../session/account.dart';
import '../session/sign_record_store.dart';
import 'tronclass_sign_api.dart';

enum TronclassBatchSignKind { number, qr, radar }

enum TronclassBatchNetworkPolicy { strict, qrFastFirst }

class TronclassBatchSignItemResult {
  const TronclassBatchSignItemResult({
    required this.user,
    required this.success,
    required this.message,
    this.skipped = false,
  });

  final User user;
  final bool success;
  final bool skipped;
  final String message;
}

class TronclassBatchSignResult {
  const TronclassBatchSignResult({required this.items});

  final List<TronclassBatchSignItemResult> items;

  int get totalCount => items.length;
  int get successCount => items.where((item) => item.success).length;
  int get skippedCount => items.where((item) => item.skipped).length;
  int get failedCount => totalCount - successCount - skippedCount;
}

typedef TronclassSignAction =
    Future<Response<dynamic>> Function(User user, String deviceId);

typedef TronclassSessionHealthChecker = Future<bool> Function(User user);

class TronclassBatchSignExecutor {
  TronclassBatchSignExecutor({
    SignNetworkGate? networkGate,
    SignRecordStore? recordStore,
    SessionHealthService? sessionHealthService,
    TronclassSessionHealthChecker? sessionHealthChecker,
  }) : _networkGate = networkGate ?? SignNetworkGate(),
       _recordStore = recordStore ?? SignRecordStore(),
       _sessionHealthService = sessionHealthService ?? SessionHealthService(),
       _sessionHealthChecker = sessionHealthChecker;

  final SignNetworkGate _networkGate;
  final SignRecordStore _recordStore;
  final SessionHealthService _sessionHealthService;
  final TronclassSessionHealthChecker? _sessionHealthChecker;

  Future<TronclassBatchSignResult> sign({
    required BuildContext context,
    required String courseName,
    required SignRunConsoleController console,
    required TronclassSignAction action,
    List<User>? users,
    bool Function()? isContextMounted,
    TronclassBatchNetworkPolicy networkPolicy =
        TronclassBatchNetworkPolicy.strict,
  }) async {
    final accounts =
        users ?? AccountManager.getAccountsForPlatform(PlatformType.tronclass);
    console.resetForPlatform(SignPlatformContext.tronclass);
    final originalSession = AccountManager.currentSessionId;
    final results = <TronclassBatchSignItemResult>[];
    var qrCodeExpired = false;

    try {
      for (var index = 0; index < accounts.length; index++) {
        final user = accounts[index];
        if (qrCodeExpired) {
          const message = '签到二维码已过期，请重新扫码';
          console.add(
            platform: '畅课',
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.userSkipped,
            message: message,
          );
          await _appendRecord(courseName, user, false, message);
          results.add(
            TronclassBatchSignItemResult(
              user: user,
              success: false,
              skipped: true,
              message: message,
            ),
          );
          continue;
        }

        console.add(
          platform: '畅课',
          accountName: user.name,
          accountId: user.uid,
          stage: SignRunStage.sessionCheck,
          message: '检查畅课会话',
        );

        final health = await _checkSessionHealth(user);
        if (!health.healthy) {
          final message = health.message;
          console.add(
            platform: '畅课',
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.signFailure,
            message: message,
          );
          await _appendRecord(courseName, user, false, message);
          results.add(
            TronclassBatchSignItemResult(
              user: user,
              success: false,
              message: message,
            ),
          );
          continue;
        }

        AccountManager.setCurrentSessionTemp(user.uid);
        if (!context.mounted ||
            (isContextMounted != null && !isContextMounted())) {
          const message = '页面已关闭';
          await _appendRecord(courseName, user, false, message);
          results.add(
            TronclassBatchSignItemResult(
              user: user,
              success: false,
              skipped: true,
              message: message,
            ),
          );
          continue;
        }

        final response = await _runAction(
          context: context,
          user: user,
          console: console,
          action: action,
          skipNetworkGate:
              networkPolicy == TronclassBatchNetworkPolicy.qrFastFirst &&
              index == 0,
        );
        if (response.skipped) {
          await _appendRecord(courseName, user, false, response.message);
          results.add(
            TronclassBatchSignItemResult(
              user: user,
              success: false,
              skipped: true,
              message: response.message,
            ),
          );
          continue;
        }

        final signResponse = response.response;
        final success =
            signResponse != null && TronclassSignApi.isSignSuccess(signResponse);
        final message = signResponse == null
            ? '签到无响应'
            : TronclassSignApi.getSignMessage(signResponse.data);
        console.add(
          platform: '畅课',
          accountName: user.name,
          accountId: user.uid,
          stage: success ? SignRunStage.signSuccess : SignRunStage.signFailure,
          message: message,
        );
        await _appendRecord(courseName, user, success, message);
        results.add(
          TronclassBatchSignItemResult(
            user: user,
            success: success,
            message: message,
          ),
        );
        if (!success && signResponse != null) {
          qrCodeExpired = TronclassSignApi.isQrCodeExpired(signResponse.data);
        }
      }
    } finally {
      if (originalSession != null && originalSession.isNotEmpty) {
        AccountManager.setCurrentSessionTemp(originalSession);
      }
    }

    return TronclassBatchSignResult(items: results);
  }

  Future<_TronclassActionResult> _runAction({
    required BuildContext context,
    required User user,
    required SignRunConsoleController console,
    required TronclassSignAction action,
    required bool skipNetworkGate,
  }) async {
    if (!skipNetworkGate) {
      final gateResult = await _networkGate.run<Response<dynamic>>(
        context: context,
        platformLabel: '畅课',
        user: user,
        console: console,
        action: () => action(user, const Uuid().v4()),
      );
      if (gateResult.skipped) {
        return _TronclassActionResult.skipped(gateResult.reason ?? '用户跳过');
      }
      return _TronclassActionResult.response(gateResult.value);
    }

    console.add(
      platform: '畅课',
      accountName: user.name,
      accountId: user.uid,
      stage: SignRunStage.queued,
      message: '等待签到',
    );
    console.add(
      platform: '畅课',
      accountName: user.name,
      accountId: user.uid,
      stage: SignRunStage.userContinue,
      message: '极速防过期：首账号跳过换网直接提交',
    );
    console.add(
      platform: '畅课',
      accountName: user.name,
      accountId: user.uid,
      stage: SignRunStage.signStart,
      message: '开始提交签到',
    );
    try {
      return _TronclassActionResult.response(
        await action(user, const Uuid().v4()),
      );
    } catch (e) {
      console.add(
        platform: '畅课',
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.aborted,
        message: '签到请求异常',
        detail: e.toString(),
      );
      rethrow;
    }
  }

  Future<_TronclassHealthResult> _checkSessionHealth(User user) async {
    final checker = _sessionHealthChecker;
    if (checker != null) {
      return _TronclassHealthResult(
        healthy: await checker(user),
        message: '畅课会话无效，请重新登录',
      );
    }
    final health = await _sessionHealthService.checkUser(
      user,
      platform: PlatformType.tronclass,
    );
    return _TronclassHealthResult(
      healthy: health.healthy,
      message: health.issue?.reason ?? '畅课会话无效，请重新登录',
    );
  }

  Future<void> _appendRecord(
    String courseName,
    User user,
    bool success,
    String detail,
  ) {
    return _recordStore.append(
      platform: '畅课',
      platformType: PlatformType.tronclass,
      courseName: courseName,
      account: user.name,
      status: success ? '成功' : '失败',
      detail: detail,
    );
  }
}

class _TronclassActionResult {
  const _TronclassActionResult._({
    required this.skipped,
    required this.message,
    this.response,
  });

  final bool skipped;
  final String message;
  final Response<dynamic>? response;

  factory _TronclassActionResult.response(Response<dynamic>? response) {
    return _TronclassActionResult._(
      skipped: false,
      message: '',
      response: response,
    );
  }

  factory _TronclassActionResult.skipped(String message) {
    return _TronclassActionResult._(skipped: true, message: message);
  }
}

class _TronclassHealthResult {
  const _TronclassHealthResult({
    required this.healthy,
    required this.message,
  });

  final bool healthy;
  final String message;
}
