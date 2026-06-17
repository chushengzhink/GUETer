import 'dart:io';

import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_index_service.dart';
import 'package:course_helper/materials/material_search_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'material_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('material_search_test_');
    mockPathProviderForTests(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('indexes text files and searches title, path, and content', () async {
    final file = File(p.join(tempDir.path, 'notes.txt'));
    await file.writeAsString('linear algebra matrix review');
    final service = MaterialIndexService();

    final entry = await service.indexExternalFile(
      path: file.path,
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '测试输出',
    );
    final results = await service.search(query: 'matrix');
    final summary = await service.summary();

    expect(entry.content, contains('matrix'));
    expect(results.single.entry.name, 'notes.txt');
    expect(summary.indexed, 1);
    expect(summary.failed, 0);
  });

  test('unsupported files are recorded as controlled index failures', () async {
    final file = File(p.join(tempDir.path, 'binary.bin'));
    await file.writeAsBytes(<int>[0, 1, 2, 3]);
    final service = MaterialIndexService();

    final entry = await service.indexExternalFile(
      path: file.path,
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '测试输出',
    );

    expect(entry.hasError, isTrue);
    expect((await service.summary()).failed, 1);
  });

  test(
    'context search supports limit, related terms, and path prefix',
    () async {
      final mathDir = Directory(p.join(tempDir.path, 'math'));
      final codeDir = Directory(p.join(tempDir.path, 'code'));
      await mathDir.create();
      await codeDir.create();
      final algebra = File(p.join(mathDir.path, 'algebra-notes.txt'));
      final homework = File(p.join(mathDir.path, 'homework-guide.txt'));
      final code = File(p.join(codeDir.path, 'flutter-notes.txt'));
      await algebra.writeAsString('matrix eigenvalue course summary');
      await homework.writeAsString('deadline assignment matrix practice');
      await code.writeAsString('widget state route');
      final service = MaterialIndexService();
      await service.indexExternalFile(
        path: algebra.path,
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '资料',
      );
      await service.indexExternalFile(
        path: homework.path,
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '资料',
      );
      await service.indexExternalFile(
        path: code.path,
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '资料',
      );

      final context = MaterialSearchContext.todo(
        title: 'matrix assignment',
        courseName: 'linear algebra',
        limit: 1,
      );
      final results = await service.search(
        query: context.normalizedQuery,
        contextTerms: context.contextTerms,
        sourcePathPrefix: mathDir.path,
        limit: context.limit,
      );

      expect(results, hasLength(1));
      expect(results.single.entry.path.startsWith(mathDir.path), isTrue);
      expect(
        results.single.entry.name,
        anyOf('algebra-notes.txt', 'homework-guide.txt'),
      );
    },
  );

  test('material search context builds stable course and review queries', () {
    final course = MaterialSearchContext.course(
      courseName: '高等数学',
      teacher: '张老师',
    );
    final review = MaterialSearchContext.reviewSource(
      sourceFileName: 'chapter1.pdf',
      sourcePath: p.join(tempDir.path, 'materials', 'chapter1.pdf'),
    );

    expect(course.normalizedQuery, contains('高等数学'));
    expect(course.contextTerms, contains('高等数学'));
    expect(review.sourcePathPrefix, p.join(tempDir.path, 'materials'));
    expect(review.contextTerms, contains('chapter1.pdf'));
  });
}
