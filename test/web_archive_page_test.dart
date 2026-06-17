import 'package:course_helper/materials/web_archive_models.dart';
import 'package:course_helper/materials/web_archive_service.dart';
import 'package:course_helper/materials/web_archive_store.dart';
import 'package:course_helper/pages/web_archive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWebArchiveService extends WebArchiveService {
  _FakeWebArchiveService({required this.store});

  final WebArchiveStore store;

  @override
  Future<WebArchiveItem> archiveUrl({
    required String url,
    List<String> tags = const <String>[],
  }) {
    return store.saveUrlOnly(
      url: url,
      title: '抓取失败示例',
      tags: tags,
      status: WebArchiveStatus.fetchError,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(WidgetTester tester, WebArchivePage page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renders empty state, add url box, paste, search, and tag filter',
    (tester) async {
      final store = WebArchiveStore();

      await pumpPage(tester, WebArchivePage(store: store));

      expect(find.text('网页归档箱'), findsOneWidget);
      expect(find.text('保存网页资料'), findsOneWidget);
      expect(find.text('搜索标题、链接、摘要或标签'), findsOneWidget);
      expect(find.text('全部标签'), findsOneWidget);
      expect(find.byIcon(Icons.content_paste_outlined), findsOneWidget);
      expect(find.textContaining('暂无网页归档'), findsOneWidget);
    },
  );

  testWidgets('adding a failed url keeps record and shows item actions', (
    tester,
  ) async {
    final store = WebArchiveStore();
    final service = _FakeWebArchiveService(store: store);

    await pumpPage(tester, WebArchivePage(store: store, service: service));
    await tester.enterText(find.byType(TextField).first, 'example.com/private');
    await tester.tap(find.text('保存归档'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('抓取失败示例'), findsOneWidget);
    expect(find.textContaining('https://example.com/private'), findsOneWidget);
    expect(find.textContaining('状态：抓取失败'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('打开原链接'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);
    expect(find.text('加入资料库'), findsOneWidget);
    expect(find.text('生成复习卡'), findsOneWidget);
  });
}
