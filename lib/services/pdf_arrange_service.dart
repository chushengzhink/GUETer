import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../core/performance/app_performance.dart';
import '../models/pdf_arrange_models.dart';

class PdfArrangeService {
  const PdfArrangeService({this.maxPages = 150});

  final int maxPages;

  Future<List<PdfArrangePageItem>> loadPages(File file) async {
    final bytes = await _readPdfBytes(file);
    final document = _openDocument(bytes);
    try {
      final count = document.pages.count;
      if (count <= 0) {
        throw const PdfArrangeException('PDF 没有可编排的页面。');
      }
      if (count > maxPages) {
        throw PdfArrangeException(
          'PDF 页数为 $count 页，超过一期支持的 $maxPages 页上限，请先提取页面后再编排。',
        );
      }
      return List<PdfArrangePageItem>.generate(
        count,
        (index) => PdfArrangePageItem(
          id: 'page-${index + 1}',
          originalPageNumber: index + 1,
          currentIndex: index,
        ),
      );
    } finally {
      document.dispose();
    }
  }

  Future<List<PdfArrangePageItem>> renderThumbnails({
    required File file,
    required List<PdfArrangePageItem> items,
    double dpi = 60,
    void Function(int done, int total)? onProgress,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    if (items.isEmpty) return const <PdfArrangePageItem>[];
    final pageByNumber = {
      for (final item in items) item.originalPageNumber: item,
    };
    final thumbnails = <int, Uint8List>{};
    var done = 0;
    final effectiveDpi = performanceMode == AppPerformanceMode.lowPower
        ? math.min(dpi, 42).toDouble()
        : dpi;
    final yielder = CooperativeYield(
      batchSize: performanceMode == AppPerformanceMode.lowPower ? 2 : 6,
    );
    try {
      final stream = Printing.raster(await _readPdfBytes(file), dpi: effectiveDpi);
      var pageNumber = 0;
      await for (final page in stream) {
        pageNumber += 1;
        if (pageByNumber.containsKey(pageNumber)) {
          thumbnails[pageNumber] = await page.toPng();
          done += 1;
          onProgress?.call(done, items.length);
          await yielder.tick();
        }
        if (done >= items.length) break;
      }
    } catch (_) {
      return items;
    }
    return _reindex(
      items
          .map(
            (item) => item.copyWith(
              thumbnailBytes:
                  thumbnails[item.originalPageNumber] ?? item.thumbnailBytes,
            ),
          )
          .toList(),
    );
  }

  Future<PdfArrangeExportResult> exportArrangedPdf({
    required File sourceFile,
    required List<PdfArrangePageItem> items,
    required Directory outputDirectory,
    Set<String>? selectedIds,
    PdfArrangeExportMode mode = PdfArrangeExportMode.keptPages,
  }) async {
    final selected = selectedIds ?? const <String>{};
    final kept = items
        .where((item) => !item.deleted)
        .where(
          (item) =>
              mode == PdfArrangeExportMode.keptPages ||
              selected.contains(item.id),
        )
        .toList();
    if (kept.isEmpty) {
      throw PdfArrangeException(
        mode == PdfArrangeExportMode.selectedPages
            ? '至少选择并保留一页才能导出 PDF。'
            : '至少保留一页才能导出 PDF。',
      );
    }
    await outputDirectory.create(recursive: true);

    final source = _openDocument(await _readPdfBytes(sourceFile));
    final target = PdfDocument();
    try {
      for (final item in kept) {
        final sourcePage = source.pages[item.originalPageNumber - 1];
        final template = sourcePage.createTemplate();
        final rotation = _normalizeRotation(item.rotationDegrees);
        final sourceSize = sourcePage.size;
        final targetSize = rotation == 90 || rotation == 270
            ? Size(sourceSize.height, sourceSize.width)
            : sourceSize;
        target.pageSettings.size = targetSize;
        target.pageSettings.margins.all = 0;
        final page = target.pages.add();
        _drawTemplateWithRotation(
          page: page,
          template: template,
          sourceSize: sourceSize,
          rotation: rotation,
        );
      }
      final outputFile = File(
        await _uniqueOutputPath(sourceFile, outputDirectory),
      );
      await outputFile.writeAsBytes(target.saveSync(), flush: true);
      return PdfArrangeExportResult(
        outputPath: outputFile.path,
        keptCount: kept.length,
        deletedCount: items.length - kept.length,
        rotatedCount: kept.where((item) => item.hasRotation).length,
        duplicateCount: _duplicateCount(kept),
        selectedOnly: mode == PdfArrangeExportMode.selectedPages,
      );
    } finally {
      source.dispose();
      target.dispose();
    }
  }

  List<PdfArrangePageItem> reorder(
    List<PdfArrangePageItem> items,
    int oldIndex,
    int newIndex,
  ) {
    final next = List<PdfArrangePageItem>.from(items);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    return _reindex(next);
  }

  List<PdfArrangePageItem> rotatePage(
    List<PdfArrangePageItem> items,
    String itemId,
    int deltaDegrees,
  ) {
    return _reindex(
      items
          .map(
            (item) => item.id == itemId
                ? item.copyWith(
                    rotationDegrees: _normalizeRotation(
                      item.rotationDegrees + deltaDegrees,
                    ),
                  )
                : item,
          )
          .toList(),
    );
  }

  List<PdfArrangePageItem> setDeleted(
    List<PdfArrangePageItem> items,
    String itemId,
    bool deleted,
  ) {
    return _reindex(
      items
          .map(
            (item) =>
                item.id == itemId ? item.copyWith(deleted: deleted) : item,
          )
          .toList(),
    );
  }

  List<PdfArrangePageItem> rotateMany(
    List<PdfArrangePageItem> items,
    Set<String> itemIds,
    int deltaDegrees,
  ) {
    return _reindex(
      items
          .map(
            (item) => itemIds.contains(item.id)
                ? item.copyWith(
                    rotationDegrees: _normalizeRotation(
                      item.rotationDegrees + deltaDegrees,
                    ),
                  )
                : item,
          )
          .toList(),
    );
  }

  List<PdfArrangePageItem> setDeletedMany(
    List<PdfArrangePageItem> items,
    Set<String> itemIds,
    bool deleted,
  ) {
    return _reindex(
      items
          .map(
            (item) => itemIds.contains(item.id)
                ? item.copyWith(deleted: deleted)
                : item,
          )
          .toList(),
    );
  }

  List<PdfArrangePageItem> restoreMany(
    List<PdfArrangePageItem> items,
    Set<String> itemIds,
  ) {
    return _reindex(
      items
          .map(
            (item) => itemIds.contains(item.id)
                ? item.copyWith(deleted: false, rotationDegrees: 0)
                : item,
          )
          .toList(),
    );
  }

  List<PdfArrangePageItem> duplicatePages(
    List<PdfArrangePageItem> items,
    Set<String> selectedIds,
  ) {
    if (selectedIds.isEmpty) return items;
    final usedIds = items.map((item) => item.id).toSet();
    final next = <PdfArrangePageItem>[];
    for (final item in items) {
      next.add(item);
      if (!selectedIds.contains(item.id)) continue;
      final duplicateId = _nextDuplicateId(item.id, usedIds);
      usedIds.add(duplicateId);
      next.add(item.copyWith(id: duplicateId, deleted: false));
    }
    return _reindex(next);
  }

  Set<String> selectByRange(List<PdfArrangePageItem> items, String input) {
    final indexes = parseCurrentPositionRange(input, items.length);
    return indexes.map((index) => items[index].id).toSet();
  }

  Set<int> parseCurrentPositionRange(String input, int pageCount) {
    final text = input.trim();
    if (text.isEmpty) {
      throw const PdfArrangeException('请输入页码范围，例如 1-3,5,8。');
    }
    final selected = <int>{};
    for (final rawPart in text.split(',')) {
      final part = rawPart.trim();
      if (part.isEmpty) {
        throw const PdfArrangeException('页码范围格式不正确。');
      }
      final rangeParts = part.split('-').map((value) => value.trim()).toList();
      if (rangeParts.length > 2 || rangeParts.any((value) => value.isEmpty)) {
        throw const PdfArrangeException('页码范围格式不正确。');
      }
      final start = int.tryParse(rangeParts.first);
      final end = rangeParts.length == 1 ? start : int.tryParse(rangeParts[1]);
      if (start == null || end == null) {
        throw const PdfArrangeException('页码范围只能包含数字、逗号和连字符。');
      }
      if (start < 1 || end < 1 || start > pageCount || end > pageCount) {
        throw PdfArrangeException('页码范围需在 1-$pageCount 之间。');
      }
      if (start > end) {
        throw const PdfArrangeException('页码范围起始页不能大于结束页。');
      }
      for (var page = start; page <= end; page++) {
        selected.add(page - 1);
      }
    }
    return selected;
  }

  List<PdfArrangePageItem> restoreAll(List<PdfArrangePageItem> items) {
    final next =
        items
            .map((item) => item.copyWith(deleted: false, rotationDegrees: 0))
            .toList()
          ..sort(
            (a, b) => a.originalPageNumber.compareTo(b.originalPageNumber),
          );
    return _reindex(next);
  }

  Future<Uint8List> _readPdfBytes(File file) async {
    if (p.extension(file.path).toLowerCase() != '.pdf') {
      throw const PdfArrangeException('请选择 PDF 文件。');
    }
    if (!await file.exists()) {
      throw const PdfArrangeException('PDF 文件不存在或已移动。');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const PdfArrangeException('PDF 文件为空。');
    }
    return bytes;
  }

  PdfDocument _openDocument(List<int> bytes) {
    try {
      return PdfDocument(inputBytes: bytes);
    } catch (_) {
      throw const PdfArrangeException('PDF 无法解析，可能已加密或损坏。');
    }
  }

  void _drawTemplateWithRotation({
    required PdfPage page,
    required PdfTemplate template,
    required Size sourceSize,
    required int rotation,
  }) {
    final graphics = page.graphics;
    final pageSize = page.getClientSize();
    graphics.save();
    switch (rotation) {
      case 90:
        graphics.translateTransform(pageSize.width, 0);
        graphics.rotateTransform(90);
      case 180:
        graphics.translateTransform(pageSize.width, pageSize.height);
        graphics.rotateTransform(180);
      case 270:
        graphics.translateTransform(0, pageSize.height);
        graphics.rotateTransform(270);
    }
    graphics.drawPdfTemplate(
      template,
      Offset.zero,
      Size(sourceSize.width, sourceSize.height),
    );
    graphics.restore();
  }

  int _normalizeRotation(int degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  List<PdfArrangePageItem> _reindex(List<PdfArrangePageItem> items) {
    return List<PdfArrangePageItem>.generate(
      items.length,
      (index) => items[index].copyWith(currentIndex: index),
    );
  }

  int _duplicateCount(List<PdfArrangePageItem> items) {
    final seen = <int>{};
    var duplicates = 0;
    for (final item in items) {
      if (!seen.add(item.originalPageNumber)) duplicates += 1;
    }
    return duplicates;
  }

  String _nextDuplicateId(String baseId, Set<String> usedIds) {
    var index = 1;
    var candidate = '$baseId-copy-$index';
    while (usedIds.contains(candidate)) {
      index += 1;
      candidate = '$baseId-copy-$index';
    }
    return candidate;
  }

  Future<String> _uniqueOutputPath(File sourceFile, Directory outputDir) async {
    final stem = '${p.basenameWithoutExtension(sourceFile.path)}_arranged';
    final extension = p.extension(sourceFile.path).isEmpty
        ? '.pdf'
        : p.extension(sourceFile.path);
    var candidate = p.join(outputDir.path, '$stem$extension');
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(outputDir.path, '$stem ($counter)$extension');
      counter += 1;
      if (counter > math.pow(10, 6)) {
        throw const PdfArrangeException('无法生成唯一输出文件名。');
      }
    }
    return candidate;
  }
}
