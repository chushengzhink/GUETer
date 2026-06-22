import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../session/tronclass_auth.dart';
import 'api_service.dart';
import 'platform_request_stability.dart';

class TronclassUploadRecord {
  const TronclassUploadRecord({
    required this.id,
    required this.name,
    required this.uploadUrl,
  });

  final int id;
  final String name;
  final String uploadUrl;

  factory TronclassUploadRecord.fromJson(Map<String, dynamic> json) {
    final id = _intOf(json['id'] ?? json['key']);
    final uploadUrl =
        json['upload_url']?.toString() ?? json['url']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    if (id <= 0 || uploadUrl.isEmpty) {
      throw const TronclassHomeworkUploadException('上传记录响应缺少 id 或 upload_url');
    }
    return TronclassUploadRecord(id: id, name: name, uploadUrl: uploadUrl);
  }
}

class TronclassHomeworkUploadException implements Exception {
  const TronclassHomeworkUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TronclassHomeworkUploadApi {
  const TronclassHomeworkUploadApi();

  static const PlatformRequestOptions _submitOptions = PlatformRequestOptions(
    operationId: 'tronclass.homework.upload.submit',
    requestKind: PlatformRequestKind.submit,
    functionalProfileEnabled: false,
  );

  Future<TronclassUploadRecord> createUpload({
    required String name,
    required int size,
  }) async {
    final response = await ApiService.sendRequest(
      '/api/uploads',
      method: 'POST',
      headers: _jsonHeaders,
      body: <String, dynamic>{
        'name': name,
        'size': size,
        'parent_type': null,
        'parent_id': 0,
      },
      platformOptions: _submitOptions,
    );
    _ensureSuccess(response, '创建上传记录失败');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const TronclassHomeworkUploadException('创建上传记录响应格式异常');
    }
    return TronclassUploadRecord.fromJson(data);
  }

  Future<void> uploadBinary({
    required String uploadUrl,
    required File file,
    String? filename,
  }) async {
    final fileName = filename ?? p.basename(file.path);
    final formData = FormData.fromMap(<String, dynamic>{
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: _mediaTypeFor(fileName),
      ),
    });

    final response = await ApiService.sendRequest(
      uploadUrl,
      method: 'POST',
      headers: await _mediaUploadHeaders(),
      body: formData,
      platformOptions: _submitOptions,
    );
    _ensureSuccess(response, '上传文件失败');
  }

  Future<void> submitHomework({
    required int activityId,
    required List<int> uploadIds,
    String comment = '',
  }) async {
    if (uploadIds.isEmpty) {
      throw const TronclassHomeworkUploadException('请先选择要提交的附件');
    }

    final response = await ApiService.sendRequest(
      '/api/course/activities/$activityId/submissions',
      method: 'POST',
      headers: _jsonHeaders,
      body: <String, dynamic>{
        'comment': comment,
        'is_draft': false,
        'slides': <dynamic>[],
        'uploads': uploadIds,
      },
      platformOptions: _submitOptions,
    );
    _ensureSuccess(response, '提交作业失败');
  }

  Future<List<int>> uploadAndSubmit({
    required int activityId,
    required List<File> files,
    String comment = '',
    void Function(int index, int total, String message)? onProgress,
  }) async {
    if (files.isEmpty) {
      throw const TronclassHomeworkUploadException('请先选择要提交的附件');
    }

    final uploadIds = <int>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = p.basename(file.path);
      onProgress?.call(i + 1, files.length, '正在创建上传记录: $fileName');
      final upload = await createUpload(
        name: fileName,
        size: await file.length(),
      );
      onProgress?.call(i + 1, files.length, '正在上传: $fileName');
      await uploadBinary(
        uploadUrl: upload.uploadUrl,
        file: file,
        filename: fileName,
      );
      uploadIds.add(upload.id);
    }

    onProgress?.call(files.length, files.length, '正在提交作业');
    await submitHomework(
      activityId: activityId,
      uploadIds: uploadIds,
      comment: comment,
    );
    return uploadIds;
  }

  static final Map<String, String> _jsonHeaders = <String, String>{
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': 'http://localhost',
    'Referer': 'http://localhost/',
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json',
  };

  static Future<Map<String, String>> _mediaUploadHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
    };
    final sessionId = await TronclassAuthManager.getCurrentSessionId();
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['X-SESSION-ID'] = sessionId;
    }
    return headers;
  }

  static void _ensureSuccess(Response<dynamic> response, String action) {
    final statusCode = response.statusCode ?? 0;
    if (statusCode == 200 || statusCode == 201) return;
    final message = _messageOf(response.data);
    throw TronclassHomeworkUploadException(
      '$action: HTTP $statusCode${message.isEmpty ? '' : ' - $message'}',
    );
  }

  static String _messageOf(dynamic data) {
    if (data is Map) {
      return (data['message'] ?? data['msg'] ?? data['error'] ?? '').toString();
    }
    return data?.toString() ?? '';
  }

  static MediaType? _mediaTypeFor(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    return switch (extension) {
      '.jpg' || '.jpeg' => MediaType('image', 'jpeg'),
      '.png' => MediaType('image', 'png'),
      '.gif' => MediaType('image', 'gif'),
      '.webp' => MediaType('image', 'webp'),
      '.heic' => MediaType('image', 'heic'),
      '.mp4' => MediaType('video', 'mp4'),
      '.mov' => MediaType('video', 'quicktime'),
      '.avi' => MediaType('video', 'x-msvideo'),
      '.pdf' => MediaType('application', 'pdf'),
      '.doc' => MediaType('application', 'msword'),
      '.docx' => MediaType(
        'application',
        'vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      '.ppt' => MediaType('application', 'vnd.ms-powerpoint'),
      '.pptx' => MediaType(
        'application',
        'vnd.openxmlformats-officedocument.presentationml.presentation',
      ),
      '.xls' => MediaType('application', 'vnd.ms-excel'),
      '.xlsx' => MediaType(
        'application',
        'vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
      '.txt' => MediaType('text', 'plain'),
      _ => null,
    };
  }
}

int _intOf(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
