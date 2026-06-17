import 'dart:typed_data';

import 'package:course_helper/pages/update_announcements_page.dart';
import 'package:course_helper/services/update_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows cached update announcements when refresh fails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = UpdateAnnouncementStore();
    await store.save([
      UpdateAnnouncement(
        version: '1.0.6',
        buildNumber: 7,
        tag: '1.0.6+7',
        title: 'GUETer 1.0.6 更新公告',
        notes: const ['修复云盘上传连接中断重试', '优化请求控制台日志查看'],
        publishedAt: DateTime.parse('2026-06-07T20:00:00+08:00'),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: UpdateAnnouncementsPage(
          store: store,
          updateService: UpdateService(
            dio: Dio()..httpClientAdapter = _AlwaysFailAdapter(),
            folderUrl: 'https://updates.example.test/share-folder',
            folderPassword: 'test-password',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('更新公告'), findsOneWidget);
    expect(find.text('GUETer 1.0.6 更新公告'), findsOneWidget);
    expect(find.text('修复云盘上传连接中断重试'), findsOneWidget);
    expect(find.text('优化请求控制台日志查看'), findsOneWidget);
    expect(find.text('刷新失败，当前显示本地缓存公告。'), findsOneWidget);
  });
}

class _AlwaysFailAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw StateError('network unavailable');
  }

  @override
  void close({bool force = false}) {}
}
