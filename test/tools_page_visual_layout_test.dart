import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/pages/tools_page.dart').readAsStringSync();
  });

  test('wheel center still opens the selected category detail page', () {
    expect(source, contains('onCenterTap: _openSelectedToolCategory'));
    expect(source, contains('builder: (_) => _ToolCategoryDetailPage'));
  });

  test('dashboard previews current category actions below wheel', () {
    expect(source, contains('_CurrentCategoryPreview'));
    expect(source, contains('category: selectedCategory'));
  });

  test('header search opens command sheet without onChanged modal loop', () {
    expect(source, contains('onSearchTap: _openToolSearch'));
    expect(source, contains('readOnly: true'));
    expect(source, contains('showCursor: false'));
    expect(source, isNot(contains('onSearchChanged:')));
    expect(source, isNot(contains('_openToolSearch();')));
  });

  test('dashboard shows persistent search results with clear action', () {
    expect(source, contains('class _ToolSearchResultsSection'));
    expect(source, contains('_toolSearchQuery.trim().isNotEmpty'));
    expect(source, contains('actions: _filteredActions(categories)'));
    expect(source, contains('onClear: _clearToolSearch'));
    expect(source, contains("child: _ToolActionCard(action: action)"));
  });

  test('wheel category nodes expose semantic selection state', () {
    expect(source, contains('class _WheelNodeButton'));
    expect(source, contains('Semantics('));
    expect(source, contains('button: true'));
    expect(source, contains('selected: selected'));
    expect(
      source,
      contains("label: '\${category.label}, \${category.subtitle}'"),
    );
  });

  test(
    'category detail uses compact visual grid with two-column mobile layout',
    () {
      expect(source, contains('class _VisualToolTile'));
      expect(source, contains('childCount: category.actions.length'));
      expect(source, contains(': 2;'));
      expect(source, isNot(contains('columns == 1 ? 2.45 : 1.35')));
    },
  );

  test('pdf category exposes the seven pdf actions', () {
    const pdfActionIds = <String>[
      "id: 'arrange-pdf'",
      "id: 'lightweight-to-pdf'",
      "id: 'pdf-to-images'",
      "id: 'images-to-pdf'",
      "id: 'compress-pdf'",
      "id: 'extract-pages'",
      "id: 'watermark-pdf'",
    ];

    for (final id in pdfActionIds) {
      expect(source, contains(id));
    }
    expect(source, contains("category.id == 'pdf'"));
    expect(source, contains('_CompactPdfHelpPanel'));
  });

  test('tools page hosts removed main navigation destinations', () {
    expect(source, contains("id: 'smart-organizer'"));
    expect(source, contains('SmartOrganizerPage'));
    expect(source, contains("id: 'material-search'"));
    expect(source, contains('MaterialSearchPage'));
    expect(source, contains("id: 'user-manual'"));
    expect(source, contains('UserManualPage'));
    expect(source, contains("'智能'"));
    expect(source, contains("'资料'"));
    expect(source, contains("'说明书'"));
  });

  test('timeline is not nested in tools page', () {
    expect(source, isNot(contains("id: 'learning-timeline'")));
  });

  test('files category exposes output manager action', () {
    expect(source, contains("id: 'file-output-manager'"));
    expect(source, contains('FileOutputManagerPage'));
  });
}
