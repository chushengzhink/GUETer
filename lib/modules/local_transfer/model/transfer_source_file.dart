import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'transfer_file_models.dart';

class TransferSourceFile {
  const TransferSourceFile({
    required this.fileName,
    required this.size,
    required this.fileType,
    required this.path,
    required this.bytes,
    required this.preview,
    this.lastModified,
    this.lastAccessed,
  });

  final String fileName;
  final int size;
  final String fileType;
  final String? path;
  final List<int>? bytes;
  final String? preview;
  final DateTime? lastModified;
  final DateTime? lastAccessed;

  bool get isInMemory => bytes != null;

  Future<TransferFileDescriptor> toDescriptor(String id) async {
    return TransferFileDescriptor(
      id: id,
      fileName: fileName,
      size: size,
      fileType: fileType,
      preview: preview,
      metadata: lastModified != null || lastAccessed != null
          ? TransferFileMetadataDto(
              lastModified: lastModified?.toUtc().toIso8601String(),
              lastAccessed: lastAccessed?.toUtc().toIso8601String(),
            )
          : null,
    );
  }

  static Future<TransferSourceFile> fromPlatformFile(PlatformFile file) async {
    final path = file.path;
    final stat = path != null ? await File(path).stat() : null;
    return TransferSourceFile(
      fileName: file.name,
      size: file.size,
      fileType: _inferMimeType(file.name),
      path: path,
      bytes: file.bytes,
      preview: null,
      lastModified: file.path != null ? stat?.modified : null,
      lastAccessed: file.path != null ? stat?.accessed : null,
    );
  }

  factory TransferSourceFile.text(
    String text, {
    String fileName = 'message.txt',
  }) {
    final bytes = utf8.encode(text);
    return TransferSourceFile(
      fileName: fileName,
      size: bytes.length,
      fileType: 'text/plain',
      path: null,
      bytes: bytes,
      preview: text,
      lastModified: DateTime.now(),
      lastAccessed: DateTime.now(),
    );
  }
}

String inferMimeTypeFromName(String fileName) => _inferMimeType(fileName);

String _inferMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.txt') ||
      lower.endsWith('.md') ||
      lower.endsWith('.json') ||
      lower.endsWith('.csv')) {
    return 'text/plain';
  }
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  return 'application/octet-stream';
}
