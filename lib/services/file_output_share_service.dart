import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'file_tool_service.dart';
import 'gueter_storage_service.dart';

class FileOutputShareService {
  FileOutputShareService({Future<Directory> Function()? exportDirectory})
    : _exportDirectory =
          exportDirectory ??
          (() => GueterStorageService.instance.publicDirectory(
            GueterPublicDirectory.exports,
          ));

  final Future<Directory> Function() _exportDirectory;

  Future<String> shareOutput(String path, {String? text}) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.notFound) {
      throw const FileToolException('输出文件已不存在。');
    }
    if (type == FileSystemEntityType.file) {
      await Share.shareXFiles([XFile(path)], text: text);
      return path;
    }
    if (type == FileSystemEntityType.directory) {
      final zip = await zipDirectoryForShare(Directory(path));
      await Share.shareXFiles([XFile(zip.path)], text: text);
      return zip.path;
    }
    throw const FileToolException('此类型的输出暂不支持分享。');
  }

  Future<File> zipDirectoryForShare(Directory directory) async {
    if (!await directory.exists()) {
      throw const FileToolException('输出文件夹已不存在。');
    }

    final exportDir = await _exportDirectory();
    final shareDir = Directory(p.join(exportDir.path, 'shared_outputs'));
    if (!shareDir.existsSync()) {
      shareDir.createSync(recursive: true);
    }

    final stem = p.basename(directory.path).trim().isEmpty
        ? 'shared_output'
        : p.basename(directory.path).trim();
    final target = File(
      p.join(
        shareDir.path,
        '${stem}_${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );

    final archive = Archive();
    await _addDirectory(archive, directory, stem);
    final bytes = ZipEncoder().encode(archive, level: 6);
    await target.writeAsBytes(bytes, flush: true);
    return target;
  }

  Future<void> _addDirectory(
    Archive archive,
    Directory directory,
    String rootPath,
  ) async {
    final entries = directory.listSync(recursive: false, followLinks: false);
    if (entries.isEmpty) {
      archive.addFile(ArchiveFile('$rootPath/', 0, <int>[]));
      return;
    }
    for (final entry in entries) {
      final name = p.basename(entry.path);
      final childPath = p.join(rootPath, name).replaceAll('\\', '/');
      if (entry is File) {
        final bytes = await entry.readAsBytes();
        archive.addFile(ArchiveFile(childPath, bytes.length, bytes));
      } else if (entry is Directory) {
        await _addDirectory(archive, entry, childPath);
      }
    }
  }
}
