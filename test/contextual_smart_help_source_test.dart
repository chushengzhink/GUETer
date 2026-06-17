import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core pages embed contextual smart suggestions and help hints', () {
    const pages = <String, String>{
      'courses': 'lib/pages/courses.dart',
      'todos': 'lib/pages/todos_page.dart',
      'materials': 'lib/pages/material_search_page.dart',
      'study': 'lib/pages/study_center_page.dart',
      'outputs': 'lib/pages/file_output_manager_page.dart',
      'tools': 'lib/pages/tools_page.dart',
      'settings': 'lib/pages/settings.dart',
    };

    for (final entry in pages.entries) {
      final source = File(entry.value).readAsStringSync();
      expect(
        source,
        contains('SmartInlinePanel'),
        reason: '${entry.key} should show page-local smart suggestions.',
      );
      expect(
        source,
        contains('ContextHelpHint'),
        reason: '${entry.key} should expose contextual help in place.',
      );
    }
  });

  test('main navigation remains limited to the requested five entries', () {
    final registry = File('lib/app_entries/app_entry_registry.dart')
        .readAsStringSync();
    final layout = File('lib/layout/layout_preferences.dart').readAsStringSync();

    expect(registry, isNot(contains("id: 'smart-organizer'")));
    expect(registry, isNot(contains("id: 'material-search'")));
    expect(registry, isNot(contains("id: 'manual'")));
    expect(layout, contains("'courses'"));
    expect(layout, contains("'accounts'"));
    expect(layout, contains("'todos'"));
    expect(layout, contains("'tools'"));
    expect(layout, contains("'settings'"));
  });
}
