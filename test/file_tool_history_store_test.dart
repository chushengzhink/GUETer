import 'package:course_helper/models/file_tool_models.dart';
import 'package:course_helper/services/file_tool_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  FileToolHistoryRecord record({
    required FileToolHistoryScope scope,
    required String toolName,
    DateTime? timestamp,
  }) {
    return FileToolHistoryRecord(
      scope: scope,
      toolName: toolName,
      inputSummary: '$toolName input',
      outputPath: '/tmp/$toolName.out',
      timestamp: timestamp ?? DateTime(2026, 6, 5, 12),
      success: true,
      message: '$toolName done',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('append persists records and filters by scope', () async {
    final store = FileToolHistoryStore();

    await store.append(
      record(scope: FileToolHistoryScope.pdf, toolName: 'PDF 转图片'),
    );
    await store.append(
      record(scope: FileToolHistoryScope.file, toolName: 'ZIP 打包'),
    );

    final pdfRecords = await store.load(scope: FileToolHistoryScope.pdf);
    final fileRecords = await store.load(scope: FileToolHistoryScope.file);

    expect(pdfRecords, hasLength(1));
    expect(pdfRecords.single.toolName, 'PDF 转图片');
    expect(fileRecords, hasLength(1));
    expect(fileRecords.single.toolName, 'ZIP 打包');
  });

  test('load skips corrupted JSON items', () async {
    final good = record(scope: FileToolHistoryScope.pdf, toolName: '轻量转 PDF');
    SharedPreferences.setMockInitialValues(<String, Object>{
      FileToolHistoryStore.storageKey: <String>['not-json', good.encode()],
    });
    final store = FileToolHistoryStore();

    final records = await store.load();

    expect(records, hasLength(1));
    expect(records.single.toolName, '轻量转 PDF');
  });

  test('append trims records to configured max', () async {
    final store = FileToolHistoryStore(maxRecords: 3);

    for (var i = 0; i < 5; i++) {
      await store.append(
        record(
          scope: FileToolHistoryScope.file,
          toolName: 'task-$i',
          timestamp: DateTime(2026, 6, 5, 12, i),
        ),
      );
    }

    final records = await store.load();

    expect(records.map((item) => item.toolName), [
      'task-4',
      'task-3',
      'task-2',
    ]);
  });

  test('clear removes only requested scope', () async {
    final store = FileToolHistoryStore();
    await store.append(
      record(scope: FileToolHistoryScope.pdf, toolName: 'PDF'),
    );
    await store.append(
      record(scope: FileToolHistoryScope.file, toolName: 'ZIP'),
    );

    await store.clear(scope: FileToolHistoryScope.pdf);

    final allRecords = await store.load();
    expect(allRecords, hasLength(1));
    expect(allRecords.single.scope, FileToolHistoryScope.file);
  });

  test('removeByOutputPath removes only matching output path', () async {
    final store = FileToolHistoryStore();
    await store.append(
      record(scope: FileToolHistoryScope.pdf, toolName: 'PDF'),
    );
    await store.append(
      record(scope: FileToolHistoryScope.file, toolName: 'ZIP'),
    );

    await store.removeByOutputPath('/tmp/PDF.out');

    final records = await store.load();
    expect(records, hasLength(1));
    expect(records.single.toolName, 'ZIP');
  });

  test('removeManyByOutputPath removes multiple matching output paths', () async {
    final store = FileToolHistoryStore();
    await store.append(
      record(scope: FileToolHistoryScope.pdf, toolName: 'PDF'),
    );
    await store.append(
      record(scope: FileToolHistoryScope.file, toolName: 'ZIP'),
    );
    await store.append(
      record(scope: FileToolHistoryScope.file, toolName: 'Rename'),
    );

    await store.removeManyByOutputPath(<String>[
      '/tmp/PDF.out',
      '/tmp/Rename.out',
    ]);

    final records = await store.load();
    expect(records, hasLength(1));
    expect(records.single.toolName, 'ZIP');
  });
}
