import 'dart:io';

import 'package:course_helper/materials/web_archive_models.dart';
import 'package:course_helper/materials/web_archive_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saves, loads, and deduplicates items by normalized url', () async {
    final store = WebArchiveStore();
    final first = DateTime(2026, 1, 1);
    final second = DateTime(2026, 1, 2);

    await store.upsertItem(
      WebArchiveItem(
        id: WebArchiveStore.idForUrl('example.com/a'),
        url: 'example.com/a',
        title: 'A',
        tags: const <String>['course', 'course'],
        createdAt: first,
        updatedAt: first,
      ),
    );
    await store.upsertItem(
      WebArchiveItem(
        id: WebArchiveStore.idForUrl('https://example.com/a'),
        url: 'https://example.com/a',
        title: 'A updated',
        tags: const <String>['notes'],
        createdAt: second,
        updatedAt: second,
      ),
    );

    final items = await store.loadItems();

    expect(items, hasLength(1));
    expect(items.single.url, 'https://example.com/a');
    expect(items.single.title, 'A updated');
    expect(items.single.createdAt, first);
    expect(items.single.tags, <String>['notes']);
  });

  test(
    'updates tags and preserves archived or ignored status on upsert',
    () async {
      final store = WebArchiveStore();
      final item = await store.saveUrlOnly(url: 'https://example.com/a');

      await store.updateTags(item.id, const <String>['  a ', 'b,c', 'a']);
      await store.setStatus(item.id, WebArchiveStatus.archived);
      await store.upsertItem(
        item.copyWith(
          title: 'new title',
          status: WebArchiveStatus.saved,
          updatedAt: DateTime(2026, 1, 2),
        ),
      );

      final loaded = (await store.loadItems()).single;

      expect(loaded.status, WebArchiveStatus.archived);
      expect(loaded.tags, <String>['a', 'b', 'c']);
    },
  );

  test('missing snapshot is marked without deleting record', () async {
    final tempDir = await Directory.systemTemp.createTemp('web_archive_store_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = File('${tempDir.path}/snapshot.txt');
    await file.writeAsString('hello');
    final store = WebArchiveStore();
    await store.upsertItem(
      WebArchiveItem(
        id: 'item',
        url: 'https://example.com/a',
        title: 'A',
        textSnapshotPath: file.path,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await file.delete();

    final items = await store.refreshMissingStatuses();

    expect(items.single.status, WebArchiveStatus.missing);
    expect(await store.loadItems(), hasLength(1));
  });
}
