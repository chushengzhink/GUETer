import 'dart:io';

import 'package:archive/archive.dart';
import 'package:course_helper/services/file_tool_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late FileToolService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_tool_service_test_');
    service = FileToolService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('previews zip and blocks unsafe paths', () async {
    final zip = File(p.join(tempDir.path, 'unsafe.zip'));
    final archive = Archive()
      ..addFile(ArchiveFile('safe.txt', 4, 'safe'.codeUnits))
      ..addFile(ArchiveFile('../evil.txt', 4, 'evil'.codeUnits));
    await zip.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final preview = await service.previewZip(zipFile: zip);

    expect(preview.fileCount, 2);
    expect(preview.totalSizeBytes, 8);
    expect(preview.skippedUnsafeCount, 1);
    expect(preview.entries.where((entry) => !entry.isSafe), hasLength(1));
  });

  test('extracts only selected safe zip entries', () async {
    final zip = File(p.join(tempDir.path, 'docs.zip'));
    final archive = Archive()
      ..addFile(ArchiveFile('a.txt', 1, 'a'.codeUnits))
      ..addFile(ArchiveFile('folder/b.txt', 1, 'b'.codeUnits));
    await zip.writeAsBytes(ZipEncoder().encode(archive), flush: true);

    final output = Directory(p.join(tempDir.path, 'out'));
    final extracted = await service.extractZip(
      zipFile: zip,
      outputDirectory: output,
      selectedEntryPaths: {'folder/b.txt'},
    );

    expect(
      File(p.join(extracted.path, 'folder', 'b.txt')).existsSync(),
      isTrue,
    );
    expect(File(p.join(extracted.path, 'a.txt')).existsSync(), isFalse);
  });

  test('creates zip with custom name and unique conflict suffix', () async {
    final source = File(p.join(tempDir.path, 'note.txt'));
    await source.writeAsString('hello');
    final output = Directory(p.join(tempDir.path, 'out'))..createSync();
    File(p.join(output.path, 'bundle.zip')).writeAsStringSync('existing');

    final zip = await service.createZip(
      sources: [source],
      outputDirectory: output,
      preferredName: 'bundle',
      compressionLevel: 9,
    );

    expect(p.basename(zip.path), 'bundle (1).zip');
    final preview = await service.previewZip(zipFile: zip);
    expect(preview.entries.map((entry) => entry.path), contains('note.txt'));
  });

  test('rejects invalid archive name', () async {
    final source = File(p.join(tempDir.path, 'note.txt'));
    await source.writeAsString('hello');

    expect(
      () => service.createZip(
        sources: [source],
        outputDirectory: tempDir,
        preferredName: 'bad:name',
      ),
      throwsA(isA<FileToolValidationException>()),
    );
  });
}
