import 'package:course_helper/app_entries/app_entry_registry.dart';
import 'package:course_helper/layout/layout_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('主导航顺序支持隐藏入口', () {
    final entries = buildBuiltinAppEntries();
    final entryIds = entries.map((entry) => entry.id).toList();
    const preferences = LayoutPreferences(
      navOrder: <String>['tools', 'courses', 'accounts', 'todos', 'settings'],
      hiddenNavIds: <String>['accounts'],
    );

    final visible = preferences.visibleNavOrder(entryIds);

    expect(visible, <String>['tools', 'courses', 'todos', 'settings']);
  });

  test('新增入口元数据保持默认值且不影响内置顺序', () {
    final entries = buildBuiltinAppEntries();

    expect(entries.map((entry) => entry.id), <String>[
      'courses',
      'accounts',
      'todos',
      'tools',
      'settings',
    ]);
    expect(entries.every((entry) => entry.tags.isEmpty), isTrue);
    expect(entries.every((entry) => entry.priority == 0), isTrue);
    expect(entries.every((entry) => entry.badge == null), isTrue);
  });
}
