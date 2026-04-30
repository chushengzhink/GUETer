import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';
import 'credential_manager.dart';
import '../api/api_service.dart';

class TronclassAuthManager {
  static SharedPreferences? _prefs;

  static Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String _sessionKey(String uid) => 'tronclass_auth_session_$uid';
  static String _sessionExpiryKey(String uid) => 'tronclass_auth_expiry_$uid';

  static Future<void> setSessionIdForUser(String uid, String sessionId) async {
    await _ensureInitialized();
    // 不等待写入完成，减少阻塞
    _prefs!.setString(_sessionKey(uid), sessionId);

    final expiry = CredentialManager.getDefaultExpiry();
    _prefs!.setInt(_sessionExpiryKey(uid), expiry);

    final user = AccountManager.getAccountById(uid);
    if (user != null) {
      // 在后台更新凭证过期时间，不阻塞
      CredentialManager.updateCredentialExpiry(
        user,
        expiryTimestamp: expiry,
      ).catchError((e) {
        ApiService.appendExternalConsoleLog(
          '畅课',
          '更新凭证过期时间失败: $e',
        );
        return user;
      });
    }

    ApiService.appendExternalConsoleLog(
      '畅课',
      'Session ID 已存储，过期时间: ${_formatExpiry(expiry)}',
    );
  }

  static Future<String?> getSessionIdForUser(String uid) async {
    await _ensureInitialized();
    return _prefs!.getString(_sessionKey(uid));
  }

  static Future<String?> getCurrentSessionId() async {
    final uid = AccountManager.currentSessionId;
    if (uid == null || uid.isEmpty) return null;
    return getSessionIdForUser(uid);
  }

  static Future<void> clearSessionIdForUser(String uid) async {
    await _ensureInitialized();
    await _prefs!.remove(_sessionKey(uid));
    await _prefs!.remove(_sessionExpiryKey(uid));
  }

  static String _formatExpiry(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
