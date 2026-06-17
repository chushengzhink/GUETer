import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../core/performance/app_performance.dart';
import '../models/file_tool_models.dart';
import 'file_tool_service.dart';

class LightweightPdfConversionService {
  static const Set<String> supportedExtensions = <String>{
    '.jpg',
    '.jpeg',
    '.png',
    '.bmp',
    '.gif',
    '.txt',
    '.md',
    '.markdown',
    '.html',
    '.htm',
    '.csv',
  };

  Future<LightweightPdfConversionResult> convertFilesToPdf({
    required List<File> files,
    required Directory outputDirectory,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    if (files.isEmpty) {
      throw const FileToolException('Choose at least one supported file.');
    }
    if (!outputDirectory.existsSync()) {
      await outputDirectory.create(recursive: true);
    }

    final outputs = <String>[];
    final yielder = CooperativeYield(
      batchSize: performanceMode == AppPerformanceMode.lowPower ? 2 : 8,
    );
    for (final file in files) {
      final extension = p.extension(file.path).toLowerCase();
      if (!supportedExtensions.contains(extension)) {
        throw FileToolException(
          'Unsupported format: ${p.basename(file.path)}. Supported: images, TXT, Markdown, HTML, CSV.',
        );
      }
      if (!await file.exists() || await file.length() == 0) {
        throw FileToolException(
          'Source file is empty: ${p.basename(file.path)}.',
        );
      }

      final outFile = File(
        p.join(
          outputDirectory.path,
          '${p.basenameWithoutExtension(file.path)}.pdf',
        ),
      );
      final target = await _uniqueFile(outFile);
      if (_isImageExtension(extension)) {
        await _imageToPdf(file, target);
      } else if (extension == '.csv') {
        await _csvToPdf(file, target);
      } else {
        await _textLikeToPdf(file, target, extension);
      }
      outputs.add(target.path);
      await yielder.tick();
    }

    return LightweightPdfConversionResult(
      outputPaths: outputs,
      message: outputs.length == 1
          ? 'Converted 1 file to PDF.'
          : 'Converted ${outputs.length} files to PDF.',
    );
  }

  Future<void> _imageToPdf(File source, File target) async {
    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 28;
    final bytes = await source.readAsBytes();
    final bitmap = PdfBitmap(bytes);
    final page = document.pages.add();
    final size = page.getClientSize();
    page.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    await _saveDocument(document, target);
  }

  Future<void> _textLikeToPdf(
    File source,
    File target,
    String extension,
  ) async {
    final raw = await source.readAsString();
    final text = _normalizeText(
      extension == '.html' || extension == '.htm'
          ? html_parser.parse(raw).body?.text ?? raw
          : _stripMarkdown(raw),
    );
    if (text.trim().isEmpty) {
      throw FileToolException(
        'Source file has no readable text: ${p.basename(source.path)}.',
      );
    }

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 36;
    final page = document.pages.add();
    final size = page.getClientSize();

    final titleFont = PdfCjkStandardFont(
      PdfCjkFontFamily.sinoTypeSongLight,
      18,
      style: PdfFontStyle.bold,
    );
    final bodyFont = PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 11);
    final title = p.basename(source.path);

    page.graphics.drawString(
      title,
      titleFont,
      brush: PdfSolidBrush(PdfColor(20, 20, 20)),
      bounds: Rect.fromLTWH(0, 0, size.width, 28),
    );

    final element = PdfTextElement(
      text: text,
      font: bodyFont,
      brush: PdfSolidBrush(PdfColor(35, 35, 35)),
      format: PdfStringFormat(lineSpacing: 4),
    );
    element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 42, size.width, size.height - 42),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    await _saveDocument(document, target);
  }

  Future<void> _csvToPdf(File source, File target) async {
    final raw = await source.readAsString();
    final rows = _parseCsv(raw);
    if (rows.isEmpty ||
        rows.every((row) => row.every((cell) => cell.trim().isEmpty))) {
      throw FileToolException(
        'Source CSV has no readable cells: ${p.basename(source.path)}.',
      );
    }

    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;
    document.pageSettings.margins.all = 28;
    final page = document.pages.add();
    final size = page.getClientSize();
    final font = PdfCjkStandardFont(PdfCjkFontFamily.sinoTypeSongLight, 9);
    final headerFont = PdfCjkStandardFont(
      PdfCjkFontFamily.sinoTypeSongLight,
      9,
      style: PdfFontStyle.bold,
    );

    page.graphics.drawString(
      p.basename(source.path),
      PdfCjkStandardFont(
        PdfCjkFontFamily.sinoTypeSongLight,
        16,
        style: PdfFontStyle.bold,
      ),
      bounds: Rect.fromLTWH(0, 0, size.width, 26),
    );

    final columnCount = math.min(
      rows.fold<int>(0, (max, row) => math.max(max, row.length)),
      12,
    );
    final grid = PdfGrid();
    grid.columns.add(count: columnCount);
    grid.style = PdfGridStyle(
      font: font,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );

    final header = grid.headers.add(1)[0];
    final headerValues = rows.first;
    for (var i = 0; i < columnCount; i++) {
      header.cells[i].value = _cellValue(headerValues, i);
      header.cells[i].style = PdfGridCellStyle(
        font: headerFont,
        backgroundBrush: PdfSolidBrush(PdfColor(235, 245, 245)),
      );
    }

    for (final values in rows.skip(1).take(500)) {
      final row = grid.rows.add();
      for (var i = 0; i < columnCount; i++) {
        row.cells[i].value = _cellValue(values, i);
      }
    }

    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 38, size.width, size.height - 38),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    await _saveDocument(document, target);
  }

  Future<void> _saveDocument(PdfDocument document, File target) async {
    await target.parent.create(recursive: true);
    await target.writeAsBytes(document.saveSync(), flush: true);
    document.dispose();
  }

  Future<File> _uniqueFile(File target) async {
    var candidate = target;
    var counter = 1;
    while (await candidate.exists()) {
      candidate = File(
        p.join(
          target.parent.path,
          '${p.basenameWithoutExtension(target.path)} ($counter)${p.extension(target.path)}',
        ),
      );
      counter += 1;
    }
    return candidate;
  }

  bool _isImageExtension(String extension) {
    return const <String>{
      '.jpg',
      '.jpeg',
      '.png',
      '.bmp',
      '.gif',
    }.contains(extension);
  }

  String _stripMarkdown(String raw) {
    return raw
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`([^`]+)`'), r'$1')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '')
        .replaceAll(RegExp(r'[*_~]{1,3}'), '');
  }

  String _normalizeText(String raw) {
    return const LineSplitter()
        .convert(raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n'))
        .map((line) => line.trimRight())
        .join('\n')
        .trim();
  }

  List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    void endCell() {
      row.add(cell.toString().trim());
      cell.clear();
    }

    void endRow() {
      endCell();
      if (row.any((item) => item.isNotEmpty)) {
        rows.add(List<String>.from(row));
      }
      row.clear();
    }

    for (var i = 0; i < raw.length; i++) {
      final char = raw[i];
      if (char == '"') {
        if (inQuotes && i + 1 < raw.length && raw[i + 1] == '"') {
          cell.write('"');
          i += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        endCell();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') {
          i += 1;
        }
        endRow();
      } else {
        cell.write(char);
      }
    }

    if (cell.isNotEmpty || row.isNotEmpty) {
      endRow();
    }
    return rows;
  }

  String _cellValue(List<String> values, int index) {
    if (index >= values.length) return '';
    final value = values[index];
    return value.length > 120 ? '${value.substring(0, 117)}...' : value;
  }
}
