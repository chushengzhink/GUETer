import 'dart:io';

import 'package:course_helper/materials/material_library_store.dart';
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
  }) {
    return FileToolHistoryRecord(
      scope: scope,
      toolName: toolName,
      inputSummary: '$toolName input',
      outputPath: path,
      timestamp: DateTime(2026, 6, 14, 10),
      success: true,
      message: '$toolName done',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    root = await Directory.systemTemp.createTemp('output-summary-test-');
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

  test('summary separates states and duplicate candidates', () async {
    final first = File(p.join(root.path, 'same.pdf'));
    await first.writeAsString('same-content');
    final orphan = File(p.join(root.path, 'orphan.txt'));
    await orphan.writeAsString('orphan');
    final missing = p.join(root.path, 'missing.pdf');
    final externalDir = await Directory.systemTemp.createTemp(
      'output-summary-external-',
    );
    final external = File(p.join(externalDir.path, 'same.pdf'));
    await external.writeAsString('same-content');

    try {
      await historyStore.append(
        history(
          path: first.path,
          scope: FileToolHistoryScope.pdf,
          toolName: 'PDF',
        ),
      );
      await historyStore.append(
        history(
          path: missing,
          scope: FileToolHistoryScope.pdf,
          toolName: 'Missing',
        ),
      );
      await historyStore.append(
        history(
          path: external.path,
          scope: FileToolHistoryScope.pdf,
          toolName: 'External',
        ),
      );

      final outputs = await service.loadOutputs();
      final firstOutput = outputs.firstWhere((item) => item.path == first.path);
      await service.addToMaterialLibrary(<FileOutputItem>[firstOutput]);

      final summary = await service.loadSummary();

      expect(summary.totalCount, 4);
      expect(summary.availableCount, 3);
      expect(summary.missingCount, 1);
      expect(summary.externalCount, 1);
      expect(summary.scanOnlyCount, 1);
      expect(summary.inMaterialLibraryCount, 1);
      expect(summary.duplicateCandidateCount, 2);
    } finally {
      if (await externalDir.exists()) {
        await externalDir.delete(recursive: true);
      }
    }
  });
}
