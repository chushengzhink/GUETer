import 'package:flutter/foundation.dart';

import '../api/api_service.dart';
import 'sign_platform_context.dart';

enum SignRunStage {
  queued,
  sessionCheck,
  networkStart,
  networkSuccess,
  networkFailure,
  userContinue,
  userSkipped,
  signStart,
  signSuccess,
  signFailure,
  aborted,
}

class SignRunEvent {
  const SignRunEvent({
    required this.platform,
    required this.accountName,
    required this.accountId,
    required this.stage,
    required this.message,
    required this.timestamp,
    this.detail,
  });

  final String platform;
  final String accountName;
  final String accountId;
  final SignRunStage stage;
  final String message;
  final DateTime timestamp;
  final String? detail;

  bool get isFailure =>
      stage == SignRunStage.networkFailure ||
      stage == SignRunStage.signFailure ||
      stage == SignRunStage.aborted;

  bool get isSuccess => stage == SignRunStage.signSuccess;

  String get stageLabel {
    return switch (stage) {
      SignRunStage.queued => '账号排队',
      SignRunStage.sessionCheck => '会话校验',
      SignRunStage.networkStart => '开始换网',
      SignRunStage.networkSuccess => '换网成功',
      SignRunStage.networkFailure => '换网失败',
      SignRunStage.userContinue => '用户继续',
      SignRunStage.userSkipped => '用户跳过',
      SignRunStage.signStart => '开始签到',
      SignRunStage.signSuccess => '签到成功',
      SignRunStage.signFailure => '签到失败',
      SignRunStage.aborted => '异常中断',
    };
  }

  String toLine() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final suffix = detail == null || detail!.isEmpty ? '' : ' | $detail';
    return '[$time] [$platform] [$accountName/$accountId] $stageLabel: $message$suffix';
  }
}

class SignRunConsoleController extends ChangeNotifier {
  SignRunConsoleController({SignPlatformContext? platformContext})
    : _platformContext = platformContext;

  SignPlatformContext? _platformContext;
  final List<SignRunEvent> _events = <SignRunEvent>[];

  List<SignRunEvent> get events => List<SignRunEvent>.unmodifiable(_events);
  SignPlatformContext? get platformContext => _platformContext;

  int get successCount => _events.where((event) => event.isSuccess).length;
  int get failureCount => _events.where((event) => event.isFailure).length;
  int get skippedCount =>
      _events.where((event) => event.stage == SignRunStage.userSkipped).length;

  void add({
    required String platform,
    required String accountName,
    required String accountId,
    required SignRunStage stage,
    required String message,
    String? detail,
    bool mirrorToRequestConsole = true,
  }) {
    final incomingContext = SignPlatformContext.tryParse(platform);
    final boundContext = _platformContext;
    if (boundContext != null &&
        incomingContext != null &&
        incomingContext.platformKey != boundContext.platformKey) {
      ApiService.appendExternalConsoleLog(
        boundContext.platformKey,
        '[SignRunConsole] rejected cross-platform event '
        'expected=${boundContext.platformKey} actual=${incomingContext.platformKey}',
      );
      return;
    }
    _platformContext ??= incomingContext;
    final effectiveContext = _platformContext ?? incomingContext;
    final platformLabel = effectiveContext?.platformLabel ?? platform;
    final platformKey = effectiveContext?.platformKey ?? platform;

    final event = SignRunEvent(
      platform: platformLabel,
      accountName: accountName,
      accountId: accountId,
      stage: stage,
      message: message,
      detail: detail,
      timestamp: DateTime.now(),
    );
    _events.add(event);
    if (mirrorToRequestConsole) {
      ApiService.appendExternalConsoleLog(platformKey, event.toLine());
    }
    notifyListeners();
  }

  String copyText() => _events.map((event) => event.toLine()).join('\n');

  void clear() {
    _events.clear();
    notifyListeners();
  }

  void resetForPlatform(SignPlatformContext context) {
    _platformContext = context;
    clear();
  }
}
