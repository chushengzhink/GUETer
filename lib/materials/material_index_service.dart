import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../core/performance/app_performance.dart';
import '../features/openlist/openlist_offline_package.dart';
import '../features/openlist/openlist_repository.dart';
import '../services/file_tool_service.dart';
import '../study/study_card_store.dart';
import 'material_index_models.dart';
import 'material_library_store.dart';

class MaterialScanRoot {
  const MaterialScanRoot({
    required this.sourceType,
    required this.sourceLabel,
    required this.path,
  });

  final MaterialSourceType sourceType;
  final String sourceLabel;
  final String path;
}

class MaterialIndexService {
  MaterialIndexService({
    StudyCardStore? studyCardStore,
    FileToolService? fileToolService,
    MaterialLibraryStore? libraryStore,
    BackgroundTaskRunner? backgroundTaskRunner,
  }) : _studyCardStore = studyCardStore ?? StudyCardStore(),
       _fileToolService = fileToolService ?? FileToolService(),
       _libraryStore = libraryStore ?? MaterialLibraryStore(),
       _backgroundTaskRunner =
           backgroundTaskRunner ?? const BackgroundTaskRunner();

  static const int maxIndexedTextChars = 120000;
  static const int maxPlainTextBytes = 2 * 1024 * 1024;
  static const Set<String> supportedTextExtensions = <String>{
    '.txt',
    '.md',
    '.markdown',
    '.json',
    '.csv',
    '.log',
    '.xml',
    '.html',
    '.htm',
  };

  final StudyCardStore _studyCardStore;
  final FileToolService _fileToolService;
  final MaterialLibraryStore _libraryStore;
  final BackgroundTaskRunner _backgroundTaskRunner;

  Future<File> indexFile() async {
    final dir = await getApplicationSupportDirectory();
    final indexDir = Directory(p.join(dir.path, 'material_index'));
    if (!await indexDir.exists()) {
      await indexDir.create(recursive: true);
    }
    return File(p.join(indexDir.path, 'materials.jsonl'));
  }

  Future<List<MaterialIndexEntry>> loadIndex() async {
    final file = await indexFile();
    if (!await file.exists()) return const <MaterialIndexEntry>[];
    final entries = <MaterialIndexEntry>[];
    await for (final line
        in file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map) {
          entries.add(
            MaterialIndexEntry.fromJson(
              decoded.map((key, value) => MapEntry('$key', value)),
            ),
          );
        }
      } catch (_) {
        // Ignore corrupt index lines and keep the rest searchable.
      }
    }
    return entries;
  }

  Future<MaterialIndexSummary> summary() async {
    final entries = await loadIndex();
    DateTime? updatedAt;
    for (final entry in entries) {
      if (updatedAt == null || entry.indexedAt.isAfter(updatedAt)) {
        updatedAt = entry.indexedAt;
      }
    }
    return MaterialIndexSummary(
      total: entries.length,
      indexed: entries.where((entry) => !entry.hasError).length,
      failed: entries.where((entry) => entry.hasError).length,
      updatedAt: updatedAt,
    );
  }

  Future<List<MaterialSearchResult>> search({
    required String query,
    MaterialSourceType? sourceType,
    int? limit,
    Iterable<String> contextTerms = const <String>[],
    String? sourcePathPrefix,
  }) async {
    final normalized = query.trim().toLowerCase();
    final normalizedTerms = contextTerms
        .map((term) => term.trim().toLowerCase())
        .where((term) => term.length >= 2)
        .toSet()
        .toList();
    if (normalized.isEmpty && normalizedTerms.isEmpty) {
      return const <MaterialSearchResult>[];
    }
    final normalizedPrefix = sourcePathPrefix == null
        ? null
        : p.normalize(sourcePathPrefix).toLowerCase();
    final entries = await loadIndex();
    final results = <MaterialSearchResult>[];
    for (final entry in entries) {
      if (sourceType != null && entry.sourceType != sourceType) continue;
      if (normalizedPrefix != null &&
          !p.normalize(entry.path).toLowerCase().startsWith(normalizedPrefix)) {
        continue;
      }
      var score = 0;
      if (normalized.isNotEmpty) {
        score += _scoreTerm(entry, normalized, primary: true);
      }
      for (final term in normalizedTerms) {
        if (term == normalized) continue;
        score += _scoreTerm(entry, term, primary: false);
      }
      if (sourcePathPrefix != null) {
        final sourceDir = p.normalize(sourcePathPrefix);
        final entryDir = p.dirname(p.normalize(entry.path));
        if (p.equals(sourceDir, entryDir)) {
          score += 2;
        }
      }
      if (score > 0) {
        results.add(
          MaterialSearchResult(
            entry: entry,
            snippet: _snippet(
              entry,
              normalized.isNotEmpty ? normalized : normalizedTerms.first,
            ),
            score: score,
          ),
        );
      }
    }
    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return b.entry.modifiedAt.compareTo(a.entry.modifiedAt);
    });
    return limit == null ? results : results.take(limit).toList();
  }

  int _scoreTerm(
    MaterialIndexEntry entry,
    String normalized, {
    required bool primary,
  }) {
    final multiplier = primary ? 2 : 1;
    final haystacks = <({String value, int weight})>[
      (value: entry.name, weight: 8),
      (value: entry.path, weight: 5),
      (value: entry.sourceLabel, weight: 3),
      (value: entry.content, weight: 2),
    ];
    var score = 0;
    for (final haystack in haystacks) {
      final lower = haystack.value.toLowerCase();
      if (lower == normalized) {
        score += haystack.weight * 2 * multiplier;
      } else if (lower.contains(normalized)) {
        score += haystack.weight * multiplier;
      }
    }
    return score;
  }

  Future<List<MaterialIndexEntry>> rebuildIndex({
    void Function(String message)? onProgress,
    CancellationToken? cancellationToken,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final roots = await _buildRoots();
    final entries = <MaterialIndexEntry>[];
    final seenPaths = <String>{};
    final yielder = CooperativeYield(
      batchSize: performanceMode == AppPerformanceMode.lowPower ? 4 : 16,
    );
    for (final root in roots) {
      final dir = Directory(root.path);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        cancellationToken?.throwIfCancelled();
        if (entity is! File) continue;
        final normalizedPath = p.normalize(entity.path);
        if (!seenPaths.add(normalizedPath)) continue;
        onProgress?.call('索引 ${p.basename(normalizedPath)}');
        entries.add(
          await _indexLocalFile(entity, root, performanceMode: performanceMode),
        );
        await yielder.tick();
      }
    }
    await _saveIndex(entries, performanceMode: performanceMode);
    for (final entry in entries) {
      cancellationToken?.throwIfCancelled();
      await _libraryStore.recordIndexEntry(entry);
      await yielder.tick();
    }
    return entries;
  }

  Future<MaterialIndexEntry> indexExternalFile({
    required String path,
    required MaterialSourceType sourceType,
    required String sourceLabel,
  }) async {
    final entry = await _indexLocalFile(
      File(path),
      MaterialScanRoot(
        sourceType: sourceType,
        sourceLabel: sourceLabel,
        path: p.dirname(path),
      ),
    );
    final entries = await loadIndex();
    final filtered = entries.where((item) => item.path != entry.path).toList();
    await _saveIndex(<MaterialIndexEntry>[entry, ...filtered]);
    await _libraryStore.recordIndexEntry(entry);
    return entry;
  }

  Future<List<MaterialScanRoot>> _buildRoots() async {
    final roots = <MaterialScanRoot>[
      MaterialScanRoot(
        sourceType: MaterialSourceType.openListDownload,
        sourceLabel: '云盘下载',
        path: await OpenListRepository.downloadDirectoryPath(),
      ),
      MaterialScanRoot(
        sourceType: MaterialSourceType.offlinePackage,
        sourceLabel: '云盘离线包',
        path: (await OpenListOfflinePackageService.ensureOfflineRootDirectory())
            .path,
      ),
      MaterialScanRoot(
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '文件工具输出',
        path: (await _fileToolService.ensureOutputDirectory()).path,
      ),
    ];
    final supportDir = await getApplicationSupportDirectory();
    roots.add(
      MaterialScanRoot(
        sourceType: MaterialSourceType.webArchive,
        sourceLabel: '网页归档',
        path: p.join(supportDir.path, 'web_archive'),
      ),
    );
    final cards = await _studyCardStore.loadCards();
    for (final card in cards) {
      final path = card.sourcePath;
      if (path == null || path.trim().isEmpty) continue;
      final file = File(path);
      if (await file.exists()) {
        roots.add(
          MaterialScanRoot(
            sourceType: MaterialSourceType.studySource,
            sourceLabel: '复习卡片来源',
            path: p.dirname(path),
          ),
        );
      }
    }
    return roots;
  }

  Future<MaterialIndexEntry> _indexLocalFile(
    File file,
    MaterialScanRoot root, {
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final stat = await file.stat();
    final now = DateTime.now();
    final id = sha1.convert(utf8.encode(p.normalize(file.path))).toString();
    try {
      final content = await extractText(
        file.path,
        maxChars: maxIndexedTextChars,
        performanceMode: performanceMode,
      );
      return MaterialIndexEntry(
        id: id,
        path: p.normalize(file.path),
        name: p.basename(file.path),
        sourceType: root.sourceType,
        sourceLabel: root.sourceLabel,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        indexedAt: now,
        content: content,
      );
    } catch (error) {
      return MaterialIndexEntry(
        id: id,
        path: p.normalize(file.path),
        name: p.basename(file.path),
        sourceType: root.sourceType,
        sourceLabel: root.sourceLabel,
        sizeBytes: stat.size,
        modifiedAt: stat.modified,
        indexedAt: now,
        error: error.toString(),
      );
    }
  }

  Future<String> extractText(
    String path, {
    int? maxChars,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final extension = p.extension(path).toLowerCase();
    if (supportedTextExtensions.contains(extension)) {
      final file = File(path);
      final length = await file.length();
      if (length > maxPlainTextBytes) {
        throw StateError('文本文件过大，已跳过。');
      }
      return _clip(
        utf8.decode(await file.readAsBytes(), allowMalformed: true),
        maxChars,
      );
    }
    if (extension == '.pdf') {
      final bytes = await File(path).readAsBytes();
      return _backgroundTaskRunner.run(
        () => _extractPdfTextForIndex(
          bytes,
          maxChars ?? maxIndexedTextChars,
          performanceMode == AppPerformanceMode.lowPower,
        ),
      );
    }
    throw StateError('暂不支持索引此文件类型。');
  }

  Future<void> _saveIndex(
    List<MaterialIndexEntry> entries, {
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final file = await indexFile();
    final sink = file.openWrite();
    final yielder = CooperativeYield(
      batchSize: performanceMode == AppPerformanceMode.lowPower ? 8 : 32,
    );
    try {
      for (final entry in entries) {
        sink.writeln(jsonEncode(entry.toJson()));
        await yielder.tick();
      }
    } finally {
      await sink.close();
    }
  }

  String _snippet(MaterialIndexEntry entry, String query) {
    final content = entry.content.isEmpty ? entry.path : entry.content;
    final lower = content.toLowerCase();
    final index = lower.indexOf(query);
    if (index < 0) {
      return content.length > 120 ? '${content.substring(0, 120)}...' : content;
    }
    final start = (index - 50).clamp(0, content.length);
    final end = (index + query.length + 70).clamp(0, content.length);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < content.length ? '...' : '';
    return '$prefix${content.substring(start, end)}$suffix';
  }

  String _clip(String text, int? maxChars) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final limit = maxChars ?? maxIndexedTextChars;
    if (normalized.length <= limit) return normalized;
    return normalized.substring(0, limit);
  }
}

String _extractPdfTextForIndex(List<int> bytes, int maxChars, bool lowPower) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    final text = PdfTextExtractor(document).extractText();
    if (text.trim().isEmpty) {
      throw StateError('PDF 未提取到文本。');
    }
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final limit = lowPower ? maxChars.clamp(0, 60000) : maxChars;
    if (normalized.length <= limit) return normalized;
    return normalized.substring(0, limit);
  } finally {
    document.dispose();
  }
}
