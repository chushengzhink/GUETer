import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';
import '../../platform.dart';
import '../../services/gueter_storage_service.dart';
import '../../session/account.dart';
import '../../session/tronclass_auth.dart';
import 'openlist_client.dart';
import 'openlist_models.dart';

typedef OpenListUploaderResolver = Future<OpenListUploaderIdentity?> Function();
typedef OpenListAccountResolver = Future<OpenListCredentials> Function();

class OpenListRepository {
  OpenListRepository({
    OpenListClient? client,
    OpenListUploadAuditClient? auditClient,
    OpenListProvisionClient? provisionClient,
    OpenListAccountResolver? accountResolver,
    OpenListUploaderResolver? uploaderResolver,
  }) : _client = client ?? OpenListClient(),
       _auditClient = auditClient ?? OpenListUploadAuditClient(),
       _provisionClient = provisionClient ?? OpenListProvisionClient(),
       _accountResolver = accountResolver,
       _uploaderResolver = uploaderResolver ?? resolveUploaderIdentity;

  static const OpenListCredentials readonlyCredentials = OpenListCredentials(
    mode: OpenListAccountMode.readonly,
    username: 'cszm',
    password: '123123',
  );

  static const String _pendingAuditKey = 'openlist_pending_upload_audits';
  static const String _provisionedUserPrefix = 'openlist_provisioned_user_';

  final OpenListClient _client;
  final OpenListUploadAuditClient _auditClient;
  final OpenListProvisionClient _provisionClient;
  final OpenListAccountResolver? _accountResolver;
  final OpenListUploaderResolver _uploaderResolver;

  OpenListSession? _session;
  Future<OpenListSession>? _loginFuture;

  OpenListSession? get currentSession => _session;

  static Future<OpenListUploaderIdentity?> resolveUploaderIdentity() async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      return null;
    }
    final accounts = AccountManager.getAccountsForPlatform(
      PlatformType.tronclass,
    );
    for (final user in accounts) {
      if (user.uid == currentUserId &&
          await AccountManager.hasValidTronclassSession(user)) {
        final studentId = normalizeStudentId(user.studentId);
        if (studentId == null) {
          ApiService.appendExternalConsoleLog(
            'openlist',
            'audit skipped missing studentId accountUid=${user.uid}',
          );
          return null;
        }
        return OpenListUploaderIdentity(
          studentId: studentId,
          studentName: user.name,
        );
      }
    }
    return null;
  }

  Future<OpenListSession> warmUp() {
    return ensureSession(force: true);
  }

  Future<OpenListSession> ensureSession({bool force = false}) async {
    final credentials = await (_accountResolver ?? resolveCredentials)();
    final mode = credentials.mode;
    final current = _session;
    if (!force &&
        current != null &&
        current.mode == mode &&
        current.username == credentials.username) {
      return current;
    }

    final pending = _loginFuture;
    if (pending != null) {
      return pending;
    }

    _loginFuture = _login(credentials);
    try {
      return await _loginFuture!;
    } finally {
      _loginFuture = null;
    }
  }

  Future<OpenListDirectoryListing> list(String path) {
    return _withAuth((session) {
      return _client.list(token: session.token, path: normalizePath(path));
    });
  }

  Future<OpenListFileDetail> getFile(String path) {
    return _withAuth((session) {
      return _client.get(token: session.token, path: normalizePath(path));
    });
  }

  Future<String> uploadFile({
    required String currentPath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _withAuth((session) async {
      if (!session.permissions.canWriteContent) {
        throw const OpenListApiException('OpenList account cannot upload');
      }
      final remotePath = joinRemotePath(currentPath, p.basename(localPath));
      await _uploadWithNetworkRetry(
        session: session,
        remotePath: remotePath,
        localPath: localPath,
        onSendProgress: onSendProgress,
      );
      await _recordUploadAudit(
        session: session,
        remotePath: remotePath,
        localPath: localPath,
      );
      return remotePath;
    });
  }

  Future<void> _uploadWithNetworkRetry({
    required OpenListSession session,
    required String remotePath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = attempt == 0
          ? session.token
          : (await ensureSession(force: true)).token;
      try {
        await _client.uploadFile(
          token: token,
          remotePath: remotePath,
          localPath: localPath,
          onSendProgress: onSendProgress,
        );
        return;
      } catch (error) {
        if (attempt == 0 && _isRetryableUploadError(error)) {
          ApiService.appendExternalConsoleLog(
            'openlist',
            'upload interrupted remotePath=$remotePath, retrying once: ${_safeUploadError(error)}',
          );
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> createFolder({
    required String currentPath,
    required String folderName,
  }) {
    return _withAuth((session) {
      if (!session.permissions.canWriteContent) {
        throw const OpenListApiException(
          'OpenList account cannot create folder',
        );
      }
      return _client.mkdir(
        token: session.token,
        path: joinRemotePath(currentPath, folderName),
      );
    });
  }

  Future<OpenListShareInfo> createShare(String remotePath) {
    return _withAuth((session) {
      if (!session.canShare) {
        throw const OpenListApiException('OpenList account cannot share');
      }
      return _client.createShare(
        token: session.token,
        path: pathWithBasePath(session.basePath, remotePath),
      );
    });
  }

  Future<String> resolveRawUrl(String remotePath) async {
    final detail = await getFile(remotePath);
    final rawUrl = detail.rawUrl.trim();
    if (rawUrl.isEmpty) {
      throw const OpenListApiException('OpenList file has no direct URL');
    }
    return rawUrl;
  }

  Future<String> downloadFile({
    required String remotePath,
    required String fileName,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final rawUrl = await resolveRawUrl(remotePath);
    final outputDir = await ensureDownloadDirectory();
    final safeName = sanitizeFileName(fileName);
    final savePath = p.join(outputDir.path, safeName);
    await _client.download(
      url: rawUrl,
      savePath: savePath,
      onReceiveProgress: onReceiveProgress,
    );
    return savePath;
  }

  Future<void> downloadFileToPath({
    required String remotePath,
    required String savePath,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final rawUrl = await resolveRawUrl(remotePath);
    final outputFile = File(savePath);
    if (!await outputFile.parent.exists()) {
      await outputFile.parent.create(recursive: true);
    }
    await _client.download(
      url: rawUrl,
      savePath: savePath,
      onReceiveProgress: onReceiveProgress,
    );
  }

  static bool _isRetryableUploadError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return true;
      }
      final message = error.message?.toLowerCase() ?? '';
      final inner = error.error?.toString().toLowerCase() ?? '';
      return _isRetryableUploadMessage('$message $inner');
    }
    if (error is SocketException) {
      return true;
    }
    return _isRetryableUploadMessage(error.toString().toLowerCase());
  }

  static bool _isRetryableUploadMessage(String message) {
    return message.contains('broken pipe') ||
        message.contains('connection reset') ||
        message.contains('connection aborted') ||
        message.contains('connection closed') ||
        message.contains('send timeout') ||
        message.contains('receive timeout') ||
        message.contains('socketexception');
  }

  static String _safeUploadError(Object error) {
    return ApiService.sanitizeConsoleLogText(error.toString());
  }

  Future<void> retryPendingAuditRecords() async {
    final records = await _loadPendingAuditRecords();
    if (records.isEmpty) {
      return;
    }

    final remaining = <OpenListUploadAuditRecord>[];
    for (final record in records) {
      try {
        await _auditClient.submit(record);
      } catch (error) {
        remaining.add(record);
        ApiService.appendExternalConsoleLog(
          'openlist',
          'audit retry failed remotePath=${record.remotePath}: $error',
        );
      }
    }
    await _savePendingAuditRecords(remaining);
  }

  void invalidateSession() {
    _session = null;
  }

  Future<T> _withAuth<T>(Future<T> Function(OpenListSession session) action) {
    return _withAuthAttempt(action, hasRetried: false);
  }

  Future<T> _withAuthAttempt<T>(
    Future<T> Function(OpenListSession session) action, {
    required bool hasRetried,
  }) async {
    final session = await ensureSession();
    try {
      return await action(session);
    } on OpenListApiException catch (error) {
      if (!hasRetried && error.isAuthExpired) {
        ApiService.appendExternalConsoleLog(
          'openlist',
          'auth expired, relogin and retry: ${error.message}',
        );
        invalidateSession();
        final refreshed = await ensureSession(force: true);
        return action(refreshed);
      }
      rethrow;
    }
  }

  Future<OpenListSession> _login(OpenListCredentials credentials) async {
    final token = await _client.login(credentials);
    final profile = await _client.me(token);
    final session = OpenListSession(
      mode: credentials.mode,
      token: token,
      username: profile.username,
      permission: profile.permission,
      basePath: profile.basePath,
    );
    _session = session;
    ApiService.appendExternalConsoleLog(
      'openlist',
      'session ready account=${credentials.label} permission=${session.permission} basePath=${session.basePath}',
    );
    return session;
  }

  Future<OpenListCredentials> resolveCredentials() async {
    final personal = await _resolvePersonalCredentials();
    return personal ?? readonlyCredentials;
  }

  Future<OpenListCredentials?> _resolvePersonalCredentials() async {
    final proof = await buildCurrentTronclassProof();
    if (proof == null) {
      return null;
    }

    try {
      final user = await _provisionClient.ensureUser(proof);
      await _saveProvisionedUser(user);
      return OpenListCredentials(
        mode: OpenListAccountMode.personal,
        username: user.username,
        password: user.password,
      );
    } catch (error) {
      ApiService.appendExternalConsoleLog(
        'openlist',
        'provision failed, fallback readonly studentId=${proof.studentId}: $error',
      );
      return null;
    }
  }

  static Future<OpenListUserProvisionProof?>
  buildCurrentTronclassProof() async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.trim().isEmpty) {
      return null;
    }
    final accounts = AccountManager.getAccountsForPlatform(
      PlatformType.tronclass,
    );
    for (final user in accounts) {
      if (user.uid != currentUserId) {
        continue;
      }
      if (!await AccountManager.hasValidTronclassSession(user)) {
        return null;
      }
      final studentId = normalizeStudentId(user.studentId);
      if (studentId == null) {
        ApiService.appendExternalConsoleLog(
          'openlist',
          'provision skipped missing studentId accountUid=${user.uid}',
        );
        return null;
      }
      final sessionId =
          await TronclassAuthManager.getSessionIdForUser(user.uid) ?? '';
      var cookie = '';
      if (sessionId.trim().isEmpty) {
        cookie =
            await AccountManager.getCookieForPlatform(
              PlatformType.tronclass,
              user.uid,
            ) ??
            '';
      }
      if (sessionId.trim().isEmpty && cookie.trim().isEmpty) {
        return null;
      }
      return OpenListUserProvisionProof(
        accountUid: user.uid,
        studentId: studentId,
        studentName: user.name,
        sessionId: sessionId,
        cookie: cookie,
      );
    }
    return null;
  }

  static String normalizePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || trimmed == '/') {
      return '/';
    }
    final collapsed = trimmed.replaceAll(RegExp(r'/+'), '/');
    return collapsed.startsWith('/') ? collapsed : '/$collapsed';
  }

  static String? normalizeStudentId(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d{8,12}$').hasMatch(text)) {
      return null;
    }
    return text;
  }

  static String joinRemotePath(String basePath, String name) {
    final base = normalizePath(basePath);
    final cleanName = name.replaceAll('/', '').replaceAll('\\', '').trim();
    if (base == '/') {
      return '/$cleanName';
    }
    return '$base/$cleanName';
  }

  static List<String> breadcrumbPaths(String path) {
    final normalized = normalizePath(path);
    if (normalized == '/') {
      return const <String>['/'];
    }
    final paths = <String>['/'];
    final parts = normalized
        .split('/')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    var current = '';
    for (final part in parts) {
      current = '$current/$part';
      paths.add(current);
    }
    return paths;
  }

  static String pathWithBasePath(String basePath, String path) {
    final base = normalizePath(basePath);
    final normalized = normalizePath(path);
    if (base == '/') {
      return normalized;
    }
    if (normalized == '/') {
      return base;
    }
    return '$base$normalized';
  }

  static String displayNameForPath(String path) {
    final normalized = normalizePath(path);
    if (normalized == '/') {
      return '根目录';
    }
    return normalized.split('/').where((part) => part.isNotEmpty).last;
  }

  static String sanitizeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'openlist_file' : cleaned;
  }

  static Future<Directory> ensureDownloadDirectory() async {
    final dir = Directory(await downloadDirectoryPath());
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> downloadDirectoryPath() async {
    return GueterStorageService.instance.publicDirectoryPath(
      GueterPublicDirectory.cloudDownloads,
    );
  }

  Future<void> _recordUploadAudit({
    required OpenListSession session,
    required String remotePath,
    required String localPath,
  }) async {
    final identity = await _uploaderResolver();
    if (identity == null) {
      ApiService.appendExternalConsoleLog(
        'openlist',
        'audit skipped no valid tronclass identity remotePath=$remotePath',
      );
      return;
    }

    final file = File(localPath);
    final size = await file.exists() ? await file.length() : 0;
    final record = OpenListUploadAuditRecord(
      studentId: identity.studentId,
      studentName: identity.studentName,
      remotePath: remotePath,
      fileName: p.basename(localPath),
      size: size,
      uploadedAt: DateTime.now(),
      openListUsername: session.username,
      permission: session.permission,
      clientPlatform: Platform.operatingSystem,
      source: 'app',
      requestMethod: 'PUT',
    );
    await _submitAuditRecord(record, queueOnFailure: true);
  }

  Future<void> _submitAuditRecord(
    OpenListUploadAuditRecord record, {
    required bool queueOnFailure,
  }) async {
    try {
      await retryPendingAuditRecords();
      await _auditClient.submit(record);
    } catch (error) {
      ApiService.appendExternalConsoleLog(
        'openlist',
        'audit submit failed remotePath=${record.remotePath}: $error',
      );
      if (queueOnFailure) {
        await _queueAuditRecord(record);
      }
    }
  }

  Future<void> _queueAuditRecord(OpenListUploadAuditRecord record) async {
    final records = await _loadPendingAuditRecords();
    records.add(record);
    await _savePendingAuditRecords(records);
  }

  Future<List<OpenListUploadAuditRecord>> _loadPendingAuditRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_pendingAuditKey) ?? const <String>[];
    final records = <OpenListUploadAuditRecord>[];
    for (final item in encoded) {
      try {
        final decoded = json.decode(item);
        if (decoded is Map) {
          records.add(
            OpenListUploadAuditRecord.fromJson(
              decoded.map((key, value) => MapEntry('$key', value)),
            ),
          );
        }
      } catch (_) {
        // Drop corrupt pending records instead of blocking future uploads.
      }
    }
    return records;
  }

  Future<void> _saveProvisionedUser(OpenListProvisionedUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_provisionedUserPrefix${user.studentId}',
      json.encode(user.toJson()),
    );
  }

  Future<void> _savePendingAuditRecords(
    List<OpenListUploadAuditRecord> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (records.isEmpty) {
      await prefs.remove(_pendingAuditKey);
      return;
    }
    await prefs.setStringList(
      _pendingAuditKey,
      records.map((record) => json.encode(record.toJson())).toList(),
    );
  }
}
