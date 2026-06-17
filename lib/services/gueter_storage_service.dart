import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/api_service.dart';

enum GueterPublicDirectory {
  cloudDownloads('cloud_downloads'),
  offlinePackages('offline_packages'),
  fileTools('file_tools'),
  pdfTools('pdf_tools'),
  ocrTexts('ocr_texts'),
  localTransfer('local_transfer'),
  exports('exports');

  const GueterPublicDirectory(this.folderName);

  final String folderName;
}

class GueterStorageService {
  GueterStorageService({
    Directory? androidDownloadRoot,
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
    bool Function()? isAndroidProvider,
  }) : _androidDownloadRoot =
           androidDownloadRoot ?? Directory('/storage/emulated/0/Download'),
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _isAndroidProvider = isAndroidProvider ?? (() => Platform.isAndroid);

  final Directory _androidDownloadRoot;
  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final bool Function() _isAndroidProvider;

  static final GueterStorageService instance = GueterStorageService();

  static const String rootFolderName = 'gueter';

  Future<Directory> publicDirectory(
    GueterPublicDirectory type, {
    String? customPath,
    bool temporaryFallback = false,
  }) async {
    if (customPath != null && customPath.trim().isNotEmpty) {
      return _ensure(Directory(customPath.trim()));
    }

    if (_isAndroidProvider()) {
      try {
        return await _ensure(
          Directory(
            p.join(_androidDownloadRoot.path, rootFolderName, type.folderName),
          ),
        );
      } catch (error) {
        ApiService.appendExternalConsoleLog(
          'storage',
          'public output unavailable type=${type.folderName}, fallback=app-private, error=${error.runtimeType}',
        );
        // Fall through to app-private storage when scoped storage blocks direct writes.
      }
    }

    final base = temporaryFallback
        ? await _temporaryDirectoryProvider()
        : await _documentsDirectoryProvider();
    return _ensure(
      Directory(p.join(base.path, rootFolderName, type.folderName)),
    );
  }

  Future<String> publicDirectoryPath(
    GueterPublicDirectory type, {
    String? customPath,
    bool temporaryFallback = false,
  }) async {
    return (await publicDirectory(
      type,
      customPath: customPath,
      temporaryFallback: temporaryFallback,
    )).path;
  }

  Future<Directory> _ensure(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
