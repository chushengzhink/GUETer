import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/async/app_async_state.dart';
import '../../materials/material_index_models.dart';
import '../../materials/material_library_store.dart';
import 'openlist_client.dart';
import 'openlist_models.dart';
import 'openlist_offline_package.dart';
import 'openlist_repository.dart';

enum OpenListSortKey { name, type, size, modified }

class OpenListController extends ChangeNotifier {
  OpenListController({OpenListRepository? repository})
    : _repository = repository ?? OpenListRepository() {
    _offlineService = OpenListOfflinePackageService(repository: _repository);
  }

  final OpenListRepository _repository;
  final MaterialLibraryStore _materialLibraryStore = MaterialLibraryStore();
  late final OpenListOfflinePackageService _offlineService;

  AppAsyncState<OpenListDirectoryListing> _state =
      const AppAsyncState<OpenListDirectoryListing>.idle();
  String _currentPath = '/';
  OpenListSession? _session;
  bool _uploading = false;
  bool _downloading = false;
  bool _offlineSaving = false;
  double? _transferProgress;
  String _transferMessage = '';
  String _query = '';
  OpenListSortKey _sortKey = OpenListSortKey.name;
  bool _sortAscending = true;

  AppAsyncState<OpenListDirectoryListing> get state => _state;
  String get currentPath => _currentPath;
  OpenListSession? get session => _session;
  bool get uploading => _uploading;
  bool get downloading => _downloading;
  bool get offlineSaving => _offlineSaving;
  double? get transferProgress => _transferProgress;
  String get transferMessage => _transferMessage;
  String get query => _query;
  OpenListSortKey get sortKey => _sortKey;
  bool get sortAscending => _sortAscending;

  List<OpenListFileItem> get visibleItems {
    final listing = _state.data;
    if (listing == null) {
      return const <OpenListFileItem>[];
    }
    final normalizedQuery = _query.trim().toLowerCase();
    final items = listing.content.where((item) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(normalizedQuery);
    }).toList();
    items.sort(_compareItems);
    return items;
  }

  bool get canUpload {
    final currentSession = _session;
    final listing = _state.data;
    return currentSession != null &&
        currentSession.permissions.canWriteContent &&
        listing != null &&
        listing.write;
  }

  bool get canCreateFolder => canUpload;

  bool get canCreateShare {
    final currentSession = _session;
    return currentSession != null && currentSession.canShare;
  }

  bool get canRename => _session?.permissions.canRename == true;
  bool get canMove => _session?.permissions.canMove == true;
  bool get canCopy => _session?.permissions.canCopy == true;
  bool get canRemove => _session?.permissions.canRemove == true;

  List<String> get capabilityLabels {
    final currentSession = _session;
    if (currentSession == null) {
      return const <String>['连接中'];
    }
    return <String>[
      canUpload ? '可上传' : '仅浏览',
      canCreateShare ? '可分享' : '不可分享',
      canRemove ? '可删除' : '不可删除',
    ];
  }

  List<String> get breadcrumbPaths =>
      OpenListRepository.breadcrumbPaths(_currentPath);

  void setQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    notifyListeners();
  }

  void setSort(OpenListSortKey key) {
    if (_sortKey == key) {
      _sortAscending = !_sortAscending;
    } else {
      _sortKey = key;
      _sortAscending = true;
    }
    notifyListeners();
  }

  Future<void> load({String path = '/', bool refresh = false}) async {
    final nextPath = OpenListRepository.normalizePath(path);
    final previous = _state.data;
    _state = AppAsyncState<OpenListDirectoryListing>.loading(
      previousData: previous,
      isRefreshing: refresh && previous != null,
    );
    _transferMessage = '';
    notifyListeners();

    try {
      _session = await _repository.ensureSession();
      final listing = await _repository.list(nextPath);
      unawaited(_repository.retryPendingAuditRecords().catchError((_) {}));
      final pathChanged = nextPath != _currentPath;
      _currentPath = nextPath;
      if (pathChanged) {
        _query = '';
      }
      _state = AppAsyncState<OpenListDirectoryListing>.data(listing);
    } catch (error, stackTrace) {
      _state = AppAsyncState<OpenListDirectoryListing>.error(
        error,
        stackTrace: stackTrace,
        data: previous,
      );
    }
    notifyListeners();
  }

  Future<void> refresh() => load(path: _currentPath, refresh: true);

  Future<void> openFolder(OpenListFileItem item) {
    if (!item.isDir) {
      return Future<void>.value();
    }
    return load(
      path: OpenListRepository.joinRemotePath(_currentPath, item.name),
    );
  }

  Future<void> goToPath(String path) {
    return load(path: path);
  }

  Future<String> downloadFile(OpenListFileItem item) async {
    _downloading = true;
    _transferProgress = null;
    _transferMessage = '正在下载 ${item.name}';
    notifyListeners();
    try {
      final remotePath = OpenListRepository.joinRemotePath(
        _currentPath,
        item.name,
      );
      final localPath = await _repository.downloadFile(
        remotePath: remotePath,
        fileName: item.name,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _transferProgress = received / total;
            notifyListeners();
          }
        },
      );
      await _materialLibraryStore.upsertItem(
        path: localPath,
        name: item.name,
        sourceType: MaterialSourceType.openListDownload,
        sourceLabel: '云盘下载',
      );
      _transferMessage = '下载完成 ${item.name}';
      return localPath;
    } finally {
      _downloading = false;
      _transferProgress = null;
      notifyListeners();
    }
  }

  Future<String> resolveRawUrl(OpenListFileItem item) {
    return _repository.resolveRawUrl(
      OpenListRepository.joinRemotePath(_currentPath, item.name),
    );
  }

  Future<String> createShare(OpenListFileItem item) async {
    final remotePath = OpenListRepository.joinRemotePath(
      _currentPath,
      item.name,
    );
    final share = await _repository.createShare(remotePath);
    if (share.url.isEmpty) {
      throw const OpenListApiException('OpenList share did not return id');
    }
    return share.url;
  }

  Future<String> downloadDirectoryPath() {
    return OpenListRepository.ensureDownloadDirectory().then(
      (directory) => directory.path,
    );
  }

  Future<String> localPathForFile(OpenListFileItem item) async {
    final remotePath = OpenListRepository.joinRemotePath(
      _currentPath,
      item.name,
    );
    return _repository.downloadFile(
      remotePath: remotePath,
      fileName: item.name,
    );
  }

  Future<OpenListOfflinePackage> saveOfflinePackage(OpenListFileItem item) {
    final remotePath = OpenListRepository.joinRemotePath(
      _currentPath,
      item.name,
    );
    return saveOfflinePath(remotePath: remotePath, name: item.name);
  }

  Future<OpenListOfflinePackage> saveCurrentDirectoryOffline() {
    return saveOfflinePath(
      remotePath: _currentPath,
      name: OpenListRepository.displayNameForPath(_currentPath),
    );
  }

  Future<OpenListOfflinePackage> saveOfflinePath({
    required String remotePath,
    required String name,
  }) async {
    _offlineSaving = true;
    _transferProgress = null;
    _transferMessage = '准备离线保存 $name';
    notifyListeners();
    try {
      final package = await _offlineService.savePackage(
        remotePath: remotePath,
        name: name,
        item: _findCurrentItem(remotePath),
        onProgress: (message, progress) {
          _transferMessage = message;
          _transferProgress = progress;
          notifyListeners();
        },
      );
      for (final file in package.files) {
        await _materialLibraryStore.upsertItem(
          path: file.localPath,
          name: file.name,
          sourceType: MaterialSourceType.offlinePackage,
          sourceLabel: '云盘离线包 · ${package.name}',
        );
      }
      return package;
    } finally {
      _offlineSaving = false;
      _transferProgress = null;
      notifyListeners();
    }
  }

  OpenListFileItem? _findCurrentItem(String remotePath) {
    final listing = _state.data;
    if (listing == null) {
      return null;
    }
    final normalized = OpenListRepository.normalizePath(remotePath);
    for (final item in listing.content) {
      final itemPath = OpenListRepository.joinRemotePath(
        _currentPath,
        item.name,
      );
      if (OpenListRepository.normalizePath(itemPath) == normalized) {
        return item;
      }
    }
    return null;
  }

  Future<void> uploadFiles(List<String> localPaths) async {
    if (localPaths.isEmpty) {
      return;
    }
    _uploading = true;
    _transferProgress = null;
    _transferMessage = '准备上传';
    notifyListeners();
    try {
      for (var i = 0; i < localPaths.length; i++) {
        final fileName = p.basename(localPaths[i]);
        _transferMessage = '正在上传 ${i + 1}/${localPaths.length} · $fileName';
        _transferProgress = localPaths.length == 1
            ? null
            : i / localPaths.length;
        notifyListeners();
        await _repository.uploadFile(
          currentPath: _currentPath,
          localPath: localPaths[i],
          onSendProgress: (sent, total) {
            if (total <= 0) {
              return;
            }
            final fileProgress = sent / total;
            _transferProgress = (i + fileProgress) / localPaths.length;
            notifyListeners();
          },
        );
      }
      _transferMessage = '上传完成';
      await refresh();
    } finally {
      _uploading = false;
      _transferProgress = null;
      notifyListeners();
    }
  }

  Future<void> createFolder(String folderName) async {
    final name = folderName.trim();
    if (name.isEmpty) {
      throw const OpenListApiException('文件夹名称不能为空');
    }
    _transferMessage = '正在新建文件夹 $name';
    notifyListeners();
    try {
      await _repository.createFolder(
        currentPath: _currentPath,
        folderName: name,
      );
      _transferMessage = '已新建文件夹 $name';
      await refresh();
    } finally {
      notifyListeners();
    }
  }

  int _compareItems(OpenListFileItem a, OpenListFileItem b) {
    if (a.isDir != b.isDir) {
      return a.isDir ? -1 : 1;
    }

    final result = switch (_sortKey) {
      OpenListSortKey.name => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
      OpenListSortKey.type => a.type.compareTo(b.type),
      OpenListSortKey.size => a.size.compareTo(b.size),
      OpenListSortKey.modified => _compareDate(a.modified, b.modified),
    };
    return _sortAscending ? result : -result;
  }

  static int _compareDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return -1;
    }
    if (b == null) {
      return 1;
    }
    return a.compareTo(b);
  }
}
