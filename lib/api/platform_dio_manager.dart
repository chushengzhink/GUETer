import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../platform.dart';
import '../session/account.dart';
import '../session/cookie.dart';
import '../session/tronclass_auth.dart';
import '../utils/browser_headers.dart';
import 'api_service.dart';

/// 每用户独立 Dio 实例管理器（借鉴 tronclass_plus 的 ChangkeClient 设计）
class PlatformDioManager {
  PlatformDioManager._();

  static final Map<String, Dio> _dioInstances = {};
  static final Map<String, CookieJar> _cookieJars = {};

  static const int _maxRetryCount = 2;
  static const int _retryBaseDelayMs = 600;
  static const int _retryJitterMs = 220;

  /// 获取或创建每用户独立的 Dio 实例
  static Future<Dio> getDioForUser({
    required PlatformType platform,
    required String userId,
  }) async {
    final key = '${_getPlatformName(platform)}_$userId';

    if (_dioInstances.containsKey(key)) {
      return _dioInstances[key]!;
    }

    final baseUrl = _getBaseUrl(platform);
    final platformName = _getPlatformName(platform);
    final cookieJar = await _getCookieJarForUser(userId, platformName);
    final userAgent = await BrowserHeadersManager.getUserAgent();
    final referer = BrowserHeadersManager.getRefererForPlatform(platformName);

    final headers = <String, String>{
      'User-Agent': userAgent,
      ...BrowserHeadersManager.getStandardHeaders(referer: referer),
    };

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
        followRedirects: false,
        validateStatus: (status) => status! < 500,
        headers: headers,
      ),
    );

    dio.interceptors.add(_PlatformCookieInterceptor(
      platform: platform,
      userId: userId,
      cookieJar: cookieJar,
      platformName: platformName,
    ));

    dio.interceptors.add(_RetryInterceptor());

    _dioInstances[key] = dio;
    _cookieJars[key] = cookieJar;

    debugPrint('[PlatformDioManager] Created isolated Dio: platform=$platformName userId=$userId baseUrl=$baseUrl');

    return dio;
  }

  /// 清除指定用户的 Dio 实例（登出时调用）
  static void clearDioForUser({
    required PlatformType platform,
    required String userId,
  }) {
    final key = '${_getPlatformName(platform)}_$userId';
    _dioInstances[key]?.close();
    _dioInstances.remove(key);
    _cookieJars.remove(key);
    debugPrint('[PlatformDioManager] Cleared Dio instance: $key');
  }

  /// 清除所有 Dio 实例
  static void clearAll() {
    for (final dio in _dioInstances.values) {
      dio.close();
    }
    _dioInstances.clear();
    _cookieJars.clear();
    debugPrint('[PlatformDioManager] Cleared all Dio instances');
  }

  static Future<CookieJar> _getCookieJarForUser(String userId, String platformName) async {
    if (kIsWeb) {
      return CookieJar();
    }

    final dir = await getApplicationSupportDirectory();
    final cookiePath = path.join(dir.path, 'cookies', platformName, userId);
    return PersistCookieJar(
      storage: FileStorage(cookiePath),
      ignoreExpires: false,
    );
  }

  static String _getBaseUrl(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return '';
      case PlatformType.rainClassroom:
        return 'https://www.yuketang.cn';
      case PlatformType.tronclass:
        return 'https://courses.guet.edu.cn';
      case PlatformType.ketangpai:
        return 'https://openapiv5.ketangpai.com';
      case PlatformType.weizhuojiao:
        return 'https://v18.teachermate.cn';
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
}

/// Cookie 拦截器（每用户独立）
class _PlatformCookieInterceptor extends Interceptor {
  final PlatformType platform;
  final String userId;
  final CookieJar cookieJar;
  final String platformName;

  _PlatformCookieInterceptor({
    required this.platform,
    required this.userId,
    required this.cookieJar,
    required this.platformName,
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.headers['Cookie'] == null) {
      if (platform == PlatformType.chaoxing) {
        final cookieStr = await AccountManager.getCookieForPlatform(platform, userId);
        if (cookieStr == null || cookieStr.isEmpty) {
          ApiService.appendExternalConsoleLog('学习通', 'Cookie为空，请检查登录状态');
          throw Exception('[学习通] Cookie为空，无法发起请求');
        }
        options.headers['Cookie'] = cookieStr;
      } else if (platform == PlatformType.rainClassroom) {
        final cookieStr = await AccountManager.getCookieForPlatform(platform, userId);
        if (cookieStr == null || cookieStr.isEmpty) {
          ApiService.appendExternalConsoleLog('雨课堂', 'Cookie为空，请检查登录状态');
          throw Exception('[雨课堂] Cookie为空，无法发起请求');
        }
        options.headers['Cookie'] = cookieStr;

        final cookieMap = <String, String>{};
        for (final pair in cookieStr.split('; ')) {
          final parts = pair.split('=');
          if (parts.length == 2) {
            cookieMap[parts[0]] = parts[1];
          }
        }

        options.headers['xtbz'] = 'ykt';
        options.headers['x-client'] = 'web';
        options.headers['xt-agent'] = 'web';
        options.headers['university-id'] = cookieMap['university_id'] ?? '0';
        options.headers['uv-id'] = cookieMap['uv_id'] ?? '0';
        options.headers['accept'] = 'application/json, text/plain, */*';

        if (cookieMap.containsKey('classroom_id')) {
          options.headers['classroom-id'] = cookieMap['classroom_id'];
        }

        if (cookieMap.containsKey('csrftoken')) {
          options.headers['x-csrftoken'] = cookieMap['csrftoken'];
          if (options.method.toUpperCase() == 'POST' ||
              options.method.toUpperCase() == 'PUT' ||
              options.method.toUpperCase() == 'DELETE') {
            options.headers['X-CSRFToken'] = cookieMap['csrftoken'];
          }
        }
        if (cookieMap.containsKey('sessionid')) {
          options.headers['sessionid'] = cookieMap['sessionid'];
        }
      } else {
        final uri = options.uri;
        List<Cookie> cookies = await cookieJar.loadForRequest(uri);

        if (cookies.isNotEmpty) {
          final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
          options.headers['Cookie'] = cookieStr;
        }
      }

      if (platform == PlatformType.tronclass) {
        final sessionId = await TronclassAuthManager.getSessionIdForUser(userId);
        if (sessionId != null && sessionId.isNotEmpty) {
          options.headers['x-session-id'] = sessionId;
        }
      }

      if (platform == PlatformType.ketangpai) {
        final account = AccountManager.getAccountById(userId);
        if (account != null && account.token.isNotEmpty) {
          options.headers['token'] = account.token;
        }
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      final cookies = setCookieHeaders
          .map((s) => Cookie.fromSetCookieValue(s))
          .toList();
      await cookieJar.saveFromResponse(response.realUri, cookies);
      await CookieManager.saveCookiesForUser(userId);
    }
    handler.next(response);
  }
}

/// 自动重试拦截器（借鉴 tronclass_plus 的重试逻辑）
class _RetryInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retryCount = options.extra['retryCount'] ?? 0;

    if (retryCount >= PlatformDioManager._maxRetryCount) {
      handler.next(err);
      return;
    }

    if (!_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final delayMs = (PlatformDioManager._retryBaseDelayMs * (retryCount + 1) +
        Random().nextInt(PlatformDioManager._retryJitterMs)).toInt();

    ApiService.appendExternalConsoleLog(
      'RetryInterceptor',
      '重试 ${retryCount + 1}/${PlatformDioManager._maxRetryCount}: ${options.uri} (延迟 ${delayMs}ms)',
    );

    await Future.delayed(Duration(milliseconds: delayMs));

    options.extra['retryCount'] = retryCount + 1;

    try {
      final response = await Dio().fetch(options);
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(err);
      }
    }
  }

  bool _shouldRetry(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 429 || statusCode == 503 || statusCode == 504) {
      return true;
    }

    return false;
  }
}
