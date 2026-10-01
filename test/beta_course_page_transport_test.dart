import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/platform_dio_manager.dart';
import 'package:course_helper/features/courses/course_workspace.dart';
import 'package:course_helper/pages/courses.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:course_helper/session/ketangpai_semester.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'beta_platform_transport_test.dart' show identity;
import 'beta_semester_ui_test.dart' show app;

class DeferredCourseAdapter implements HttpClientAdapter {
  final requests = <(RequestOptions, Completer<ResponseBody>)>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final response = Completer<ResponseBody>();
    requests.add((options, response));
    return response.future;
  }

  void complete(int index, String title, {bool failed = false}) {
    requests[index].$2.complete(
      ResponseBody.fromString(
        jsonEncode({
          'status': failed ? '0' : '1',
          'data': failed
              ? []
              : [
                  {'id': title, 'coursename': title},
                ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'course page retains cache on failure and rejects superseded semesters',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('beta-course-page-'),
      ))!;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path,
      );
      final adapter = DeferredCourseAdapter();
      const uid = 'page-transport';
      const endpoint = 'https://ketangpai.example.test';
      final semesters = KetangpaiSemesterStore.instance;
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({
          'current_platform': 'ketangpai',
          'ketangpai_base_url': endpoint,
        });
        ApiService.resetForTests();
        CookieManager.resetForTests();
        await ApiService.initialize();
        await PlatformManager().initialize();
        await AccountManager.initialize();
        await CookieManager.initialize();
        await AccountManager.addAccountForPlatformName(
          'ketangpai',
          identity(PlatformType.ketangpai, uid).account!,
          notify: false,
          migrateTempCookies: false,
        );
        await semesters.select(uid, endpoint, const KetangpaiSemester(2025, 2));
        final dio = await PlatformDioManager.getDioForUser(
          platform: PlatformType.ketangpai,
          userId: uid,
        );
        dio.httpClientAdapter = adapter;
      });

      Future<void> until(bool Function() ready) async {
        for (var i = 0; i < 200 && !ready(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(ready(), isTrue);
        expect(tester.takeException(), isNull);
      }

      CourseWorkspace workspace() =>
          tester.widget<CourseWorkspace>(find.byType(CourseWorkspace));
      await tester.pumpWidget(app(const CoursesPage()));
      await until(() => adapter.requests.length == 1);
      expect((adapter.requests[0].$1.data as Map)['semester'], '2025-2026');
      adapter.complete(0, 'Previous semester');
      await until(() => workspace().courses.isNotEmpty && !workspace().loading);
      final timestamp = workspace().updatedAt;

      // Repeated refresh shares the real request and keeps its old successful data.
      final first = workspace().onRefresh();
      final second = workspace().onRefresh();
      var refreshFinished = false;
      final refreshes = Future.wait([first, second]).then((_) {
        refreshFinished = true;
      });
      await until(() => adapter.requests.length == 2);
      expect(workspace().courses.single.name, 'Previous semester');
      adapter.complete(1, '', failed: true);
      await until(() => workspace().failed);
      await until(() => refreshFinished);
      await refreshes;
      expect(adapter.requests.length, 2);
      expect(workspace().courses.single.name, 'Previous semester');
      expect(workspace().updatedAt, timestamp);

      await tester.runAsync(
        () => semesters.select(uid, endpoint, const KetangpaiSemester(2026, 1)),
      );
      await until(() => adapter.requests.length == 3);
      expect(workspace().courses, isEmpty);
      expect(workspace().semesterLabel, contains('2026-2027'));
      await tester.runAsync(
        () => semesters.select(uid, endpoint, const KetangpaiSemester(2024, 1)),
      );
      // The existing per-account POST throttle serializes these read requests.
      // Complete the old semester only after the UI has switched away from it.
      await tester.pump();
      expect(workspace().semesterLabel, contains('2024-2025'));
      adapter.complete(2, 'Stale semester');
      await until(() => adapter.requests.length == 4);
      expect(workspace().courses, isEmpty);
      adapter.complete(3, 'Current semester');
      await until(() => workspace().courses.isNotEmpty && !workspace().loading);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(workspace().courses.single.name, 'Current semester');

      // Applying a recently cached semester still refreshes it.
      await tester.runAsync(
        () => semesters.select(uid, endpoint, const KetangpaiSemester(2025, 2)),
      );
      await until(() => adapter.requests.length == 5);
      expect(workspace().courses.single.name, 'Previous semester');
      adapter.complete(4, 'Updated previous semester');
      await until(() => !workspace().refreshing);
      expect(workspace().courses.single.name, 'Updated previous semester');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        PlatformDioManager.clearAll();
        await dir.delete(recursive: true);
      });
    },
  );
}
