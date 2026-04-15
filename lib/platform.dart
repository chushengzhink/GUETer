import 'package:course_helper/session/cookie.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../api/api_service.dart';
import '../session/account.dart';
import 'pages/accounts.dart';

/// 平台类型枚举
enum PlatformType {
  chaoxing, // 学习通
  rainClassroom, // 雨课堂
  tronclass, // 畅课
  ketangpai, // 课堂派
  weizhuojiao // 微助教
}

/// 雨课堂服务器类型枚举
enum RainClassroomServerType {
  yuketang, // 雨课堂
  pro, // 荷塘雨课堂
  changjiang, // 长江雨课堂
  huanghe // 黄河雨课堂
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
  final StreamController<PlatformType> _platformChangeController = StreamController<PlatformType>.broadcast();
  Stream<PlatformType> get platformChanges => _platformChangeController.stream;

  /// 获取当前平台
  PlatformType get currentPlatform => _currentPlatform;

  bool get isChaoxing => _currentPlatform == PlatformType.chaoxing;
  bool get isRainClassroom => _currentPlatform == PlatformType.rainClassroom;
  bool get isTronclass => _currentPlatform == PlatformType.tronclass;
  bool get isKetangpai => _currentPlatform == PlatformType.ketangpai;
  bool get isWeizhuojiao => _currentPlatform == PlatformType.weizhuojiao;
  String get tronclassBaseUrl => _tronclassBaseUrl;
  String get ketangpaiBaseUrl => _ketangpaiBaseUrl;
  
  /// 获取当前雨课堂服务器
  RainClassroomServerType get currentServer => _currentServer;
  
  /// 获取雨课堂服务器名称
  String get serverName {
    switch (_currentServer) {
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

  /// 设置平台
  Future<void> setPlatform(PlatformType platform) async {
    final oldPlatform = _currentPlatform;

    if (oldPlatform != platform) {
      _currentPlatform = platform;
      try {
        await _prefs.setString(_platformKey, currentPlatformName);
      } catch (e) {
        debugPrint('保存平台失败：$e');
      }
      ApiService.onPlatformChange?.call();
      _platformChangeController.add(platform);
      await AccountManager.switchToPlatformAccount();
      await AccountManager.refreshAccounts();
      await CookieManager.loadAllCookies(refreshOnlineState: false);
      unawaited(CookieManager.refreshAccountsInBackground());
      AccountChangeNotifier().notifyAccountChanged(AccountManager.currentSessionId);
    }
  }
  
  /// 设置雨课堂服务器
  Future<void> setServer(RainClassroomServerType server) async {
    if (_currentServer != server) {
      final oldServer = _currentServer;
      _currentServer = server;
      try {
        await _prefs.setString(_serverKey, serverName);
      } catch (e) {
        debugPrint('保存服务器失败：$e');
      }
      ApiService.onPlatformChange?.call();
      debugPrint('[Platform] rainclassroom server switched $oldServer -> $_currentServer');
      // Reuse platform change stream to force page-level refresh after server switch.
      _platformChangeController.add(_currentPlatform);
    }
  }

  /// 设置畅课服务器地址
  Future<void> setTronclassBaseUrl(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    if (_tronclassBaseUrl == normalized) return;

    _tronclassBaseUrl = normalized;
    try {
      await _prefs.setString(_tronclassBaseUrlKey, normalized);
    } catch (e) {
      debugPrint('保存畅课服务器失败：$e');
    }
    ApiService.onPlatformChange?.call();
  }

  /// 设置课堂派服务器地址
  Future<void> setKetangpaiBaseUrl(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    if (_ketangpaiBaseUrl == normalized) return;

    _ketangpaiBaseUrl = normalized;
    try {
      await _prefs.setString(_ketangpaiBaseUrlKey, normalized);
    } catch (e) {
      debugPrint('保存课堂派服务器失败：$e');
    }
    ApiService.onPlatformChange?.call();
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
    switch (_currentPlatform) {
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
