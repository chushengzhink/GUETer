import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/pages/accounts.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/services/update_service.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _bootstrap({UpdateCheckStatus? status}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'current_platform': 'tronclass',
  });
  ApiService.resetForTests();
  CookieManager.resetForTests();
  await ApiService.initialize();
  await PlatformManager().initialize();
  await AccountManager.initialize();
  await CookieManager.initialize();
  if (status != null) {
    await UpdateCheckStatusStore().save(status);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows update available card when cached status has update', (
    tester,
  ) async {
    await _bootstrap(
      status: UpdateCheckStatus(
        currentVersion: '1.0.5',
        latestVersion: '1.0.6',
        hasUpdate: true,
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: '修复云盘上传连接中断重试',
        checkedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: AccountsPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('版本可更新'), findsOneWidget);
    expect(find.text('1.0.5 -> 1.0.6'), findsOneWidget);
    expect(find.text('查看更新公告'), findsOneWidget);
    expect(find.text('前往下载'), findsOneWidget);
    expect(find.text('使用手册'), findsNothing);
    expect(find.text('常见问题'), findsNothing);
  });

  testWidgets('shows three help entries when cached status is latest', (
    tester,
  ) async {
    await _bootstrap(
      status: UpdateCheckStatus(
        currentVersion: '1.0.6',
        latestVersion: '1.0.6',
        hasUpdate: false,
        downloadUrl: 'https://example.com/app.apk',
        releaseNotes: '暂无更新',
        checkedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: AccountsPage()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('当前已是最新版本 1.0.6'), findsOneWidget);
    expect(find.text('使用手册'), findsOneWidget);
    expect(find.text('常见问题'), findsOneWidget);
    expect(find.text('更新公告'), findsOneWidget);
    expect(find.text('版本可更新'), findsNothing);

    await tester.tap(find.text('常见问题'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('使用说明书'), findsWidgets);
    expect(find.text('常见问题'), findsWidgets);
  });
}
