import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';
import '../../services/gueter_storage_service.dart';
import 'openlist_models.dart';
import 'openlist_repository.dart';

class OpenListOfflineFile {
  const OpenListOfflineFile({
    required this.name,
    required this.remotePath,
    required this.localPath,
    required this.size,
    required this.modified,
    this.missing = false,
    this.changed = false,
  });

  final String name;
  final String remotePath;
  final String localPath;
  final int size;
  final DateTime? modified;
  final bool missing;
  final bool changed;

  OpenListOfflineFile copyWith({bool? missing, bool? changed}) {
    return OpenListOfflineFile(
      name: name,
      remotePath: remotePath,
      localPath: localPath,
      size: size,
      modified: modified,
      missing: missing ?? this.missing,
      changed: changed ?? this.changed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'remotePath': remotePath,
      'localPath': localPath,
      'size': size,
      'modified': modified?.toUtc().toIso8601String(),
      'missing': missing,
      'changed': changed,
    };
  }

  factory OpenListOfflineFile.fromJson(Map<String, dynamic> json) {
    return OpenListOfflineFile(
      name: json['name']?.toString() ?? '',
      remotePath: json['remotePath']?.toString() ?? '',
      localPath: json['localPath']?.toString() ?? '',
      size: _intValue(json['size']),
      modified: DateTime.tryParse(json['modified']?.toString() ?? ''),
      missing: json['missing'] == true,
      changed: json['changed'] == true,
    );
  }
}

class OpenListOfflinePackage {
  const OpenListOfflinePackage({
    required this.id,
    required this.name,
    required this.remotePath,
    required this.localPath,
    required this.fileCount,
    required this.totalSize,
    required this.createdAt,
    required this.lastCheckedAt,
    required this.files,
    this.hasMissingFiles = false,
    this.hasRemoteChanges = false,
  });

  final String id;
  final String name;
  final String remotePath;
  final String localPath;
  final int fileCount;
  final int totalSize;
  final DateTime createdAt;
  final DateTime? lastCheckedAt;
  final List<OpenListOfflineFile> files;
  final bool hasMissingFiles;
  final bool hasRemoteChanges;

  OpenListOfflinePackage copyWith({
    int? fileCount,
    int? totalSize,
    DateTime? lastCheckedAt,
    List<OpenListOfflineFile>? files,
    bool? hasMissingFiles,
    bool? hasRemoteChanges,
  }) {
    return OpenListOfflinePackage(
      id: id,
      name: name,
      remotePath: remotePath,
      localPath: localPath,
      fileCount: fileCount ?? this.fileCount,
      totalSize: totalSize ?? this.totalSize,
      createdAt: createdAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      files: files ?? this.files,
      hasMissingFiles: hasMissingFiles ?? this.hasMissingFiles,
      hasRemoteChanges: hasRemoteChanges ?? this.hasRemoteChanges,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'remotePath': remotePath,
      'localPath': localPath,
      'fileCount': fileCount,
      'totalSize': totalSize,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastCheckedAt': lastCheckedAt?.toUtc().toIso8601String(),
      'files': files.map((file) => file.toJson()).toList(),
      'hasMissingFiles': hasMissingFiles,
      'hasRemoteChanges': hasRemoteChanges,
    };
  }

  factory OpenListOfflinePackage.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'];
    return OpenListOfflinePackage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      remotePath: json['remotePath']?.toString() ?? '/',
      localPath: json['localPath']?.toString() ?? '',
      fileCount: _intValue(json['fileCount']),
      totalSize: _intValue(json['totalSize']),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastCheckedAt: DateTime.tryParse(json['lastCheckedAt']?.toString() ?? ''),
      files: rawFiles is List
          ? rawFiles
                .whereType<Map>()
                .map(
                  (item) => OpenListOfflineFile.fromJson(
                    item.map((key, value) => MapEntry('$key', value)),
                  ),
                )
                .toList()
          : const <OpenListOfflineFile>[],
      hasMissingFiles: json['hasMissingFiles'] == true,
      hasRemoteChanges: json['hasRemoteChanges'] == true,
    );
  }
}

class OpenListOfflinePackageService {
  OpenListOfflinePackageService({OpenListRepository? repository})
    : _repository = repository ?? OpenListRepository();

  static const String _manifestKey = 'openlist_offline_packages_v1';

  final OpenListRepository _repository;

  Future<List<OpenListOfflinePackage>> loadPackages() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_manifestKey) ?? const <String>[];
    final packages = <OpenListOfflinePackage>[];
    for (final item in encoded) {
      try {
        final decoded = json.decode(item);
        if (decoded is Map) {
          final package = OpenListOfflinePackage.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
          if (package.id.isNotEmpty) {
            packages.add(package);
          }
        }
      } catch (_) {
        // Ignore corrupt entries and keep the rest usable.
      }
    }
    packages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return packages;
  }

  Future<OpenListOfflinePackage> savePackage({
    required String remotePath,
    required String name,
    OpenListFileItem? item,
    void Function(String message, double? progress)? onProgress,
  }) async {
    final normalizedPath = OpenListRepository.normalizePath(remotePath);
    final packageId = _packageId(normalizedPath);
    final root = await ensureOfflineRootDirectory();
    final packageDir = Directory(p.join(root.path, packageId));
    if (!await packageDir.exists()) {
      await packageDir.create(recursive: true);
    }

    onProgress?.call('正在扫描 $name', null);
    final files = item != null && !item.isDir
        ? <_RemoteFileEntry>[
            _RemoteFileEntry(remotePath: normalizedPath, item: item),
          ]
        : await _collectFiles(normalizedPath);
    var downloaded = 0;
    final offlineFiles = <OpenListOfflineFile>[];

    for (final entry in files) {
      downloaded++;
      final relativePath = _relativePath(normalizedPath, entry.remotePath);
      final localPath = p.joinAll(<String>[packageDir.path, ...relativePath]);
      final localFile = File(localPath);
      if (!await localFile.parent.exists()) {
        await localFile.parent.create(recursive: true);
      }
      onProgress?.call(
        '正在离线保存 $downloaded/${files.length} · ${entry.name}',
        files.isEmpty ? null : (downloaded - 1) / files.length,
      );
      await _repository.downloadFileToPath(
        remotePath: entry.remotePath,
        savePath: localPath,
      );
      offlineFiles.add(
        OpenListOfflineFile(
          name: entry.name,
          remotePath: entry.remotePath,
          localPath: localPath,
          size: entry.size,
          modified: entry.modified,
        ),
      );
    }

    final now = DateTime.now();
    final package = OpenListOfflinePackage(
      id: packageId,
      name: name,
      remotePath: normalizedPath,
      localPath: packageDir.path,
      fileCount: offlineFiles.length,
      totalSize: offlineFiles.fold<int>(0, (sum, file) => sum + file.size),
      createdAt: now,
      lastCheckedAt: now,
      files: offlineFiles,
    );
    await upsertPackage(package);
    onProgress?.call('离线保存完成 $name', 1);
    ApiService.appendExternalConsoleLog(
      'openlist',
      'offline package saved name=$name files=${package.fileCount} size=${package.totalSize}',
    );
    return package;
  }

  Future<OpenListOfflinePackage> checkPackage(
    OpenListOfflinePackage package,
  ) async {
    final remoteFiles = <String, OpenListFileItem>{};
    try {
      for (final entry in await _collectFiles(package.remotePath)) {
        remoteFiles[entry.remotePath] = entry.item;
      }
    } catch (error) {
      ApiService.appendExternalConsoleLog(
        'openlist',
        'offline package check remote failed name=${package.name}: $error',
      );
    }

    var hasMissing = false;
    var hasChanged = false;
    final updatedFiles = <OpenListOfflineFile>[];
    for (final file in package.files) {
      final exists = await File(file.localPath).exists();
      final remote = remoteFiles[file.remotePath];
      final changed =
          remote != null &&
          (remote.size != file.size ||
              remote.modified?.toUtc().toIso8601String() !=
                  file.modified?.toUtc().toIso8601String());
      hasMissing = hasMissing || !exists;
      hasChanged = hasChanged || changed;
      updatedFiles.add(file.copyWith(missing: !exists, changed: changed));
    }

    final updated = package.copyWith(
      lastCheckedAt: DateTime.now(),
      files: updatedFiles,
      hasMissingFiles: hasMissing,
      hasRemoteChanges: hasChanged,
    );
    await upsertPackage(updated);
    return updated;
  }

  Future<void> deletePackage(OpenListOfflinePackage package) async {
    final dir = Directory(package.localPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    final packages = await loadPackages();
    await _savePackages(
      packages.where((item) => item.id != package.id).toList(),
    );
  }

  Future<void> upsertPackage(OpenListOfflinePackage package) async {
    final packages = await loadPackages();
    final index = packages.indexWhere((item) => item.id == package.id);
    if (index >= 0) {
      packages[index] = package;
    } else {
      packages.add(package);
    }
    await _savePackages(packages);
  }

  Future<void> _savePackages(List<OpenListOfflinePackage> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _manifestKey,
      packages.map((package) => json.encode(package.toJson())).toList(),
    );
  }

  Future<List<_RemoteFileEntry>> _collectFiles(String remotePath) async {
    final normalized = OpenListRepository.normalizePath(remotePath);
    final listing = await _repository.list(normalized);
    final files = <_RemoteFileEntry>[];
    for (final item in listing.content) {
      final childPath = OpenListRepository.joinRemotePath(
        normalized,
        item.name,
      );
      if (item.isDir) {
        files.addAll(await _collectFiles(childPath));
      } else {
        files.add(_RemoteFileEntry(remotePath: childPath, item: item));
      }
    }
    return files;
  }

  static Future<Directory> ensureOfflineRootDirectory() async {
    return GueterStorageService.instance.publicDirectory(
      GueterPublicDirectory.offlinePackages,
    );
  }

  static String _packageId(String remotePath) {
    final bytes = utf8.encode(remotePath);
    final encoded = base64Url.encode(bytes).replaceAll('=', '');
    return encoded.length > 80 ? encoded.substring(0, 80) : encoded;
  }

  static List<String> _relativePath(String rootPath, String filePath) {
    final root = OpenListRepository.normalizePath(rootPath);
    final file = OpenListRepository.normalizePath(filePath);
    final relative = root == '/'
        ? file.replaceFirst(RegExp(r'^/+'), '')
        : file.replaceFirst(RegExp('^${RegExp.escape(root)}/?'), '');
    return relative
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .map(OpenListRepository.sanitizeFileName)
        .toList();
  }
}

class _RemoteFileEntry {
  const _RemoteFileEntry({required this.remotePath, required this.item});

  final String remotePath;
  final OpenListFileItem item;

  String get name => item.name;
  int get size => item.size;
  DateTime? get modified => item.modified;
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
