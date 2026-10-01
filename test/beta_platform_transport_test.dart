import 'dart:io';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/api/ketangpai_course.dart';
import 'package:course_helper/api/course.dart';
import 'package:course_helper/api/platform_dio_manager.dart';
import 'package:course_helper/api/platform_read_exception.dart';
import 'package:course_helper/api/tronclass_client.dart';
import 'package:course_helper/api/tronclass_sign_api.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/ketangpai_semester.dart';
import 'package:course_helper/session/sign_execution_context.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReplayAdapter implements HttpClientAdapter {
  ReplayAdapter(this.respond);
  final ResponseBody Function(RequestOptions request) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

SignExecutionContext identity(PlatformType platform, String uid) =>
    SignExecutionContext(
      platform: platform,
      account: User(
        uid: uid,
        name: 'Fixture',
        avatar: '',
        phone: '',
        school: '',
        platform: platform.name,
        token: 'fixture-token',
      ),
      server: RainClassroomServerType.yuketang,
      tronclassBaseUrl: 'https://tronclass.example.test',
      ketangpaiBaseUrl: 'https://ketangpai.example.test',
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AccountManager.initialize();
    dir = await Directory.systemTemp.createTemp('beta-transport-');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
  });
  tearDownAll(() async {
    PlatformDioManager.clearAll();
    TronclassClient.clearAll();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await dir.delete(recursive: true);
  });

  test(
    'KTP compatibility entry propagates pending attendance failures',
    () async {
      await identity(PlatformType.ketangpai, 'transport-pending').run(() async {
        final dio = await PlatformDioManager.getDioForUser(
          platform: PlatformType.ketangpai,
          userId: 'transport-pending',
        );
        dio.httpClientAdapter = ReplayAdapter((request) {
          return ResponseBody.fromString(
            '{"status":"0","message":"failed","data":[]}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
        await expectLater(
          KTCourseApi.getNotFinishSign('course-pending'),
          throwsA(isA<PlatformReadException>()),
        );
      });
    },
  );

  test(
    'actual Tronclass GET accepts text/plain JSON and reports HTML without a cast error',
    () async {
      await identity(PlatformType.tronclass, 'transport-tc').run(() async {
        final client = await TronclassClient.getInstance('transport-tc');
        var html = false;
        client.dio.httpClientAdapter = ReplayAdapter((request) {
          expect(request.path, '/api/radar/rollcalls?api_version=1.1.0');
          expect(request.method, 'GET');
          return ResponseBody.fromString(
            html
                ? '<html>unavailable</html>'
                : '{"rollcalls":[{"rollcall_id":12,"course_title":"Math"}]}',
            200,
            headers: {
              Headers.contentTypeHeader: ['text/plain'],
            },
          );
        });
        final result = await TronclassSignApi.getRollcalls();
        expect(result.rollcalls.single.rollcallId, 12);
        html = true;
        await expectLater(
          TronclassSignApi.getRollcalls(),
          throwsA(
            isA<PlatformReadException>().having(
              (e) => e.kind,
              'kind',
              PlatformReadFailure.format,
            ),
          ),
        );
      });
    },
  );

  test(
    'actual KTP POST uses stored semester and preserves explicit overrides',
    () async {
      await identity(PlatformType.ketangpai, 'transport-kt').run(() async {
        await KetangpaiSemesterStore.instance.select(
          'transport-kt',
          'https://ketangpai.example.test',
          const KetangpaiSemester(2024, 2),
        );
        final dio = await PlatformDioManager.getDioForUser(
          platform: PlatformType.ketangpai,
          userId: 'transport-kt',
        );
        final bodies = <Map<String, dynamic>>[];
        dio.httpClientAdapter = ReplayAdapter((request) {
          expect(request.method, 'POST');
          expect(request.path, '/CourseApi/semesterCourseList');
          bodies.add(Map<String, dynamic>.from(request.data as Map));
          return ResponseBody.fromString(
            '{"status":"1","code":"10000","data":[]}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
        expect(await KTPCourseApi.getCoursesList(), isEmpty);
        expect(bodies.single['semester'], '2024-2025');
        expect(bodies.single['term'], '2');
        await KTPCourseApi.getCoursesList(semester: '2025-2026', term: '1');
        expect(bodies.last['semester'], '2025-2026');
        expect(bodies.last['term'], '1');
      });
    },
  );
}
