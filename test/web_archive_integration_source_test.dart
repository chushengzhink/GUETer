import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tools page exposes web archive entry', () {
    final source = File('lib/pages/tools_page.dart').readAsStringSync();

    expect(source, contains("id: 'web-archive'"));
    expect(source, contains('WebArchivePage'));
    expect(source, contains('网页归档箱'));
  });

  test('material search and index know web archive source type', () {
    final models = File(
      'lib/materials/material_index_models.dart',
    ).readAsStringSync();
    final indexService = File(
      'lib/materials/material_index_service.dart',
    ).readAsStringSync();
    final searchPage = File(
      'lib/pages/material_search_page.dart',
    ).readAsStringSync();

    expect(models, contains("webArchive('web_archive')"));
    expect(indexService, contains("sourceLabel: '网页归档'"));
    expect(searchPage, contains("MaterialSourceType.webArchive => '网页归档'"));
  });
}
