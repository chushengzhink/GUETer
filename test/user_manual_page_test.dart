import 'package:course_helper/pages/material_search_page.dart';
import 'package:course_helper/pages/user_manual_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders manual title, quick jumps, and core sections', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UserManualPage()));

    expect(find.text('使用说明书'), findsWidgets);
    expect(find.text('首次使用流程'), findsWidgets);
    expect(find.text('资料到复习卡'), findsWidgets);
    expect(find.text('登录/签到排障'), findsOneWidget);
    expect(find.text('隐私与合规'), findsWidgets);
    expect(
      userManualSections.map((section) => section.title),
      containsAll(<String>['账号与登录', '资料到复习卡', '故障排查']),
    );
  });

  testWidgets('opens material search page from manual action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: UserManualPage()));

    await tester.enterText(find.byType(TextField), '资料到复习卡');
    await tester.pump();
    final openMaterials = find.text('打开资料').first;
    await tester.ensureVisible(openMaterials);
    await tester.pumpAndSettle();
    await tester.tap(openMaterials);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(MaterialSearchPage), findsOneWidget);
  });
}
