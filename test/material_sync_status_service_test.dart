import 'dart:io';

import 'package:course_helper/features/openlist/openlist_offline_package.dart';
import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_index_service.dart';
import 'package:course_helper/materials/material_sync_status_service.dart';
import 'package:course_helper/services/file_tool_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'material_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory downloads;
  late Directory offlineRoot;
  late Directory outputs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('material_sync_test_');
    mockPathProviderForTests(tempDir);
    downloads = Directory(p.join(tempDir.path, 'downloads'))
      ..createSync(recursive: true);
    offlineRoot = Directory(p.join(tempDir.path, 'offline'))
      ..createSync(recursive: true);
    outputs = Directory(p.join(tempDir.path, 'outputs'))
      ..createSync(recursive: true);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'summarizes local directories, index, duplicates, and offline issues',
    () async {
      await File(p.join(downloads.path, 'a.txt')).writeAsString('same');
      await File(p.join(outputs.path, 'b.txt')).writeAsString('same');
      final indexedFile = File(p.join(outputs.path, 'indexed.txt'));
      await indexedFile.writeAsString('searchable content');
      final indexService = MaterialIndexService();
      await indexService.indexExternalFile(
        path: indexedFile.path,
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '测试输出',
      );

      final service = MaterialSyncStatusService(
        offlineService: _FakeOfflinePackageService(),
        indexService: indexService,
        fileToolService: _FakeFileToolService(outputs),
        downloadPathLoader: () async => downloads.path,
        offlineRootLoader: () async => offlineRoot,
      );

      final snapshot = await service.loadSnapshot();

      expect(snapshot.downloads.fileCount, 1);
      expect(snapshot.fileToolOutput.fileCount, 2);
      expect(snapshot.offlinePackageCount, 1);
      expect(snapshot.offlineMissingCount, 1);
      expect(snapshot.offlineChangedCount, 1);
      expect(snapshot.indexSummary.indexed, 1);
      expect(snapshot.duplicateGroupCount, 1);
      expect(snapshot.duplicateBytes, greaterThan(0));
    },
  );
}

class _FakeOfflinePackageService extends OpenListOfflinePackageService {
  @override
  Future<List<OpenListOfflinePackage>> loadPackages() async {
    return [
      OpenListOfflinePackage(
        id: 'pkg',
        name: '离线包',
        remotePath: '/',
        localPath: '',
        fileCount: 1,
        totalSize: 4,
        createdAt: DateTime(2026, 1, 1),
        lastCheckedAt: DateTime(2026, 1, 1),
        hasMissingFiles: true,
        hasRemoteChanges: true,
        files: [
          OpenListOfflineFile(
            name: 'missing.txt',
            remotePath: '/missing.txt',
            localPath: '',
            size: 4,
            modified: DateTime(2026, 1, 1),
            missing: true,
            changed: true,
          ),
        ],
      ),
    ];
  }

  @override
  Future<OpenListOfflinePackage> checkPackage(
    OpenListOfflinePackage package,
  ) async {
    return package;
  }
}

class _FakeFileToolService extends FileToolService {
  _FakeFileToolService(this.directory);

  final Directory directory;

  @override
  Future<Directory> ensureOutputDirectory({String? customOutputPath}) async {
    return directory;
  }
}
