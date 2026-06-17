import 'dart:io';

import 'package:course_helper/services/gueter_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'creates categorized public directory under Download gueter root',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'gueter_storage_root_',
      );
      final docs = await Directory.systemTemp.createTemp(
        'gueter_storage_docs_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
        if (await docs.exists()) await docs.delete(recursive: true);
      });

      final service = GueterStorageService(
        androidDownloadRoot: root,
        documentsDirectoryProvider: () async => docs,
        isAndroidProvider: () => true,
      );

      final dir = await service.publicDirectory(
        GueterPublicDirectory.cloudDownloads,
      );

      expect(dir.path, p.join(root.path, 'gueter', 'cloud_downloads'));
      expect(await dir.exists(), isTrue);
    },
  );

  test('uses custom directory before default public directory', () async {
    final root = await Directory.systemTemp.createTemp('gueter_storage_root_');
    final custom = Directory(p.join(root.path, 'custom_output'));
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    final service = GueterStorageService(
      androidDownloadRoot: root,
      isAndroidProvider: () => true,
    );
    final dir = await service.publicDirectory(
      GueterPublicDirectory.fileTools,
      customPath: custom.path,
    );

    expect(dir.path, custom.path);
    expect(await dir.exists(), isTrue);
  });
}
