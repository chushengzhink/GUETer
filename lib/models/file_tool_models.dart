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
