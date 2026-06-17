import 'dart:io';

import 'package:course_helper/services/file_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late FilePreviewService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_preview_test_');
    service = const FilePreviewService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('detects supported preview kinds', () async {
    expect(service.kindForPath('a.pdf'), FilePreviewKind.pdf);
    expect(service.kindForPath('a.png'), FilePreviewKind.image);
    expect(service.kindForPath('a.md'), FilePreviewKind.markdown);
    expect(service.kindForPath('a.json'), FilePreviewKind.json);
    expect(service.kindForPath('a.csv'), FilePreviewKind.csv);
    expect(service.kindForPath('a.zip'), FilePreviewKind.zip);
    expect(service.kindForPath('a.bin'), FilePreviewKind.unsupported);
  });

  test('formats JSON text preview when possible', () async {
    final file = File(p.join(tempDir.path, 'data.json'));
    await file.writeAsString('{"name":"GUETer"}');

    final text = await service.readTextPreview(file.path, FilePreviewKind.json);

    expect(text, contains('\n  "name": "GUETer"'));
  });

  test('marks oversized text as not previewable', () async {
    final file = File(p.join(tempDir.path, 'large.txt'));
    await file.writeAsBytes(List<int>.filled(1024 * 1024 + 1, 65));

    final descriptor = await service.describe(file.path);

    expect(descriptor.kind, FilePreviewKind.text);
    expect(descriptor.canPreview, isFalse);
  });
}
