import 'dart:io';

import 'package:course_helper/services/file_tool_service.dart';
import 'package:course_helper/services/lightweight_pdf_conversion_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late LightweightPdfConversionService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lightweight_pdf_test_');
    service = LightweightPdfConversionService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('converts txt markdown html and csv files into pdf files', () async {
    final txt = File(p.join(tempDir.path, 'note.txt'))
      ..writeAsStringSync('中文笔记\nSecond line');
    final markdown = File(p.join(tempDir.path, 'readme.md'))
      ..writeAsStringSync('# 标题\n\n- item\n\n[link](https://example.com)');
    final html = File(p.join(tempDir.path, 'page.html'))
      ..writeAsStringSync('<h1>标题</h1><p>正文内容</p>');
    final csv = File(p.join(tempDir.path, 'table.csv'))
      ..writeAsStringSync('姓名,分数\n张三,99\n李四,88');
    final out = Directory(p.join(tempDir.path, 'out'));

    final result = await service.convertFilesToPdf(
      files: [txt, markdown, html, csv],
      outputDirectory: out,
    );

    expect(result.outputPaths, hasLength(4));
    for (final outputPath in result.outputPaths) {
      final file = File(outputPath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      expect(p.extension(outputPath), '.pdf');
    }
  });

  test('rejects empty source files', () async {
    final empty = File(p.join(tempDir.path, 'empty.txt'))
      ..writeAsStringSync('');

    expect(
      () => service.convertFilesToPdf(files: [empty], outputDirectory: tempDir),
      throwsA(isA<FileToolException>()),
    );
  });

  test('rejects unsupported source formats', () async {
    final docx = File(p.join(tempDir.path, 'paper.docx'))
      ..writeAsStringSync('x');

    expect(
      () => service.convertFilesToPdf(files: [docx], outputDirectory: tempDir),
      throwsA(isA<FileToolException>()),
    );
  });
}
