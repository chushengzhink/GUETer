import 'package:flutter/material.dart';

import '../models/user.dart';
import 'mobile_data_reconnect_service.dart';
import 'sign_run_console.dart';

enum SignNetworkDecision { proceed, skipped }

class SignNetworkGateResult<T> {
  const SignNetworkGateResult({
    required this.decision,
    this.value,
    this.networkResult,
    this.reason,
  });

  final SignNetworkDecision decision;
  final T? value;
  final MobileDataReconnectResult? networkResult;
  final String? reason;

  bool get skipped => decision == SignNetworkDecision.skipped;
}

class SignNetworkGate {
  SignNetworkGate({MobileDataReconnectService? service})
    : _service = service ?? MobileDataReconnectService();

  final MobileDataReconnectService _service;

  Future<SignNetworkGateResult<T>> run<T>({
    required BuildContext context,
    required String platformLabel,
    required User user,
    required SignRunConsoleController console,
    required Future<T> Function() action,
  }) async {
    console.add(
      platform: platformLabel,
      accountName: user.name,
      accountId: user.uid,
      stage: SignRunStage.queued,
      message: '等待签到',
    );
    console.add(
      platform: platformLabel,
      accountName: user.name,
      accountId: user.uid,
      stage: SignRunStage.networkStart,
      message: '开始重启移动数据',
    );

    final networkResult = await _service.restartForSign();
    var canProceed =
        networkResult.success &&
        (networkResult.ipChanged ||
            networkResult.ipBefore == null ||
            networkResult.ipAfter == null);

    if (networkResult.success) {
      console.add(
        platform: platformLabel,
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.networkSuccess,
        message: networkResult.ipChanged ? '公网 IP 已变化' : networkResult.message,
        detail: _ipDetail(networkResult),
      );
    } else {
      console.add(
        platform: platformLabel,
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.networkFailure,
        message: networkResult.message,
        detail: _ipDetail(networkResult),
      );

      if (networkResult.requiresManualAction && context.mounted) {
        final manualDecision = await _showManualReconnectDialog(
          context: context,
          accountName: user.name,
          platformLabel: platformLabel,
          message: networkResult.message,
        );
        if (manualDecision == SignNetworkDecision.skipped) {
          console.add(
            platform: platformLabel,
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.userSkipped,
            message: '用户选择跳过',
          );
          return SignNetworkGateResult<T>(
            decision: SignNetworkDecision.skipped,
            networkResult: networkResult,
            reason: '用户跳过换网失败账号',
          );
        }
        await _service.openNetworkSettings();
        if (!context.mounted) {
          return SignNetworkGateResult<T>(
            decision: SignNetworkDecision.skipped,
            networkResult: networkResult,
            reason: '页面已关闭',
          );
        }
        final afterManual = await _showManualDoneDialog(
          context: context,
          accountName: user.name,
          platformLabel: platformLabel,
          ipBefore: networkResult.ipBefore,
        );
        if (afterManual.decision == SignNetworkDecision.skipped) {
          console.add(
            platform: platformLabel,
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.userSkipped,
            message: afterManual.reason ?? '用户选择跳过',
          );
          return SignNetworkGateResult<T>(
            decision: SignNetworkDecision.skipped,
            networkResult: afterManual.networkResult ?? networkResult,
            reason: afterManual.reason,
          );
        }
        canProceed = true;
        console.add(
          platform: platformLabel,
          accountName: user.name,
          accountId: user.uid,
          stage: SignRunStage.userContinue,
          message: '用户确认继续签到',
          detail: _ipDetail(afterManual.networkResult ?? networkResult),
        );
      }
    }

    if (!canProceed && context.mounted) {
      final decision = await _confirmProceedAfterNetworkIssue(
        context: context,
        accountName: user.name,
        platformLabel: platformLabel,
        result: networkResult,
      );
      if (decision == SignNetworkDecision.skipped) {
        console.add(
          platform: platformLabel,
          accountName: user.name,
          accountId: user.uid,
          stage: SignRunStage.userSkipped,
          message: '用户选择跳过',
        );
        return SignNetworkGateResult<T>(
          decision: SignNetworkDecision.skipped,
          networkResult: networkResult,
          reason: '换网未确认',
        );
      }
      console.add(
        platform: platformLabel,
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.userContinue,
        message: '换网未确认，用户选择继续',
        detail: _ipDetail(networkResult),
      );
    }

    console.add(
      platform: platformLabel,
      accountName: user.name,
      accountId: user.uid,
      stage: SignRunStage.signStart,
      message: '开始提交签到',
    );

    try {
      final value = await action();
      return SignNetworkGateResult<T>(
        decision: SignNetworkDecision.proceed,
        value: value,
        networkResult: networkResult,
      );
    } catch (e) {
      console.add(
        platform: platformLabel,
        accountName: user.name,
        accountId: user.uid,
        stage: SignRunStage.aborted,
        message: '签到请求异常',
        detail: e.toString(),
      );
      rethrow;
    }
  }

  Future<SignNetworkDecision> _showManualReconnectDialog({
    required BuildContext context,
    required String platformLabel,
    required String accountName,
    required String message,
  }) async {
    return await showDialog<SignNetworkDecision>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('需要手动重启移动数据'),
            content: Text(
              '$platformLabel 账号 $accountName 签到前需要更换网络。\n\n$message\n\n'
              '下一步会打开系统网络设置，请先开启移动数据、关闭、再开启，然后返回应用确认。',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, SignNetworkDecision.skipped),
                child: const Text('跳过该账号'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, SignNetworkDecision.proceed),
                child: const Text('去设置'),
              ),
            ],
          ),
        ) ??
        SignNetworkDecision.skipped;
  }

  Future<SignNetworkGateResult<void>> _showManualDoneDialog({
    required BuildContext context,
    required String platformLabel,
    required String accountName,
    String? ipBefore,
  }) async {
    final decision =
        await showDialog<SignNetworkDecision>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('确认已完成换网'),
            content: Text(
              '请确认已为 $platformLabel 账号 $accountName 完成移动数据“开-关-开”。',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, SignNetworkDecision.skipped),
                child: const Text('跳过该账号'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, SignNetworkDecision.proceed),
                child: const Text('已完成，继续'),
              ),
            ],
          ),
        ) ??
        SignNetworkDecision.skipped;

    if (decision == SignNetworkDecision.skipped) {
      return const SignNetworkGateResult<void>(
        decision: SignNetworkDecision.skipped,
        reason: '用户未确认手动换网',
      );
    }

    final verified = await _service.verifyManualReconnect(ipBefore: ipBefore);
    if (!verified.ipChanged && context.mounted) {
      final continueAnyway = await _confirmProceedAfterNetworkIssue(
        context: context,
        accountName: accountName,
        platformLabel: platformLabel,
        result: verified,
      );
      if (continueAnyway == SignNetworkDecision.skipped) {
        return SignNetworkGateResult<void>(
          decision: SignNetworkDecision.skipped,
          networkResult: verified,
          reason: verified.message,
        );
      }
    }

    return SignNetworkGateResult<void>(
      decision: SignNetworkDecision.proceed,
      networkResult: verified,
    );
  }

  Future<SignNetworkDecision> _confirmProceedAfterNetworkIssue({
    required BuildContext context,
    required String platformLabel,
    required String accountName,
    required MobileDataReconnectResult result,
  }) async {
    return await showDialog<SignNetworkDecision>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('无法确认已更换 IP'),
            content: Text(
              '$platformLabel 账号 $accountName 的网络换新未完全确认。\n\n'
              '${result.message}\n${_ipDetail(result)}\n\n是否仍继续签到？',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, SignNetworkDecision.skipped),
                child: const Text('跳过该账号'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, SignNetworkDecision.proceed),
                child: const Text('继续签到'),
              ),
            ],
          ),
        ) ??
        SignNetworkDecision.skipped;
  }

  static String _ipDetail(MobileDataReconnectResult? result) {
    if (result == null) return '';
    final before = result.ipBefore ?? '未知';
    final after = result.ipAfter ?? '未知';
    return 'IP: $before -> $after';
  }
}
