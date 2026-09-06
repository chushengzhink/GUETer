import 'package:course_helper/l10n/app_localizations.dart';
import 'package:course_helper/pages/tools_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'file history and workflows remain reachable as secondary actions',
    (tester) async {
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
      await tester.scrollUntilVisible(
        find.text('工作流'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('文件记录与输出管理'), findsOneWidget);
      await tester.tap(find.text('工作流'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('PDF 收件箱整理'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
