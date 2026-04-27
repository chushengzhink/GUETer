import 'package:flutter/material.dart';
import '../api/login.dart';
import '../api/api_service.dart';
import '../models/user.dart';
import '../session/account.dart';
import '../session/cookie.dart';
import '../platform.dart';
import 'dart:io';

/// 雨课堂认证管理器
class RainAuthManager {
  static bool _isAuthExpired = false;
  static DateTime? _lastAuthCheck;
  static const _authCheckInterval = Duration(minutes: 5);

  /// 标记认证已过期
  static void markAuthExpired() {
    _isAuthExpired = true;
    debugPrint('[RainAuthManager] 认证已标记为过期');
  }

  /// 清除认证过期标记
  static void clearAuthExpired() {
    _isAuthExpired = false;
    _lastAuthCheck = DateTime.now();
    debugPrint('[RainAuthManager] 认证过期标记已清除');
  }

  /// 检查是否已标记为认证过期
  static bool isMarkedExpired() {
    return _isAuthExpired;
  }

  /// 检查认证是否需要刷新
  static bool needsAuthCheck() {
    if (_lastAuthCheck == null) return true;
    return DateTime.now().difference(_lastAuthCheck!) > _authCheckInterval;
  }

  /// 验证当前认证状态
  static Future<bool> validateAuth() async {
    try {
      final user = await RCLoginApi.getUserInfo();
      final isValid = user != null;

      if (isValid) {
        clearAuthExpired();
        // 验证成功后提取并同步 CSRF token
        await extractAndSyncCsrfToken();
      } else {
        markAuthExpired();
      }

      return isValid;
    } catch (e) {
      debugPrint('[RainAuthManager] 认证验证失败: $e');
      return false;
    }
  }

  /// 从页面或响应中提取 CSRF token
  static Future<String?> extractCsrfToken() async {
    try {
      final jar = CookieManager.getTempCookieJar() ??
                  CookieManager.getCurrentUserCookieJar();
      if (jar == null) return null;

      // 从主域名获取 csrftoken cookie
      final mainDomain = Uri.parse('https://www.yuketang.cn');
      final cookies = await jar.loadForRequest(mainDomain);

      for (final cookie in cookies) {
        if (cookie.name == 'csrftoken') {
          debugPrint('[RainAuthManager] 提取到 CSRF token: ${cookie.value.substring(0, 10)}...');
          return cookie.value;
        }
      }

      debugPrint('[RainAuthManager] 未找到 csrftoken cookie');
      return null;
    } catch (e) {
      debugPrint('[RainAuthManager] 提取 CSRF token 失败: $e');
      return null;
    }
  }

  /// 提取并同步 CSRF token 到所有域名
  static Future<void> extractAndSyncCsrfToken() async {
    try {
      final csrfToken = await extractCsrfToken();
      if (csrfToken == null || csrfToken.isEmpty) {
        debugPrint('[RainAuthManager] CSRF token 为空，跳过同步');
        return;
      }

      final jar = CookieManager.getTempCookieJar() ??
                  CookieManager.getCurrentUserCookieJar();
      if (jar == null) return;

      // 需要同步 CSRF token 的域名
      final domains = [
        Uri.parse('https://www.yuketang.cn'),
        Uri.parse('https://pro.yuketang.cn'),
        Uri.parse('https://changjiang.yuketang.cn'),
        Uri.parse('https://huanghe.yuketang.cn'),
        Uri.parse('https://examination.xuetangx.com'),
      ];

      // 同步 CSRF token 到所有域名
      for (final domain in domains) {
        final csrfCookie = Cookie('csrftoken', csrfToken)
          ..domain = domain.host
          ..path = '/'
          ..httpOnly = false
          ..secure = true;

        await jar.saveFromResponse(domain, [csrfCookie]);
      }

      debugPrint('[RainAuthManager] CSRF token 已同步到所有域名');
    } catch (e) {
      debugPrint('[RainAuthManager] CSRF token 同步失败: $e');
    }
  }

  /// 显示登录过期对话框（带重新登录功能）
  static Future<bool> showAuthExpiredDialog(
    BuildContext context, {
    String? message,
    VoidCallback? onLoginSuccess,
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AuthExpiredDialog(
        message: message,
        onLoginSuccess: onLoginSuccess,
      ),
    );

    return result ?? false;
  }

  /// 触发重新登录流程
  static Future<bool> reLogin(BuildContext context) async {
    if (!context.mounted) return false;

    try {
      // 导航到登录页面
      final result = await Navigator.pushNamed(
        context,
        '/login',
        arguments: {
          'platform': 'rainClassroom',
          'auto_return': true,
        },
      );

      if (result == true) {
        // 登录成功，验证认证状态
        final isValid = await validateAuth();
        if (isValid) {
          clearAuthExpired();
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[RainAuthManager] 重新登录失败: $e');
      return false;
    }
  }

  /// 同步多域名Cookie并主动授权（yuketang.cn, pro.yuketang.cn, examination.xuetangx.com）
  static Future<bool> syncMultiDomainCookies() async {
    try {
      final jar = CookieManager.getTempCookieJar() ??
                  CookieManager.getCurrentUserCookieJar();
      if (jar == null) {
        debugPrint('[RainAuthManager] Cookie jar 不可用');
        return false;
      }

      // 获取主域名的 Cookie
      final mainDomain = Uri.parse('https://www.yuketang.cn');
      final mainCookies = await jar.loadForRequest(mainDomain);

      if (mainCookies.isEmpty) {
        debugPrint('[RainAuthManager] 主域名无Cookie，跳过同步');
        return false;
      }

      // 需要同步的域名列表
      final domains = [
        Uri.parse('https://pro.yuketang.cn'),
        Uri.parse('https://changjiang.yuketang.cn'),
        Uri.parse('https://huanghe.yuketang.cn'),
        Uri.parse('https://examination.xuetangx.com'),
      ];

      // 同步 Cookie 到其他域名
      for (final domain in domains) {
        for (final cookie in mainCookies) {
          // 创建新的 Cookie 用于目标域名
          final newCookie = Cookie(cookie.name, cookie.value)
            ..domain = domain.host
            ..path = cookie.path ?? '/'
            ..expires = cookie.expires
            ..httpOnly = cookie.httpOnly
            ..secure = cookie.secure;

          await jar.saveFromResponse(domain, [newCookie]);
        }
      }

      debugPrint('[RainAuthManager] Cookie 已同步到所有域名');

      // 主动向 pro.yuketang.cn 发起授权请求以激活认证
      final proAuthSuccess = await _activateProDomainAuth();
      if (!proAuthSuccess) {
        debugPrint('[RainAuthManager] pro.yuketang.cn 授权激活失败');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[RainAuthManager] Cookie同步失败: $e');
      return false;
    }
  }

  /// 激活 pro.yuketang.cn 域名的认证
  static Future<bool> _activateProDomainAuth() async {
    try {
      // 向 pro.yuketang.cn 发起请求以激活认证
      final response = await ApiService.sendRequest(
        'https://pro.yuketang.cn/v/course_meta/user_info',
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true || data['errcode'] == 0) {
          debugPrint('[RainAuthManager] pro.yuketang.cn 认证已激活');
          return true;
        }
      }

      debugPrint('[RainAuthManager] pro.yuketang.cn 认证激活失败: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[RainAuthManager] pro.yuketang.cn 认证激活异常: $e');
      return false;
    }
  }

  /// 检查 pro.yuketang.cn 的认证状态
  static Future<bool> checkProDomainAuth() async {
    try {
      final response = await ApiService.sendRequest(
        'https://pro.yuketang.cn/api/v3/classroom/on-lesson-upcoming-exam',
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final code = data['code'];
        final msg = data['msg']?.toString() ?? '';

        if (code == 50000 || msg.toUpperCase().contains('UNAUTHENTICATED')) {
          debugPrint('[RainAuthManager] pro.yuketang.cn 认证失效');
          return false;
        }
      }

      debugPrint('[RainAuthManager] pro.yuketang.cn 认证有效');
      return true;
    } catch (e) {
      debugPrint('[RainAuthManager] pro.yuketang.cn 认证检查异常: $e');
      return false;
    }
  }
}

/// 认证过期对话框
class _AuthExpiredDialog extends StatefulWidget {
  final String? message;
  final VoidCallback? onLoginSuccess;

  const _AuthExpiredDialog({
    this.message,
    this.onLoginSuccess,
  });

  @override
  State<_AuthExpiredDialog> createState() => _AuthExpiredDialogState();
}

class _AuthExpiredDialogState extends State<_AuthExpiredDialog> {
  bool _isLoggingIn = false;

  Future<void> _handleReLogin() async {
    setState(() => _isLoggingIn = true);

    try {
      final success = await RainAuthManager.reLogin(context);

      if (!mounted) return;

      if (success) {
        // 同步多域名Cookie和CSRF token
        final syncSuccess = await RainAuthManager.syncMultiDomainCookies();
        await RainAuthManager.extractAndSyncCsrfToken();

        if (!syncSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('登录成功，但多域名认证同步失败，可能影响考试功能'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }

        widget.onLoginSuccess?.call();

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(syncSuccess ? '登录成功，多域名认证已同步' : '登录成功'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录失败，请重试'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
          SizedBox(width: 12),
          Text('登录已过期'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message ?? '雨课堂登录已过期，无法访问考试系统。',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            const Text(
              '可能的原因：',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Cookie已过期\n'
              '• 多个雨课堂域名之间认证信息未同步\n'
              '• pro.yuketang.cn 需要独立授权',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            const Text(
              '请选择操作：',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoggingIn
              ? null
              : () {
                  Navigator.of(context).pop(false);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
          child: const Text('返回课程列表'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoggingIn ? null : _handleReLogin,
          icon: _isLoggingIn
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(_isLoggingIn ? '登录中...' : '重新登录'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
