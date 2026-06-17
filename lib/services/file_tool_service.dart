import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../core/performance/app_performance.dart';
import '../models/file_tool_models.dart';
import 'gueter_storage_service.dart';

class FileToolService {
  FileToolService({BackgroundTaskRunner? backgroundTaskRunner})
    : _backgroundTaskRunner =
          backgroundTaskRunner ?? const BackgroundTaskRunner();

  static final RegExp _invalidNamePattern = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
  final BackgroundTaskRunner _backgroundTaskRunner;

  Future<Directory> ensureOutputDirectory({String? customOutputPath}) async {
    return GueterStorageService.instance.publicDirectory(
      GueterPublicDirectory.fileTools,
      customPath: customOutputPath,
    );
  }

  Future<Directory> extractZip({
    required File zipFile,
    required Directory outputDirectory,
    Set<String>? selectedEntryPaths,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
    CancellationToken? cancellationToken,
  }) async {
    if (p.extension(zipFile.path).toLowerCase() != '.zip') {
      throw const FileToolException('Selected file is not a ZIP archive.');
    }

    final archive = await _readZip(zipFile);
    final yielder = CooperativeYield(
      batchSize: performanceMode == AppPerformanceMode.lowPower ? 8 : 32,
    );

    final rootName = p.basenameWithoutExtension(zipFile.path).trim().isEmpty
        ? 'unzipped'
        : p.basenameWithoutExtension(zipFile.path).trim();
    final extractRootPath = await _resolveUniquePath(
      p.join(outputDirectory.path, rootName),
      isDirectory: true,
    );
    final extractRoot = Directory(extractRootPath);
    await extractRoot.create(recursive: true);

    for (final entry in archive) {
      cancellationToken?.throwIfCancelled();
      final relativePath = _sanitizeArchiveEntryPath(entry.name);
      if (relativePath == null) {
        continue;
      }
      if (selectedEntryPaths != null &&
          !_entryMatchesSelection(relativePath, selectedEntryPaths)) {
        continue;
      }

      await _extractEntry(entry, extractRoot, relativePath);
      await yielder.tick();
    }

    return extractRoot;
  }

  Future<ZipPreview> previewZip({
    required File zipFile,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final archive = await _readZip(zipFile);
    final entries = <ZipEntryPreview>[];
    var fileCount = 0;
    var directoryCount = 0;
    var totalSizeBytes = 0;
    var skippedUnsafeCount = 0;

    for (final entry in archive) {
      final safePath = _sanitizeArchiveEntryPath(entry.name);
      final isSafe = safePath != null;
      if (!isSafe) {
        skippedUnsafeCount += 1;
      }
      if (entry.isFile) {
        fileCount += 1;
        totalSizeBytes += entry.size;
      } else {
        directoryCount += 1;
      }
      entries.add(
        ZipEntryPreview(
          path: safePath ?? entry.name,
          sizeBytes: entry.isFile ? entry.size : 0,
          isDirectory: !entry.isFile,
          isSafe: isSafe,
        ),
      );
    }

    entries.sort(
      (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
    );
    return ZipPreview(
      entries: entries,
      fileCount: fileCount,
      directoryCount: directoryCount,
      totalSizeBytes: totalSizeBytes,
      skippedUnsafeCount: skippedUnsafeCount,
    );
  }

  Future<File> createZip({
    required List<FileSystemEntity> sources,
    required Directory outputDirectory,
    String? preferredName,
    int compressionLevel = 6,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
    CancellationToken? cancellationToken,
  }) async {
    if (sources.isEmpty) {
      throw const FileToolException('Choose at least one file or folder.');
    }

    final archive = Archive();
    final yielder = CooperativeYield(
      batchSize: performanceMode == AppPerformanceMode.lowPower ? 4 : 16,
    );
    for (final source in sources) {
      cancellationToken?.throwIfCancelled();
      if (source is File) {
        await _addFileToArchive(archive, source, p.basename(source.path));
      } else if (source is Directory) {
        await _addDirectoryToArchive(
          archive,
          source,
          p.basename(source.path),
          yielder,
          cancellationToken,
        );
      }
      await yielder.tick();
    }

    final desiredStem = _buildArchiveStem(sources, preferredName);
    validateBaseName(desiredStem);

    final level = _normalizeCompressionLevel(compressionLevel);
    final encoded = await _backgroundTaskRunner.run(
      () => ZipEncoder().encode(archive, level: level),
    );
    final outputPath = await _resolveUniquePath(
      p.join(outputDirectory.path, '$desiredStem.zip'),
      isDirectory: false,
    );
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  Future<File> renameFile({
    required File source,
    required String baseName,
    required String extension,
  }) async {
    final preview = buildRenamePreview(baseName, extension);
    validateBaseName(preview.baseName);
    validateExtension(preview.normalizedExtension);

    final targetPath = p.join(p.dirname(source.path), preview.fullName);
    if (p.equals(targetPath, source.path)) {
      return source;
    }
    if (await File(targetPath).exists()) {
      throw const FileToolConflictException(
        'Target file already exists. Choose another name.',
      );
    }
    return source.rename(targetPath);
  }

  RenamePreview buildRenamePreview(String baseName, String extension) {
    final trimmedBase = baseName.trim();
    final trimmedExtension = extension.trim();
    final normalizedExtension = trimmedExtension.isEmpty
        ? ''
        : (trimmedExtension.startsWith('.')
              ? trimmedExtension
              : '.$trimmedExtension');
    return RenamePreview(
      baseName: trimmedBase,
      normalizedExtension: normalizedExtension,
    );
  }

  void validateBaseName(String value) {
    if (value.trim().isEmpty) {
      throw const FileToolValidationException('File name cannot be empty.');
    }
    if (_invalidNamePattern.hasMatch(value)) {
      throw const FileToolValidationException(
        'File name contains invalid characters.',
      );
    }
  }

  void validateExtension(String value) {
    if (value.isEmpty) {
      return;
    }
    final normalized = value.startsWith('.') ? value.substring(1) : value;
    if (normalized.isEmpty) {
      throw const FileToolValidationException('Extension format is invalid.');
    }
    if (_invalidNamePattern.hasMatch(normalized)) {
      throw const FileToolValidationException(
        'Extension contains invalid characters.',
      );
    }
  }

  Future<Archive> _readZip(File zipFile) async {
    if (p.extension(zipFile.path).toLowerCase() != '.zip') {
      throw const FileToolException('Selected file is not a ZIP archive.');
    }

    final bytes = await zipFile.readAsBytes();
    try {
      return _backgroundTaskRunner.run(
        () => ZipDecoder().decodeBytes(bytes, verify: true),
      );
    } catch (_) {
      throw const FileToolException(
        'ZIP extraction failed. The archive may be corrupted.',
      );
    }
  }

  Future<void> _extractEntry(
    ArchiveFile entry,
    Directory extractRoot,
    String relativePath,
  ) async {
    final targetPath = p.join(extractRoot.path, relativePath);
    if (entry.isFile) {
      final uniqueTargetPath = await _resolveUniquePath(
        targetPath,
        isDirectory: false,
      );
      final outFile = File(uniqueTargetPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>, flush: true);
    } else {
      await Directory(targetPath).create(recursive: true);
    }
  }

  Future<void> _addDirectoryToArchive(
    Archive archive,
    Directory directory,
    String rootPath,
    CooperativeYield yielder,
    CancellationToken? cancellationToken,
  ) async {
    final entries = <FileSystemEntity>[];
    await for (final entry in directory.list(
      recursive: false,
      followLinks: false,
    )) {
      cancellationToken?.throwIfCancelled();
      entries.add(entry);
      await yielder.tick();
    }
    if (entries.isEmpty) {
      archive.addFile(ArchiveFile('$rootPath/', 0, <int>[]));
      return;
    }

    for (final entry in entries) {
      final name = p.basename(entry.path);
      final childPath = p.join(rootPath, name);
      if (entry is File) {
        await _addFileToArchive(archive, entry, childPath);
      } else if (entry is Directory) {
        await _addDirectoryToArchive(
          archive,
          entry,
          childPath,
          yielder,
          cancellationToken,
        );
      }
      await yielder.tick();
    }
  }

  Future<void> _addFileToArchive(
    Archive archive,
    File file,
    String archivePath,
  ) async {
    final bytes = await file.readAsBytes();
    final normalizedPath = archivePath.replaceAll('\\', '/');
    archive.addFile(ArchiveFile(normalizedPath, bytes.length, bytes));
  }

  String _buildArchiveStem(
    List<FileSystemEntity> sources,
    String? preferredName,
  ) {
    if (preferredName != null && preferredName.trim().isNotEmpty) {
      return preferredName.trim();
    }
    if (sources.length == 1) {
      return p.basenameWithoutExtension(sources.first.path);
    }
    return 'archive_${DateTime.now().millisecondsSinceEpoch}';
  }

  bool _entryMatchesSelection(String relativePath, Set<String> selectedPaths) {
    final normalized = relativePath.replaceAll('\\', '/');
    for (final selected in selectedPaths) {
      final selectedNormalized = selected.replaceAll('\\', '/');
      if (normalized == selectedNormalized ||
          normalized.startsWith('$selectedNormalized/')) {
        return true;
      }
    }
    return false;
  }

  int _normalizeCompressionLevel(int level) {
    if (level <= 0) return 0;
    if (level <= 3) return 3;
    if (level <= 6) return 6;
    return 9;
  }

  String? _sanitizeArchiveEntryPath(String rawPath) {
    final normalized = rawPath.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) {
      return null;
    }
    final parts = normalized
        .split('/')
        .where((part) => part.isNotEmpty && part != '.')
        .toList();
    if (parts.isEmpty || parts.any((part) => part == '..')) {
      return null;
    }
    return p.joinAll(parts);
  }

  Future<String> _resolveUniquePath(
    String targetPath, {
    required bool isDirectory,
  }) async {
    final extension = isDirectory ? '' : p.extension(targetPath);
    final stem = isDirectory
        ? p.basename(targetPath)
        : p.basenameWithoutExtension(targetPath);
    final parent = p.dirname(targetPath);
    var candidatePath = targetPath;
    var counter = 1;

    while (await FileSystemEntity.type(candidatePath) !=
        FileSystemEntityType.notFound) {
      final suffix = ' ($counter)';
      final name = isDirectory ? '$stem$suffix' : '$stem$suffix$extension';
      candidatePath = p.join(parent, name);
      counter += 1;
    }
    return candidatePath;
  }
}

class FileToolException implements Exception {
  const FileToolException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FileToolValidationException extends FileToolException {
  const FileToolValidationException(super.message);
}

class FileToolConflictException extends FileToolException {
  const FileToolConflictException(super.message);
}
