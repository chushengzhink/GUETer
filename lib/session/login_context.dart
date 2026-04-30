import 'dart:async';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:uuid/uuid.dart';

import '../platform.dart';
import '../utils/browser_headers.dart';

/// 登录上下文 - 为每次登录会话提供隔离的状态
class LoginContext {
  /// 唯一标识符
  final String contextId;

  /// 所属平台
  final PlatformType platform;

  /// 隔离的临时 Cookie 存储
  final CookieJar tempCookieJar;

  /// 创建时间（用于自动清理）
  final DateTime createdAt;

  /// Set-Cookie 响应头（用于凭证过期时间）
  List<String>? setCookieHeaders;

  LoginContext({
    required this.contextId,
    required this.platform,
    required this.tempCookieJar,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 检查上下文是否过期（默认 10 分钟）
  bool isExpired({Duration timeout = const Duration(minutes: 10)}) {
    return DateTime.now().difference(createdAt) > timeout;
  }

  @override
  String toString() {
    return 'LoginContext(id: $contextId, platform: $platform, created: $createdAt)';
  }
}

/// 登录上下文管理器 - 管理所有活跃的登录上下文
class LoginContextManager {
  LoginContextManager._();

  static final LoginContextManager instance = LoginContextManager._();

  final Map<String, LoginContext> _activeContexts = {};
  Timer? _cleanupTimer;

  /// 创建新的登录上下文
  LoginContext createContext(PlatformType platform) {
    final contextId = const Uuid().v4();
    final tempCookieJar = CookieJar();

    final context = LoginContext(
      contextId: contextId,
      platform: platform,
      tempCookieJar: tempCookieJar,
    );

    _activeContexts[contextId] = context;

    // 启动自动清理定时器（如果尚未启动）
    _ensureCleanupTimer();

    print('[LoginContext] 创建上下文: $context');
    return context;
  }

  /// 获取指定的登录上下文
  LoginContext? getContext(String contextId) {
    return _activeContexts[contextId];
  }

  /// 删除登录上下文
  void removeContext(String contextId) {
    final context = _activeContexts.remove(contextId);
    if (context != null) {
      print('[LoginContext] 删除上下文: $context');
    }

    // 如果没有活跃上下文，停止清理定时器
    if (_activeContexts.isEmpty) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    }
  }

  /// 检查指定平台是否有正在进行的登录
  bool isPlatformLoggingIn(PlatformType platform) {
    return _activeContexts.values.any((ctx) => ctx.platform == platform);
  }

  /// 检查是否有任何活跃的登录上下文
  bool get hasActiveContexts => _activeContexts.isNotEmpty;

  /// 获取所有活跃上下文的数量
  int get activeContextCount => _activeContexts.length;

  /// 清理过期的上下文
  void _cleanupExpiredContexts() {
    final expiredIds = <String>[];

    for (final entry in _activeContexts.entries) {
      if (entry.value.isExpired()) {
        expiredIds.add(entry.key);
      }
    }

    for (final id in expiredIds) {
      print('[LoginContext] 自动清理过期上下文: ${_activeContexts[id]}');
      _activeContexts.remove(id);
    }

    // 如果没有活跃上下文，停止定时器
    if (_activeContexts.isEmpty) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    }
  }

  /// 确保清理定时器正在运行
  void _ensureCleanupTimer() {
    if (_cleanupTimer == null || !_cleanupTimer!.isActive) {
      _cleanupTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _cleanupExpiredContexts(),
      );
    }
  }

  /// 清理所有上下文（用于测试或重置）
  void clearAll() {
    print('[LoginContext] 清理所有上下文，共 ${_activeContexts.length} 个');
    _activeContexts.clear();
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }
}

/// 登录 Dio 工厂 - 为登录创建隔离的 Dio 实例
class LoginDioFactory {
  LoginDioFactory._();

  /// 为登录上下文创建隔离的 Dio 实例
  static Future<Dio> createLoginDio(LoginContext context) async {
    final baseUrl = _getBaseUrl(context.platform);
    final platformName = _getPlatformName(context.platform);
    final userAgent = await BrowserHeadersManager.getUserAgent();
    final referer = BrowserHeadersManager.getRefererForPlatform(platformName);

    final headers = <String, String>{
      'User-Agent': userAgent,
      ...BrowserHeadersManager.getStandardHeaders(referer: referer),
    };

    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: headers,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      followRedirects: true,
      maxRedirects: 5,
    ));

    // 添加 Cookie 拦截器（使用上下文的临时 CookieJar）
    dio.interceptors.add(_LoginCookieInterceptor(context));

    // 添加日志拦截器（仅在调试模式）
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      dio.interceptors.add(_LoginLogInterceptor(context));
    }

    print('[LoginDio] 为上下文 ${context.contextId} 创建隔离 Dio 实例');
    return dio;
  }

  static String _getBaseUrl(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return 'https://passport2.chaoxing.com';
      case PlatformType.rainClassroom:
        return 'https://www.yuketang.cn';
      case PlatformType.ketangpai:
        return 'https://openapiv5.ketangpai.com';
      case PlatformType.tronclass:
        return 'https://www.tronclass.com.cn';
      case PlatformType.weizhuojiao:
        return 'https://www.weizhuojiao.com'; // 微助教暂不支持
    }
  }

  static String _getPlatformName(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return 'chaoxing';
      case PlatformType.rainClassroom:
        return 'yuketang';
      case PlatformType.ketangpai:
        return 'ketangpai';
      case PlatformType.tronclass:
        return 'tronclass';
      case PlatformType.weizhuojiao:
        return 'weizhuojiao';
    }
  }
}

/// 登录专用 Cookie 拦截器
class _LoginCookieInterceptor extends Interceptor {
  final LoginContext context;

  _LoginCookieInterceptor(this.context);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 从上下文的临时 CookieJar 加载 Cookie
    if (options.headers['Cookie'] == null) {
      final cookies = await context.tempCookieJar.loadForRequest(options.uri);
      if (cookies.isNotEmpty) {
        final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
        options.headers['Cookie'] = cookieStr;
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // 保存响应中的 Cookie 到上下文的临时 CookieJar
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
      // 保存 Set-Cookie 头到上下文
      context.setCookieHeaders = setCookieHeaders;

      // 解析并保存 Cookie
      final cookies = setCookieHeaders
          .map((str) => Cookie.fromSetCookieValue(str))
          .toList();

      await context.tempCookieJar.saveFromResponse(
        response.requestOptions.uri,
        cookies,
      );

      print('[LoginCookie] 保存 ${cookies.length} 个 Cookie 到上下文 ${context.contextId}');
    }

    handler.next(response);
  }
}

/// 登录专用日志拦截器
class _LoginLogInterceptor extends Interceptor {
  final LoginContext context;

  _LoginLogInterceptor(this.context);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('[LoginDio] ${context.contextId} → ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('[LoginDio] ${context.contextId} ← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('[LoginDio] ${context.contextId} ✗ ${err.type} ${err.requestOptions.uri}');
    handler.next(err);
  }
}
