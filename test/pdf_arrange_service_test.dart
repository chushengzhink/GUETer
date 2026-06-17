import 'dart:io';

import 'package:course_helper/models/pdf_arrange_models.dart';
import 'package:course_helper/services/pdf_arrange_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late Directory tempDir;
  late PdfArrangeService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pdf_arrange_service_');
    service = const PdfArrangeService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loads PDF pages into arrange items', () async {
    final file = await _createPdf(tempDir, 'source.pdf', 3);

    final items = await service.loadPages(file);

    expect(items, hasLength(3));
    expect(items.map((item) => item.id), <String>[
      'page-1',
      'page-2',
      'page-3',
    ]);
    expect(items.map((item) => item.originalPageNumber), <int>[1, 2, 3]);
    expect(items.map((item) => item.currentIndex), <int>[0, 1, 2]);
  });

  test('reorders, deletes and rotates before export', () async {
    final file = await _createPdf(tempDir, 'source.pdf', 3);
    var items = await service.loadPages(file);
    items = service.reorder(items, 0, 3);
    items = service.setDeleted(items, 'page-2', true);
    items = service.rotatePage(items, 'page-1', 90);

    final result = await service.exportArrangedPdf(
      sourceFile: file,
      items: items,
      outputDirectory: tempDir,
    );

    expect(result.keptCount, 2);
    expect(result.deletedCount, 1);
    expect(result.rotatedCount, 1);
    expect(File(result.outputPath).existsSync(), isTrue);
    final exported = PdfDocument(
      inputBytes: File(result.outputPath).readAsBytesSync(),
    );
    expect(exported.pages.count, 2);
    exported.dispose();
  });

  test('uses unique output name when target exists', () async {
    final file = await _createPdf(tempDir, 'source.pdf', 1);
    File(p.join(tempDir.path, 'source_arranged.pdf')).writeAsStringSync('old');
    final items = await service.loadPages(file);

    final result = await service.exportArrangedPdf(
      sourceFile: file,
      items: items,
      outputDirectory: tempDir,
    );

    expect(p.basename(result.outputPath), 'source_arranged (1).pdf');
  });

  test('restoreAll clears deletion rotation and restores original order', () {
    final items = <PdfArrangePageItem>[
      const PdfArrangePageItem(
        id: 'page-3',
        originalPageNumber: 3,
        currentIndex: 0,
        deleted: true,
        rotationDegrees: 90,
      ),
      const PdfArrangePageItem(
        id: 'page-1',
        originalPageNumber: 1,
        currentIndex: 1,
      ),
      const PdfArrangePageItem(
        id: 'page-2',
        originalPageNumber: 2,
        currentIndex: 2,
      ),
    ];

    final restored = service.restoreAll(items);

    expect(restored.map((item) => item.originalPageNumber), <int>[1, 2, 3]);
    expect(restored.map((item) => item.currentIndex), <int>[0, 1, 2]);
    expect(restored.every((item) => !item.deleted), isTrue);
    expect(restored.every((item) => item.rotationDegrees == 0), isTrue);
  });

  test(
    'duplicates pages as separate instances and exports selected pages',
    () async {
      final file = await _createPdf(tempDir, 'source.pdf', 2);
      var items = await service.loadPages(file);
      items = service.rotatePage(items, 'page-1', 90);
      items = service.duplicatePages(items, {'page-1'});
      final duplicate = items.singleWhere(
        (item) => item.id != 'page-1' && item.originalPageNumber == 1,
      );

      expect(items.map((item) => item.originalPageNumber), <int>[1, 1, 2]);
      expect(duplicate.id, isNot('page-1'));
      expect(duplicate.rotationDegrees, 90);

      items = service.setDeleted(items, 'page-2', true);
      final result = await service.exportArrangedPdf(
        sourceFile: file,
        items: items,
        outputDirectory: tempDir,
        selectedIds: {duplicate.id, 'page-2'},
        mode: PdfArrangeExportMode.selectedPages,
      );

      expect(result.keptCount, 1);
      expect(result.selectedOnly, isTrue);
      expect(result.duplicateCount, 0);
      final exported = PdfDocument(
        inputBytes: File(result.outputPath).readAsBytesSync(),
      );
      expect(exported.pages.count, 1);
      exported.dispose();
    },
  );

  test('batch operations affect only selected page instances', () {
    const items = <PdfArrangePageItem>[
      PdfArrangePageItem(id: 'a', originalPageNumber: 1, currentIndex: 0),
      PdfArrangePageItem(id: 'b', originalPageNumber: 1, currentIndex: 1),
      PdfArrangePageItem(id: 'c', originalPageNumber: 2, currentIndex: 2),
    ];

    final rotated = service.rotateMany(items, {'b'}, 90);
    expect(rotated.first.rotationDegrees, 0);
    expect(rotated[1].rotationDegrees, 90);

    final deleted = service.setDeletedMany(rotated, {'a', 'c'}, true);
    expect(deleted.map((item) => item.deleted), <bool>[true, false, true]);

    final restored = service.restoreMany(deleted, {'c'});
    expect(restored[2].deleted, isFalse);
    expect(restored[1].rotationDegrees, 90);
  });

  test('range parser supports comma ranges and rejects invalid input', () {
    expect(service.parseCurrentPositionRange('1-3,5,8', 10), <int>{
      0,
      1,
      2,
      4,
      7,
    });
    expect(
      () => service.parseCurrentPositionRange('4-2', 10),
      throwsA(isA<PdfArrangeException>()),
    );
    expect(
      () => service.parseCurrentPositionRange('1,20', 10),
      throwsA(isA<PdfArrangeException>()),
    );
  });

  test('rejects PDFs over configured page limit', () async {
    final smallLimit = const PdfArrangeService(maxPages: 2);
    final file = await _createPdf(tempDir, 'large.pdf', 3);

    expect(
      () => smallLimit.loadPages(file),
      throwsA(isA<PdfArrangeException>()),
    );
  });
}

Future<File> _createPdf(Directory dir, String name, int pageCount) async {
  final document = PdfDocument();
  for (var i = 0; i < pageCount; i++) {
    final page = document.pages.add();
    page.graphics.drawString(
      'Page ${i + 1}',
      PdfStandardFont(PdfFontFamily.helvetica, 20),
    );
  }
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(document.saveSync(), flush: true);
  document.dispose();
  return file;
}
