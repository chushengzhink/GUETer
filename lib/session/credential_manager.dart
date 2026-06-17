import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_service.dart';
import '../api/login.dart';
import '../models/user.dart';
import '../platform.dart';
import 'account.dart';
import 'tronclass_auth.dart';

/// Unified credential manager for all platforms.
class CredentialManager {
  static const int _defaultExpiryDays = 7;
  static const int _refreshThresholdHours = 24;
  static final Map<String, Future<bool>> _refreshInFlight = {};

  /// Parse cookie expiry from a Set-Cookie header.
  static int? parseCookieExpiry(String setCookieHeader) {
    try {
      final cookie = Cookie.fromSetCookieValue(setCookieHeader);
      if (cookie.expires != null) {
        return cookie.expires!.millisecondsSinceEpoch ~/ 1000;
      }

      final maxAgeMatch = RegExp(
        r'Max-Age=(\d+)',
        caseSensitive: false,
      ).firstMatch(setCookieHeader);
      if (maxAgeMatch != null) {
        final maxAge = int.parse(maxAgeMatch.group(1)!);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        return now + maxAge;
      }
    } catch (e) {
      debugPrint('[CredentialManager] Failed to parse cookie expiry: $e');
    }
    return null;
  }

  /// Calculate the default expiry timestamp (7 days from now).
  static int getDefaultExpiry() {
    final now = DateTime.now();
    final expiry = now.add(const Duration(days: _defaultExpiryDays));
    return expiry.millisecondsSinceEpoch ~/ 1000;
  }

  /// Check if a credential should be refreshed soon.
  static bool needsRefresh(User user) {
    if (user.credentialExpiry == null) {
      return false;
    }
    return user.isCredentialExpired(
      bufferSeconds: _refreshThresholdHours * 3600,
    );
  }

  static String _refreshKey(User user) =>
      '${user.platform.toLowerCase()}_${user.uid}';

  /// Update user credential expiry after a successful request.
  static Future<User> updateCredentialExpiry(
    User user, {
    int? expiryTimestamp,
    bool extendDefault = true,
    bool notify = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newExpiry =
        expiryTimestamp ??
        (extendDefault ? getDefaultExpiry() : user.credentialExpiry);

    final latest = AccountManager.getAccountsForPlatformName(user.platform)
        .where((account) => account.uid == user.uid)
        .cast<User?>()
        .firstWhere((account) => account != null, orElse: () => user);

    final base = latest ?? user;
    final updated = base.copyWith(
      credentialExpiry: newExpiry,
      lastRefreshTime: now,
    );

    await AccountManager.addAccountForPlatformName(
      user.platform,
      updated,
      notify: notify,
    );

    final remaining = updated.credentialRemainingHours;
    if (remaining != null) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        'Credential updated, remaining ${remaining.toStringAsFixed(1)} hours',
      );
    }

    return updated;
  }

  /// Refresh a credential for a specific platform.
  static Future<bool> refreshCredential(User user) async {
    try {
      ApiService.appendExternalConsoleLog(
        user.platform,
        'Refreshing credential (remaining ${user.credentialRemainingHours?.toStringAsFixed(1) ?? "unknown"} hours)',
      );

      if (user.isChaoxing) {
        return _refreshChaoxing(user);
      }
      if (user.isRainClassroom) {
        return _refreshRainClassroom(user);
      }
      if (user.isTronclass) {
        return _refreshTronclass(user);
      }
      if (user.isKetangpai) {
        return _refreshKetangpai(user);
      }

      return false;
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        'Credential refresh failed: $e',
      );
      return false;
    }
  }

  static Future<bool> refreshCredentialGuarded(
    User user, {
    Duration? timeout,
    bool startupMode = false,
  }) async {
    final key = _refreshKey(user);
    final existing = _refreshInFlight[key];
    if (existing != null) {
      if (startupMode) {
        ApiService.logStartupRecovery(
          '[CredentialManager] reuse refresh in-flight userId=${user.uid} platform=${user.platform}',
        );
      }
      return timeout == null
          ? existing
          : existing.timeout(timeout, onTimeout: () => false);
    }

    final future = refreshCredential(user);
    _refreshInFlight[key] = future;

    if (startupMode) {
      ApiService.logStartupRecovery(
        '[CredentialManager] refresh begin userId=${user.uid} platform=${user.platform}',
      );
    }

    try {
      final result = timeout == null
          ? await future
          : await future.timeout(timeout, onTimeout: () => false);
      if (startupMode) {
        ApiService.logStartupRecovery(
          '[CredentialManager] refresh done userId=${user.uid} success=$result',
        );
      }
      return result;
    } catch (e) {
      if (startupMode) {
        ApiService.logStartupRecovery(
          '[CredentialManager] refresh error userId=${user.uid} error=$e',
        );
      }
      rethrow;
    } finally {
      if (identical(_refreshInFlight[key], future)) {
        _refreshInFlight.remove(key);
      }
    }
  }

  static Future<bool> _refreshChaoxing(User user) async {
    try {
      final refreshedUser = await CXLoginApi.getUserInfoForAccount(user.uid);
      if (refreshedUser == null) {
        return false;
      }

      final updated = await updateCredentialExpiry(
        refreshedUser,
        notify: false,
      );
      ApiService.appendExternalConsoleLog(
        'chaoxing',
        'Credential refresh succeeded, expiry: ${_formatExpiry(updated.credentialExpiry)}',
      );
      return true;
    } catch (e) {
      debugPrint('[CredentialManager] Chaoxing refresh failed: $e');
      return false;
    }
  }

  static Future<bool> _refreshRainClassroom(User user) async {
    try {
      final refreshedUser = await RCLoginApi.getUserInfoForAccount(user.uid);
      if (refreshedUser == null) {
        return false;
      }

      final updated = await updateCredentialExpiry(
        refreshedUser,
        notify: false,
      );
      ApiService.appendExternalConsoleLog(
        'rainclassroom',
        'Credential refresh succeeded, expiry: ${_formatExpiry(updated.credentialExpiry)}',
      );
      return true;
    } catch (e) {
      debugPrint('[CredentialManager] RainClassroom refresh failed: $e');
      return false;
    }
  }

  static Future<bool> _refreshTronclass(User user) async {
    try {
      final sessionId = await TronclassAuthManager.getSessionIdForUser(
        user.uid,
      );
      if (sessionId != null && sessionId.isNotEmpty) {
        final bootstrapped = await TCLoginApi.bootstrapPortalSession(
          sessionId: sessionId,
        );
        if (bootstrapped) {
          final updated = await updateCredentialExpiry(user, notify: false);
          ApiService.appendExternalConsoleLog(
            'tronclass',
            'Credential refresh succeeded, expiry: ${_formatExpiry(updated.credentialExpiry)}',
          );
          return true;
        }
      }

      final hasCookieSession = await AccountManager.hasValidTronclassSession(
        user,
      );
      if (!hasCookieSession) {
        return false;
      }

      final cookie = await AccountManager.getCookieForPlatform(
        PlatformType.tronclass,
        user.uid,
      );
      if (cookie == null || cookie.isEmpty) {
        return false;
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: PlatformManager().tronclassBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 10),
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Cookie': cookie,
            'accept': 'application/json, text/plain, */*',
          },
        ),
      );

      for (final endpoint in const [
        '/api/profile',
        '/api/users/profile',
        '/api/users/me',
      ]) {
        try {
          final response = await dio.get(endpoint);
          final refreshedUser = TCLoginApi.parseTronclassUserFromPayload(
            response.data,
            fallbackUid: user.uid,
          );
          if (refreshedUser == null) {
            continue;
          }

          final updated = await updateCredentialExpiry(user, notify: false);
          ApiService.appendExternalConsoleLog(
            'tronclass',
            'Credential refresh succeeded, expiry: ${_formatExpiry(updated.credentialExpiry)}',
          );
          return true;
        } catch (_) {
          // try next endpoint
        }
      }
    } catch (e) {
      debugPrint('[CredentialManager] Tronclass refresh failed: $e');
    }
    return false;
  }

  static Future<bool> _refreshKetangpai(User user) async {
    try {
      if (user.token.isEmpty) {
        return false;
      }

      final isValid = await KTLoginApi.checkTokenStatus(user.token);
      if (!isValid) {
        return false;
      }

      final updated = await updateCredentialExpiry(user, notify: false);
      ApiService.appendExternalConsoleLog(
        'ketangpai',
        'Credential refresh succeeded, expiry: ${_formatExpiry(updated.credentialExpiry)}',
      );
      return true;
    } catch (e) {
      debugPrint('[CredentialManager] Ketangpai refresh failed: $e');
      return false;
    }
  }

  /// Check and refresh a credential before a request.
  static Future<bool> ensureCredentialValid(String userId) async {
    final user = AccountManager.getAccountById(userId);
    if (user == null) {
      return false;
    }

    if (user.isCredentialExpired()) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        'Credential expired; re-login required',
      );
      return false;
    }

    if (needsRefresh(user)) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        'Credential nearing expiry; attempting refresh',
      );
      return refreshCredentialGuarded(user);
    }

    return true;
  }

  /// Validate all stored credentials.
  static Future<void> validateAllCredentials() async {
    final accounts = AccountManager.getAllAccounts();

    for (final user in accounts) {
      final remaining = user.credentialRemainingHours;

      if (user.credentialExpiry == null) {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: no expiry set, defaulting to 7 days',
        );
        await updateCredentialExpiry(user, notify: false);
        continue;
      }

      if (user.isCredentialExpired()) {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: credential expired; re-login required',
        );
        continue;
      }

      if (needsRefresh(user)) {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: remaining ${remaining?.toStringAsFixed(1)} hours, refreshing',
        );
        final success = await refreshCredentialGuarded(user);
        if (!success) {
          ApiService.appendExternalConsoleLog(
            user.platform,
            '${user.name}: credential refresh failed',
          );
        }
      } else {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: credential valid, remaining ${remaining?.toStringAsFixed(1)} hours',
        );
      }
    }
  }

  static Future<void> validateAllCredentialsForStartup({
    Duration perUserTimeout = const Duration(seconds: 5),
  }) async {
    final accounts = AccountManager.getAllAccounts();
    ApiService.logStartupRecovery(
      '[CredentialManager] startup validate begin accounts=${accounts.length}',
    );

    for (final user in accounts) {
      ApiService.logStartupRecovery(
        '[CredentialManager] startup validate user begin userId=${user.uid} platform=${user.platform}',
      );
      try {
        if (user.credentialExpiry == null) {
          await updateCredentialExpiry(
            user,
            notify: false,
          ).timeout(perUserTimeout);
          ApiService.logStartupRecovery(
            '[CredentialManager] startup validate user default-expiry userId=${user.uid}',
          );
          continue;
        }

        if (user.isCredentialExpired()) {
          ApiService.logStartupRecovery(
            '[CredentialManager] startup validate user expired userId=${user.uid}',
          );
          continue;
        }

        if (!needsRefresh(user)) {
          ApiService.logStartupRecovery(
            '[CredentialManager] startup validate user skipped userId=${user.uid}',
          );
          continue;
        }

        final success = await refreshCredentialGuarded(
          user,
          timeout: perUserTimeout,
          startupMode: true,
        );
        ApiService.logStartupRecovery(
          '[CredentialManager] startup validate user done userId=${user.uid} success=$success',
        );
      } on TimeoutException {
        ApiService.logStartupRecovery(
          '[CredentialManager] startup validate user timeout userId=${user.uid}',
        );
      } catch (e) {
        ApiService.logStartupRecovery(
          '[CredentialManager] startup validate user error userId=${user.uid} error=$e',
        );
      }
    }

    ApiService.logStartupRecovery('[CredentialManager] startup validate done');
  }

  static String _formatExpiry(int? timestamp) {
    if (timestamp == null) {
      return 'unknown';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
