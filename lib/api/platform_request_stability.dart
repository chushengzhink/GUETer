import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlatformRequestCachePolicy {
  networkOnly,
  cacheFirst,
  refresh,
  staleIfError,
}

enum PlatformRequestTimeoutProfile { standard, quick, long }

enum PlatformRequestKind {
  read,
  sign,
  login,
  captcha,
  submit,
  healthCheck,
  other,
}

enum PlatformRequestFailureCategory {
  network,
  auth,
  rateLimited,
  server,
  schema,
  empty,
  cancelled,
  unknown,
}

class PlatformRequestOptions {
  const PlatformRequestOptions({
    required this.operationId,
    this.cachePolicy = PlatformRequestCachePolicy.networkOnly,
    this.timeoutProfile = PlatformRequestTimeoutProfile.standard,
    this.dedupeKey,
    this.cancelGroup,
    this.logLabel,
    this.cacheTtl,
    this.requestKind,
    this.throttleKey,
    this.allowControlledParallelism = false,
    this.functionalProfileEnabled = true,
  });

  final String operationId;
  final PlatformRequestCachePolicy cachePolicy;
  final PlatformRequestTimeoutProfile timeoutProfile;
  final String? dedupeKey;
  final String? cancelGroup;
  final String? logLabel;
  final Duration? cacheTtl;
  final PlatformRequestKind? requestKind;
  final String? throttleKey;
  final bool allowControlledParallelism;
  final bool functionalProfileEnabled;

  Duration get effectiveCacheTtl => cacheTtl ?? defaultCacheTtl(operationId);

  static Duration defaultCacheTtl(String operationId) {
    final lower = operationId.toLowerCase();
    if (lower.contains('exam') || lower.contains('work')) {
      return const Duration(minutes: 5);
    }
    if (lower.contains('offline')) {
      return const Duration(minutes: 30);
    }
    return const Duration(minutes: 10);
  }
}

class PlatformRequestFailure {
  const PlatformRequestFailure({
    required this.category,
    required this.message,
    this.statusCode,
  });

  final PlatformRequestFailureCategory category;
  final String message;
  final int? statusCode;

  static PlatformRequestFailure classify(Object error, {Response? response}) {
    final statusCode =
        response?.statusCode ??
        (error is DioException ? error.response?.statusCode : null);
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.cancel:
          return PlatformRequestFailure(
            category: PlatformRequestFailureCategory.cancelled,
            message: error.message ?? 'request cancelled',
            statusCode: statusCode,
          );
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return PlatformRequestFailure(
            category: PlatformRequestFailureCategory.network,
            message: error.message ?? 'network error',
            statusCode: statusCode,
          );
        case DioExceptionType.badResponse:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          break;
      }
    }

    if (statusCode == 401 || statusCode == 403) {
      return PlatformRequestFailure(
        category: PlatformRequestFailureCategory.auth,
        message: 'auth failed',
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return PlatformRequestFailure(
        category: PlatformRequestFailureCategory.rateLimited,
        message: 'rate limited',
        statusCode: statusCode,
      );
    }
    if (statusCode != null && statusCode >= 500) {
      return PlatformRequestFailure(
        category: PlatformRequestFailureCategory.server,
        message: 'server error',
        statusCode: statusCode,
      );
    }
    if (error is FormatException || error is TypeError) {
      return PlatformRequestFailure(
        category: PlatformRequestFailureCategory.schema,
        message: error.toString(),
        statusCode: statusCode,
      );
    }
    return PlatformRequestFailure(
      category: PlatformRequestFailureCategory.unknown,
      message: error.toString(),
      statusCode: statusCode,
    );
  }

  bool get canUseStaleCache {
    return category == PlatformRequestFailureCategory.network ||
        category == PlatformRequestFailureCategory.rateLimited ||
        statusCode == 503 ||
        statusCode == 504;
  }

  String get categoryName => category.name;
}

class PlatformRequestCacheEntry {
  const PlatformRequestCacheEntry({
    required this.key,
    required this.createdAt,
    required this.statusCode,
    required this.data,
    required this.url,
    required this.method,
  });

  final String key;
  final DateTime createdAt;
  final int? statusCode;
  final dynamic data;
  final String url;
  final String method;

  bool isFresh(Duration ttl, DateTime now) {
    return now.difference(createdAt) <= ttl;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'createdAt': createdAt.toIso8601String(),
      'statusCode': statusCode,
      'data': data,
      'url': url,
      'method': method,
    };
  }

  static PlatformRequestCacheEntry? fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString();
    final createdAt = createdAtRaw == null
        ? null
        : DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return null;
    return PlatformRequestCacheEntry(
      key: json['key']?.toString() ?? '',
      createdAt: createdAt,
      statusCode: json['statusCode'] is int ? json['statusCode'] as int : null,
      data: json['data'],
      url: json['url']?.toString() ?? '',
      method: json['method']?.toString() ?? 'GET',
    );
  }
}

class PlatformRequestCacheStore {
  PlatformRequestCacheStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _prefix = 'platform_request_cache_v1_';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  static String buildKey({
    required String platform,
    required String userId,
    required String method,
    required String url,
    Map<String, String>? params,
    String? operationId,
    String? dedupeKey,
  }) {
    final normalizedParams = _normalizeParams(params);
    final raw = jsonEncode(<String, dynamic>{
      'platform': platform,
      'userId': userId,
      'method': method.toUpperCase(),
      'url': url,
      'params': normalizedParams,
      'operationId': operationId,
      'dedupeKey': dedupeKey,
    });
    return base64Url.encode(utf8.encode(raw));
  }

  Future<PlatformRequestCacheEntry?> read(String key) async {
    final raw = (await _prefs).getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return PlatformRequestCacheEntry.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String key,
    required Response response,
    required String url,
    required String method,
  }) async {
    if (!_canEncode(response.data)) return;
    final entry = PlatformRequestCacheEntry(
      key: key,
      createdAt: DateTime.now(),
      statusCode: response.statusCode,
      data: response.data,
      url: url,
      method: method.toUpperCase(),
    );
    await (await _prefs).setString('$_prefix$key', jsonEncode(entry.toJson()));
  }

  static bool _canEncode(dynamic value) {
    try {
      jsonEncode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> _normalizeParams(Map<String, String>? params) {
    if (params == null || params.isEmpty) return const <String, String>{};
    final keys = params.keys.toList()..sort();
    return <String, String>{for (final key in keys) key: params[key] ?? ''};
  }
}

class PlatformRequestCoordinator {
  PlatformRequestCoordinator._();

  static final PlatformRequestCoordinator instance =
      PlatformRequestCoordinator._();

  final Map<String, Future<Response<dynamic>>> _inFlight =
      <String, Future<Response<dynamic>>>{};
  final Map<String, Set<CancelToken>> _cancelGroups =
      <String, Set<CancelToken>>{};

  Future<Response<dynamic>> run({
    required String key,
    required bool enabled,
    String? cancelGroup,
    required Future<Response<dynamic>> Function(CancelToken? cancelToken) task,
    void Function(bool dedupeHit)? onDedupe,
  }) {
    if (!enabled) {
      return task(null);
    }

    final existing = _inFlight[key];
    if (existing != null) {
      onDedupe?.call(true);
      return existing;
    }

    onDedupe?.call(false);
    final cancelToken = cancelGroup == null ? null : CancelToken();
    if (cancelGroup != null && cancelToken != null) {
      _cancelGroups
          .putIfAbsent(cancelGroup, () => <CancelToken>{})
          .add(cancelToken);
    }

    final future = task(cancelToken).whenComplete(() {
      _inFlight.remove(key);
      if (cancelGroup != null && cancelToken != null) {
        final group = _cancelGroups[cancelGroup];
        group?.remove(cancelToken);
        if (group != null && group.isEmpty) {
          _cancelGroups.remove(cancelGroup);
        }
      }
    });
    _inFlight[key] = future;
    return future;
  }

  void cancelGroup(String cancelGroup, [String reason = 'cancelled']) {
    final tokens = _cancelGroups.remove(cancelGroup);
    if (tokens == null) return;
    for (final token in tokens) {
      if (!token.isCancelled) {
        token.cancel(reason);
      }
    }
  }

  @visibleForTesting
  void resetForTests() {
    _inFlight.clear();
    _cancelGroups.clear();
  }
}

class PlatformRequestThrottlePolicy {
  const PlatformRequestThrottlePolicy({
    this.readPerAccount = 2,
    this.readPerPlatform = 3,
    this.writePerAccount = 1,
    this.healthCheckPerPlatform = 1,
    this.degradeDuration = const Duration(minutes: 2),
  });

  final int readPerAccount;
  final int readPerPlatform;
  final int writePerAccount;
  final int healthCheckPerPlatform;
  final Duration degradeDuration;

  int perAccountLimitFor({
    required String method,
    required PlatformRequestKind kind,
    required bool allowControlledParallelism,
    required bool degraded,
  }) {
    if (degraded) return 1;
    if (kind == PlatformRequestKind.healthCheck) return healthCheckPerPlatform;
    if (!allowControlledParallelism) return 1;
    if (method.toUpperCase() == 'GET' && kind == PlatformRequestKind.read) {
      return readPerAccount;
    }
    return writePerAccount;
  }

  int platformLimitFor({
    required PlatformRequestKind kind,
    required bool allowControlledParallelism,
    required bool degraded,
  }) {
    if (degraded) return 1;
    if (kind == PlatformRequestKind.healthCheck) return healthCheckPerPlatform;
    if (!allowControlledParallelism) return 1;
    return readPerPlatform;
  }
}

class PlatformRequestThrottleState {
  const PlatformRequestThrottleState({
    required this.platform,
    required this.userId,
    required this.inFlightForAccount,
    required this.inFlightForPlatform,
    required this.degradedUntil,
    required this.lastDegradeReason,
    required this.lastQueueWaitMs,
  });

  final String platform;
  final String userId;
  final int inFlightForAccount;
  final int inFlightForPlatform;
  final DateTime? degradedUntil;
  final String? lastDegradeReason;
  final int lastQueueWaitMs;

  bool get isDegraded {
    final until = degradedUntil;
    return until != null && DateTime.now().isBefore(until);
  }
}

class PlatformRequestThrottle {
  PlatformRequestThrottle({
    this.policy = const PlatformRequestThrottlePolicy(),
  });

  final PlatformRequestThrottlePolicy policy;
  final Map<String, int> _accountInFlight = <String, int>{};
  final Map<String, int> _platformInFlight = <String, int>{};
  final Map<String, DateTime> _degradedUntil = <String, DateTime>{};
  final Map<String, String> _degradeReasons = <String, String>{};
  final Map<String, int> _lastQueueWaitMs = <String, int>{};
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>({
    required String platform,
    required String userId,
    required String method,
    required PlatformRequestKind kind,
    required bool allowControlledParallelism,
    required Future<T> Function() task,
    void Function(PlatformRequestThrottleState state)? onState,
  }) async {
    final accountKey = _accountKey(platform, userId);
    final platformKey = platform.toLowerCase();
    await _acquire(
      platformKey: platformKey,
      accountKey: accountKey,
      userId: userId,
      method: method,
      kind: kind,
      allowControlledParallelism: allowControlledParallelism,
      onState: onState,
    );
    try {
      final result = await task();
      _recordResult(platformKey, accountKey, result);
      return result;
    } catch (error) {
      _recordFailure(platformKey, accountKey, error);
      rethrow;
    } finally {
      _release(platformKey: platformKey, accountKey: accountKey);
    }
  }

  PlatformRequestThrottleState stateFor({
    required String platform,
    required String userId,
  }) {
    final platformKey = platform.toLowerCase();
    final accountKey = _accountKey(platform, userId);
    return PlatformRequestThrottleState(
      platform: platformKey,
      userId: userId,
      inFlightForAccount: _accountInFlight[accountKey] ?? 0,
      inFlightForPlatform: _platformInFlight[platformKey] ?? 0,
      degradedUntil:
          _activeDegradedUntil(accountKey) ?? _activeDegradedUntil(platformKey),
      lastDegradeReason:
          _degradeReasons[accountKey] ?? _degradeReasons[platformKey],
      lastQueueWaitMs:
          _lastQueueWaitMs[accountKey] ?? _lastQueueWaitMs[platformKey] ?? 0,
    );
  }

  Future<void> _acquire({
    required String platformKey,
    required String accountKey,
    required String userId,
    required String method,
    required PlatformRequestKind kind,
    required bool allowControlledParallelism,
    required void Function(PlatformRequestThrottleState state)? onState,
  }) async {
    final queuedAt = DateTime.now();
    while (true) {
      final acquired = await _withLock(() async {
        _purgeExpiredDegrade(platformKey);
        _purgeExpiredDegrade(accountKey);
        final degraded =
            _activeDegradedUntil(accountKey) != null ||
            _activeDegradedUntil(platformKey) != null;
        final accountLimit = policy.perAccountLimitFor(
          method: method,
          kind: kind,
          allowControlledParallelism: allowControlledParallelism,
          degraded: degraded,
        );
        final platformLimit = policy.platformLimitFor(
          kind: kind,
          allowControlledParallelism: allowControlledParallelism,
          degraded: degraded,
        );
        final accountCount = _accountInFlight[accountKey] ?? 0;
        final platformCount = _platformInFlight[platformKey] ?? 0;
        if (accountCount < accountLimit && platformCount < platformLimit) {
          final waitMs = DateTime.now().difference(queuedAt).inMilliseconds;
          _lastQueueWaitMs[accountKey] = waitMs;
          _lastQueueWaitMs[platformKey] = waitMs;
          _accountInFlight[accountKey] = accountCount + 1;
          _platformInFlight[platformKey] = platformCount + 1;
          onState?.call(stateFor(platform: platformKey, userId: userId));
          return true;
        }
        return false;
      });
      if (acquired) return;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<T> _withLock<T>(FutureOr<T> Function() action) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        completer.complete();
      }
    });
  }

  void _release({required String platformKey, required String accountKey}) {
    final accountCount = (_accountInFlight[accountKey] ?? 1) - 1;
    final platformCount = (_platformInFlight[platformKey] ?? 1) - 1;
    if (accountCount <= 0) {
      _accountInFlight.remove(accountKey);
    } else {
      _accountInFlight[accountKey] = accountCount;
    }
    if (platformCount <= 0) {
      _platformInFlight.remove(platformKey);
    } else {
      _platformInFlight[platformKey] = platformCount;
    }
  }

  void _recordResult(String platformKey, String accountKey, Object? result) {
    if (result is Response && _shouldDegradeStatus(result.statusCode)) {
      _degrade(platformKey, accountKey, 'HTTP ${result.statusCode}');
    }
  }

  void _recordFailure(String platformKey, String accountKey, Object error) {
    if (_shouldDegradeError(error)) {
      _degrade(platformKey, accountKey, error.toString());
    }
  }

  void _degrade(String platformKey, String accountKey, String reason) {
    final until = DateTime.now().add(policy.degradeDuration);
    _degradedUntil[platformKey] = until;
    _degradedUntil[accountKey] = until;
    _degradeReasons[platformKey] = reason;
    _degradeReasons[accountKey] = reason;
  }

  DateTime? _activeDegradedUntil(String key) {
    final until = _degradedUntil[key];
    if (until == null) return null;
    if (DateTime.now().isAfter(until)) {
      _degradedUntil.remove(key);
      _degradeReasons.remove(key);
      return null;
    }
    return until;
  }

  void _purgeExpiredDegrade(String key) {
    _activeDegradedUntil(key);
  }

  static bool _shouldDegradeStatus(int? statusCode) {
    return statusCode == 401 ||
        statusCode == 403 ||
        statusCode == 429 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  static bool _shouldDegradeError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError ||
          _shouldDegradeStatus(error.response?.statusCode);
    }
    return false;
  }

  static String _accountKey(String platform, String userId) {
    return '${platform.toLowerCase()}::$userId';
  }

  @visibleForTesting
  void resetForTests() {
    _accountInFlight.clear();
    _platformInFlight.clear();
    _degradedUntil.clear();
    _degradeReasons.clear();
    _lastQueueWaitMs.clear();
    _tail = Future<void>.value();
  }
}

class PlatformStableRequestResult {
  const PlatformStableRequestResult({
    required this.response,
    required this.fromCache,
    required this.dedupeHit,
    this.staleReason,
    this.failure,
  });

  final Response<dynamic> response;
  final bool fromCache;
  final bool dedupeHit;
  final String? staleReason;
  final PlatformRequestFailure? failure;
}

class PlatformCacheFirstRefreshResult {
  const PlatformCacheFirstRefreshResult({
    required this.cached,
    required this.refreshed,
  });

  final PlatformStableRequestResult? cached;
  final Future<PlatformStableRequestResult> refreshed;
}

class PlatformRequestStability {
  PlatformRequestStability._();

  static PlatformRequestCacheStore cacheStore = PlatformRequestCacheStore();
  static PlatformRequestCoordinator coordinator =
      PlatformRequestCoordinator.instance;
  static PlatformRequestThrottle throttle = PlatformRequestThrottle();

  static bool isReadRequest(String method) => method.toUpperCase() == 'GET';

  static bool shouldHandle({
    required String method,
    required PlatformRequestOptions? options,
  }) {
    if (options == null) return false;
    if (isReadRequest(method)) {
      return options.cachePolicy != PlatformRequestCachePolicy.networkOnly ||
          options.allowControlledParallelism ||
          options.requestKind != null;
    }
    return options.requestKind != null;
  }

  static Future<PlatformStableRequestResult> execute({
    required String platform,
    required String userId,
    required String url,
    required String method,
    required Map<String, String>? params,
    required PlatformRequestOptions options,
    required Future<Response<dynamic>> Function(CancelToken? cancelToken)
    network,
  }) async {
    final cacheEnabled =
        isReadRequest(method) &&
        options.cachePolicy != PlatformRequestCachePolicy.networkOnly;
    final key = PlatformRequestCacheStore.buildKey(
      platform: platform,
      userId: userId,
      method: method,
      url: url,
      params: params,
      operationId: options.operationId,
      dedupeKey: options.dedupeKey,
    );
    final ttl = options.effectiveCacheTtl;
    final now = DateTime.now();
    final cached = cacheEnabled ? await cacheStore.read(key) : null;

    if (cacheEnabled &&
        options.cachePolicy == PlatformRequestCachePolicy.cacheFirst &&
        cached != null &&
        cached.isFresh(ttl, now)) {
      return PlatformStableRequestResult(
        response: _responseFromCache(
          cached,
          url: url,
          method: method,
          params: params,
          options: options,
          staleReason: null,
        ),
        fromCache: true,
        dedupeHit: false,
      );
    }

    var dedupeHit = false;
    try {
      final response = await coordinator.run(
        key: key,
        enabled:
            cacheEnabled &&
            options.cachePolicy != PlatformRequestCachePolicy.refresh,
        cancelGroup: options.cancelGroup,
        onDedupe: (hit) => dedupeHit = hit,
        task: (cancelToken) {
          return _runThrottled(
            platform: platform,
            userId: userId,
            method: method,
            options: options,
            network: () => network(cancelToken),
          );
        },
      );
      response.extra.addAll(<String, dynamic>{
        'fromCache': false,
        'cachePolicy': options.cachePolicy.name,
        'dedupeHit': dedupeHit,
        'operationId': options.operationId,
      });
      if (cacheEnabled && _isSuccessfulGet(response)) {
        await cacheStore.write(
          key: key,
          response: response,
          url: url,
          method: method,
        );
      }
      final failure = PlatformRequestFailure.classify(
        Exception('HTTP ${response.statusCode}'),
        response: response,
      );
      if (cacheEnabled &&
          options.cachePolicy == PlatformRequestCachePolicy.staleIfError &&
          cached != null &&
          failure.canUseStaleCache) {
        return PlatformStableRequestResult(
          response: _responseFromCache(
            cached,
            url: url,
            method: method,
            params: params,
            options: options,
            staleReason: failure.categoryName,
          ),
          fromCache: true,
          dedupeHit: dedupeHit,
          staleReason: failure.categoryName,
          failure: failure,
        );
      }
      return PlatformStableRequestResult(
        response: response,
        fromCache: false,
        dedupeHit: dedupeHit,
      );
    } catch (error) {
      final failure = PlatformRequestFailure.classify(error);
      if (cacheEnabled &&
          options.cachePolicy == PlatformRequestCachePolicy.staleIfError &&
          cached != null &&
          failure.canUseStaleCache) {
        return PlatformStableRequestResult(
          response: _responseFromCache(
            cached,
            url: url,
            method: method,
            params: params,
            options: options,
            staleReason: failure.categoryName,
          ),
          fromCache: true,
          dedupeHit: dedupeHit,
          staleReason: failure.categoryName,
          failure: failure,
        );
      }
      rethrow;
    }
  }

  static Future<PlatformCacheFirstRefreshResult> cacheFirstThenRefresh({
    required String platform,
    required String userId,
    required String url,
    required String method,
    required Map<String, String>? params,
    required PlatformRequestOptions options,
    required Future<Response<dynamic>> Function(CancelToken? cancelToken)
    network,
  }) async {
    if (!isReadRequest(method)) {
      return PlatformCacheFirstRefreshResult(
        cached: null,
        refreshed: execute(
          platform: platform,
          userId: userId,
          url: url,
          method: method,
          params: params,
          options: options,
          network: network,
        ),
      );
    }

    final cacheOptions = PlatformRequestOptions(
      operationId: options.operationId,
      cachePolicy: PlatformRequestCachePolicy.cacheFirst,
      timeoutProfile: options.timeoutProfile,
      dedupeKey: options.dedupeKey,
      cancelGroup: options.cancelGroup,
      logLabel: options.logLabel,
      cacheTtl: options.cacheTtl,
      requestKind: options.requestKind,
      throttleKey: options.throttleKey,
      allowControlledParallelism: options.allowControlledParallelism,
      functionalProfileEnabled: options.functionalProfileEnabled,
    );
    final refreshOptions = PlatformRequestOptions(
      operationId: options.operationId,
      cachePolicy: PlatformRequestCachePolicy.refresh,
      timeoutProfile: options.timeoutProfile,
      dedupeKey: options.dedupeKey,
      cancelGroup: options.cancelGroup,
      logLabel: options.logLabel,
      cacheTtl: options.cacheTtl,
      requestKind: options.requestKind,
      throttleKey: options.throttleKey,
      allowControlledParallelism: options.allowControlledParallelism,
      functionalProfileEnabled: options.functionalProfileEnabled,
    );

    PlatformStableRequestResult? cached;
    try {
      cached = await execute(
        platform: platform,
        userId: userId,
        url: url,
        method: method,
        params: params,
        options: cacheOptions,
        network: (_) {
          throw StateError('cache miss');
        },
      );
      if (!cached.fromCache) {
        cached = null;
      }
    } catch (_) {
      cached = null;
    }

    return PlatformCacheFirstRefreshResult(
      cached: cached,
      refreshed: execute(
        platform: platform,
        userId: userId,
        url: url,
        method: method,
        params: params,
        options: refreshOptions,
        network: network,
      ),
    );
  }

  static Future<Response<dynamic>> _runThrottled({
    required String platform,
    required String userId,
    required String method,
    required PlatformRequestOptions options,
    required Future<Response<dynamic>> Function() network,
  }) {
    final kind = options.requestKind ?? _inferRequestKind(method, options);
    return throttle.run<Response<dynamic>>(
      platform: platform,
      userId: options.throttleKey ?? userId,
      method: method,
      kind: kind,
      allowControlledParallelism: options.allowControlledParallelism,
      task: network,
    );
  }

  static PlatformRequestKind _inferRequestKind(
    String method,
    PlatformRequestOptions options,
  ) {
    if (method.toUpperCase() == 'GET') {
      return PlatformRequestKind.read;
    }
    final lower = options.operationId.toLowerCase();
    if (lower.contains('sign') ||
        lower.contains('rollcall') ||
        lower.contains('attendance') ||
        lower.contains('checkin')) {
      return PlatformRequestKind.sign;
    }
    if (lower.contains('login')) return PlatformRequestKind.login;
    if (lower.contains('captcha')) return PlatformRequestKind.captcha;
    return PlatformRequestKind.submit;
  }

  static Response<dynamic> _responseFromCache(
    PlatformRequestCacheEntry entry, {
    required String url,
    required String method,
    required Map<String, String>? params,
    required PlatformRequestOptions options,
    required String? staleReason,
  }) {
    return Response<dynamic>(
      requestOptions: RequestOptions(
        path: url,
        method: method.toUpperCase(),
        queryParameters: params,
      ),
      statusCode: entry.statusCode,
      data: entry.data,
      extra: <String, dynamic>{
        'fromCache': true,
        'cachePolicy': options.cachePolicy.name,
        'operationId': options.operationId,
        'staleReason': ?staleReason,
      },
    );
  }

  static bool _isSuccessfulGet(Response response) {
    final statusCode = response.statusCode ?? 0;
    return statusCode >= 200 && statusCode < 300;
  }

  @visibleForTesting
  static void resetForTests({PlatformRequestCacheStore? store}) {
    cacheStore = store ?? PlatformRequestCacheStore();
    coordinator.resetForTests();
    throttle.resetForTests();
  }
}
