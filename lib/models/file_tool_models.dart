import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class SelectedFileItem {
  const SelectedFileItem({
    required this.path,
    required this.name,
    required this.fileExtension,
    required this.sizeBytes,
    required this.isDirectory,
  });

  final String path;
  final String name;
  final String fileExtension;
  final int sizeBytes;
  final bool isDirectory;

  String get displayExtension => fileExtension.isEmpty ? '-' : fileExtension;

  static Future<SelectedFileItem> fromEntity(FileSystemEntity entity) async {
    final path = entity.path;
    final isDirectory = entity is Directory;
    final name = p.basename(path);
    final fileExtension = isDirectory ? '' : p.extension(path);
    final sizeBytes = isDirectory ? 0 : await File(path).length();
    return SelectedFileItem(
      path: path,
      name: name,
      fileExtension: fileExtension,
      sizeBytes: sizeBytes,
      isDirectory: isDirectory,
    );
  }
}

class RenamePreview {
  const RenamePreview({
    required this.baseName,
    required this.normalizedExtension,
  });

  final String baseName;
  final String normalizedExtension;

  String get fullName =>
      normalizedExtension.isEmpty ? baseName : '$baseName$normalizedExtension';
}

class FileToolTaskRecord {
  const FileToolTaskRecord({
    required this.toolName,
    required this.inputSummary,
    required this.outputPath,
    required this.timestamp,
    required this.success,
    required this.message,
  });

  final String toolName;
  final String inputSummary;
  final String outputPath;
  final DateTime timestamp;
  final bool success;
  final String message;
}

enum FileToolHistoryScope {
  pdf,
  file;

  static FileToolHistoryScope fromStorage(String value) {
    return FileToolHistoryScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => FileToolHistoryScope.file,
    );
  }
}

class FileToolHistoryRecord {
  const FileToolHistoryRecord({
    required this.scope,
    required this.toolName,
    required this.inputSummary,
    required this.outputPath,
    required this.timestamp,
    required this.success,
    required this.message,
  });

  final FileToolHistoryScope scope;
  final String toolName;
  final String inputSummary;
  final String outputPath;
  final DateTime timestamp;
  final bool success;
  final String message;

  FileToolTaskRecord toTaskRecord() {
    return FileToolTaskRecord(
      toolName: toolName,
      inputSummary: inputSummary,
      outputPath: outputPath,
      timestamp: timestamp,
      success: success,
      message: message,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'scope': scope.name,
      'toolName': toolName,
      'inputSummary': inputSummary,
      'outputPath': outputPath,
      'timestamp': timestamp.toIso8601String(),
      'success': success,
      'message': message,
    };
  }

  String encode() => jsonEncode(toJson());

  static FileToolHistoryRecord? decode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final map = decoded.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      final timestamp = DateTime.tryParse(map['timestamp']?.toString() ?? '');
      if (timestamp == null) return null;
      return FileToolHistoryRecord(
        scope: FileToolHistoryScope.fromStorage(
          map['scope']?.toString() ?? FileToolHistoryScope.file.name,
        ),
        toolName: map['toolName']?.toString() ?? '',
        inputSummary: map['inputSummary']?.toString() ?? '',
        outputPath: map['outputPath']?.toString() ?? '',
        timestamp: timestamp,
        success: map['success'] == true,
        message: map['message']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

class ZipEntryPreview {
  const ZipEntryPreview({
    required this.path,
    required this.sizeBytes,
    required this.isDirectory,
    required this.isSafe,
  });

  final String path;
  final int sizeBytes;
  final bool isDirectory;
  final bool isSafe;

  String get name => p.basename(path);
}

class ZipPreview {
  const ZipPreview({
    required this.entries,
    required this.fileCount,
    required this.directoryCount,
    required this.totalSizeBytes,
    required this.skippedUnsafeCount,
  });

  final List<ZipEntryPreview> entries;
  final int fileCount;
  final int directoryCount;
  final int totalSizeBytes;
  final int skippedUnsafeCount;

  bool get hasUnsafeEntries => skippedUnsafeCount > 0;
}

class ZipCreateOptions {
  const ZipCreateOptions({this.preferredName, this.compressionLevel = 6});

  final String? preferredName;
  final int compressionLevel;
}

class LightweightPdfConversionResult {
  const LightweightPdfConversionResult({
    required this.outputPaths,
    required this.message,
  });

  final List<String> outputPaths;
  final String message;

  String get primaryOutputPath => outputPaths.length == 1
      ? outputPaths.first
      : p.dirname(outputPaths.first);
}
