import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/performance/app_performance.dart';
import '../materials/material_index_models.dart';
import '../materials/material_library_store.dart';
import '../models/file_output_manager_models.dart';
import '../models/file_tool_models.dart';
import 'file_tool_history_store.dart';
import 'gueter_storage_service.dart';

class FileOutputManagerService {
  FileOutputManagerService({
    FileToolHistoryStore? historyStore,
    MaterialLibraryStore? materialLibraryStore,
    GueterStorageService? storageService,
    Future<List<Directory>> Function()? scanDirectoriesProvider,
  }) : _historyStore = historyStore ?? FileToolHistoryStore(),
       _materialLibraryStore = materialLibraryStore ?? MaterialLibraryStore(),
       _storageService = storageService ?? GueterStorageService.instance,
       _scanDirectoriesProvider = scanDirectoriesProvider;

  final FileToolHistoryStore _historyStore;
  final MaterialLibraryStore _materialLibraryStore;
  final GueterStorageService _storageService;
  final Future<List<Directory>> Function()? _scanDirectoriesProvider;

  Future<List<FileOutputItem>> loadOutputs({
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final histories = await _historyStore.load();
    final libraryItems = await _materialLibraryStore.loadItems();
    final libraryPaths = libraryItems
        .map((item) => p.normalize(item.path))
        .toSet();
    final managedRoots = await _managedRoots();
    final byPath = <String, FileOutputItem>{};

    for (final record in histories) {
      if (record.outputPath.trim().isEmpty) continue;
      final item = await _itemFromHistory(
        record,
        managedRoots: managedRoots,
        libraryPaths: libraryPaths,
        performanceMode: performanceMode,
      );
      byPath[p.normalize(item.path)] = item;
    }

    for (final entity in await _scanOutputEntities(managedRoots)) {
      final normalized = p.normalize(entity.path);
      if (byPath.containsKey(normalized)) continue;
      byPath[normalized] = await _itemFromEntity(
        entity,
        libraryPaths: libraryPaths,
        performanceMode: performanceMode,
      );
    }

    final items = byPath.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  Future<FileOutputManagerSummary> loadSummary({
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final items = await loadOutputs(performanceMode: performanceMode);
    return FileOutputManagerSummary.fromItems(items);
  }

  Future<void> removeFromHistory(Iterable<String> paths) {
    return _historyStore.removeManyByOutputPath(paths);
  }

  Future<int> addToMaterialLibrary(Iterable<FileOutputItem> items) async {
    var count = 0;
    for (final item in items) {
      if (!item.exists) continue;
      await _materialLibraryStore.upsertItem(
        path: item.path,
        name: item.name,
        sourceType: _sourceTypeForItem(item),
        sourceLabel: item.sourceLabel,
        tags: <String>['输出文件管家'],
      );
      count++;
    }
    return count;
  }

  Future<int> deleteOutputs(Iterable<FileOutputItem> items) async {
    var count = 0;
    for (final item in items) {
      if (!item.exists) continue;
      final type = await FileSystemEntity.type(item.path);
      if (type == FileSystemEntityType.file) {
        await File(item.path).delete();
        count++;
      } else if (type == FileSystemEntityType.directory) {
        await Directory(item.path).delete(recursive: true);
        count++;
      }
    }
    return count;
  }

  Future<List<Directory>> _managedRoots() async {
    final provider = _scanDirectoriesProvider;
    if (provider != null) {
      return provider();
    }
    final types = <GueterPublicDirectory>[
      GueterPublicDirectory.cloudDownloads,
      GueterPublicDirectory.offlinePackages,
      GueterPublicDirectory.fileTools,
      GueterPublicDirectory.pdfTools,
      GueterPublicDirectory.ocrTexts,
      GueterPublicDirectory.exports,
    ];
    final roots = <Directory>[];
    for (final type in types) {
      roots.add(await _storageService.publicDirectory(type));
    }
    return roots;
  }

  Future<FileOutputItem> _itemFromHistory(
    FileToolHistoryRecord record, {
    required List<Directory> managedRoots,
    required Set<String> libraryPaths,
    required AppPerformanceMode performanceMode,
  }) async {
    final path = p.normalize(record.outputPath);
    final type = await FileSystemEntity.type(path);
    final exists = type != FileSystemEntityType.notFound;
    final isDirectory = type == FileSystemEntityType.directory;
    final sizeBytes = exists
        ? await _entitySize(path, isDirectory, performanceMode: performanceMode)
        : 0;
    final status = !exists
        ? FileOutputStatus.missing
        : _isInsideAnyRoot(path, managedRoots)
        ? FileOutputStatus.available
        : FileOutputStatus.external;
    return FileOutputItem(
      id: MaterialLibraryStore.idForPath(path),
      path: path,
      name: _displayName(path),
      scope: record.scope,
      sourceLabel: _sourceLabelForHistory(record),
      toolName: record.toolName,
      timestamp: record.timestamp,
      exists: exists,
      isDirectory: isDirectory,
      sizeBytes: sizeBytes,
      status: status,
      hasHistory: true,
      inMaterialLibrary: libraryPaths.contains(path),
    );
  }

  Future<FileOutputItem> _itemFromEntity(
    FileSystemEntity entity, {
    required Set<String> libraryPaths,
    required AppPerformanceMode performanceMode,
  }) async {
    final path = p.normalize(entity.path);
    final type = await FileSystemEntity.type(path);
    final isDirectory = type == FileSystemEntityType.directory;
    return FileOutputItem(
      id: MaterialLibraryStore.idForPath(path),
      path: path,
      name: _displayName(path),
      scope: null,
      sourceLabel: _sourceLabelForScannedPath(path),
      toolName: '扫描发现',
      timestamp: await _modifiedAt(path),
      exists: true,
      isDirectory: isDirectory,
      sizeBytes: await _entitySize(
        path,
        isDirectory,
        performanceMode: performanceMode,
      ),
      status: FileOutputStatus.scanOnly,
      hasHistory: false,
      inMaterialLibrary: libraryPaths.contains(path),
    );
  }

  Future<List<FileSystemEntity>> _scanOutputEntities(
    List<Directory> roots,
  ) async {
    final entities = <FileSystemEntity>[];
    for (final root in roots) {
      if (!await root.exists()) continue;
      final children = root.listSync(recursive: false, followLinks: false);
      for (final child in children) {
        final name = p.basename(child.path);
        if (name.startsWith('.')) continue;
        entities.add(child);
      }
    }
    return entities;
  }

  Future<int> _entitySize(
    String path,
    bool isDirectory, {
    required AppPerformanceMode performanceMode,
  }) async {
    if (!isDirectory) {
      return File(path).length();
    }
    if (performanceMode == AppPerformanceMode.lowPower) {
      return 0;
    }
    var size = 0;
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    final yielder = CooperativeYield(batchSize: 24);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          size += await entity.length();
        } catch (_) {
          // Ignore files that disappear during scanning.
        }
      }
      await yielder.tick();
    }
    return size;
  }

  Future<DateTime> _modifiedAt(String path) async {
    try {
      return (await FileStat.stat(path)).modified;
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _displayName(String path) {
    final name = p.basename(path);
    return name.trim().isEmpty ? path : name;
  }

  bool _isInsideAnyRoot(String path, List<Directory> roots) {
    final normalized = p.normalize(path);
    for (final root in roots) {
      final rootPath = p.normalize(root.path);
      if (p.equals(normalized, rootPath) || p.isWithin(rootPath, normalized)) {
        return true;
      }
    }
    return false;
  }

  MaterialSourceType _sourceTypeForItem(FileOutputItem item) {
    final label = item.sourceLabel.toLowerCase();
    if (label.contains('openlist') || label.contains('云盘')) {
      return MaterialSourceType.openListDownload;
    }
    if (label.contains('离线包')) {
      return MaterialSourceType.offlinePackage;
    }
    return MaterialSourceType.fileToolOutput;
  }

  String _sourceLabelForHistory(FileToolHistoryRecord record) {
    return switch (record.scope) {
      FileToolHistoryScope.pdf => 'PDF 工具输出',
      FileToolHistoryScope.file => '文件工具输出',
    };
  }

  String _sourceLabelForScannedPath(String path) {
    final normalized = p.normalize(path).toLowerCase();
    if (normalized.contains('${p.separator}pdf_tools${p.separator}')) {
      return 'PDF 工具输出';
    }
    if (normalized.contains('${p.separator}file_tools${p.separator}')) {
      return '文件工具输出';
    }
    if (normalized.contains('${p.separator}ocr_texts${p.separator}')) {
      return 'OCR 文本输出';
    }
    if (normalized.contains('${p.separator}cloud_downloads${p.separator}')) {
      return 'OpenList 下载';
    }
    if (normalized.contains('${p.separator}offline_packages${p.separator}')) {
      return '离线包输出';
    }
    if (normalized.contains('${p.separator}exports${p.separator}')) {
      return '分享导出';
    }
    return '扫描发现';
  }
}
