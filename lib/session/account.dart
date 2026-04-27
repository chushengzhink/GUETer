import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';
import '../models/user.dart';
import '../platform.dart';
import 'cookie.dart';
import 'credential_manager.dart';
import '../utils/encrypt.dart';
import '../pages/accounts.dart';

/// 统一的账户管理器
class AccountManager {
  static late SharedPreferences _prefs;

  static List<User> _accounts = [];
  static String? _currentSessionId;

  static bool _isLoggingOut = false;
  static String? _lastLoggedOutUserId;
  static int? _lastLogoutTimestamp;

  static String get _currentPlatformStorageKey {
    return PlatformManager().currentPlatformName;
  }

  static String get _sessionKey {
    return '${_currentPlatformStorageKey}_current_session';
  }

  static String get _accountsKey {
    return '${_currentPlatformStorageKey}_accounts';
  }

  static String _encryptAccountsPayload(String payload) {
    final encrypted = EncryptionUtil.aesCbcEncrypt(
      payload,
      Constant.localAccountStoreKey,
    );
    return 'enc:$encrypted';
  }

  static String? _decryptAccountsPayload(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return null;
    }

    if (value.startsWith('enc:')) {
      final encrypted = value.substring(4);
      return EncryptionUtil.aesCbcDecrypt(
        encrypted,
        Constant.localAccountStoreKey,
      );
    }

    return value;
  }

  /// 从存储中获取所有账户（异步，从当前平台读取）
  static Future<List<User>> _getAllAccountsFromStorage() async {
    final String? accountsJson = _prefs.getString(_accountsKey);
    if (accountsJson != null) {
      try {
        final decodedPayload = _decryptAccountsPayload(accountsJson);
        if (decodedPayload == null || decodedPayload.isEmpty) {
          return [];
        }
        final List<dynamic> accountsData = json.decode(decodedPayload);
        final accounts = accountsData
            .whereType<Map>()
            .map(
              (data) =>
                  User.fromJson(data.map((k, v) => MapEntry(k.toString(), v))),
            )
            .toList();

        if (!accountsJson.startsWith('enc:') && accounts.isNotEmpty) {
          await _saveAccounts(accounts);
        }
        return accounts;
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  /// 保存账户列表到存储（保存到当前平台）
  static Future<void> _saveAccounts(List<User> accounts) async {
    final accountsJson = json.encode(accounts.map((u) => u.toJson()).toList());
    await _prefs.setString(_accountsKey, _encryptAccountsPayload(accountsJson));
    // 同步更新缓存
    _accounts = accounts;
  }

  // ========== 对外公开方法 ==========

  /// 初始化账户管理器
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _accounts = await _getAllAccountsFromStorage();
    _currentSessionId = await getCurrentSession();
    await switchToPlatformAccount();

    // Validate all credentials on startup
    unawaited(_validateCredentialsInBackground());
  }

  static Future<void> _validateCredentialsInBackground() async {
    await Future.delayed(const Duration(seconds: 2));
    await CredentialManager.validateAllCredentials();
  }

  /// 获取当前会话的用户 ID（同步，使用缓存）
  static String? get currentSessionId => _currentSessionId;

  /// 获取当前会话的用户 ID
  static Future<String?> getCurrentSession() async {
    _currentSessionId = _prefs.getString(_sessionKey);
    return _currentSessionId;
  }

  /// 设置当前会话的用户 ID
  static Future<void> setCurrentSession(String? userId) async {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      _currentSessionId = null;
      await _prefs.remove(_sessionKey);
      AccountChangeNotifier().notifyAccountChanged(null);
      return;
    }

    // Clear logout markers when explicitly setting new session
    _lastLoggedOutUserId = null;
    _lastLogoutTimestamp = null;

    _currentSessionId = normalized;
    // 使用 setString 而不是等待，减少阻塞
    _prefs.setString(_sessionKey, normalized);
    AccountChangeNotifier().notifyAccountChanged(normalized);
  }

  /// 临时设置当前会话的用户 ID 修改内存
  static void setCurrentSessionTemp(String userId) {
    _currentSessionId = userId;
  }

  /// 检查是否存在活跃会话（同步，使用内存缓存）
  static bool hasActiveSession() {
    return _currentSessionId != null && _currentSessionId!.isNotEmpty;
  }

  /// 获取指定平台用户的 Cookie（用于独立请求上下文）
  static Future<String?> getCookieForPlatform(PlatformType platform, String userId) async {
    final platformName = _getPlatformName(platform).toLowerCase();
    final cookieKey = '${platformName}_$userId';

    debugPrint('[AccountManager] getCookieForPlatform: platform=$platformName userId=$userId cookieKey=$cookieKey');

    final cookieJar = await CookieManager.getCookieJarForUser(userId, platformName: platformName);

    if (platform == PlatformType.chaoxing) {
      final probeUris = [
        Uri.parse('https://chaoxing.com'),
        Uri.parse('https://passport2.chaoxing.com'),
        Uri.parse('https://sso.chaoxing.com'),
        Uri.parse('https://i.chaoxing.com'),
        Uri.parse('https://.chaoxing.com'),
      ];

      final allCookies = <Cookie>[];
      for (final uri in probeUris) {
        final cookies = await cookieJar.loadForRequest(uri);
        allCookies.addAll(cookies);
      }

      if (allCookies.isEmpty) {
        ApiService.appendExternalConsoleLog(
          '学习通',
          'Cookie 为空，cookieKey=$cookieKey',
        );
        return null;
      }

      final cookieStr = allCookies.map((c) => '${c.name}=${c.value}').join('; ');
      ApiService.appendExternalConsoleLog(
        '学习通',
        'Cookie 长度: ${cookieStr.length}, 键: ${allCookies.map((c) => c.name).take(10).join(", ")}',
      );
      return cookieStr;
    }

    if (platform == PlatformType.rainClassroom) {
      final probeUris = [
        Uri.parse('https://www.yuketang.cn'),
        Uri.parse('https://pro.yuketang.cn'),
        Uri.parse('https://changjiang.yuketang.cn'),
        Uri.parse('https://huanghe.yuketang.cn'),
        Uri.parse('https://.yuketang.cn'),
      ];

      final allCookies = <Cookie>[];
      for (final uri in probeUris) {
        final cookies = await cookieJar.loadForRequest(uri);
        allCookies.addAll(cookies);
      }

      if (allCookies.isEmpty) {
        debugPrint('[AccountManager] 雨课堂 Cookie 为空，cookieKey=$cookieKey');
        return null;
      }

      final cookieStr = allCookies.map((c) => '${c.name}=${c.value}').join('; ');
      debugPrint('[AccountManager] 雨课堂 Cookie 长度: ${cookieStr.length}, 键: ${allCookies.map((c) => c.name).join(", ")}');
      return cookieStr;
    }

    final domainUri = CookieManager.getDomainUri();
    final cookies = await cookieJar.loadForRequest(domainUri);

    if (cookies.isEmpty) {
      debugPrint('[AccountManager] ${platformName} Cookie 为空');
      return null;
    }

    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  /// 从存储中获取账户列表
  static Future<void> refreshAccounts() async {
    _accounts = await _getAllAccountsFromStorage();
  }

  /// 获取所有账户
  static List<User> getAllAccounts() {
    return _accounts;
  }

  /// 根据ID获取账户（同步，使用缓存）
  static User? getAccountById(String userId) {
    try {
      return _accounts.firstWhere((acc) => acc.uid == userId);
    } catch (e) {
      return null;
    }
  }

  /// 获取指定平台的账户列表（不切换全局平台状态）
  static List<User> getAccountsForPlatform(PlatformType platform) {
    final platformName = _getPlatformName(platform);
    final accountsKey = '${platformName}_accounts';
    final accountsJson = _prefs.getString(accountsKey);

    if (accountsJson == null || accountsJson.isEmpty) {
      return [];
    }

    try {
      final decodedPayload = _decryptAccountsPayload(accountsJson);
      if (decodedPayload == null || decodedPayload.isEmpty) {
        return [];
      }
      final List<dynamic> accountsData = json.decode(decodedPayload);
      return accountsData
          .whereType<Map>()
          .map((data) => User.fromJson(data.map((k, v) => MapEntry(k.toString(), v))))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _getPlatformName(PlatformType platform) {
    switch (platform) {
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

  /// 添加账户（如果已存在则更新）
  static Future<void> addAccount(User user) async {
    debugPrint('[AccountManager.addAccount] 开始添加账户 uid=${user.uid}');

    final accounts = _accounts;
    final hasTempCookies = CookieManager.getTempCookieJar() != null;
    final index = accounts.indexWhere((acc) => acc.uid == user.uid);
    if (index != -1) {
      accounts[index] = user;
    } else {
      accounts.add(user);
      // 如果没有当前会话，自动设置为当前账户
      if (!hasActiveSession()) {
        _currentSessionId = user.uid;
        _prefs.setString(_sessionKey, user.uid);
      }
    }

    debugPrint('[AccountManager.addAccount] 准备保存账户到存储');
    // 使用 compute 在后台线程执行 JSON 编码和加密
    final accountsJson = await compute(
      _encodeAndEncryptAccounts,
      accounts.map((u) => u.toJson()).toList(),
    );
    await _prefs.setString(_accountsKey, accountsJson);
    _accounts = accounts;
    debugPrint('[AccountManager.addAccount] 账户保存完成');

    // 登录成功后不论账号是新增还是更新，都迁移临时 Cookie。
    if (hasTempCookies) {
      debugPrint('[AccountManager.addAccount] 开始迁移临时 Cookie');
      await CookieManager.saveTempCookies(user.uid);
      debugPrint('[AccountManager.addAccount] Cookie 迁移完成');
    }

    debugPrint('[AccountManager.addAccount] 通知账户变更');
    AccountChangeNotifier().notifyAccountChanged(user.uid);
    debugPrint('[AccountManager.addAccount] 完成');
  }

  /// 后台线程执行 JSON 编码和加密（用于 compute）
  static String _encodeAndEncryptAccounts(List<Map<String, dynamic>> accountsData) {
    final accountsJson = json.encode(accountsData);
    return _encryptAccountsPayload(accountsJson);
  }

  /// 批量删除账户
  static Future<void> removeAccounts(List<String> userIds) async {
    final accounts = await _getAllAccountsFromStorage();
    accounts.removeWhere((acc) => userIds.contains(acc.uid));
    await _saveAccounts(accounts);

    // 检查当前会话是否被删除
    final current = await getCurrentSession();
    if (current != null && userIds.contains(current)) {
      await clearCurrentSession();
    } else {
      // 对于其他被删除的用户，清除他们的 Cookie
      for (final uid in userIds) {
        if (uid != current) {
          await CookieManager.clearCookiesForUser(uid);
        }
      }
    }
    AccountChangeNotifier().notifyAccountChanged(null);
  }

  /// 清除当前会话（仅清除会话 ID，不清除账户数据）
  static Future<void> clearCurrentSession() async {
    // CRITICAL: Clear in-memory cache FIRST, synchronously
    final currentUserId = _currentSessionId;
    _currentSessionId = null;
    _lastLoggedOutUserId = currentUserId;
    _lastLogoutTimestamp = DateTime.now().millisecondsSinceEpoch;
    _isLoggingOut = true;

    await _prefs.remove(_sessionKey);
    if (currentUserId != null) {
      await CookieManager.clearCookiesForUser(currentUserId);
    }

    _isLoggingOut = false;
    AccountChangeNotifier().notifyAccountChanged(null);
  }

  /// 切换到对应平台的账号
  static Future<void> switchToPlatformAccount() async {
    await refreshAccounts();

    final currentPlatformName = PlatformManager().currentPlatformName.toLowerCase();
    final currentSession = await getCurrentSession();

    debugPrint('[AccountManager] 切换到平台账号: platform=$currentPlatformName currentSession=$currentSession');

    // Guard against restoration after recent logout
    if (_lastLogoutTimestamp != null && currentSession != null) {
      final timeSinceLogout = DateTime.now().millisecondsSinceEpoch - _lastLogoutTimestamp!;
      if (timeSinceLogout < 2000 && currentSession == _lastLoggedOutUserId) {
        debugPrint('[AccountManager] 阻止登出后的会话恢复 (userId=$currentSession, ${timeSinceLogout}ms ago)');
        _currentSessionId = null;
        await _prefs.remove(_sessionKey);
        return;
      }
    }

    if (currentSession != null && currentSession.isNotEmpty) {
      final currentAccount = getAccountById(currentSession);
      if (currentAccount != null &&
          currentAccount.platform.toLowerCase() == currentPlatformName) {
        debugPrint('[AccountManager] 当前账号已匹配平台，无需切换 (uid=${currentAccount.uid})');
        return;
      }
    }

    final platformAccounts = _accounts
        .where((user) => user.platform.toLowerCase() == currentPlatformName)
        .toList();

    if (platformAccounts.isNotEmpty) {
      // Only auto-switch if there's a current session - don't restore after logout
      if (currentSession != null && currentSession.isNotEmpty) {
        await setCurrentSession(platformAccounts.first.uid);
        debugPrint('[AccountManager] 已切换到平台账号 (uid=${platformAccounts.first.uid} name=${platformAccounts.first.name})');
        return;
      }
    }

    // Clear session without notification to prevent cascade
    _currentSessionId = null;
    await _prefs.remove(_sessionKey);
    debugPrint('[AccountManager] 平台无账号或已登出，清除会话');
  }
}
