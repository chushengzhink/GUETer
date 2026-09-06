import 'controllers/account_context_controller.dart';
import 'session/sign_execution_context.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../api/api_service.dart';
import '../session/account.dart';

/// 平台类型枚举
enum PlatformType {
  chaoxing, // 学习通
  rainClassroom, // 雨课堂
  tronclass, // 畅课
  ketangpai, // 课堂派
  weizhuojiao, // 微助教
}

/// 雨课堂服务器类型枚举
enum RainClassroomServerType {
  yuketang, // 雨课堂
  pro, // 荷塘雨课堂
  changjiang, // 长江雨课堂
  huanghe, // 黄河雨课堂
}

/// 平台状态管理器
class PlatformManager {
  static final PlatformManager _instance = PlatformManager._internal();
  factory PlatformManager() => _instance;
  PlatformManager._internal();

  late SharedPreferences _prefs;
  static const _platformKey = 'current_platform';
  static const _serverKey = 'current_server';
  static const _tronclassBaseUrlKey = 'tronclass_base_url';
  static const _ketangpaiBaseUrlKey = 'ketangpai_base_url';
  PlatformType _currentPlatform = PlatformType.chaoxing;
  RainClassroomServerType _currentServer = RainClassroomServerType.yuketang;
  String _tronclassBaseUrl = 'https://courses.guet.edu.cn';
  String _ketangpaiBaseUrl = 'https://openapiv5.ketangpai.com';

  // 平台变化通知流
  final StreamController<PlatformType> _platformChangeController =
      StreamController<PlatformType>.broadcast();
  Stream<PlatformType> get platformChanges => _platformChangeController.stream;

  /// 获取当前平台
  PlatformType get currentPlatform =>
      SignExecutionContext.current?.platform ?? _currentPlatform;

  bool get isChaoxing => currentPlatform == PlatformType.chaoxing;
  bool get isRainClassroom => currentPlatform == PlatformType.rainClassroom;
  bool get isTronclass => currentPlatform == PlatformType.tronclass;
  bool get isKetangpai => currentPlatform == PlatformType.ketangpai;
  bool get isWeizhuojiao => currentPlatform == PlatformType.weizhuojiao;
  String get tronclassBaseUrl =>
      SignExecutionContext.current?.tronclassBaseUrl ?? _tronclassBaseUrl;
  String get ketangpaiBaseUrl =>
      SignExecutionContext.current?.ketangpaiBaseUrl ?? _ketangpaiBaseUrl;

  /// 同步切换平台（不触发异步操作）
  void setPlatformSync(PlatformType platform) {
    _currentPlatform = platform;
  }

  Future<void> activatePlatformForLoginCompletion(PlatformType platform) async {
    await AccountContextController.instance.select(
      platform,
      accountId: AccountManager.currentSessionForPlatform(platform),
    );
    if (AccountContextController.instance.error != null) {
      throw StateError('Unable to restore login context');
    }
  }

  /// 获取当前雨课堂服务器
  RainClassroomServerType get currentServer =>
      SignExecutionContext.current?.server ?? _currentServer;

  /// 获取雨课堂服务器名称
  String get serverName {
    switch (currentServer) {
      case RainClassroomServerType.yuketang:
        return 'yuketang';
      case RainClassroomServerType.pro:
        return 'pro';
      case RainClassroomServerType.changjiang:
        return 'changjiang';
      case RainClassroomServerType.huanghe:
        return 'huanghe';
    }
  }

  /// 初始化平台
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final platformStr = _prefs.getString(_platformKey);

      if (platformStr != null && platformStr.isNotEmpty) {
        switch (platformStr.toLowerCase()) {
          case 'chaoxing':
            _currentPlatform = PlatformType.chaoxing;
            break;
          case 'rainclassroom':
            _currentPlatform = PlatformType.rainClassroom;
            break;
          case 'tronclass':
            _currentPlatform = PlatformType.tronclass;
            break;
          case 'ketangpai':
            _currentPlatform = PlatformType.ketangpai;
            break;
          case 'weizhuojiao':
            _currentPlatform = PlatformType.weizhuojiao;
            break;
        }
      }

      final tronclassBaseUrl = _prefs.getString(_tronclassBaseUrlKey);
      if (tronclassBaseUrl != null && tronclassBaseUrl.trim().isNotEmpty) {
        _tronclassBaseUrl = _normalizeBaseUrl(tronclassBaseUrl);
      }

      final ketangpaiBaseUrl = _prefs.getString(_ketangpaiBaseUrlKey);
      if (ketangpaiBaseUrl != null && ketangpaiBaseUrl.trim().isNotEmpty) {
        _ketangpaiBaseUrl = _normalizeBaseUrl(ketangpaiBaseUrl);
      }

      // 加载雨课堂服务器设置
      final serverStr = _prefs.getString(_serverKey);
      if (serverStr != null && serverStr.isNotEmpty) {
        switch (serverStr.toLowerCase()) {
          case 'yuketang':
            _currentServer = RainClassroomServerType.yuketang;
            break;
          case 'pro':
            _currentServer = RainClassroomServerType.pro;
            break;
          case 'changjiang':
            _currentServer = RainClassroomServerType.changjiang;
            break;
          case 'huanghe':
            _currentServer = RainClassroomServerType.huanghe;
            break;
        }
      }

      // 触发平台变化回调，初始化 headers
      ApiService.onPlatformChange!();
      debugPrint(
        '[Platform] initialized platform=$_currentPlatform server=$serverName tronclass=$_tronclassBaseUrl ketangpai=$_ketangpaiBaseUrl',
      );
    } catch (e) {
      debugPrint('加载平台失败：$e');
    }
  }

  /// 设置平台（唯一写入口，仅由用户主动操作触发）
  Future<void> setPlatform(
    PlatformType platform, {
    bool userInitiated = true,
  }) async {
    if (!userInitiated) return;
    await AccountContextController.instance.select(platform);
  }

  /// Only the account context coordinator calls this local commit operation.
  Future<void> applyPlatformSelection(
    PlatformType platform, {
    bool notify = true,
  }) async {
    if (_currentPlatform == platform) return;
    final previous = _currentPlatform;
    _currentPlatform = platform;
    try {
      await _prefs.setString(_platformKey, currentPlatformName);
      await AccountManager.switchToPlatformAccount(refreshFromStorage: false);
      final userId = AccountManager.currentSessionId;
      if (userId != null) await CookieManager.getCookieJarForUser(userId);
      ApiService.onPlatformChange?.call();
      if (notify) _platformChangeController.add(platform);
    } catch (_) {
      _currentPlatform = previous;
      await _prefs.setString(_platformKey, currentPlatformName);
      await AccountManager.switchToPlatformAccount(refreshFromStorage: false);
      ApiService.onPlatformChange?.call();
      rethrow;
    }
  }

  Future<void> setServer(RainClassroomServerType server) =>
      AccountContextController.instance.select(currentPlatform, server: server);

  Future<void> setTronclassBaseUrl(String baseUrl) => AccountContextController
      .instance
      .select(currentPlatform, tronclassBaseUrl: _normalizeBaseUrl(baseUrl));

  Future<void> setKetangpaiBaseUrl(String baseUrl) => AccountContextController
      .instance
      .select(currentPlatform, ketangpaiBaseUrl: _normalizeBaseUrl(baseUrl));

  /// The coordinator serializes site changes with platform/account commits.
  Future<void> applySiteSelection({
    required RainClassroomServerType server,
    required String tronclassBaseUrl,
    required String ketangpaiBaseUrl,
  }) async {
    if (_currentServer != server) {
      if (!await _prefs.setString(_serverKey, server.name)) {
        throw StateError('Unable to save server');
      }
      _currentServer = server;
    }
    if (_tronclassBaseUrl != tronclassBaseUrl) {
      if (!await _prefs.setString(_tronclassBaseUrlKey, tronclassBaseUrl)) {
        throw StateError('Unable to save site');
      }
      _tronclassBaseUrl = tronclassBaseUrl;
    }
    if (_ketangpaiBaseUrl != ketangpaiBaseUrl) {
      if (!await _prefs.setString(_ketangpaiBaseUrlKey, ketangpaiBaseUrl)) {
        throw StateError('Unable to save site');
      }
      _ketangpaiBaseUrl = ketangpaiBaseUrl;
    }
  }

  void notifyContextChanged() {
    ApiService.onPlatformChange?.call();
    _platformChangeController.add(_currentPlatform);
  }

  String _normalizeBaseUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 'https://courses.guet.edu.cn';
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
  }

  /// 获取平台字符串标识
  String get currentPlatformName {
    switch (currentPlatform) {
      case PlatformType.chaoxing:
        return 'chaoxing';
      case PlatformType.rainClassroom:
        return 'rainclassroom';
      case PlatformType.tronclass:
        return 'tronclass';
      case PlatformType.ketangpai:
        return 'ketangpai';
      case PlatformType.weizhuojiao:
        return 'weizhuojiao';
    }
  }

  void dispose() {
    _platformChangeController.close();
  }
}
