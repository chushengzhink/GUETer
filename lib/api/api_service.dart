import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../utils/encrypt.dart';
import '../session/cookie.dart';
import '../session/app_settings.dart';
import '../platform.dart';

class HeadersManager {
  static const _brand = 'google';
  static const _deviceModel = 'Pixel 9 Pro';
  static const _systemVersion = '16';
  static const _buildNumber = '1610';
  static const _incremental = '14624737'; // ro.build.version.incremental
  static const _systemHttpAgent =
      'Dalvik/2.1.0 (Linux; U; Android 16; Pixel 9 Pro Build/BP4A.260205.002)';

  static const _rcVersion = '1.3.3';

  static const _cxProductId = '3';
  static const _cxVersion = '6.7.4';
  static const _cxVersionCode = '10940';
  static const _cxApiVersion = '314';
  static const _ktUserAgent =
      'Mozilla/5.0 (Linux; Android 16; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36';

  static const _uniqueIdKey = 'app_unique_id';
  static late String _uniqueId;

  static late String _cxUserAgent;

  static late Map<String, String> _cxHeaders;

  static final Map<String, String> _rcHeaders = {
    'user-agent': 'Android',
    'brand': '$_brand $_deviceModel',
    'uuid': '',
    'buildnumber': _buildNumber,
    'xtua': 'client=app&tag=$_rcVersion&platform=Android',
    'systemversion': _systemVersion,
    'incremental': _incremental,
    'accept': 'application/json',
    'isphysicaldevice': 'true',
    'xtbz': 'ykt',
    'x-client': 'app',
  };

  static final Map<String, String> _tcHeaders = {
    'user-agent':
        'Mozilla/5.0 (Linux; Android 16; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36',
    'accept': 'application/json, text/plain, */*',
  };

  static final Map<String, String> _ktHeaders = {
    'user-agent': _ktUserAgent,
    'accept': 'application/json, text/plain, */*',
  };

  static final Map<String, String> _wzjHeaders = {
    'user-agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H143 MicroMessenger/6.2.3 NetType/WIFI Language/zh_CN',
    'accept': 'application/json, text/plain, */*',
  };

  static Future<void> updateChaoxingHeaders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_uniqueIdKey)) {
      _uniqueId = prefs.getString(_uniqueIdKey)!;
    } else {
      _uniqueId = EncryptionUtil.getUniqueId();
      prefs.setString(_uniqueIdKey, _uniqueId);
    }
    // 内测版：@Azeroth
    // 正式版：@Kalimdor
    final userAgentTemp =
        '(device:$_deviceModel) Language/zh_CN com.chaoxing.mobile/ChaoXingStudy_${_cxProductId}_${_cxVersion}_android_phone_${_cxVersionCode}_$_cxApiVersion (@Kalimdor)_$_uniqueId';
    final schild = EncryptionUtil.md5Hash(
      '(schild:${Constant.schildSalt}) $userAgentTemp',
    );
    _cxUserAgent = '$_systemHttpAgent (schild:$schild) $userAgentTemp';

    _cxHeaders = {
      'User-Agent': _cxUserAgent,
      'Accept-Language': 'zh_CN',
      'Connection': 'keep-alive',
      'Accept-Encoding': 'gzip',
      'content-type': 'application/x-www-form-urlencoded',
      // 'X-Requested-With': 'com.chaoxing.mobile'
    };
  }

  static Map<String, String> get chaoxingHeaders =>
      Map.unmodifiable(_cxHeaders);

  static Map<String, String> get rainClassroomHeaders =>
      Map.unmodifiable(_rcHeaders);

  static Map<String, String> get tronclassHeaders =>
      Map.unmodifiable(_tcHeaders);

  static Map<String, String> get ketangpaiHeaders =>
      Map.unmodifiable(_ktHeaders);
}

class ApiService {
  static late Dio _dio;
  static void Function()? onPlatformChange;
  static Future<void> _throttleTail = Future.value();
  static DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  static final Map<String, DateTime> _bucketLastRequestAt =
      <String, DateTime>{};
  static final Random _random = Random();
  static bool _strictSecurityMode = false;

  // 全局请求节流：避免短时间连续请求触发风控误判
  static const int _minRequestIntervalMs = 350;
  static const int _requestJitterMs = 120;
  static const int _highRiskSignIntervalMs = 1400;
  static const int _maxRetryCount = 2;
  static const bool _enableVerboseLogsInRelease = true;
  static const int _maxConsoleLogLines = 800;
  static final List<String> _consoleLogs = <String>[];
  static final ValueNotifier<int> consoleLogVersion = ValueNotifier<int>(0);

  /// 获取雨课堂服务器对应的 baseUrl
  static const _serverBaseUrlMap = {
    RainClassroomServerType.yuketang: 'https://www.yuketang.cn',
    RainClassroomServerType.pro: 'https://pro.yuketang.cn',
    RainClassroomServerType.changjiang: 'https://changjiang.yuketang.cn',
    RainClassroomServerType.huanghe: 'https://huanghe.yuketang.cn',
  };

  static void _logRequest(String stage, String url, {Object? extra}) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    final line = extra == null
        ? '[$hh:$mm:$ss] [$stage] $url'
        : '[$hh:$mm:$ss] [$stage] $url $extra';
    _appendConsoleLog(line);

    if (extra == null) {
      debugPrint('[ApiService][$stage] $url');
    } else {
      debugPrint('[ApiService][$stage] $url $extra');
    }
  }

  static void _appendConsoleLog(String line) {
    _consoleLogs.add(line);
    if (_consoleLogs.length > _maxConsoleLogLines) {
      final overflow = _consoleLogs.length - _maxConsoleLogLines;
      _consoleLogs.removeRange(0, overflow);
    }
    consoleLogVersion.value++;
  }

  static List<String> getConsoleLogs() {
    return List<String>.unmodifiable(_consoleLogs);
  }

  static void clearConsoleLogs() {
    if (_consoleLogs.isEmpty) return;
    _consoleLogs.clear();
    consoleLogVersion.value++;
  }

  // 初始化平台变化回调函数
  static void _setupPlatformChangeCallback() {
    onPlatformChange = () async {
      if (PlatformManager().isChaoxing) {
        _dio.options.baseUrl = '';
        _dio.options.headers = HeadersManager.chaoxingHeaders;
      } else if (PlatformManager().isRainClassroom) {
        _dio.options.baseUrl =
            _serverBaseUrlMap[PlatformManager().currentServer]!;
        _dio.options.headers = HeadersManager.rainClassroomHeaders;
      } else if (PlatformManager().isTronclass) {
        _dio.options.baseUrl = PlatformManager().tronclassBaseUrl;
        _dio.options.headers = HeadersManager.tronclassHeaders;
      } else if (PlatformManager().isKetangpai) {
        _dio.options.baseUrl = PlatformManager().ketangpaiBaseUrl;
        _dio.options.headers = HeadersManager.ketangpaiHeaders;
      } else if (PlatformManager().isWeizhuojiao) {
        _dio.options.baseUrl = 'https://v18.teachermate.cn';
        _dio.options.headers = HeadersManager._wzjHeaders;
      }
    };
  }

  static Future<void> initialize() async {
    await HeadersManager.updateChaoxingHeaders();
    _strictSecurityMode = AppSettings.strictSecurityModeNotifier.value;
    AppSettings.strictSecurityModeNotifier.addListener(
      _onStrictSecurityModeChanged,
    );

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
        followRedirects: false,
        validateStatus: (status) => status! < 500,
        // contentType: Headers.formUrlEncodedContentType, // application/x-www-form-urlencoded
        // headers: HeadersManager.chaoxingHeaders,
      ),
    );

    /*
    // 初始化平台变化回调
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.userAgent = HeadersManager._cxUserAgent;
      return client;
    }; // dio 自动重定向会使用默认的 User-Agent
    // 似乎无法在初始化结束后进行更改
     */
    _setupPlatformChangeCallback();

    _dio.interceptors.add(CookieInterceptor());

    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: false,
        maxWidth: 90,
        enabled: kDebugMode || _enableVerboseLogsInRelease,
        filter: (options, args) {
          if (args.data.toString().contains('<html>')) {
            return false;
          }
          return !args.isResponse || !args.hasUint8ListData;
        },
      ),
    );
  }

  static void _onStrictSecurityModeChanged() {
    _strictSecurityMode = AppSettings.strictSecurityModeNotifier.value;
  }

  /// 发送 HTTP 请求
  static Future<Response> sendRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? params,
    Map<String, String>? headers,
    dynamic body,
    ResponseType responseType = ResponseType.json,
    bool allowRedirects = true,
  }) async {
    final options = Options(
      method: method,
      headers: headers,
      responseType: responseType,
    );

    _logRequest(
      'request',
      url,
      extra:
          'method=${method.toUpperCase()} platform=${PlatformManager().currentPlatformName} '
          'server=${PlatformManager().isRainClassroom ? PlatformManager().serverName : '-'} '
          'baseUrl=${_dio.options.baseUrl.isEmpty ? '<relative>' : _dio.options.baseUrl}',
    );

    var response = await _requestWithRetry(
      url,
      queryParameters: params,
      body: body,
      options: options,
    );

    if (allowRedirects) {
      int redirectCount = 0;
      const maxRedirects = 10;
      final visitedUrls = <String>{response.requestOptions.uri.toString()};

      while (redirectCount < maxRedirects) {
        final locationHeader = response.headers.value('location');
        if (locationHeader == null || locationHeader.isEmpty) {
          break;
        }

        final currentUri = response.requestOptions.uri;
        final locationUri = Uri.tryParse(locationHeader);
        if (locationUri == null) {
          break;
        }

        final resolvedUri = locationUri.hasScheme
            ? locationUri
            : currentUri.resolveUri(locationUri);
        final locationUrl = resolvedUri.toString();

        if (kDebugMode) {
          debugPrint(
            '[ApiService.redirect] ${response.statusCode} ${currentUri.toString()} -> $locationUrl',
          );
        }

        if (visitedUrls.contains(locationUrl)) {
          if (kDebugMode) {
            debugPrint('[ApiService.redirect] detected redirect loop, stop.');
          }
          break;
        }
        visitedUrls.add(locationUrl);

        response = await _requestWithRetry(
          locationUrl,
          options: Options(
            method: 'GET',
            headers: options.headers,
            responseType: options.responseType,
          ),
        );
        redirectCount++;
      }
    }

    if (options.responseType == ResponseType.json) {
      if (response.data is String) {
        response.data = jsonDecode(response.data);
      }
    } // dio 的 json 解析有问题

    _logRequest(
      'response',
      url,
      extra: 'status=${response.statusCode} uri=${response.requestOptions.uri}',
    );

    return response;
  }

  static Future<void> _throttleRequest(String url, String method) async {
    final previous = _throttleTail;
    final completer = Completer<void>();
    _throttleTail = completer.future;

    await previous;
    try {
      final now = DateTime.now();
      final elapsedMs = now.difference(_lastRequestAt).inMilliseconds;
      final jitterMs = _random.nextInt(_requestJitterMs + 1);
      var waitMs = _minRequestIntervalMs - elapsedMs + jitterMs;

      final bucket = _requestBucket(url, method);
      if (_strictSecurityMode && bucket != null) {
        final bucketLast =
            _bucketLastRequestAt[bucket] ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bucketElapsedMs = now.difference(bucketLast).inMilliseconds;
        final bucketWaitMs =
            _highRiskSignIntervalMs - bucketElapsedMs + jitterMs;
        if (bucketWaitMs > waitMs) {
          waitMs = bucketWaitMs;
        }
      }

      if (waitMs > 0) {
        await Future.delayed(Duration(milliseconds: waitMs));
      }
      _lastRequestAt = DateTime.now();
      if (_strictSecurityMode && bucket != null) {
        _bucketLastRequestAt[bucket] = _lastRequestAt;
      }
    } finally {
      completer.complete();
    }
  }

  static String? _requestBucket(String url, String method) {
    final upperMethod = method.toUpperCase();
    if (upperMethod != 'POST' &&
        upperMethod != 'PUT' &&
        upperMethod != 'PATCH') {
      return null;
    }

    final lowerUrl = url.toLowerCase();
    final markers = <String>[
      '/attenceapi/checkin',
      '/attenceapi/attenceresult',
      '/api/rollcall/',
      '/answer_qr_rollcall',
      '/answer_number_rollcall',
      '/wechat-api/v1/class-attendance/student-sign-in',
      '/api/radar/rollcalls/',
      '/checkin',
    ];

    for (final marker in markers) {
      if (lowerUrl.contains(marker)) {
        return 'high-risk-sign';
      }
    }
    return null;
  }

  static Future<Response> _requestWithRetry(
    String url, {
    Map<String, String>? queryParameters,
    dynamic body,
    required Options options,
  }) async {
    Response? lastResponse;
    Object? lastError;

    for (var attempt = 0; attempt <= _maxRetryCount; attempt++) {
      await _throttleRequest(url, options.method ?? 'GET');
      try {
        _logRequest(
          'attempt',
          url,
          extra: 'try=${attempt + 1}/${_maxRetryCount + 1} method=${options.method ?? 'GET'}',
        );
        final response = await _dio.request(
          url,
          queryParameters: queryParameters,
          data: body,
          options: options,
        );

        if (_shouldRetryByStatus(response.statusCode) &&
            attempt < _maxRetryCount) {
          _logRequest(
            'retry-status',
            url,
            extra: 'status=${response.statusCode} nextTry=${attempt + 2}/${_maxRetryCount + 1}',
          );
          await _backoffDelay(attempt);
          lastResponse = response;
          continue;
        }
        return response;
      } catch (e) {
        lastError = e;
        if (attempt >= _maxRetryCount || !_shouldRetryByError(e)) {
          _logRequest('fail', url, extra: 'attempt=${attempt + 1} error=$e');
          rethrow;
        }
        _logRequest(
          'retry-error',
          url,
          extra: 'attempt=${attempt + 1} error=$e nextTry=${attempt + 2}/${_maxRetryCount + 1}',
        );
        await _backoffDelay(attempt);
      }
    }

    if (lastResponse != null) {
      return lastResponse;
    }
    throw lastError ?? Exception('request failed');
  }

  static bool _shouldRetryByStatus(int? statusCode) {
    if (statusCode == null) return false;
    return statusCode == 429 || statusCode == 503 || statusCode == 504;
  }

  static bool _shouldRetryByError(Object error) {
    if (error is! DioException) return false;
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  static Future<void> _backoffDelay(int attempt) async {
    final baseMs = 600 * (attempt + 1);
    final jitterMs = _random.nextInt(220);
    await Future.delayed(Duration(milliseconds: baseMs + jitterMs));
  }

  /// 将学习通的Star3图片转换为Star4 减少一次重定向
  String toNewImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 3) {
        final size = pathSegments[1];
        final fileNameWithExt = pathSegments[2];

        final lastDotIndex = fileNameWithExt.lastIndexOf('.');
        if (lastDotIndex != -1) {
          final filename = fileNameWithExt.substring(0, lastDotIndex);
          final extension = fileNameWithExt.substring(lastDotIndex);
          return '${uri.scheme}://${uri.host}/star4/$filename/$size$extension';
        } else {
          return '${uri.scheme}://${uri.host}/star4/$fileNameWithExt/$size.png';
        }
      }
    } catch (e) {
      debugPrint('URL转换失败: $e');
    }
    return url;
  }
}
