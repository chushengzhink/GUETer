import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/pages/tools_page.dart').readAsStringSync();
  });

  // Navigation, search, direct category access and large-text layouts are
  // covered by beta_tool_catalog_test.dart through real widget interactions.

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
