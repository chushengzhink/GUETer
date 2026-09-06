import 'package:course_helper/pages/tools_page.dart';
import 'package:course_helper/features/tools/tool_catalog.dart';
import 'package:course_helper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('real tools page retains actions and searches inline', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: ToolsPage(initializeServices: false),
      ),
    );
    await tester.pumpAndSettle();
    final catalog = tester.widget<ToolCatalog>(find.byType(ToolCatalog));
    final ids = catalog.categories
        .expand((c) => c.actions)
        .map((a) => a.id)
        .toList();
    expect(ids, hasLength(26));
    expect(
      ids,
      containsAll([
        'smart-organizer',
        'material-search',
        'user-manual',
        'file-output-manager',
      ]),
    );
    expect(ids, isNot(contains('apod')));
    expect(ids, isNot(contains('ai-figure')));
    expect(
      catalog.categories.singleWhere((c) => c.id == 'pdf').actions,
      hasLength(7),
    );
    expect(
      ToolCatalogController()
          .favorites(catalog.categories, [])
          .map((a) => a.id),
      ['material-search', 'material-ocr', 'arrange-pdf', 'file-output-manager'],
    );
    await tester.enterText(find.byKey(const ValueKey('tool-search')), 'PDF');
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const ValueKey('tool-arrange-pdf')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('tool-search')),
      'nonexistent-tool',
    );
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的工具，换个关键词试试。'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('category-pdf')));
    await tester.tap(find.byKey(const ValueKey('category-pdf')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PDF'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
