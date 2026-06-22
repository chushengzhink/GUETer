import 'dart:convert';
import 'dart:typed_data';

import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/pages/accounts.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/services/update_service.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:dio/dio.dart';
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

    await tester.pumpWidget(
      MaterialApp(
        home: AccountsPage(
          currentVersionLoader: () async => '1.0.5',
          updateService: UpdateService(
            dio: Dio()..httpClientAdapter = _AlwaysFailAdapter(),
            folderUrl: 'https://updates.example.test/share-folder',
            folderPassword: 'test-password',
          ),
        ),
      ),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        home: AccountsPage(
          currentVersionLoader: () async => '1.0.6',
          updateService: UpdateService(
            dio: Dio()..httpClientAdapter = _AlwaysFailAdapter(),
            folderUrl: 'https://updates.example.test/share-folder',
            folderPassword: 'test-password',
          ),
        ),
      ),
    );
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

  testWidgets('refreshes update status when accounts page opens', (
    tester,
  ) async {
    await _bootstrap(
      status: UpdateCheckStatus(
        currentVersion: '1.0.8',
        latestVersion: '1.0.8',
        hasUpdate: false,
        downloadUrl: 'https://example.com/old.apk',
        releaseNotes: 'old',
        checkedAt: DateTime.parse('2026-06-18T00:00:00+08:00'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountsPage(
          currentVersionLoader: () async => '1.0.8',
          updateService: UpdateService(
            dio: _dioWith(_LanzouUpdateAdapter()),
            folderUrl: 'https://updates.example.test/share-folder',
            folderPassword: 'test-password',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('版本可更新'), findsOneWidget);
    expect(find.text('1.0.8 -> 1.0.9'), findsOneWidget);
    expect(find.text('重新检查'), findsOneWidget);
  });
}

Dio _dioWith(HttpClientAdapter adapter) {
  return Dio(
    BaseOptions(validateStatus: (status) => status != null && status < 500),
  )..httpClientAdapter = adapter;
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

class _LanzouUpdateAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyBytes = await requestStream?.fold<BytesBuilder>(
      BytesBuilder(),
      (builder, chunk) => builder..add(chunk),
    );
    final requestBody = utf8.decode(bodyBytes?.takeBytes() ?? Uint8List(0));
    final uri = options.uri.toString();

    if (options.method == 'GET' &&
        uri == 'https://updates.example.test/share-folder') {
      return ResponseBody.fromString(
        _folderHtml(),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
          'set-cookie': ['ylogin=abc; path=/'],
        },
      );
    }

    if (options.method == 'POST' &&
        uri == 'https://updates.example.test/filemoreajax.php?file=13573753') {
      Uri.splitQueryString(requestBody);
      return ResponseBody.fromString(
        json.encode(_folderListJson()),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        },
      );
    }

    if (options.method == 'GET' &&
        uri == 'https://updates.example.test/iUpdateTxt') {
      return ResponseBody.fromString(
        '<html><iframe src="/fn?abc"></iframe></html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        },
      );
    }

    if (options.method == 'GET' &&
        uri == 'https://updates.example.test/fn?abc') {
      return ResponseBody.fromString(
        '{"version":"1.0.9","buildNumber":10,"releaseNotes":"update chain fixed","apk":{"downloadUrl":"https://expired.example/app.apk"}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      );
    }

    return ResponseBody.fromString('not found', 404);
  }

  @override
  void close({bool force = false}) {}
}

String _folderHtml() {
  return '''
<script>
var ibjbqp = '1780631275';
var _hhnsi = '53ebc445780f61f05fea715118abc286';
function file(){
  jQuery.ajax({
    type : 'post',
    url : '/filemoreajax.php?file=13573753',
    data : {
      'lx':2,
      'fid':13573753,
      'uid':'4981610',
      'pg':pgs,
      'rep':'0',
      't':ibjbqp,
      'k':_hhnsi,
      'up':1,
      'ls':1,
      'pwd':pwd
    }
  });
}
</script>
''';
}

Map<String, dynamic> _folderListJson() {
  return {
    'zt': 1,
    'info': 'sucess',
    'text': [
      {
        'icon': 'txt',
        'id': 'iUpdateTxt',
        'name_all': 'update.txt',
        'size': '4.1 K',
        'time': '1 minutes ago',
      },
      {
        'icon': 'apk',
        'id': 'iApk?webpage=abc',
        'name_all': 'GUETer_1.0.9+10_arm64-v8a.apk',
        'size': '83.1 M',
        'time': '1 minutes ago',
      },
    ],
  };
}
