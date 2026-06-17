import 'dart:io';

import 'package:course_helper/materials/material_library_store.dart';
import 'package:course_helper/core/performance/app_performance.dart';
import 'package:course_helper/models/file_output_manager_models.dart';
import 'package:course_helper/models/file_tool_models.dart';
import 'package:course_helper/services/file_output_manager_service.dart';
import 'package:course_helper/services/file_tool_history_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late FileToolHistoryStore historyStore;
  late MaterialLibraryStore libraryStore;
  late FileOutputManagerService service;

  FileToolHistoryRecord history({
    required String path,
    required FileToolHistoryScope scope,
    required String toolName,
    DateTime? timestamp,
  }) {
    return FileToolHistoryRecord(
      scope: scope,
      toolName: toolName,
      inputSummary: '$toolName input',
      outputPath: path,
      timestamp: timestamp ?? DateTime(2026, 6, 7, 10),
      success: true,
      message: '$toolName done',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('output-manager-test-');
    historyStore = FileToolHistoryStore();
    libraryStore = MaterialLibraryStore();
    service = FileOutputManagerService(
      historyStore: historyStore,
      materialLibraryStore: libraryStore,
      scanDirectoriesProvider: () async => <Directory>[root],
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('aggregates history records with file state and size', () async {
    final file = File(p.join(root.path, 'arranged.pdf'));
    await file.writeAsString('pdf-output');
    await historyStore.append(
      history(
        path: file.path,
        scope: FileToolHistoryScope.pdf,
        toolName: 'PDF 页面编排',
      ),
    );

    final outputs = await service.loadOutputs();

    expect(outputs, hasLength(1));
    expect(outputs.single.name, 'arranged.pdf');
    expect(outputs.single.exists, isTrue);
    expect(outputs.single.sizeBytes, 'pdf-output'.length);
    expect(outputs.single.status, FileOutputStatus.available);
  });

  test('marks missing history output without deleting the record', () async {
    final missing = p.join(root.path, 'missing.zip');
    await historyStore.append(
      history(
        path: missing,
        scope: FileToolHistoryScope.file,
        toolName: 'ZIP 打包',
      ),
    );

    final outputs = await service.loadOutputs();
    final records = await historyStore.load();

    expect(outputs.single.status, FileOutputStatus.missing);
    expect(outputs.single.exists, isFalse);
    expect(records, hasLength(1));
  });

  test('deduplicates same path from history and scanned directory', () async {
    final file = File(p.join(root.path, 'same.txt'));
    await file.writeAsString('same');
    await historyStore.append(
      history(
        path: file.path,
        scope: FileToolHistoryScope.file,
        toolName: 'TXT 输出',
      ),
    );

    final outputs = await service.loadOutputs();

    expect(outputs, hasLength(1));
    expect(outputs.single.hasHistory, isTrue);
    expect(outputs.single.status, FileOutputStatus.available);
  });

  test('adds scan-only files when no history exists', () async {
    final file = File(p.join(root.path, 'orphan.txt'));
    await file.writeAsString('orphan');

    final outputs = await service.loadOutputs();

    expect(outputs, hasLength(1));
    expect(outputs.single.status, FileOutputStatus.scanOnly);
    expect(outputs.single.hasHistory, isFalse);
  });

  test('low power mode skips recursive directory size on first load', () async {
    final dir = Directory(p.join(root.path, 'folder-output'));
    await dir.create();
    await File(p.join(dir.path, 'large.txt')).writeAsString('large-output');

    final outputs = await service.loadOutputs(
      performanceMode: AppPerformanceMode.lowPower,
    );

    expect(outputs.single.isDirectory, isTrue);
    expect(outputs.single.status, FileOutputStatus.scanOnly);
    expect(outputs.single.sizeBytes, 0);
  });

  test('addToMaterialLibrary preserves output source label', () async {
    final file = File(p.join(root.path, 'material.txt'));
    await file.writeAsString('material');
    await historyStore.append(
      history(
        path: file.path,
        scope: FileToolHistoryScope.file,
        toolName: '文件工具',
      ),
    );
    final output = (await service.loadOutputs()).single;

    final count = await service.addToMaterialLibrary(<FileOutputItem>[output]);
    final libraryItems = await libraryStore.loadItems();

    expect(count, 1);
    expect(libraryItems.single.path, p.normalize(file.path));
    expect(libraryItems.single.sourceLabel, '文件工具输出');
  });
}
