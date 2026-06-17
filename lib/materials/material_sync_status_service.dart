import 'dart:io';

import '../features/openlist/openlist_offline_package.dart';
import '../features/openlist/openlist_repository.dart';
import '../services/duplicate_file_scanner.dart';
import '../services/file_tool_service.dart';
import 'material_index_models.dart';
import 'material_index_service.dart';

class MaterialDirectoryStatus {
  const MaterialDirectoryStatus({
    required this.label,
    required this.path,
    required this.fileCount,
    required this.totalBytes,
    required this.exists,
  });

  final String label;
  final String path;
  final int fileCount;
  final int totalBytes;
  final bool exists;
}

class MaterialSyncStatusSnapshot {
  const MaterialSyncStatusSnapshot({
    required this.downloads,
    required this.offlineRoot,
    required this.fileToolOutput,
    required this.offlinePackageCount,
    required this.offlineFileCount,
    required this.offlineMissingCount,
    required this.offlineChangedCount,
    required this.indexSummary,
    required this.duplicateGroupCount,
    required this.duplicateBytes,
    required this.generatedAt,
  });

  final MaterialDirectoryStatus downloads;
  final MaterialDirectoryStatus offlineRoot;
  final MaterialDirectoryStatus fileToolOutput;
  final int offlinePackageCount;
  final int offlineFileCount;
  final int offlineMissingCount;
  final int offlineChangedCount;
  final MaterialIndexSummary indexSummary;
  final int duplicateGroupCount;
  final int duplicateBytes;
  final DateTime generatedAt;

  bool get hasOfflineIssues =>
      offlineMissingCount > 0 || offlineChangedCount > 0;
  bool get hasIndexIssues => indexSummary.failed > 0;
  bool get hasDuplicates => duplicateGroupCount > 0;
}

class MaterialSyncStatusService {
  MaterialSyncStatusService({
    OpenListOfflinePackageService? offlineService,
    MaterialIndexService? indexService,
    DuplicateFileScanner? duplicateScanner,
    FileToolService? fileToolService,
    Future<String> Function()? downloadPathLoader,
    Future<Directory> Function()? offlineRootLoader,
  }) : _offlineService = offlineService ?? OpenListOfflinePackageService(),
       _indexService = indexService ?? MaterialIndexService(),
       _duplicateScanner = duplicateScanner ?? const DuplicateFileScanner(),
       _fileToolService = fileToolService ?? FileToolService(),
       _downloadPathLoader =
           downloadPathLoader ?? OpenListRepository.downloadDirectoryPath,
       _offlineRootLoader =
           offlineRootLoader ??
           OpenListOfflinePackageService.ensureOfflineRootDirectory;

  final OpenListOfflinePackageService _offlineService;
  final MaterialIndexService _indexService;
  final DuplicateFileScanner _duplicateScanner;
  final FileToolService _fileToolService;
  final Future<String> Function() _downloadPathLoader;
  final Future<Directory> Function() _offlineRootLoader;

  Future<MaterialSyncStatusSnapshot> loadSnapshot({
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('正在读取本地目录...');
    final downloadPath = await _downloadPathLoader();
    final offlineRoot = await _offlineRootLoader();
    final fileToolDir = await _fileToolService.ensureOutputDirectory();

    final packages = await _offlineService.loadPackages();
    final offlineFiles = packages.expand((package) => package.files).toList();
    final missingCount = offlineFiles.where((file) => file.missing).length;
    final changedCount = offlineFiles.where((file) => file.changed).length;

    onProgress?.call('正在读取索引...');
    final summary = await _indexService.summary();

    onProgress?.call('正在扫描重复文件...');
    final duplicateGroups = await _duplicateScanner.scan(
      duplicateRoots(
        downloadPath: downloadPath,
        offlineRootPath: offlineRoot.path,
        fileToolOutputPath: fileToolDir.path,
      ),
      onProgress: onProgress,
    );

    return MaterialSyncStatusSnapshot(
      downloads: await _directoryStatus('云盘下载', downloadPath),
      offlineRoot: await _directoryStatus('云盘离线包', offlineRoot.path),
      fileToolOutput: await _directoryStatus('文件工具输出', fileToolDir.path),
      offlinePackageCount: packages.length,
      offlineFileCount: offlineFiles.length,
      offlineMissingCount: missingCount,
      offlineChangedCount: changedCount,
      indexSummary: summary,
      duplicateGroupCount: duplicateGroups.length,
      duplicateBytes: duplicateGroups.fold<int>(
        0,
        (sum, group) => sum + group.duplicateBytes,
      ),
      generatedAt: DateTime.now(),
    );
  }

  Future<void> checkOfflinePackages({
    void Function(String message)? onProgress,
  }) async {
    final packages = await _offlineService.loadPackages();
    for (var i = 0; i < packages.length; i++) {
      onProgress?.call('正在校验离线包 ${i + 1}/${packages.length}');
      await _offlineService.checkPackage(packages[i]);
    }
  }

  static List<DuplicateScanRoot> duplicateRoots({
    required String downloadPath,
    required String offlineRootPath,
    required String fileToolOutputPath,
  }) {
    return <DuplicateScanRoot>[
      DuplicateScanRoot(label: '云盘下载', path: downloadPath),
      DuplicateScanRoot(label: '云盘离线包', path: offlineRootPath),
      DuplicateScanRoot(label: '文件工具输出', path: fileToolOutputPath),
    ];
  }

  Future<List<DuplicateScanRoot>> defaultDuplicateRoots() async {
    final downloadPath = await _downloadPathLoader();
    final offlineRoot = await _offlineRootLoader();
    final fileToolDir = await _fileToolService.ensureOutputDirectory();
    return duplicateRoots(
      downloadPath: downloadPath,
      offlineRootPath: offlineRoot.path,
      fileToolOutputPath: fileToolDir.path,
    );
  }

  Future<MaterialDirectoryStatus> _directoryStatus(
    String label,
    String path,
  ) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return MaterialDirectoryStatus(
        label: label,
        path: path,
        fileCount: 0,
        totalBytes: 0,
        exists: false,
      );
    }
    var count = 0;
    var bytes = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        count++;
        bytes += await entity.length();
      } catch (_) {
        // Files can disappear while scanning; ignore them for a best-effort panel.
      }
    }
    return MaterialDirectoryStatus(
      label: label,
      path: path,
      fileCount: count,
      totalBytes: bytes,
      exists: true,
    );
  }
}
