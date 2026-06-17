import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:course_helper/services/file_output_share_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('zipDirectoryForShare creates ZIP containing directory files', () async {
    final root = await Directory.systemTemp.createTemp('course-helper-share-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final source = Directory(p.join(root.path, 'output-folder'))
      ..createSync(recursive: true);
    File(p.join(source.path, 'note.txt')).writeAsStringSync('hello');
    Directory(p.join(source.path, 'nested')).createSync();
    File(p.join(source.path, 'nested', 'data.csv')).writeAsStringSync('a,b');

    final service = FileOutputShareService(exportDirectory: () async => root);

    final zipFile = await service.zipDirectoryForShare(source);
    addTearDown(() async {
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    });

    expect(await zipFile.exists(), isTrue);
    expect(await zipFile.length(), greaterThan(0));
    expect(zipFile.path, contains(p.join(root.path, 'shared_outputs')));

    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final names = archive.files.map((file) => file.name).toSet();

    expect(names, contains('output-folder/note.txt'));
    expect(names, contains('output-folder/nested/data.csv'));
  });
}
