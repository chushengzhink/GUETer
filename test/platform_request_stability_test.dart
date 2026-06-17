import 'package:course_helper/api/platform_request_stability.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Response<dynamic> _response({
  required String path,
  required int statusCode,
  dynamic data,
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: path, method: 'GET'),
    statusCode: statusCode,
    data: data ?? <String, dynamic>{'ok': true},
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PlatformRequestStability.resetForTests();
  });

  test('GET success writes cache and cacheFirst reads it', () async {
    var networkCalls = 0;
    const options = PlatformRequestOptions(
      operationId: 'test.course.list',
      cachePolicy: PlatformRequestCachePolicy.refresh,
    );

    await PlatformRequestStability.execute(
      platform: 'chaoxing',
      userId: 'u1',
      url: 'https://example.test/courses',
      method: 'GET',
      params: const <String, String>{'page': '1'},
      options: options,
      network: (_) async {
        networkCalls++;
        return _response(
          path: 'https://example.test/courses',
          statusCode: 200,
          data: <String, dynamic>{
            'items': <int>[1, 2],
          },
        );
      },
    );

    final cached = await PlatformRequestStability.execute(
      platform: 'chaoxing',
      userId: 'u1',
      url: 'https://example.test/courses',
      method: 'GET',
      params: const <String, String>{'page': '1'},
      options: const PlatformRequestOptions(
        operationId: 'test.course.list',
        cachePolicy: PlatformRequestCachePolicy.cacheFirst,
      ),
      network: (_) async {
        networkCalls++;
        return _response(path: 'unused', statusCode: 200);
      },
    );

    expect(networkCalls, 1);
    expect(cached.fromCache, isTrue);
    expect(cached.response.extra['fromCache'], isTrue);
    expect(cached.response.data, <String, dynamic>{
      'items': <int>[1, 2],
    });
  });

  test('staleIfError returns cached response on 503', () async {
    const url = 'https://example.test/todos';
    await PlatformRequestStability.execute(
      platform: 'tronclass',
      userId: 'u1',
      url: url,
      method: 'GET',
      params: null,
      options: const PlatformRequestOptions(
        operationId: 'test.todo.list',
        cachePolicy: PlatformRequestCachePolicy.refresh,
      ),
      network: (_) async {
        return _response(
          path: url,
          statusCode: 200,
          data: <String, dynamic>{
            'todo_list': <String>['cached'],
          },
        );
      },
    );

    final result = await PlatformRequestStability.execute(
      platform: 'tronclass',
      userId: 'u1',
      url: url,
      method: 'GET',
      params: null,
      options: const PlatformRequestOptions(
        operationId: 'test.todo.list',
        cachePolicy: PlatformRequestCachePolicy.staleIfError,
      ),
      network: (_) async => _response(path: url, statusCode: 503),
    );

    expect(result.fromCache, isTrue);
    expect(result.staleReason, PlatformRequestFailureCategory.server.name);
    expect(result.response.extra['staleReason'], 'server');
    expect(result.response.data, <String, dynamic>{
      'todo_list': <String>['cached'],
    });
  });

  test('staleIfError does not mask auth failures with cache', () async {
    const url = 'https://example.test/courses';
    await PlatformRequestStability.execute(
      platform: 'chaoxing',
      userId: 'u1',
      url: url,
      method: 'GET',
      params: null,
      options: const PlatformRequestOptions(
        operationId: 'test.course.auth_guard',
        cachePolicy: PlatformRequestCachePolicy.refresh,
      ),
      network: (_) async {
        return _response(
          path: url,
          statusCode: 200,
          data: <String, dynamic>{
            'items': <String>['cached'],
          },
        );
      },
    );

    final result = await PlatformRequestStability.execute(
      platform: 'chaoxing',
      userId: 'u1',
      url: url,
      method: 'GET',
      params: null,
      options: const PlatformRequestOptions(
        operationId: 'test.course.auth_guard',
        cachePolicy: PlatformRequestCachePolicy.staleIfError,
      ),
      network: (_) async => _response(path: url, statusCode: 403),
    );

    expect(result.fromCache, isFalse);
    expect(result.response.statusCode, 403);
  });

  test('POST is not handled by stable cache layer', () {
    expect(
      PlatformRequestStability.shouldHandle(
        method: 'POST',
        options: const PlatformRequestOptions(
          operationId: 'test.submit',
          cachePolicy: PlatformRequestCachePolicy.staleIfError,
        ),
      ),
      isFalse,
    );
  });

  test('POST with explicit request kind is throttled but not cached', () async {
    var calls = 0;
    var inFlight = 0;
    var maxInFlight = 0;
    Future<PlatformStableRequestResult> run() {
      return PlatformRequestStability.execute(
        platform: 'chaoxing',
        userId: 'u1',
        url: 'https://example.test/sign',
        method: 'POST',
        params: const <String, String>{'activeId': 'a1'},
        options: const PlatformRequestOptions(
          operationId: 'test.sign.submit',
          cachePolicy: PlatformRequestCachePolicy.staleIfError,
          requestKind: PlatformRequestKind.sign,
          allowControlledParallelism: true,
        ),
        network: (_) async {
          calls++;
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          inFlight--;
          return _response(path: 'https://example.test/sign', statusCode: 200);
        },
      );
    }

    await Future.wait(<Future<PlatformStableRequestResult>>[run(), run()]);
    expect(calls, 2);
    expect(maxInFlight, 1);
  });

  test(
    'cacheFirstThenRefresh returns cache before refresh updates it',
    () async {
      const url = 'https://example.test/courses';
      var calls = 0;
      await PlatformRequestStability.execute(
        platform: 'chaoxing',
        userId: 'u1',
        url: url,
        method: 'GET',
        params: null,
        options: const PlatformRequestOptions(
          operationId: 'test.course.fast_first_paint',
          cachePolicy: PlatformRequestCachePolicy.refresh,
        ),
        network: (_) async {
          calls++;
          return _response(
            path: url,
            statusCode: 200,
            data: <String, dynamic>{'version': 'cached'},
          );
        },
      );

      final result = await PlatformRequestStability.cacheFirstThenRefresh(
        platform: 'chaoxing',
        userId: 'u1',
        url: url,
        method: 'GET',
        params: null,
        options: const PlatformRequestOptions(
          operationId: 'test.course.fast_first_paint',
          cachePolicy: PlatformRequestCachePolicy.staleIfError,
        ),
        network: (_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return _response(
            path: url,
            statusCode: 200,
            data: <String, dynamic>{'version': 'fresh'},
          );
        },
      );

      expect(result.cached, isNotNull);
      expect(result.cached!.fromCache, isTrue);
      expect(result.cached!.response.data, <String, dynamic>{
        'version': 'cached',
      });

      final refreshed = await result.refreshed;
      expect(refreshed.fromCache, isFalse);
      expect(refreshed.response.data, <String, dynamic>{'version': 'fresh'});
      expect(calls, 2);
    },
  );

  test('cacheFirstThenRefresh preserves throttle options on refresh', () async {
    const url = 'https://example.test/courses';
    await PlatformRequestStability.execute(
      platform: 'chaoxing',
      userId: 'u1',
      url: url,
      method: 'GET',
      params: null,
      options: const PlatformRequestOptions(
        operationId: 'test.course.throttle_refresh',
        cachePolicy: PlatformRequestCachePolicy.refresh,
      ),
      network: (_) async {
        return _response(path: url, statusCode: 200);
      },
    );

    var inFlight = 0;
    var maxInFlight = 0;
    Future<PlatformCacheFirstRefreshResult> run() {
      return PlatformRequestStability.cacheFirstThenRefresh(
        platform: 'chaoxing',
        userId: 'u1',
        url: url,
        method: 'GET',
        params: null,
        options: const PlatformRequestOptions(
          operationId: 'test.course.throttle_refresh',
          cachePolicy: PlatformRequestCachePolicy.staleIfError,
          requestKind: PlatformRequestKind.read,
          allowControlledParallelism: true,
        ),
        network: (_) async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
          return _response(path: url, statusCode: 200);
        },
      );
    }

    final results = await Future.wait(<Future<PlatformCacheFirstRefreshResult>>[
      run(),
      run(),
    ]);
    await Future.wait(results.map((item) => item.refreshed));
    expect(maxInFlight, 2);
  });

  test('same GET is deduped but different user is not', () async {
    var calls = 0;
    Future<PlatformStableRequestResult> run(String userId) {
      return PlatformRequestStability.execute(
        platform: 'rainclassroom',
        userId: userId,
        url: 'https://example.test/courses',
        method: 'GET',
        params: const <String, String>{'identity': '2'},
        options: const PlatformRequestOptions(
          operationId: 'test.rain.courses',
          cachePolicy: PlatformRequestCachePolicy.staleIfError,
        ),
        network: (_) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _response(
            path: 'https://example.test/courses',
            statusCode: 200,
          );
        },
      );
    }

    final sameUser = await Future.wait([run('u1'), run('u1')]);
    expect(calls, 1);
    expect(sameUser.map((item) => item.response.statusCode), everyElement(200));

    await Future.wait([run('u1'), run('u2')]);
    expect(calls, 3);
  });

  test('failure classification recognizes auth rate limit and network', () {
    expect(
      PlatformRequestFailure.classify(
        Exception('401'),
        response: _response(path: '/', statusCode: 401),
      ).category,
      PlatformRequestFailureCategory.auth,
    );
    expect(
      PlatformRequestFailure.classify(
        Exception('429'),
        response: _response(path: '/', statusCode: 429),
      ).category,
      PlatformRequestFailureCategory.rateLimited,
    );
    expect(
      PlatformRequestFailure.classify(
        DioException(
          requestOptions: RequestOptions(path: '/'),
          type: DioExceptionType.connectionTimeout,
        ),
      ).category,
      PlatformRequestFailureCategory.network,
    );
  });

  test('throttle limits read concurrency per account', () async {
    final throttle = PlatformRequestThrottle(
      policy: const PlatformRequestThrottlePolicy(
        readPerAccount: 2,
        readPerPlatform: 3,
        degradeDuration: Duration(milliseconds: 80),
      ),
    );
    var inFlight = 0;
    var maxInFlight = 0;

    Future<void> run() {
      return throttle.run<void>(
        platform: 'tronclass',
        userId: 'u1',
        method: 'GET',
        kind: PlatformRequestKind.read,
        allowControlledParallelism: true,
        task: () async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          inFlight--;
        },
      );
    }

    await Future.wait(<Future<void>>[run(), run(), run(), run()]);
    expect(maxInFlight, 2);
  });

  test('throttle exposes recent queue wait time', () async {
    final throttle = PlatformRequestThrottle(
      policy: const PlatformRequestThrottlePolicy(
        readPerAccount: 1,
        readPerPlatform: 1,
      ),
    );

    Future<void> run() {
      return throttle.run<void>(
        platform: 'chaoxing',
        userId: 'u1',
        method: 'GET',
        kind: PlatformRequestKind.read,
        allowControlledParallelism: true,
        task: () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
    }

    await Future.wait(<Future<void>>[run(), run()]);

    final state = throttle.stateFor(platform: 'chaoxing', userId: 'u1');
    expect(state.lastQueueWaitMs, greaterThan(0));
  });

  test(
    'throttle keeps submit requests serial even when parallelism is allowed',
    () async {
      final throttle = PlatformRequestThrottle(
        policy: const PlatformRequestThrottlePolicy(
          readPerAccount: 3,
          readPerPlatform: 3,
        ),
      );
      var inFlight = 0;
      var maxInFlight = 0;

      Future<void> run() {
        return throttle.run<void>(
          platform: 'chaoxing',
          userId: 'u1',
          method: 'POST',
          kind: PlatformRequestKind.sign,
          allowControlledParallelism: true,
          task: () async {
            inFlight++;
            if (inFlight > maxInFlight) maxInFlight = inFlight;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            inFlight--;
          },
        );
      }

      await Future.wait(<Future<void>>[run(), run(), run()]);
      expect(maxInFlight, 1);
    },
  );

  test('throttle degrades to serial after rate limit response', () async {
    final throttle = PlatformRequestThrottle(
      policy: const PlatformRequestThrottlePolicy(
        readPerAccount: 2,
        readPerPlatform: 3,
        degradeDuration: Duration(milliseconds: 120),
      ),
    );

    await throttle.run<Response<dynamic>>(
      platform: 'rainclassroom',
      userId: 'u1',
      method: 'GET',
      kind: PlatformRequestKind.read,
      allowControlledParallelism: true,
      task: () async => _response(path: '/', statusCode: 429),
    );

    expect(
      throttle.stateFor(platform: 'rainclassroom', userId: 'u1').isDegraded,
      isTrue,
    );

    var inFlight = 0;
    var maxInFlight = 0;
    Future<void> run() {
      return throttle.run<void>(
        platform: 'rainclassroom',
        userId: 'u1',
        method: 'GET',
        kind: PlatformRequestKind.read,
        allowControlledParallelism: true,
        task: () async {
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
        },
      );
    }

    await Future.wait(<Future<void>>[run(), run()]);
    expect(maxInFlight, 1);
  });
}
