import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('material search is embedded into contextual pages', () {
    const pages = <String, String>{
      'courses': 'lib/pages/courses.dart',
      'todos': 'lib/pages/todos_page.dart',
      'study': 'lib/pages/study_center_page.dart',
      'preview': 'lib/pages/file_preview_page.dart',
      'webArchive': 'lib/pages/web_archive_page.dart',
      'outputs': 'lib/pages/file_output_manager_page.dart',
    };

    for (final entry in pages.entries) {
      final source = File(entry.value).readAsStringSync();
      expect(
        source,
        anyOf(
          contains('MaterialRelatedPanel'),
          contains('MaterialInlineSearchPanel'),
          contains('MaterialSearchLauncher.open'),
        ),
        reason: '${entry.key} should expose material search in context.',
      );
      expect(
        source,
        contains('MaterialSearchContext'),
        reason: '${entry.key} should pass explicit scene context.',
      );
    }
  });

  test('material search stays outside the main navigation registry', () {
    final registry = File(
      'lib/app_entries/app_entry_registry.dart',
    ).readAsStringSync();

    expect(registry, isNot(contains("id: 'material-search'")));
    expect(registry, isNot(contains("MaterialSearchPage")));
  });
}
