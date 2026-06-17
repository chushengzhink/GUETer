import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../core/performance/app_performance.dart';

class DuplicateScanRoot {
  const DuplicateScanRoot({required this.label, required this.path});

  final String label;
  final String path;
}

class DuplicateFileEntry {
  const DuplicateFileEntry({
    required this.path,
    required this.name,
    required this.sourceLabel,
    required this.sizeBytes,
    required this.modified,
    required this.sha256,
  });

  final String path;
  final String name;
  final String sourceLabel;
  final int sizeBytes;
  final DateTime modified;
  final String sha256;
}

class DuplicateFileGroup {
  const DuplicateFileGroup({required this.sha256, required this.files});

  final String sha256;
  final List<DuplicateFileEntry> files;

  int get sizeBytes => files.isEmpty ? 0 : files.first.sizeBytes;
  int get duplicateBytes => sizeBytes * (files.length - 1);
}

class DuplicateDeleteResult {
  const DuplicateDeleteResult({
    required this.deletedCount,
    required this.freedBytes,
    required this.failedPaths,
  });

  final int deletedCount;
  final int freedBytes;
  final List<String> failedPaths;
}

class DuplicateFileScanner {
  const DuplicateFileScanner();

  Future<List<DuplicateFileGroup>> scan(
    List<DuplicateScanRoot> roots, {
    void Function(String message)? onProgress,
    CancellationToken? cancellationToken,
    AppPerformanceMode performanceMode = AppPerformanceMode.balanced,
  }) async {
    final candidatesBySize = <int, List<_CandidateFile>>{};
    final yielder = CooperativeYield(
      batchSize: performanceMode == AppPerformanceMode.lowPower ? 8 : 32,
    );
    for (final root in roots) {
      final dir = Directory(root.path);
      if (!await dir.exists()) {
        continue;
      }
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }
        cancellationToken?.throwIfCancelled();
        try {
          final stat = await entity.stat();
          if (stat.size <= 0) {
            continue;
          }
          candidatesBySize
              .putIfAbsent(stat.size, () => <_CandidateFile>[])
              .add(
                _CandidateFile(
                  path: entity.path,
                  sourceLabel: root.label,
                  sizeBytes: stat.size,
                  modified: stat.modified,
                ),
              );
        } catch (_) {
          // Ignore files that disappear during scanning.
        }
        await yielder.tick();
      }
    }

    final groupsByHash = <String, List<DuplicateFileEntry>>{};
    for (final entry in candidatesBySize.entries.where(
      (entry) => entry.value.length > 1,
    )) {
      for (final candidate in entry.value) {
        cancellationToken?.throwIfCancelled();
        onProgress?.call('正在校验 ${p.basename(candidate.path)}');
        try {
          final hash = await _sha256File(candidate.path);
          groupsByHash
              .putIfAbsent(hash, () => <DuplicateFileEntry>[])
              .add(
                DuplicateFileEntry(
                  path: candidate.path,
                  name: p.basename(candidate.path),
                  sourceLabel: candidate.sourceLabel,
                  sizeBytes: candidate.sizeBytes,
                  modified: candidate.modified,
                  sha256: hash,
                ),
              );
        } catch (_) {
          // Ignore unreadable files.
        }
        await yielder.tick();
      }
    }

    final groups =
        groupsByHash.entries.where((entry) => entry.value.length > 1).map((
            entry,
          ) {
            final files = List<DuplicateFileEntry>.from(entry.value)
              ..sort((a, b) => b.modified.compareTo(a.modified));
            return DuplicateFileGroup(sha256: entry.key, files: files);
          }).toList()
          ..sort((a, b) => b.duplicateBytes.compareTo(a.duplicateBytes));
    return groups;
  }

  Future<DuplicateDeleteResult> deleteFiles(Iterable<String> paths) async {
    var deletedCount = 0;
    var freedBytes = 0;
    final failed = <String>[];
    for (final path in paths.toSet()) {
      try {
        final file = File(path);
        if (!await file.exists()) {
          continue;
        }
        final size = await file.length();
        await file.delete();
        deletedCount++;
        freedBytes += size;
      } catch (_) {
        failed.add(path);
      }
    }
    return DuplicateDeleteResult(
      deletedCount: deletedCount,
      freedBytes: freedBytes,
      failedPaths: failed,
    );
  }

  Future<String> _sha256File(String path) async {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  static String shortHash(String hash) {
    return hash.length <= 12 ? hash : hash.substring(0, 12);
  }
}

class _CandidateFile {
  const _CandidateFile({
    required this.path,
    required this.sourceLabel,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;
  final String sourceLabel;
  final int sizeBytes;
  final DateTime modified;
}

String duplicateFormatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
