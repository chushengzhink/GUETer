import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';

class TronclassAuthManager {
  static SharedPreferences? _prefs;

  static Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String _sessionKey(String uid) => 'tronclass_auth_session_$uid';

  static Future<void> setSessionIdForUser(String uid, String sessionId) async {
    await _ensureInitialized();
    await _prefs!.setString(_sessionKey(uid), sessionId);
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
  }
}
