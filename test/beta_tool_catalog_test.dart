import 'package:course_helper/features/tools/tool_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

List<ToolCategorySpec> catalog(VoidCallback onTap) => [
  ToolCategorySpec(
    id: 'pdf',
    label: 'PDF',
    subtitle: '阅读、转换与整理',
    icon: Icons.picture_as_pdf_outlined,
    color: Colors.blue,
    actions: [
      ToolActionSpec(
        id: 'arrange-pdf',
        title: 'PDF 页面整理',
        subtitle: '调整顺序、旋转、删除页面',
        icon: Icons.picture_as_pdf_outlined,
        color: Colors.blue,
        onTap: onTap,
      ),
      ToolActionSpec(
        id: 'compress-pdf',
        title: '压缩 PDF',
        subtitle: '减小文件体积',
        icon: Icons.compress,
        color: Colors.blue,
        onTap: onTap,
      ),
    ],
  ),
  ToolCategorySpec(
    id: 'files',
    label: '资料',
    subtitle: '搜索、复习与文件管理',
    icon: Icons.folder_outlined,
    color: Colors.green,
    actions: [
      ToolActionSpec(
        id: 'search',
        title: '资料搜索',
        subtitle: '全文搜索本地资料',
        icon: Icons.manage_search,
        color: Colors.green,
        onTap: onTap,
      ),
    ],
  ),
  ToolCategorySpec(
    id: 'transfer',
    label: '传输',
    subtitle: '附近设备与局域网',
    icon: Icons.devices,
    color: Colors.teal,
    actions: [
      ToolActionSpec(
        id: 'transfer',
        title: '局域网传输',
        subtitle: '发送文件到附近设备',
        icon: Icons.swap_horiz,
        color: Colors.teal,
        onTap: onTap,
      ),
    ],
  ),
];

Widget app(
  Widget child, {
  bool dark = false,
  bool en = false,
  double scale = 1,
}) => MaterialApp(
  locale: Locale(en ? 'en' : 'zh'),
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(
    useMaterial3: true,
    fontFamily: 'BetaTestUI',
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: dark ? Brightness.dark : Brightness.light,
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    appBar: AppBar(title: Text(en ? 'Tools' : '工具')),
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'inline search opens actions directly and clear restores categories',
    (tester) async {
      var opened = 0;
      String? category;
      await tester.pumpWidget(
        app(
          ToolCatalog(
            categories: catalog(() => opened++),
            pinnedIds: const ['search'],
            onOpenCategory: (value) => category = value.id,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('tool-search')), findsWidgets);
      await tester.enterText(find.byType(TextField), '压缩');
      await tester.pump();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('tool-compress-pdf')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tool-compress-pdf')));
      expect(opened, 1);
      await tester.enterText(find.byType(TextField), '不存在');
      await tester.pump();
      expect(find.text('没有匹配的工具，换个关键词试试。'), findsOneWidget);
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('category-pdf')));
      await tester.tap(find.byKey(const ValueKey('category-pdf')));
      expect(category, 'pdf');
    },
  );

  test('favorites respect saved order and omit missing or hidden actions', () {
    final controller = ToolCatalogController();
    expect(
      controller
          .favorites(catalog(() {}), [
            'search',
            'missing',
            'arrange-pdf',
            'search',
          ])
          .map((a) => a.id),
      ['search', 'arrange-pdf'],
    );
    controller.search('PDF 压缩');
    expect(controller.results(catalog(() {})).map((a) => a.id), [
      'compress-pdf',
    ]);
    controller.dispose();
  });

  for (final width in [360.0, 412.0, 600.0]) {
    for (final dark in [false, true]) {
      for (final en in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('catalog layout $width dark=$dark en=$en scale=$scale', (
            tester,
          ) async {
            await tester.view.setSurfaceSizeForBeta(Size(width, 900));
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final key = GlobalKey();
            await tester.pumpWidget(
              app(
                RepaintBoundary(
                  key: key,
                  child: ToolCatalog(
                    categories: catalog(() {}),
                    pinnedIds: const [],
                    onOpenCategory: (_) {},
                  ),
                ),
                dark: dark,
                en: en,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}

extension on TestFlutterView {
  Future<void> setSurfaceSizeForBeta(Size size) async {
    devicePixelRatio = 1;
    physicalSize = size;
  }
}
