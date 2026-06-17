import 'dart:io';

import 'package:course_helper/services/duplicate_file_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late DuplicateFileScanner scanner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('duplicate_scan_test_');
    scanner = const DuplicateFileScanner();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('groups duplicate files by size and hash', () async {
    final a = File(p.join(tempDir.path, 'a.txt'));
    final b = File(p.join(tempDir.path, 'b.txt'));
    final c = File(p.join(tempDir.path, 'c.txt'));
    await a.writeAsString('same');
    await b.writeAsString('same');
    await c.writeAsString('diff');

    final groups = await scanner.scan([
      DuplicateScanRoot(label: 'temp', path: tempDir.path),
    ]);

    expect(groups, hasLength(1));
    expect(
      groups.single.files.map((file) => file.name),
      containsAll(['a.txt', 'b.txt']),
    );
    expect(
      groups.single.files.map((file) => file.name),
      isNot(contains('c.txt')),
    );
  });

  test('deleteFiles only deletes selected local paths', () async {
    final a = File(p.join(tempDir.path, 'a.txt'));
    final b = File(p.join(tempDir.path, 'b.txt'));
    await a.writeAsString('same');
    await b.writeAsString('same');

    final result = await scanner.deleteFiles([a.path]);

    expect(result.deletedCount, 1);
    expect(result.freedBytes, greaterThan(0));
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isTrue);
  });
}
