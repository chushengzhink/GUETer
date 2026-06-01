import 'package:flutter/foundation.dart';
import '../session/account.dart';
import '../session/tronclass_auth.dart';

class TronclassDebug {
  static Future<void> printSessionInfo() async {
    debugPrint('========== 畅课 Session 诊断 ==========');

    final currentUserId = AccountManager.currentSessionId;
    debugPrint('1. 当前用户 ID: $currentUserId');

    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint('   ❌ 未登录或用户 ID 为空');
      return;
    }

    final account = AccountManager.getAccountById(currentUserId);
    debugPrint('2. 账号信息: ${account?.name ?? "未找到"}');
    debugPrint('   平台: ${account?.platform ?? "未知"}');

    final sessionId = await TronclassAuthManager.getCurrentSessionId();
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('3. ❌ Session ID 为空');
      debugPrint('   可能原因：');
      debugPrint('   - 未登录畅课平台');
      debugPrint('   - 登录流程未完成');
      debugPrint('   - Session ID 未正确存储');
    } else {
      debugPrint('3. ✅ Session ID: ${sessionId.substring(0, sessionId.length > 20 ? 20 : sessionId.length)}...');
      debugPrint('   完整长度: ${sessionId.length}');
    }

    debugPrint('======================================');
  }

  static Future<Map<String, dynamic>> getSessionStatus() async {
    final currentUserId = AccountManager.currentSessionId;
    final sessionId = await TronclassAuthManager.getCurrentSessionId();

    return {
      'hasUserId': currentUserId != null && currentUserId.isNotEmpty,
      'hasSessionId': sessionId != null && sessionId.isNotEmpty,
      'userId': currentUserId,
      'sessionIdLength': sessionId?.length ?? 0,
    };
  }
}
