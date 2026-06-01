import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../utils/encrypt.dart';
import '../utils/browser_headers.dart';
import '../session/cookie.dart';
import '../session/app_settings.dart';
import '../session/account.dart';
import '../session/credential_manager.dart';
import '../session/login_context.dart';
import '../platform.dart';

typedef DebugSendRequestOverride =
    Future<Response<dynamic>> Function(
      String url, {
      required String method,
      Map<String, String>? params,
      Map<String, String>? headers,
      dynamic body,
      ResponseType responseType,
      bool allowRedirects,
      bool skipCredentialValidation,
    });

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
    // 鍐呮祴鐗堬細@Azeroth
    // 姝ｅ紡鐗堬細@Kalimdor
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
  static const String _consolePlatformAll = '\u5168\u90e8';
  static const String _consolePlatformCommon = '\u901a\u7528';
  static const String _consolePlatformChaoxing = '\u5b66\u4e60\u901a';
  static const String _consolePlatformRainClassroom = '\u96e8\u8bfe\u5802';
  static const String _consolePlatformTronclass = '\u7545\u8bfe';
  static const String _consolePlatformKetangpai = '\u8bfe\u5802\u6d3e';

  static late Dio _dio;
  static SharedPreferences? _consolePrefs;
  static void Function()? onPlatformChange;
  static Future<void> _throttleTail = Future.value();
  static DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  static final Map<String, DateTime> _bucketLastRequestAt =
      <String, DateTime>{};
  static final Random _random = Random();
  static bool _strictSecurityMode = false;

  // 鍏ㄥ眬璇锋眰鑺傛祦锛氶伩鍏嶇煭鏃堕棿杩炵画璇锋眰瑙﹀彂椋庢帶璇垽
  static const int _minRequestIntervalMs = 350;
  static const int _requestJitterMs = 120;
  static const int _highRiskSignIntervalMs = 1400;
  static const int _maxRetryCount = 2;
  static const bool _enableVerboseLogsInRelease = true;
  static const int _maxConsoleLogLines = 800;
  static const int _maxStartupLogLines = 200;
  static const String _startupActiveLogsKey = 'startup_recovery_active_logs_v1';
  static const String _startupLastLogsKey = 'startup_recovery_last_logs_v1';
  static final List<Map<String, String>> _consoleLogs = <Map<String, String>>[];
  static final ValueNotifier<int> consoleLogVersion = ValueNotifier<int>(0);
  static final List<String> _startupActiveLogs = <String>[];
  static Future<void> _startupLogPersistTail = Future.value();
  static bool _startupRecoverySessionActive = false;

  @visibleForTesting
  static DebugSendRequestOverride? debugSendRequestOverride;

  @visibleForTesting
  static Future<bool> Function(String userId)? debugCredentialValidatorOverride;

  @visibleForTesting
  static String get startupActiveLogsKey => _startupActiveLogsKey;

  @visibleForTesting
  static String get startupLastLogsKey => _startupLastLogsKey;

  /// 鑾峰彇闆ㄨ鍫傛湇鍔″櫒瀵瑰簲鐨?baseUrl
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
    _consoleLogs.add({
      'timestamp': DateTime.now().toIso8601String(),
      'platform': _consolePlatformCommon,
      'message': line,
    });
    if (_consoleLogs.length > _maxConsoleLogLines) {
      final overflow = _consoleLogs.length - _maxConsoleLogLines;
      _consoleLogs.removeRange(0, overflow);
    }
    consoleLogVersion.value++;
  }

  static void appendExternalConsoleLog(String tag, String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');

    String platform = _consolePlatformCommon;
    if (tag.contains(_consolePlatformChaoxing) || tag == 'chaoxing') {
      platform = _consolePlatformChaoxing;
    } else if (tag.contains(_consolePlatformRainClassroom) ||
        tag == 'yuketang' ||
        tag == 'rainclassroom') {
      platform = _consolePlatformRainClassroom;
    } else if (tag.contains(_consolePlatformTronclass) || tag == 'tronclass') {
      platform = _consolePlatformTronclass;
    } else if (tag.contains(_consolePlatformKetangpai) || tag == 'ketangpai') {
      platform = _consolePlatformKetangpai;
    }

    _consoleLogs.add({
      'timestamp': now.toIso8601String(),
      'platform': platform,
      'message': '[$hh:$mm:$ss] [$tag] $message',
    });

    if (_consoleLogs.length > _maxConsoleLogLines) {
      final overflow = _consoleLogs.length - _maxConsoleLogLines;
      _consoleLogs.removeRange(0, overflow);
    }
    consoleLogVersion.value++;
  }

  static String _responseSummary(dynamic data) {
    if (data is Map<String, dynamic>) {
      final code =
          data['code'] ?? data['result'] ?? data['success'] ?? data['status'];
      final msg = data['msg'] ?? data['message'] ?? data['error'];
      final keys = data.keys.take(8).join(',');
      return 'code=$code msg=$msg keys=$keys';
    }
    if (data is List) {
      return 'listLength=${data.length}';
    }
    if (data == null) {
      return 'body=null';
    }
    return 'bodyType=${data.runtimeType}';
  }

  static List<Map<String, String>> getConsoleLogs({String? platform}) {
    if (platform == null || platform == _consolePlatformAll) {
      return List<Map<String, String>>.unmodifiable(_consoleLogs);
    }
    return List<Map<String, String>>.unmodifiable(
      _consoleLogs.where((log) => log['platform'] == platform).toList(),
    );
  }

  static void clearConsoleLogs() {
    if (_consoleLogs.isEmpty) return;
    _consoleLogs.clear();
    consoleLogVersion.value++;
  }

  static Future<void> _loadPersistedStartupLogs() async {
    final prefs = _consolePrefs;
    if (prefs == null) {
      return;
    }

    _appendRecoveredStartupLogs(
      prefs.getStringList(_startupLastLogsKey),
      label: 'LastStartup',
    );
    _appendRecoveredStartupLogs(
      prefs.getStringList(_startupActiveLogsKey),
      label: 'LastStartup/Incomplete',
    );
  }

  static void _appendRecoveredStartupLogs(
    List<String>? lines, {
    required String label,
  }) {
    if (lines == null || lines.isEmpty) {
      return;
    }

    for (final line in lines) {
      _consoleLogs.add({
        'timestamp': DateTime.now().toIso8601String(),
        'platform': '\u901a\u7528',
        'message': '[$label] $line',
      });
    }

    if (_consoleLogs.length > _maxConsoleLogLines) {
      final overflow = _consoleLogs.length - _maxConsoleLogLines;
      _consoleLogs.removeRange(0, overflow);
    }
    consoleLogVersion.value++;
  }

  static String _formatClock(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  static Future<void> beginStartupRecoverySession({
    String reason = 'cold_start',
  }) async {
    _startupActiveLogs.clear();
    _startupRecoverySessionActive = true;
    await _persistStartupActiveLogs();
    logStartupRecovery('[Main] startup session opened reason=$reason');
  }

  static void logStartupRecovery(String message) {
    final line = '[${_formatClock(DateTime.now())}] $message';
    appendExternalConsoleLog('StartupRecovery', message);

    if (!_startupRecoverySessionActive) {
      return;
    }

    _startupActiveLogs.add(line);
    if (_startupActiveLogs.length > _maxStartupLogLines) {
      final overflow = _startupActiveLogs.length - _maxStartupLogLines;
      _startupActiveLogs.removeRange(0, overflow);
    }
    _startupLogPersistTail = _startupLogPersistTail.then((_) async {
      await _persistStartupActiveLogs();
    });
  }

  static Future<void> finishStartupRecoverySession({
    required String status,
    String? summary,
  }) async {
    final suffix = summary == null || summary.isEmpty ? '' : ' $summary';
    if (_startupRecoverySessionActive) {
      logStartupRecovery(
        '[Main] startup session finished status=$status$suffix',
      );
      _startupRecoverySessionActive = false;
      await _startupLogPersistTail;
      final prefs = _consolePrefs;
      if (prefs != null) {
        await prefs.setStringList(
          _startupLastLogsKey,
          List<String>.from(_startupActiveLogs),
        );
        await prefs.remove(_startupActiveLogsKey);
      }
      return;
    }

    appendExternalConsoleLog(
      'StartupRecovery',
      '[Main] startup session finished status=$status$suffix',
    );
  }

  static Future<void> _persistStartupActiveLogs() async {
    final prefs = _consolePrefs;
    if (prefs == null) {
      return;
    }
    await prefs.setStringList(
      _startupActiveLogsKey,
      List<String>.from(_startupActiveLogs),
    );
  }

  // 初始化平台变化回调函数
  static void _setupPlatformChangeCallback() {
    onPlatformChange = () async {
      final platform = PlatformManager().currentPlatformName;
      if (PlatformManager().isChaoxing) {
        _dio.options.baseUrl = 'https://www.chaoxing.com';
        _dio.options.headers = HeadersManager.chaoxingHeaders;
        debugPrint(
          '[ApiService] 鍒囨崲鍒板涔犻€氾紝baseUrl宸叉洿鏂颁负 ${_dio.options.baseUrl}',
        );
      } else if (PlatformManager().isRainClassroom) {
        _dio.options.baseUrl =
            _serverBaseUrlMap[PlatformManager().currentServer]!;
        _dio.options.headers = HeadersManager.rainClassroomHeaders;
        debugPrint(
          '[ApiService] 鍒囨崲鍒伴洦璇惧爞锛宐aseUrl宸叉洿鏂颁负 ${_dio.options.baseUrl}',
        );
      } else if (PlatformManager().isTronclass) {
        _dio.options.baseUrl = PlatformManager().tronclassBaseUrl;
        _dio.options.headers = HeadersManager.tronclassHeaders;
        debugPrint(
          '[ApiService] 鍒囨崲鍒扮晠璇撅紝baseUrl宸叉洿鏂颁负 ${_dio.options.baseUrl}',
        );
      } else if (PlatformManager().isKetangpai) {
        _dio.options.baseUrl = PlatformManager().ketangpaiBaseUrl;
        _dio.options.headers = HeadersManager.ketangpaiHeaders;
        debugPrint(
          '[ApiService] 鍒囨崲鍒拌鍫傛淳锛宐aseUrl宸叉洿鏂颁负 ${_dio.options.baseUrl}',
        );
      } else if (PlatformManager().isWeizhuojiao) {
        _dio.options.baseUrl = 'https://v18.teachermate.cn';
        _dio.options.headers = HeadersManager._wzjHeaders;
        debugPrint(
          '[ApiService] 鍒囨崲鍒板井鍔╂暀锛宐aseUrl宸叉洿鏂颁负 ${_dio.options.baseUrl}',
        );
      }
      appendExternalConsoleLog(
        'ApiService',
        '骞冲彴鍒囨崲瀹屾垚: platform=$platform baseUrl=${_dio.options.baseUrl}',
      );
    };
  }

  static Future<void> initialize() async {
    _consolePrefs = await SharedPreferences.getInstance();
    await _loadPersistedStartupLogs();

    await HeadersManager.updateChaoxingHeaders();
    await BrowserHeadersManager.getUserAgent();
    _strictSecurityMode = AppSettings.strictSecurityModeNotifier.value;
    AppSettings.strictSecurityModeNotifier.addListener(
      _onStrictSecurityModeChanged,
    );

    final userAgent = await BrowserHeadersManager.getUserAgent();
    final standardHeaders = BrowserHeadersManager.getStandardHeaders();

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
        followRedirects: false,
        validateStatus: (status) => status! < 500,
        headers: {'User-Agent': userAgent, ...standardHeaders},
      ),
    );

    /*
    // 鍒濆鍖栧钩鍙板彉鍖栧洖璋?    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.userAgent = HeadersManager._cxUserAgent;
      return client;
    }; // dio 鑷姩閲嶅畾鍚戜細浣跨敤榛樿鐨?User-Agent
    // 浼间箮鏃犳硶鍦ㄥ垵濮嬪寲缁撴潫鍚庤繘琛屾洿鏀?     */
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

  /// 鍙戦€?HTTP 璇锋眰
  static Future<Response<dynamic>> sendRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? params,
    Map<String, String>? headers,
    dynamic body,
    ResponseType responseType = ResponseType.json,
    bool allowRedirects = true,
    bool skipCredentialValidation = false,
    LoginContext? loginContext,
  }) async {
    // Validate credential before request (skip during login)
    if (!skipCredentialValidation && !CookieManager.isLoggingIn) {
      final currentUserId = AccountManager.currentSessionId;
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final validator =
            debugCredentialValidatorOverride ??
            CredentialManager.ensureCredentialValid;
        final isValid = await validator(currentUserId);
        if (!isValid) {
          final user = AccountManager.getAccountById(currentUserId);
          if (user != null) {
            appendExternalConsoleLog(user.platform, '鍑瘉楠岃瘉澶辫触锛岃閲嶆柊鐧诲綍');
          }
        }
      }
    }

    final debugOverride = debugSendRequestOverride;
    if (debugOverride != null) {
      return debugOverride(
        url,
        method: method,
        params: params,
        headers: headers,
        body: body,
        responseType: responseType,
        allowRedirects: allowRedirects,
        skipCredentialValidation: skipCredentialValidation,
      );
    }

    final options = Options(
      method: method,
      headers: headers,
      responseType: responseType,
      extra: {
        if (loginContext != null) 'loginContext': loginContext,
      },
    );

    final isAbsoluteUrl =
        url.startsWith('http://') || url.startsWith('https://');
    final fullUrl = isAbsoluteUrl || _dio.options.baseUrl.isEmpty
        ? url
        : '${_dio.options.baseUrl}$url';
    _logRequest(
      'request',
      url,
      extra:
          'method=${method.toUpperCase()} platform=${PlatformManager().currentPlatformName} '
          'server=${PlatformManager().isRainClassroom ? PlatformManager().serverName : '-'} '
          'baseUrl=${_dio.options.baseUrl.isEmpty ? '<relative>' : _dio.options.baseUrl} '
          'fullUrl=$fullUrl',
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
            extra: options.extra,
          ),
        );
        redirectCount++;
      }
    }

    if (options.responseType == ResponseType.json) {
      if (response.data is String) {
        response.data = jsonDecode(response.data);
      }
    } // dio 鐨?json 瑙ｆ瀽鏈夐棶棰?
    _logRequest(
      'response',
      url,
      extra:
          'status=${response.statusCode} uri=${response.requestOptions.uri} ${_responseSummary(response.data)}',
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

    final isAbsoluteUrl =
        url.startsWith('http://') || url.startsWith('https://');

    for (var attempt = 0; attempt <= _maxRetryCount; attempt++) {
      await _throttleRequest(url, options.method ?? 'GET');
      try {
        _logRequest(
          'attempt',
          url,
          extra:
              'try=${attempt + 1}/${_maxRetryCount + 1} method=${options.method ?? 'GET'}',
        );

        Dio dioInstance = _dio;
        if (isAbsoluteUrl && _dio.options.baseUrl.isNotEmpty) {
          dioInstance = Dio(_dio.options.copyWith(baseUrl: ''));
          dioInstance.interceptors.addAll(_dio.interceptors);
        }

        final response = await dioInstance.request(
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
            extra:
                'status=${response.statusCode} nextTry=${attempt + 2}/${_maxRetryCount + 1}',
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
          extra:
              'attempt=${attempt + 1} error=$e nextTry=${attempt + 2}/${_maxRetryCount + 1}',
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

  /// 灏嗗涔犻€氱殑Star3鍥剧墖杞崲涓篠tar4 鍑忓皯涓€娆￠噸瀹氬悜
  @visibleForTesting
  static void resetForTests() {
    _dio = Dio();
    _consolePrefs = null;
    _consoleLogs.clear();
    _startupActiveLogs.clear();
    _startupLogPersistTail = Future.value();
    _startupRecoverySessionActive = false;
    debugSendRequestOverride = null;
    debugCredentialValidatorOverride = null;
    consoleLogVersion.value = 0;
  }

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
      debugPrint('URL杞崲澶辫触: $e');
    }
    return url;
  }
}
