import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../platform.dart';
import 'account.dart';
import 'cookie.dart';
import 'tronclass_auth.dart';
import '../api/login.dart';
import '../api/api_service.dart';

/// Unified credential manager for all platforms
class CredentialManager {
  static const int _defaultExpiryDays = 7;
  static const int _refreshThresholdHours = 24;

  /// Parse cookie expiry from Set-Cookie header
  static int? parseCookieExpiry(String setCookieHeader) {
    try {
      final cookie = Cookie.fromSetCookieValue(setCookieHeader);
      if (cookie.expires != null) {
        return cookie.expires!.millisecondsSinceEpoch ~/ 1000;
      }

      final maxAgeMatch = RegExp(r'Max-Age=(\d+)', caseSensitive: false)
          .firstMatch(setCookieHeader);
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

  /// Calculate default expiry timestamp (7 days from now)
  static int getDefaultExpiry() {
    final now = DateTime.now();
    final expiry = now.add(Duration(days: _defaultExpiryDays));
    return expiry.millisecondsSinceEpoch ~/ 1000;
  }

  /// Check if credential needs refresh (< 24 hours remaining)
  static bool needsRefresh(User user) {
    if (user.credentialExpiry == null) {
      return false;
    }
    return user.isCredentialExpired(bufferSeconds: _refreshThresholdHours * 3600);
  }

  /// Update user credential expiry after successful request
  static Future<User> updateCredentialExpiry(
    User user, {
    int? expiryTimestamp,
    bool extendDefault = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final newExpiry = expiryTimestamp ??
        (extendDefault ? getDefaultExpiry() : user.credentialExpiry);

    final updated = user.copyWith(
      credentialExpiry: newExpiry,
      lastRefreshTime: now,
    );

    await AccountManager.addAccount(updated);

    final remaining = updated.credentialRemainingHours;
    if (remaining != null) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        '凭证已更新，剩余 ${remaining.toStringAsFixed(1)} 小时',
      );
    }

    return updated;
  }

  /// Refresh credential for a specific platform
  static Future<bool> refreshCredential(User user) async {
    try {
      ApiService.appendExternalConsoleLog(
        user.platform,
        '开始刷新凭证 (剩余 ${user.credentialRemainingHours?.toStringAsFixed(1) ?? "未知"} 小时)',
      );

      if (user.isChaoxing) {
        return await _refreshChaoxing(user);
      } else if (user.isRainClassroom) {
        return await _refreshRainClassroom(user);
      } else if (user.isTronclass) {
        return await _refreshTronclass(user);
      } else if (user.isKetangpai) {
        return await _refreshKetangpai(user);
      }

      return false;
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        '凭证刷新失败: $e',
      );
      return false;
    }
  }

  static Future<bool> _refreshChaoxing(User user) async {
    try {
      AccountManager.setCurrentSessionTemp(user.uid);
      final refreshedUser = await CXLoginApi.getUserInfo();

      if (refreshedUser != null) {
        final updated = await updateCredentialExpiry(refreshedUser);
        ApiService.appendExternalConsoleLog(
          '学习通',
          '凭证刷新成功，过期时间: ${_formatExpiry(updated.credentialExpiry)}',
        );
        return true;
      }
    } catch (e) {
      debugPrint('[CredentialManager] Chaoxing refresh failed: $e');
    }
    return false;
  }

  static Future<bool> _refreshRainClassroom(User user) async {
    try {
      AccountManager.setCurrentSessionTemp(user.uid);
      final refreshedUser = await RCLoginApi.getUserInfo();

      if (refreshedUser != null) {
        final updated = await updateCredentialExpiry(refreshedUser);
        ApiService.appendExternalConsoleLog(
          '雨课堂',
          '凭证刷新成功，过期时间: ${_formatExpiry(updated.credentialExpiry)}',
        );
        return true;
      }
    } catch (e) {
      debugPrint('[CredentialManager] RainClassroom refresh failed: $e');
    }
    return false;
  }

  static Future<bool> _refreshTronclass(User user) async {
    try {
      final sessionId = await TronclassAuthManager.getSessionIdForUser(user.uid);
      if (sessionId == null || sessionId.isEmpty) {
        return false;
      }

      final bootstrapped = await TCLoginApi.bootstrapPortalSession(
        sessionId: sessionId,
      );

      if (bootstrapped) {
        final updated = await updateCredentialExpiry(user);
        ApiService.appendExternalConsoleLog(
          '畅课',
          '凭证刷新成功，过期时间: ${_formatExpiry(updated.credentialExpiry)}',
        );
        return true;
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

      if (isValid) {
        final updated = await updateCredentialExpiry(user);
        ApiService.appendExternalConsoleLog(
          '课堂派',
          '凭证刷新成功，过期时间: ${_formatExpiry(updated.credentialExpiry)}',
        );
        return true;
      }
    } catch (e) {
      debugPrint('[CredentialManager] Ketangpai refresh failed: $e');
    }
    return false;
  }

  /// Check and refresh credential if needed before request
  static Future<bool> ensureCredentialValid(String userId) async {
    final user = AccountManager.getAccountById(userId);
    if (user == null) {
      return false;
    }

    if (user.isCredentialExpired()) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        '凭证已过期，需要重新登录',
      );
      return false;
    }

    if (needsRefresh(user)) {
      ApiService.appendExternalConsoleLog(
        user.platform,
        '凭证即将过期，尝试自动刷新',
      );
      return await refreshCredential(user);
    }

    return true;
  }

  /// Validate all stored credentials on startup
  static Future<void> validateAllCredentials() async {
    final accounts = AccountManager.getAllAccounts();

    for (final user in accounts) {
      final remaining = user.credentialRemainingHours;

      if (user.credentialExpiry == null) {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: 凭证未设置过期时间，设置默认7天有效期',
        );
        await updateCredentialExpiry(user);
        continue;
      }

      if (user.isCredentialExpired()) {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: 凭证已过期，需要重新登录',
        );
        continue;
      }

      if (needsRefresh(user)) {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: 凭证剩余 ${remaining?.toStringAsFixed(1)} 小时，开始刷新',
        );
        final success = await refreshCredential(user);
        if (!success) {
          ApiService.appendExternalConsoleLog(
            user.platform,
            '${user.name}: 凭证刷新失败',
          );
        }
      } else {
        ApiService.appendExternalConsoleLog(
          user.platform,
          '${user.name}: 凭证有效，剩余 ${remaining?.toStringAsFixed(1)} 小时',
        );
      }
    }
  }

  static String _formatExpiry(int? timestamp) {
    if (timestamp == null) return '未知';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
