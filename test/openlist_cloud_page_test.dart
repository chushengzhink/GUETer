import 'dart:io';

import 'package:course_helper/features/openlist/openlist_client.dart';
import 'package:course_helper/features/openlist/openlist_cloud_page.dart';
import 'package:course_helper/features/openlist/openlist_controller.dart';
import 'package:course_helper/features/openlist/openlist_models.dart';
import 'package:course_helper/features/openlist/openlist_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  testWidgets('hides write actions for readonly OpenList session', (
    tester,
  ) async {
    final controller = OpenListController(
      repository: OpenListRepository(
        client: _FakeOpenListClient(permission: 16640),
        accountResolver: () async => OpenListRepository.readonlyCredentials,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: OpenListCloudPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('云盘共享'), findsOneWidget);
    expect(find.byTooltip('上传'), findsNothing);
    expect(find.byTooltip('新建文件夹'), findsNothing);
    expect(find.text('仅浏览'), findsOneWidget);
    expect(find.text('不可分享'), findsOneWidget);
    expect(find.textContaining('云盘需要连接校园网或校园 VPN'), findsOneWidget);
    expect(find.textContaining('未登录畅课时仅可浏览和下载'), findsOneWidget);
    await tester.tap(find.byTooltip('文件操作'));
    await tester.pumpAndSettle();
    expect(find.text('创建分享链接'), findsNothing);
  });

  testWidgets('shows write actions for readwrite OpenList session', (
    tester,
  ) async {
    final controller = OpenListController(
      repository: OpenListRepository(
        client: _FakeOpenListClient(permission: 16648),
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: OpenListCloudPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('上传'), findsOneWidget);
    expect(find.byTooltip('新建文件夹'), findsOneWidget);
    expect(find.text('可上传'), findsOneWidget);
    expect(find.text('可分享'), findsOneWidget);
    expect(find.text('不可删除'), findsOneWidget);
    expect(find.textContaining('云盘需要连接校园网或校园 VPN'), findsOneWidget);
    expect(find.textContaining('已登录畅课，可上传文件'), findsOneWidget);
    expect(find.text('folder'), findsOneWidget);
  });

  testWidgets('shows campus network hint when OpenList loading fails', (
    tester,
  ) async {
    final controller = OpenListController(
      repository: OpenListRepository(
        client: _FakeOpenListClient(permission: 16640, failList: true),
        accountResolver: () async => OpenListRepository.readonlyCredentials,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: OpenListCloudPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('请先确认已连接校园网或校园 VPN'), findsOneWidget);
    expect(find.textContaining('network unreachable'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('creates folder from dialog and refreshes listing', (
    tester,
  ) async {
    final client = _FakeOpenListClient(permission: 16648);
    final controller = OpenListController(
      repository: OpenListRepository(
        client: client,
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: OpenListCloudPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '新资料');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(client.createdFolders, ['/新资料']);
  });

  testWidgets('supports local search, sort menu, and file actions', (
    tester,
  ) async {
    final controller = OpenListController(
      repository: OpenListRepository(
        client: _FakeOpenListClient(permission: 16648),
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: OpenListCloudPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'report');
    await tester.pump();

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('folder'), findsNothing);

    await tester.tap(find.byTooltip('排序'));
    await tester.pumpAndSettle();
    expect(find.text('按大小'), findsOneWidget);

    await tester.tap(find.text('按大小'));
    await tester.pumpAndSettle();
    expect(controller.sortKey, OpenListSortKey.size);

    await tester.tap(find.byTooltip('文件操作'));
    await tester.pumpAndSettle();
    expect(find.text('下载并打开'), findsOneWidget);
    expect(find.text('复制直链'), findsOneWidget);
    expect(find.text('创建分享链接'), findsOneWidget);
    expect(find.text('分享文件'), findsOneWidget);
    expect(find.text('删除'), findsNothing);
    expect(find.text('重命名'), findsNothing);
    expect(find.text('移动'), findsNothing);
  });

  test(
    'upload broken pipe error message is shown without private endpoint',
    () {
      final message = friendlyOpenListUploadError(
        DioException(
          requestOptions: RequestOptions(path: '/api/fs/put'),
          type: DioExceptionType.unknown,
          error: SocketException(
            'Broken pipe',
            address: InternetAddress('192.0.2.1'),
            port: 48580,
          ),
        ),
      );

      expect(message, '上传连接中断，请确认校园网/VPN 稳定后重试。');
      expect(message, isNot(contains('192.0.2.1')));
      expect(message, isNot(contains('48580')));
      expect(message, isNot(contains('DioException')));
    },
  );
}

class _FakeOpenListClient extends OpenListClient {
  _FakeOpenListClient({required this.permission, this.failList = false});

  final int permission;
  final bool failList;
  final List<String> createdFolders = <String>[];

  @override
  Future<String> login(OpenListCredentials credentials) async {
    return 'token';
  }

  @override
  Future<OpenListUserProfile> me(String token) async {
    return OpenListUserProfile(
      username: permission == 16648 ? 'cszm1' : 'cszm',
      permission: permission,
      basePath: '/',
      disabled: false,
    );
  }

  @override
  Future<OpenListDirectoryListing> list({
    required String token,
    required String path,
  }) async {
    if (failList) {
      throw const OpenListApiException('network unreachable');
    }
    return const OpenListDirectoryListing(
      content: [
        OpenListFileItem(
          name: 'folder',
          size: 0,
          isDir: true,
          modified: null,
          created: null,
          sign: '',
          thumb: '',
          type: 1,
        ),
        OpenListFileItem(
          name: 'report.pdf',
          size: 2048,
          isDir: false,
          modified: null,
          created: null,
          sign: '',
          thumb: '',
          type: 0,
        ),
      ],
      total: 2,
      write: true,
      provider: 'unknown',
      readme: '',
      header: '',
    );
  }

  @override
  Future<void> mkdir({required String token, required String path}) async {
    createdFolders.add(path);
  }

  @override
  Future<void> uploadFile({
    required String token,
    required String remotePath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) async {}

  @override
  Future<OpenListShareInfo> createShare({
    required String token,
    required String path,
  }) async {
    return const OpenListShareInfo(
      id: 'share-id',
      files: ['/report.pdf'],
      url: 'http://openlist.test/sd/share-id',
    );
  }
}
