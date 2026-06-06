import 'package:path/path.dart' as p;

import 'plugin_manifest.dart';

class PluginActionContext {
  const PluginActionContext({
    this.type,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.isDirectory,
    this.text,
    this.healthIssueId,
    this.values = const <String, Object?>{},
  });

  final PluginContextType? type;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final bool? isDirectory;
  final String? text;
  final String? healthIssueId;
  final Map<String, Object?> values;

  String get resolvedFileName {
    final explicit = fileName;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit.trim();
    }
    final path = filePath;
    if (path == null || path.isEmpty) return '';
    return p.basename(path);
  }

  String get fileExtension {
    final name = resolvedFileName;
    if (name.isEmpty) return '';
    return p.extension(name).toLowerCase();
  }

  PluginActionContext copyWithFile(String path, {String? name, int? size}) {
    return PluginActionContext(
      type: type ?? PluginContextType.file,
      filePath: path,
      fileName: name ?? fileName,
      fileSize: size ?? fileSize,
      isDirectory: isDirectory,
      text: text,
      healthIssueId: healthIssueId,
      values: values,
    );
  }
}
