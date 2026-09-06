import 'dart:async';

import '../models/user.dart';
import '../platform.dart';
import 'account.dart';

/// Immutable identity inherited by an asynchronous request chain. A task never
/// borrows the UI's mutable selection, including after an await or retry.
class SignExecutionContext {
  const SignExecutionContext({
    required this.platform,
    required this.account,
    required this.server,
    required this.tronclassBaseUrl,
    required this.ketangpaiBaseUrl,
  });

  static final Object _zoneKey = Object();
  static SignExecutionContext? get current =>
      Zone.current[_zoneKey] as SignExecutionContext?;

  final PlatformType platform;
  final User? account;
  final RainClassroomServerType server;
  final String tronclassBaseUrl;
  final String ketangpaiBaseUrl;

  factory SignExecutionContext.capture({User? account}) {
    final manager = PlatformManager();
    return SignExecutionContext(
      platform: manager.currentPlatform,
      account: account ?? AccountManager.currentAccount,
      server: manager.currentServer,
      tronclassBaseUrl: manager.tronclassBaseUrl,
      ketangpaiBaseUrl: manager.ketangpaiBaseUrl,
    );
  }

  SignExecutionContext withAccount(User account) => SignExecutionContext(
    platform: platform,
    account: account,
    server: server,
    tronclassBaseUrl: tronclassBaseUrl,
    ketangpaiBaseUrl: ketangpaiBaseUrl,
  );

  String get endpoint => switch (platform) {
    PlatformType.chaoxing => 'https://www.chaoxing.com',
    PlatformType.rainClassroom => switch (server) {
      RainClassroomServerType.yuketang => 'https://www.yuketang.cn',
      RainClassroomServerType.pro => 'https://pro.yuketang.cn',
      RainClassroomServerType.changjiang => 'https://changjiang.yuketang.cn',
      RainClassroomServerType.huanghe => 'https://huanghe.yuketang.cn',
    },
    PlatformType.tronclass => tronclassBaseUrl,
    PlatformType.ketangpai => ketangpaiBaseUrl,
    PlatformType.weizhuojiao => 'https://v18.teachermate.cn',
  };

  String get key => '${platform.name}|$endpoint|${account?.uid ?? ''}';

  T run<T>(T Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: this});
}
