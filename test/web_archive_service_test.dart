import 'dart:io';

import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_library_store.dart';
import 'package:course_helper/materials/web_archive_models.dart';
import 'package:course_helper/materials/web_archive_service.dart';
import 'package:course_helper/materials/web_archive_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('web_archive_service_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('parseHtml extracts metadata and readable text', () {
    final service = WebArchiveService(directoryLoader: () async => tempDir);

    final parsed = service.parseHtml('https://example.com/a', '''
      <html>
        <head>
          <title>Fallback title</title>
          <meta property="og:title" content="Course Note">
          <meta name="description" content="A useful article">
          <meta property="og:site_name" content="Example Docs">
          <link rel="icon" href="/favicon.ico">
        </head>
        <body>
          <script>ignore me</script>
          <article><h1>Heading</h1><p>First paragraph.</p></article>
        </body>
      </html>
      ''');

    expect(parsed.title, 'Course Note');
    expect(parsed.description, 'A useful article');
    expect(parsed.siteName, 'Example Docs');
    expect(parsed.faviconUrl, 'https://example.com/favicon.ico');
    expect(parsed.text, contains('Heading'));
    expect(parsed.text, contains('First paragraph.'));
    expect(parsed.text, isNot(contains('ignore me')));
  });

  test(
    'archiveUrl writes snapshot, stores item, and adds material entry',
    () async {
      final store = WebArchiveStore();
      final libraryStore = MaterialLibraryStore();
      final service = WebArchiveService(
        store: store,
        materialLibraryStore: libraryStore,
        directoryLoader: () async => tempDir,
        fetch: (url) async => Response<String>(
          requestOptions: RequestOptions(path: url),
          statusCode: 200,
          data:
              '<html><head><title>Docs</title></head><body><main>Flutter cache note</main></body></html>',
        ),
      );

      final item = await service.archiveUrl(
        url: 'https://example.com/docs',
        tags: const <String>['flutter'],
      );

      expect(item.status, WebArchiveStatus.saved);
      expect(await File(item.textSnapshotPath).exists(), isTrue);
      expect(
        await File(item.textSnapshotPath).readAsString(),
        contains('Flutter cache note'),
      );
      final libraryItem = (await libraryStore.loadItems()).single;
      expect(libraryItem.sourceType, MaterialSourceType.webArchive);
      expect(libraryItem.sourceLabel, WebArchiveService.sourceLabel);
    },
  );

  test('archiveUrl keeps url record when fetch fails', () async {
    final store = WebArchiveStore();
    final service = WebArchiveService(
      store: store,
      directoryLoader: () async => tempDir,
      fetch: (url) async => Response<String>(
        requestOptions: RequestOptions(path: url),
        statusCode: 403,
        data: 'Forbidden',
      ),
    );

    final item = await service.archiveUrl(url: 'https://example.com/private');

    expect(item.status, WebArchiveStatus.fetchError);
    expect(item.url, 'https://example.com/private');
    expect(
      (await store.loadItems()).single.status,
      WebArchiveStatus.fetchError,
    );
  });
}
