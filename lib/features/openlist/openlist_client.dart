import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../api/api_service.dart';
import 'openlist_endpoint_config.dart';
import 'openlist_models.dart';

class OpenListApiException implements Exception {
  const OpenListApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final int? code;

  bool get isAuthExpired =>
      statusCode == 401 ||
      statusCode == 403 ||
      code == 401 ||
      code == 403 ||
      message.toLowerCase().contains('token') ||
      message.toLowerCase().contains('unauthorized');

  @override
  String toString() => message;
}

class OpenListClient {
  OpenListClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status != null && status < 500,
              headers: const <String, String>{
                'accept': 'application/json, text/plain, */*',
              },
            ),
          );

  static String get baseUrl => OpenListEndpointConfig.baseUrl;

  final Dio _dio;

  Future<String> login(OpenListCredentials credentials) async {
    _log(
      'login start account=${credentials.label} username=${credentials.username}',
    );
    final response = await _dio.post<dynamic>(
      '/api/auth/login',
      data: <String, String>{
        'username': credentials.username,
        'password': credentials.password,
      },
    );
    final data = _readDataMap(response);
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const OpenListApiException('OpenList login did not return token');
    }
    _log(
      'login success account=${credentials.label} tokenLength=${token.length}',
    );
    return token;
  }

  Future<OpenListUserProfile> me(String token) async {
    final response = await _dio.get<dynamic>(
      '/api/me',
      options: Options(headers: _authHeaders(token)),
    );
    return OpenListUserProfile.fromJson(_readDataMap(response));
  }

  Future<OpenListDirectoryListing> list({
    required String token,
    required String path,
  }) async {
    _log('list path=$path');
    final response = await _dio.post<dynamic>(
      '/api/fs/list',
      data: <String, dynamic>{
        'path': path,
        'password': '',
        'page': 1,
        'per_page': 0,
        'refresh': false,
      },
      options: Options(headers: _authHeaders(token)),
    );
    final listing = OpenListDirectoryListing.fromJson(_readDataMap(response));
    _log('list done path=$path total=${listing.total} write=${listing.write}');
    return listing;
  }

  Future<OpenListFileDetail> get({
    required String token,
    required String path,
  }) async {
    _log('get path=$path');
    final response = await _dio.post<dynamic>(
      '/api/fs/get',
      data: <String, dynamic>{'path': path, 'password': ''},
      options: Options(headers: _authHeaders(token)),
    );
    return OpenListFileDetail.fromJson(_readDataMap(response));
  }

  Future<void> mkdir({required String token, required String path}) async {
    _log('mkdir path=$path');
    final response = await _dio.post<dynamic>(
      '/api/fs/mkdir',
      data: <String, dynamic>{'path': path},
      options: Options(headers: _authHeaders(token)),
    );
    _readData(response);
    _log('mkdir done path=$path');
  }

  Future<OpenListShareInfo> createShare({
    required String token,
    required String path,
  }) async {
    _log('share create path=$path');
    final response = await _dio.post<dynamic>(
      '/api/share/create',
      data: <String, dynamic>{
        'files': <String>[path],
        'pwd': '',
        'max_accessed': 0,
        'disabled': false,
      },
      options: Options(headers: _authHeaders(token)),
    );
    final share = OpenListShareInfo.fromJson(
      _readDataMap(response),
      baseUrl: _dio.options.baseUrl.isEmpty ? baseUrl : _dio.options.baseUrl,
    );
    _log('share create done path=$path id=${share.id}');
    return share;
  }

  Future<void> uploadForm({
    required String token,
    required String remotePath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final fileName = p.basename(localPath);
    _log('upload form start remotePath=$remotePath file=$fileName');
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(localPath, filename: fileName),
    });
    final response = await _dio.put<dynamic>(
      '/api/fs/form',
      data: formData,
      onSendProgress: onSendProgress,
      options: Options(
        headers: <String, String>{
          ..._authHeaders(token),
          'File-Path': Uri.encodeComponent(remotePath),
          'Overwrite': 'true',
        },
      ),
    );
    _readData(response);
    _log('upload form done remotePath=$remotePath');
  }

  Future<void> uploadFile({
    required String token,
    required String remotePath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final file = File(localPath);
    final fileName = p.basename(localPath);
    final fileSize = await file.length();
    _log(
      'upload stream start remotePath=$remotePath file=$fileName size=$fileSize',
    );
    try {
      final response = await _dio.put<dynamic>(
        '/api/fs/put',
        data: file.openRead(),
        onSendProgress: onSendProgress,
        options: Options(
          headers: <String, String>{
            ..._authHeaders(token),
            'Content-Type': 'application/octet-stream',
            'File-Path': Uri.encodeComponent(remotePath),
            'Overwrite': 'true',
          },
          sendTimeout: _uploadSendTimeout(fileSize),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      _readData(response);
      _log('upload stream done remotePath=$remotePath');
    } on OpenListApiException catch (error) {
      if (!_shouldFallbackToForm(error)) {
        rethrow;
      }
      _log('upload stream unsupported, fallback form remotePath=$remotePath');
      await uploadForm(
        token: token,
        remotePath: remotePath,
        localPath: localPath,
        onSendProgress: onSendProgress,
      );
    }
  }

  Future<void> download({
    required String url,
    required String savePath,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    _log('download start hostHash=${OpenListEndpointConfig.hostHash(url)}');
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: Options(responseType: ResponseType.bytes),
    );
    final size = await File(savePath).length();
    _log('download done path=$savePath size=$size');
  }

  static Map<String, String> _authHeaders(String token) {
    return <String, String>{'Authorization': token};
  }

  static Map<String, dynamic> _readDataMap(Response<dynamic> response) {
    final data = _readData(response);
    if (data is Map) {
      return data.map((key, value) => MapEntry('$key', value));
    }
    throw const OpenListApiException('OpenList response data is not an object');
  }

  static dynamic _readData(Response<dynamic> response) {
    final statusCode = response.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      throw OpenListApiException(
        'OpenList auth expired: HTTP $statusCode',
        statusCode: statusCode,
      );
    }
    if (statusCode == null || statusCode >= 400) {
      throw OpenListApiException(
        'OpenList request failed: HTTP $statusCode',
        statusCode: statusCode,
      );
    }

    final body = response.data;
    if (body is! Map) {
      return body;
    }

    final map = body.map((key, value) => MapEntry('$key', value));
    final code = _intValue(map['code']);
    if (map.containsKey('code') && code != 200) {
      final message = map['message']?.toString() ?? 'OpenList request failed';
      throw OpenListApiException(message, statusCode: statusCode, code: code);
    }
    return map['data'];
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static void _log(String message) {
    ApiService.appendExternalConsoleLog('openlist', message);
  }

  static Duration _uploadSendTimeout(int fileSize) {
    final mib = fileSize / (1024 * 1024);
    final seconds = (mib * 20).ceil();
    return Duration(seconds: seconds < 300 ? 300 : seconds);
  }

  static bool _shouldFallbackToForm(OpenListApiException error) {
    final status = error.statusCode;
    if (status == 404 || status == 405 || status == 415) {
      return true;
    }
    final message = error.message.toLowerCase();
    return message.contains('not found') ||
        message.contains('method not allowed') ||
        message.contains('unsupported media');
  }
}

class OpenListUploadAuditClient {
  OpenListUploadAuditClient({
    Dio? dio,
    String? endpoint,
    String auditKey = const String.fromEnvironment(
      'OPENLIST_AUDIT_KEY',
      defaultValue: defaultAuditKey,
    ),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 10),
               sendTimeout: const Duration(seconds: 10),
               validateStatus: (status) => status != null && status < 500,
               headers: const <String, String>{
                 'accept': 'application/json, text/plain, */*',
               },
             ),
           ),
       _endpoint = endpoint ?? OpenListEndpointConfig.auditEndpoint,
       _auditKey = auditKey;

  static const String defaultAuditKey = 'gueter-openlist-audit';

  final Dio _dio;
  final String _endpoint;
  final String _auditKey;

  Future<void> submit(OpenListUploadAuditRecord record) async {
    final endpoint = _endpoint.trim();
    if (endpoint.isEmpty) {
      _log('audit skipped endpoint empty remotePath=${record.remotePath}');
      return;
    }

    _log('audit submit remotePath=${record.remotePath}');
    final response = await _dio.post<dynamic>(
      endpoint,
      data: record.toJson(),
      options: Options(
        headers: <String, String>{
          if (_auditKey.trim().isNotEmpty)
            'X-GUETer-Audit-Key': _auditKey.trim(),
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );
    final status = response.statusCode;
    if (status == null || status >= 400) {
      throw OpenListApiException(
        'OpenList audit failed: HTTP $status',
        statusCode: status,
      );
    }
    _log('audit submit done remotePath=${record.remotePath}');
  }

  static void _log(String message) {
    ApiService.appendExternalConsoleLog('openlist', message);
  }
}

class OpenListProvisionClient {
  OpenListProvisionClient({Dio? dio, String? endpoint})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 10),
              validateStatus: (status) => status != null && status < 500,
              headers: const <String, String>{
                'accept': 'application/json, text/plain, */*',
              },
            ),
          ),
      _endpoint = endpoint ?? OpenListEndpointConfig.provisionEndpoint;

  final Dio _dio;
  final String _endpoint;

  Future<OpenListProvisionedUser> ensureUser(
    OpenListUserProvisionProof proof,
  ) async {
    _log(
      'provision start studentId=${proof.studentId} accountUid=${proof.accountUid} sessionLength=${proof.sessionId.length} cookieLength=${proof.cookie.length}',
    );
    final response = await _dio.post<dynamic>(
      _endpoint,
      data: proof.toJson(),
      options: Options(
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      ),
    );
    final status = response.statusCode;
    if (status == null || status >= 400) {
      throw OpenListApiException(
        'OpenList provision failed: HTTP $status',
        statusCode: status,
      );
    }
    final data = response.data;
    if (data is! Map) {
      throw const OpenListApiException('OpenList provision response invalid');
    }
    final user = OpenListProvisionedUser.fromJson(
      data.map((key, value) => MapEntry('$key', value)),
    );
    if (user.username.isEmpty || user.password.isEmpty) {
      throw const OpenListApiException('OpenList provision missing account');
    }
    _log('provision done username=${user.username}');
    return user;
  }

  static void _log(String message) {
    ApiService.appendExternalConsoleLog('openlist', message);
  }
}
