import 'dart:io';
import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/platform_dio_manager.dart';
import 'package:course_helper/api/tronclass_client.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:course_helper/session/sign_execution_context.dart';
import 'package:course_helper/session/tronclass_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'beta2_workspace_interaction_test.dart' show fixtureUser;

class _TimeoutAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.receiveTimeout,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final directory = Directory(
      '${Directory.current.path}/_tmp/beta2-cookie-fixture',
    )..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    SharedPreferences.setMockInitialValues({});
    ApiService.resetForTests();
    CookieManager.resetForTests();
    await ApiService.initialize();
    await PlatformManager().initialize();
    await AccountManager.initialize();
    await CookieManager.initialize();
  });
  tearDownAll(() {
    PlatformDioManager.clearAll();
    TronclassClient.clearAll();
    ApiService.resetForTests();
    CookieManager.resetForTests();
  });

  test(
    'same UID on two sites has separate client and session; default session key survives',
    () async {
      await TronclassAuthManager.setSessionIdForUser(
        'test-user',
        'default-session',
        baseUrl: 'https://courses.guet.edu.cn',
      );
      await TronclassAuthManager.setSessionIdForUser(
        'test-user',
        'school-session',
        baseUrl: 'https://school.test',
      );
      final a = await TronclassClient.getInstance(
        'test-user',
        baseUrl: 'https://courses.guet.edu.cn',
      );
      final b = await TronclassClient.getInstance(
        'test-user',
        baseUrl: 'https://school.test',
      );
      expect(identical(a, b), isFalse);
      expect(a.sessionId, 'default-session');
      expect(b.sessionId, 'school-session');
      expect(b.dio.options.baseUrl, 'https://school.test');
      expect(
        (await SharedPreferences.getInstance()).getString(
          'tronclass_auth_session_test-user',
        ),
        'default-session',
      );
      final repeated = await Future.wait([
        TronclassClient.getInstance(
          'test-user',
          baseUrl: 'https://school.test',
        ),
        TronclassClient.getInstance(
          'test-user',
          baseUrl: 'https://school.test',
        ),
      ]);
      expect(identical(repeated[0], repeated[1]), isTrue);
    },
  );

  test(
    'rain server changes create isolated base URLs for the same UID',
    () async {
      SignExecutionContext identity(RainClassroomServerType server) =>
          SignExecutionContext(
            platform: PlatformType.rainClassroom,
            account: fixtureUser('same'),
            server: server,
            tronclassBaseUrl: 'https://school.test',
            ketangpaiBaseUrl: 'https://kt.test',
          );
      final pro = await identity(RainClassroomServerType.pro).run(
        () => PlatformDioManager.getDioForUser(
          platform: PlatformType.rainClassroom,
          userId: 'same',
        ),
      );
      final river = await identity(RainClassroomServerType.huanghe).run(
        () => PlatformDioManager.getDioForUser(
          platform: PlatformType.rainClassroom,
          userId: 'same',
        ),
      );
      expect(identical(pro, river), isFalse);
      expect(pro.options.baseUrl, 'https://pro.yuketang.cn');
      expect(river.options.baseUrl, 'https://huanghe.yuketang.cn');
    },
  );

  test(
    'actual client sends ambiguous check-in GET and write POST only once',
    () async {
      final client = await PlatformDioManager.getDioForUser(
        platform: PlatformType.chaoxing,
        userId: 'request-test',
      );
      final adapter = _TimeoutAdapter();
      client.httpClientAdapter = adapter;
      final options = Options(headers: {'Cookie': 'fixture=1'});
      await expectLater(
        client.get('/pptSign/stuSignajax', options: options),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
      await expectLater(
        client.post('/write', options: options),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 2);
    },
  );
}
