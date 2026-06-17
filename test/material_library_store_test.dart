import 'dart:io';

import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_library_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'upserts items by path and keeps inbox ordered by import time',
    () async {
      final store = MaterialLibraryStore();
      await store.upsertItem(
        path: 'C:/tmp/a.txt',
        name: 'A',
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '工具',
        importedAt: DateTime(2026, 1, 1),
      );
      await store.upsertItem(
        path: 'C:/tmp/b.txt',
        name: 'B',
        sourceType: MaterialSourceType.openListDownload,
        sourceLabel: '云盘',
        importedAt: DateTime(2026, 1, 2),
      );
      await store.upsertItem(
        path: 'C:/tmp/a.txt',
        name: 'A updated',
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '工具',
        importedAt: DateTime(2026, 1, 3),
      );

      final inbox = await store.inboxItems();

      expect(inbox, hasLength(2));
      expect(inbox.first.name, 'B');
      expect(inbox.last.name, 'A updated');
      expect(inbox.last.importedAt, DateTime(2026, 1, 1));
    },
  );

  test('recordOpened updates recent order', () async {
    final store = MaterialLibraryStore();
    await store.recordOpened(
      path: 'C:/tmp/a.txt',
      name: 'A',
      openedAt: DateTime(2026, 1, 1, 8),
    );
    await store.recordOpened(
      path: 'C:/tmp/b.txt',
      name: 'B',
      openedAt: DateTime(2026, 1, 1, 9),
    );

    final recent = await store.recentItems();

    expect(recent.map((item) => item.name), <String>['B', 'A']);
  });

  test('status can be archived or ignored', () async {
    final store = MaterialLibraryStore();
    final item = await store.upsertItem(
      path: 'C:/tmp/a.txt',
      name: 'A',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '工具',
    );

    await store.setStatus(item.id, MaterialLibraryStatus.archived);
    expect((await store.inboxItems()), isEmpty);

    await store.setStatus(item.id, MaterialLibraryStatus.ignored);
    expect(
      (await store.loadItems()).single.status,
      MaterialLibraryStatus.ignored,
    );
  });

  test('upsert preserves archived and ignored statuses', () async {
    final store = MaterialLibraryStore();
    final archived = await store.upsertItem(
      path: 'C:/tmp/a.txt',
      name: 'A',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '工具',
    );
    final ignored = await store.upsertItem(
      path: 'C:/tmp/b.txt',
      name: 'B',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '工具',
    );
    await store.setStatus(archived.id, MaterialLibraryStatus.archived);
    await store.setStatus(ignored.id, MaterialLibraryStatus.ignored);

    await store.upsertItem(
      path: 'C:/tmp/a.txt',
      name: 'A reindexed',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '工具',
    );
    await store.upsertItem(
      path: 'C:/tmp/b.txt',
      name: 'B reindexed',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '工具',
    );

    final items = await store.loadItems();
    expect(
      items
          .singleWhere((item) => item.path == p.normalize('C:/tmp/a.txt'))
          .status,
      MaterialLibraryStatus.archived,
    );
    expect(
      items
          .singleWhere((item) => item.path == p.normalize('C:/tmp/b.txt'))
          .status,
      MaterialLibraryStatus.ignored,
    );
    expect(await store.inboxItems(), isEmpty);
  });

  test('missing files are marked without deleting records', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'material_library_store_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final file = File(p.join(tempDir.path, 'notes.txt'));
    await file.writeAsString('hello');
    final store = MaterialLibraryStore();
    await store.upsertItem(
      path: file.path,
      name: 'notes.txt',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '工具',
    );
    await file.delete();

    final items = await store.refreshMissingStatuses();

    expect(items.single.status, MaterialLibraryStatus.missing);
    expect((await store.loadItems()), hasLength(1));
  });
}
