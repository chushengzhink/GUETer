import 'package:course_helper/app_entries/app_entry_registry.dart';
import 'package:course_helper/layout/layout_preferences.dart';
import 'package:course_helper/pages/my_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('My groups account management, settings, help and updates', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MyPage()));
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Updates'), 200);
    expect(find.text('Updates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('registry retains legacy IDs with four default destinations', () {
    final entries = buildBuiltinAppEntries();
    expect(entries.map((e) => e.id), LayoutPreferences.defaultNavOrder);
    expect(
      const LayoutPreferences().visibleNavOrder(
        entries.map((e) => e.id).toList(),
      ),
      ['courses', 'todos', 'tools', 'settings'],
    );
    expect(entries.singleWhere((e) => e.id == 'settings').titleZh, '我的');
  });
}
