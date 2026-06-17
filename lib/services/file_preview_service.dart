import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

enum FilePreviewKind { pdf, image, text, markdown, json, csv, zip, unsupported }

class FilePreviewDescriptor {
  const FilePreviewDescriptor({
    required this.path,
    required this.name,
    required this.extension,
    required this.kind,
    required this.sizeBytes,
    required this.canPreview,
    required this.reason,
  });

  final String path;
  final String name;
  final String extension;
  final FilePreviewKind kind;
  final int sizeBytes;
  final bool canPreview;
  final String reason;
}

class FilePreviewService {
  const FilePreviewService();

  static const int maxInlineTextBytes = 1024 * 1024;

  Future<FilePreviewDescriptor> describe(String path) async {
    final file = File(path);
    final stat = await file.stat();
    final extension = p.extension(path).toLowerCase();
    final kind = kindForPath(path);
    final canPreview = switch (kind) {
      FilePreviewKind.unsupported => false,
      FilePreviewKind.text ||
      FilePreviewKind.markdown ||
      FilePreviewKind.json ||
      FilePreviewKind.csv => stat.size <= maxInlineTextBytes,
      _ => true,
    };
    final reason = canPreview
        ? ''
        : kind == FilePreviewKind.unsupported
        ? '此文件类型暂不支持内置预览。'
        : '文本文件超过 1 MB，建议使用外部应用打开。';
    return FilePreviewDescriptor(
      path: path,
      name: p.basename(path),
      extension: extension,
      kind: kind,
      sizeBytes: stat.size,
      canPreview: canPreview,
      reason: reason,
    );
  }

  FilePreviewKind kindForPath(String path) {
    final extension = p.extension(path).toLowerCase();
    if (extension == '.pdf') return FilePreviewKind.pdf;
    if (const <String>{
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
    }.contains(extension)) {
      return FilePreviewKind.image;
    }
    if (extension == '.md' || extension == '.markdown') {
      return FilePreviewKind.markdown;
    }
    if (extension == '.json') return FilePreviewKind.json;
    if (extension == '.csv') return FilePreviewKind.csv;
    if (extension == '.zip') return FilePreviewKind.zip;
    if (const <String>{
      '.txt',
      '.log',
      '.xml',
      '.html',
      '.htm',
    }.contains(extension)) {
      return FilePreviewKind.text;
    }
    return FilePreviewKind.unsupported;
  }

  Future<String> readTextPreview(String path, FilePreviewKind kind) async {
    final bytes = await File(path).readAsBytes();
    var text = utf8.decode(bytes, allowMalformed: true);
    if (kind == FilePreviewKind.json) {
      try {
        text = const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
      } catch (_) {
        // Keep original malformed JSON visible for troubleshooting.
      }
    }
    return text;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
