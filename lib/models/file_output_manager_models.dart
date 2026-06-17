import 'package:path/path.dart' as p;

import 'file_tool_models.dart';

enum FileOutputStatus {
  available,
  missing,
  external,
  scanOnly;

  String get labelZh {
    return switch (this) {
      FileOutputStatus.available => '可用',
      FileOutputStatus.missing => '缺失',
      FileOutputStatus.external => '外部路径',
      FileOutputStatus.scanOnly => '扫描发现',
    };
  }

  String get labelEn {
    return switch (this) {
      FileOutputStatus.available => 'Available',
      FileOutputStatus.missing => 'Missing',
      FileOutputStatus.external => 'External',
      FileOutputStatus.scanOnly => 'Scanned',
    };
  }
}

class FileOutputItem {
  const FileOutputItem({
    required this.id,
    required this.path,
    required this.name,
    required this.scope,
    required this.sourceLabel,
    required this.toolName,
    required this.timestamp,
    required this.exists,
    required this.isDirectory,
    required this.sizeBytes,
    required this.status,
    this.hasHistory = false,
    this.inMaterialLibrary = false,
  });

  final String id;
  final String path;
  final String name;
  final FileToolHistoryScope? scope;
  final String sourceLabel;
  final String toolName;
  final DateTime timestamp;
  final bool exists;
  final bool isDirectory;
  final int sizeBytes;
  final FileOutputStatus status;
  final bool hasHistory;
  final bool inMaterialLibrary;

  bool get canPreview => exists && !isDirectory;
  bool get canShare => exists;
  bool get canDelete => exists;
  bool get canHideHistory => hasHistory;

  String get normalizedPath => p.normalize(path);

  FileOutputItem copyWith({
    String? id,
    String? path,
    String? name,
    FileToolHistoryScope? scope,
    String? sourceLabel,
    String? toolName,
    DateTime? timestamp,
    bool? exists,
    bool? isDirectory,
    int? sizeBytes,
    FileOutputStatus? status,
    bool? hasHistory,
    bool? inMaterialLibrary,
  }) {
    return FileOutputItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      scope: scope ?? this.scope,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      toolName: toolName ?? this.toolName,
      timestamp: timestamp ?? this.timestamp,
      exists: exists ?? this.exists,
      isDirectory: isDirectory ?? this.isDirectory,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
      hasHistory: hasHistory ?? this.hasHistory,
      inMaterialLibrary: inMaterialLibrary ?? this.inMaterialLibrary,
    );
  }
}

class FileOutputManagerSummary {
  const FileOutputManagerSummary({
    required this.totalCount,
    required this.availableCount,
    required this.missingCount,
    required this.externalCount,
    required this.scanOnlyCount,
    required this.inMaterialLibraryCount,
    required this.duplicateCandidateCount,
    required this.totalSizeBytes,
    this.updatedAt,
  });

  final int totalCount;
  final int availableCount;
  final int missingCount;
  final int externalCount;
  final int scanOnlyCount;
  final int inMaterialLibraryCount;
  final int duplicateCandidateCount;
  final int totalSizeBytes;
  final DateTime? updatedAt;

  static FileOutputManagerSummary fromItems(List<FileOutputItem> items) {
    DateTime? updatedAt;
    var availableCount = 0;
    var missingCount = 0;
    var externalCount = 0;
    var scanOnlyCount = 0;
    var inMaterialLibraryCount = 0;
    var totalSizeBytes = 0;
    final duplicateKeys = <String, int>{};
    for (final item in items) {
      if (item.exists) {
        availableCount++;
        totalSizeBytes += item.sizeBytes;
      }
      if (item.status == FileOutputStatus.missing) {
        missingCount++;
      }
      if (item.status == FileOutputStatus.external) {
        externalCount++;
      }
      if (item.status == FileOutputStatus.scanOnly) {
        scanOnlyCount++;
      }
      if (item.inMaterialLibrary) {
        inMaterialLibraryCount++;
      }
      if (item.exists && !item.isDirectory) {
        final key = '${item.name.toLowerCase()}::${item.sizeBytes}';
        duplicateKeys[key] = (duplicateKeys[key] ?? 0) + 1;
      }
      if (updatedAt == null || item.timestamp.isAfter(updatedAt)) {
        updatedAt = item.timestamp;
      }
    }
    final duplicateCandidateCount = duplicateKeys.values
        .where((count) => count > 1)
        .fold<int>(0, (sum, count) => sum + count);
    return FileOutputManagerSummary(
      totalCount: items.length,
      availableCount: availableCount,
      missingCount: missingCount,
      externalCount: externalCount,
      scanOnlyCount: scanOnlyCount,
      inMaterialLibraryCount: inMaterialLibraryCount,
      duplicateCandidateCount: duplicateCandidateCount,
      totalSizeBytes: totalSizeBytes,
      updatedAt: updatedAt,
    );
  }
}
