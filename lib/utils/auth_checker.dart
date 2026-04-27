import 'package:flutter/material.dart';

/// 雨课堂认证检查工具
class RainClassroomAuthChecker {
  /// 检查响应是否表示认证失效
  static bool isAuthExpired(Map<String, dynamic>? response) {
    if (response == null) return false;

    final code = response['code'];
    final msg = response['msg']?.toString() ?? '';
    final errcode = response['errcode'];
    final errmsg = response['errmsg']?.toString() ?? '';

    // 检查错误码
    if (code == 50000 || errcode == 50000) {
      return true;
    }

    // 检查错误消息
    final upperMsg = msg.toUpperCase();
    final upperErrmsg = errmsg.toUpperCase();

    return upperMsg.contains('UNAUTHENTICATED') ||
        upperMsg.contains('UNAUTHORIZED') ||
        upperMsg.contains('未登录') ||
        upperMsg.contains('登录') ||
        upperErrmsg.contains('UNAUTHENTICATED') ||
        upperErrmsg.contains('UNAUTHORIZED') ||
        upperErrmsg.contains('未登录') ||
        upperErrmsg.contains('登录');
  }

  /// 显示认证失效提示对话框
  static Future<void> showAuthExpiredDialog(BuildContext context) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('登录已过期'),
          ],
        ),
        content: const Text(
          '雨课堂登录已过期，请返回课程列表页面重新登录。\n\n'
          '提示：如果频繁出现此问题，可能是因为：\n'
          '1. Cookie已过期，需要重新登录\n'
          '2. 多个雨课堂域名之间认证信息未同步',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 返回到课程列表页面
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('返回课程列表'),
          ),
        ],
      ),
    );
  }

  /// 显示认证失效提示 SnackBar
  static void showAuthExpiredSnackBar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('登录已过期，请返回课程列表重新登录雨课堂'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '返回',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }
}
