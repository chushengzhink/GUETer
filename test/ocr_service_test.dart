import 'dart:io';

import 'package:course_helper/materials/material_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'material_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocr_service_test_');
    mockPathProviderForTests(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveText writes OCR result into local TXT file', () async {
    final imagePath = p.join(tempDir.path, 'scan.png');
    final service = const MaterialOcrService();
    final file = await service.saveText(
      MaterialOcrResult(
        sourcePath: imagePath,
        text: '本地 OCR 结果',
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    expect(file.path, endsWith('.txt'));
    expect(await file.readAsString(), '本地 OCR 结果');
    expect(file.path, contains(p.join('gueter', 'ocr_texts')));
  });
}
