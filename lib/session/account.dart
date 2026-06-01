import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_service.dart';
import '../api/platform_dio_manager.dart';
import '../models/user.dart';
import '../platform.dart';
import '../utils/encrypt.dart';
import 'account_events.dart';
import 'cookie.dart';
import 'tronclass_auth.dart';

class AccountManager {
  static const Duration _startupStepTimeout = Duration(seconds: 5);
  static late SharedPreferences _prefs;

  static List<User> _accounts = [];
  static String? _currentSessionId;

  static String? _lastLoggedOutUserId;
  static int? _lastLogoutTimestamp;

  static String get _currentPlatformStorageKey =>
      PlatformManager().currentPlatformName;

  static String get _sessionKey =>
      '${_currentPlatformStorageKey}_current_session';

  static String get _accountsKey => '${_currentPlatformStorageKey}_accounts';

  static String _normalizePlatformStorageName(String platformName) {
    final platformType = _getPlatformTypeFromName(platformName.toLowerCase());
    if (platformType != null) {
      return _getPlatformName(platformType);
    }
    return platformName.toLowerCase();
  }

  static String _accountsKeyForPlatformName(String platformName) {
    final normalized = _normalizePlatformStorageName(platformName);
    return '${normalized}_accounts';
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

  static Future<List<User>> _getAccountsFromStorageByKey(
    String accountsKey,
  ) async {
    final accountsJson = _prefs.getString(accountsKey);
    if (accountsJson == null) {
      return [];
    }

    try {
      final decodedPayload = _decryptAccountsPayload(accountsJson);
      if (decodedPayload == null || decodedPayload.isEmpty) {
        return [];
      }

      final accountsData = json.decode(decodedPayload) as List<dynamic>;
      final accounts = accountsData
          .whereType<Map>()
          .map((data) => User.fromJson(data.map((k, v) => MapEntry('$k', v))))
          .toList();

      if (!accountsJson.startsWith('enc:') && accounts.isNotEmpty) {
        await _saveAccounts(accounts);
      }

      return accounts;
    } catch (_) {
      return [];
    }
  }

  static Future<List<User>> _getAllAccountsFromStorage() async {
    return _getAccountsFromStorageByKey(_accountsKey);
  }

  static Future<List<User>> _getAccountsFromStorageForPlatformName(
    String platformName,
  ) async {
    return _getAccountsFromStorageByKey(
      _accountsKeyForPlatformName(platformName),
    );
  }

  static Future<void> _saveAccounts(List<User> accounts) async {
    await _saveAccountsForPlatformName(_currentPlatformStorageKey, accounts);
  }

  static Future<void> _saveAccountsForPlatformName(
    String platformName,
    List<User> accounts,
  ) async {
    final accountsJson = json.encode(accounts.map((u) => u.toJson()).toList());
    final accountsKey = _accountsKeyForPlatformName(platformName);
    await _prefs.setString(accountsKey, _encryptAccountsPayload(accountsJson));
    if (_normalizePlatformStorageName(platformName) ==
        _currentPlatformStorageKey) {
      _accounts = accounts;
    }
  }

  static String _encodeAndEncryptAccounts(
    List<Map<String, dynamic>> accountsData,
  ) {
    final accountsJson = json.encode(accountsData);
    return _encryptAccountsPayload(accountsJson);
  }

  static List<User> _sortedAccountsForDisplay(List<User> accounts) {
    final sorted = List<User>.from(accounts);
    sorted.sort((a, b) {
      final aCurrent = a.uid == _currentSessionId;
      final bCurrent = b.uid == _currentSessionId;
      if (aCurrent != bCurrent) {
        return aCurrent ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  static void _notifyAccountState() {
    AccountChangeNotifier().notifySnapshot(
      AccountStateSnapshot(
        platform: PlatformManager().currentPlatform,
        accounts: getCurrentPlatformAccounts(),
        currentAccountId: _currentSessionId,
      ),
    );
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

  static PlatformType? _getPlatformTypeFromName(String platformName) {
    switch (platformName) {
      case 'chaoxing':
      case '学习通':
        return PlatformType.chaoxing;
      case 'rainclassroom':
      case '雨课堂':
        return PlatformType.rainClassroom;
      case 'tronclass':
      case '畅课':
        return PlatformType.tronclass;
      case 'ketangpai':
      case '课堂派':
        return PlatformType.ketangpai;
      case 'weizhuojiao':
      case '微助教':
        return PlatformType.weizhuojiao;
      default:
        return null;
    }
  }

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    ApiService.logStartupRecovery('[AccountManager] initialize start');

    await _runStartupStep<void>(
      'refreshAccounts',
      refreshAccounts,
      onFailure: (reason) => clearCurrentSessionForStartupRecovery(
        reason: 'refreshAccounts $reason',
        notify: false,
      ),
    );
    await _runStartupStep<String?>(
      'getCurrentSession',
      getCurrentSession,
      onFailure: (reason) => clearCurrentSessionForStartupRecovery(
        reason: 'getCurrentSession $reason',
        notify: false,
      ),
    );
    await _runStartupStep<void>(
      'switchToPlatformAccount',
      () => switchToPlatformAccount(refreshFromStorage: false),
      onFailure: (reason) => clearCurrentSessionForStartupRecovery(
        reason: 'switchToPlatformAccount $reason',
        notify: false,
      ),
    );

    _notifyAccountState();
    ApiService.logStartupRecovery('[AccountManager] initialize done');
  }

  static Future<T?> _runStartupStep<T>(
    String name,
    Future<T> Function() action, {
    Future<void> Function(String reason)? onFailure,
  }) async {
    ApiService.logStartupRecovery('[AccountManager] $name start');
    try {
      final result = await action().timeout(_startupStepTimeout);
      ApiService.logStartupRecovery('[AccountManager] $name done');
      return result;
    } on TimeoutException {
      ApiService.logStartupRecovery('[AccountManager] $name timeout');
      if (onFailure != null) {
        await onFailure('timeout');
      }
    } catch (e) {
      ApiService.logStartupRecovery('[AccountManager] $name error: $e');
      if (onFailure != null) {
        await onFailure('error: $e');
      }
    }
    return null;
  }

  static String? get currentSessionId => _currentSessionId;

  static User? get currentAccount {
    final userId = _currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }
    return getAccountById(userId);
  }

  static Future<String?> getCurrentSession() async {
    _currentSessionId = _prefs.getString(_sessionKey);
    return _currentSessionId;
  }

  static Future<void> setCurrentSession(
    String? userId, {
    bool notify = true,
  }) async {
    final normalized = userId?.trim();
    if (normalized == null || normalized.isEmpty) {
      _currentSessionId = null;
      await _prefs.remove(_sessionKey);
      if (notify) {
        _notifyAccountState();
      }
      return;
    }

    _lastLoggedOutUserId = null;
    _lastLogoutTimestamp = null;

    _currentSessionId = normalized;
    await _prefs.setString(_sessionKey, normalized);
    if (notify) {
      _notifyAccountState();
    }
  }

  static Future<void> clearCurrentSessionForStartupRecovery({
    required String reason,
    bool notify = true,
  }) async {
    final currentUserId = _currentSessionId;
    _currentSessionId = null;
    await _prefs.remove(_sessionKey);
    ApiService.logStartupRecovery(
      '[AccountManager] cleared current session during startup reason=$reason userId=${currentUserId ?? "null"}',
    );
    if (notify) {
      _notifyAccountState();
    }
  }

  static void setCurrentSessionTemp(String userId) {
    _currentSessionId = userId;
  }

  static bool hasActiveSession() {
    return _currentSessionId != null && _currentSessionId!.isNotEmpty;
  }

  static Future<String?> getCookieForPlatform(
    PlatformType platform,
    String userId,
  ) async {
    final platformName = _getPlatformName(platform).toLowerCase();
    final cookieKey = '${platformName}_$userId';

    debugPrint(
      '[AccountManager] getCookieForPlatform: platform=$platformName userId=$userId cookieKey=$cookieKey',
    );

    final cookieJar = await CookieManager.getCookieJarForUser(
      userId,
      platformName: platformName,
    );

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

      final cookieStr = allCookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
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

      final cookieStr = allCookies
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
      debugPrint(
        '[AccountManager] 雨课堂 Cookie 长度: ${cookieStr.length}, 键: ${allCookies.map((c) => c.name).join(", ")}',
      );
      return cookieStr;
    }

    final domainUri = CookieManager.getDomainUri();
    final cookies = await cookieJar.loadForRequest(domainUri);
    if (cookies.isEmpty) {
      debugPrint('[AccountManager] $platformName Cookie 为空');
      return null;
    }

    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  static Future<bool> hasValidTronclassSession(User user) async {
    if (!user.isTronclass) {
      return false;
    }

    final sessionId = await TronclassAuthManager.getSessionIdForUser(user.uid);
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      return true;
    }

    if (user.isCredentialExpired()) {
      return false;
    }

    final cookieJar = await CookieManager.getCookieJarForUser(
      user.uid,
      platformName: user.platform.toLowerCase(),
    );
    final cookies = await cookieJar.loadForRequest(
      Uri.parse('https://${CookieManager.tcDomain}'),
    );

    return cookies.any(
      (cookie) =>
          cookie.name.toLowerCase() == 'session' &&
          cookie.value.trim().isNotEmpty,
    );
  }

  static Future<void> refreshAccounts() async {
    _accounts = await _getAllAccountsFromStorage();
  }

  static List<User> getAllAccounts() {
    return _sortedAccountsForDisplay(_accounts);
  }

  static List<User> getCurrentPlatformAccounts() {
    return getAllAccounts();
  }

  static User? getAccountById(String userId) {
    try {
      return _accounts.firstWhere((acc) => acc.uid == userId);
    } catch (_) {
      return null;
    }
  }

  static List<User> getAccountsForPlatform(PlatformType platform) {
    final platformName = _getPlatformName(platform);
    final accountsKey = _accountsKeyForPlatformName(platformName);
    final accountsJson = _prefs.getString(accountsKey);

    if (accountsJson == null || accountsJson.isEmpty) {
      return [];
    }

    try {
      final decodedPayload = _decryptAccountsPayload(accountsJson);
      if (decodedPayload == null || decodedPayload.isEmpty) {
        return [];
      }

      final accountsData = json.decode(decodedPayload) as List<dynamic>;
      return _sortedAccountsForDisplay(
        accountsData
            .whereType<Map>()
            .map((data) => User.fromJson(data.map((k, v) => MapEntry('$k', v))))
            .toList(),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<void> addAccount(
    User user, {
    bool notify = true,
    bool migrateTempCookies = true,
  }) async {
    await addAccountForPlatformName(
      _currentPlatformStorageKey,
      user,
      notify: notify,
      migrateTempCookies: migrateTempCookies,
    );
  }

  static Future<void> addAccountForPlatformName(
    String platformName,
    User user, {
    bool notify = true,
    bool migrateTempCookies = true,
  }) async {
    debugPrint('[AccountManager.addAccount] 开始添加账户 uid=${user.uid}');

    final normalizedPlatform = _normalizePlatformStorageName(platformName);
    final accounts = List<User>.from(
      await _getAccountsFromStorageForPlatformName(normalizedPlatform),
    );
    final isCurrentPlatform = normalizedPlatform == _currentPlatformStorageKey;
    final hasTempCookies =
        migrateTempCookies &&
        isCurrentPlatform &&
        CookieManager.getTempCookieJar() != null;
    final index = accounts.indexWhere((acc) => acc.uid == user.uid);

    if (index != -1) {
      accounts[index] = user;
    } else {
      accounts.add(user);
      if (isCurrentPlatform && !hasActiveSession()) {
        _currentSessionId = user.uid;
        await _prefs.setString(_sessionKey, user.uid);
      }
    }

    final accountsJson = await compute(
      _encodeAndEncryptAccounts,
      accounts.map((u) => u.toJson()).toList(),
    );
    await _prefs.setString(
      _accountsKeyForPlatformName(normalizedPlatform),
      accountsJson,
    );
    if (isCurrentPlatform) {
      _accounts = accounts;
    }

    if (hasTempCookies) {
      await CookieManager.saveTempCookies(user.uid);
    }

    if (notify && isCurrentPlatform) {
      _notifyAccountState();
    }
  }

  static Future<void> removeAccounts(
    List<String> userIds, {
    bool notify = true,
  }) async {
    final accounts = await _getAllAccountsFromStorage();
    final userPlatforms = <String, String>{};

    for (final acc in accounts) {
      if (userIds.contains(acc.uid)) {
        userPlatforms[acc.uid] = acc.platform.toLowerCase();
      }
    }

    accounts.removeWhere((acc) => userIds.contains(acc.uid));
    await _saveAccounts(accounts);

    final current = await getCurrentSession();
    if (current != null && userIds.contains(current)) {
      await clearCurrentSession(notify: false);
    } else {
      for (final uid in userIds) {
        if (uid == current) {
          continue;
        }

        await CookieManager.clearCookiesForUser(uid);
        final userPlatform = userPlatforms[uid];
        if (userPlatform != null) {
          final platformType = _getPlatformTypeFromName(userPlatform);
          if (platformType != null) {
            PlatformDioManager.clearDioForUser(
              platform: platformType,
              userId: uid,
            );
          }
        }
      }
    }

    if (notify) {
      _notifyAccountState();
    }
  }

  static Future<void> clearCurrentSession({bool notify = true}) async {
    final currentUserId = _currentSessionId;
    _currentSessionId = null;
    _lastLoggedOutUserId = currentUserId;
    _lastLogoutTimestamp = DateTime.now().millisecondsSinceEpoch;

    await _prefs.remove(_sessionKey);
    if (currentUserId != null) {
      await CookieManager.clearCookiesForUser(currentUserId);
      PlatformDioManager.clearDioForUser(
        platform: PlatformManager().currentPlatform,
        userId: currentUserId,
      );
    }

    if (notify) {
      _notifyAccountState();
    }
  }

  static Future<bool> switchAccount(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final account = getAccountById(normalized);
    if (account == null) {
      debugPrint(
        '[AccountManager] switchAccount skipped: unknown userId=$normalized',
      );
      return false;
    }

    final currentPlatform = PlatformManager().currentPlatformName.toLowerCase();
    if (account.platform.toLowerCase() != currentPlatform) {
      debugPrint(
        '[AccountManager] switchAccount skipped: platform mismatch user=${account.platform} current=$currentPlatform',
      );
      return false;
    }

    if (_currentSessionId == normalized) {
      return true;
    }

    await setCurrentSession(normalized);
    return true;
  }

  static Future<void> logoutAccount(User user) async {
    final isCurrentUser = user.uid == _currentSessionId;

    if (isCurrentUser) {
      await clearCurrentSession(notify: false);
    } else {
      await CookieManager.clearCookiesForUser(user.uid);
      PlatformDioManager.clearDioForUser(
        platform:
            _getPlatformTypeFromName(user.platform) ??
            PlatformManager().currentPlatform,
        userId: user.uid,
      );
    }

    if (user.isTronclass) {
      await TronclassAuthManager.clearSessionIdForUser(user.uid);
    }

    if (user.isKetangpai) {
      await addAccount(
        user.copyWith(
          token: '',
          credentialExpiry: null,
          lastRefreshTime: null,
          refreshToken: null,
        ),
        notify: false,
      );
    }

    _notifyAccountState();
  }

  static Future<void> switchToPlatformAccount({
    bool refreshFromStorage = true,
  }) async {
    if (refreshFromStorage) {
      await refreshAccounts();
    }

    final currentPlatformName = PlatformManager().currentPlatformName
        .toLowerCase();
    final currentSession = await getCurrentSession();

    debugPrint(
      '[AccountManager] 切换到平台账号: platform=$currentPlatformName currentSession=$currentSession',
    );

    if (_lastLogoutTimestamp != null && currentSession != null) {
      final timeSinceLogout =
          DateTime.now().millisecondsSinceEpoch - _lastLogoutTimestamp!;
      if (timeSinceLogout < 5000 && currentSession == _lastLoggedOutUserId) {
        debugPrint(
          '[AccountManager] 阻止登出后的会话恢复 (userId=$currentSession, ${timeSinceLogout}ms ago)',
        );
        _currentSessionId = null;
        await _prefs.remove(_sessionKey);
        return;
      }
    }

    if (currentSession != null && currentSession.isNotEmpty) {
      final currentAccount = getAccountById(currentSession);
      if (currentAccount != null &&
          currentAccount.platform.toLowerCase() == currentPlatformName) {
        debugPrint(
          '[AccountManager] 当前账号已匹配平台，无需切换 (uid=${currentAccount.uid})',
        );
        return;
      }
    }

    final platformAccounts = _accounts
        .where((user) => user.platform.toLowerCase() == currentPlatformName)
        .toList();

    if (platformAccounts.isNotEmpty &&
        currentSession != null &&
        currentSession.isNotEmpty) {
      await setCurrentSession(platformAccounts.first.uid, notify: false);
      debugPrint(
        '[AccountManager] 已切换到平台账号 (uid=${platformAccounts.first.uid} name=${platformAccounts.first.name})',
      );
      return;
    }

    _currentSessionId = null;
    await _prefs.remove(_sessionKey);
    debugPrint('[AccountManager] 平台无账号或已登出，清除会话');
  }

  static void notifyStateChanged() {
    _notifyAccountState();
  }
}
