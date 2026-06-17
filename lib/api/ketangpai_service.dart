import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../platform.dart';
import '../session/account.dart';
import 'api_service.dart';
import 'ketangpai_response.dart';
import 'platform_request_context.dart';
import 'platform_request_stability.dart';
import 'sign_request_profile.dart';

class KetangpaiServiceResult<T> {
  const KetangpaiServiceResult({
    required this.success,
    this.data,
    this.message = '',
    this.code,
    this.state,
    this.raw,
    this.authExpired = false,
  });

  final bool success;
  final T? data;
  final String message;
  final int? code;
  final int? state;
  final dynamic raw;
  final bool authExpired;

  static KetangpaiServiceResult<T> failure<T>(
    String message, {
    int? code,
    int? state,
    dynamic raw,
    bool authExpired = false,
  }) {
    return KetangpaiServiceResult<T>(
      success: false,
      message: message,
      code: code,
      state: state,
      raw: raw,
      authExpired: authExpired,
    );
  }
}

class KetangpaiService {
  KetangpaiService._();

  static PlatformRequestOptions _readOptions(String operationId) {
    return PlatformRequestOptions(
      operationId: operationId,
      requestKind: PlatformRequestKind.read,
      allowControlledParallelism: true,
    );
  }

  static PlatformRequestOptions _signOptions(String operationId) {
    return PlatformRequestOptions(
      operationId: operationId,
      requestKind: PlatformRequestKind.sign,
      cachePolicy: PlatformRequestCachePolicy.networkOnly,
    );
  }

  static PlatformRequestOptions _submitOptions(String operationId) {
    return PlatformRequestOptions(
      operationId: operationId,
      requestKind: PlatformRequestKind.submit,
      cachePolicy: PlatformRequestCachePolicy.networkOnly,
    );
  }

  static Map<String, dynamic> _withTimestamp(
    Map<String, dynamic> body, {
    bool seconds = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return <String, dynamic>{
      ...body,
      'reqtimestamp': seconds ? now ~/ 1000 : now,
    };
  }

  static int? _intOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _messageOf(dynamic payload) {
    final message = ketangpaiMessageOf(payload);
    if (message.isNotEmpty) return message;
    final map = asKetangpaiMap(payload);
    return (map?['message'] ?? map?['msg'] ?? '课堂派请求失败').toString();
  }

  @visibleForTesting
  static KetangpaiServiceResult<Map<String, dynamic>> mapResult(
    dynamic payload, {
    bool Function(Map<String, dynamic> map)? successWhen,
  }) {
    final map = asKetangpaiMap(payload);
    if (map == null) {
      return KetangpaiServiceResult.failure('课堂派响应格式异常', raw: payload);
    }

    final dataMap = asKetangpaiMap(map['data']);
    final code = _intOrNull(map['code']);
    final state = _intOrNull(dataMap?['state']);
    final authExpired = isKetangpaiAuthExpired(map);
    return KetangpaiServiceResult<Map<String, dynamic>>(
      success: authExpired
          ? false
          : (successWhen?.call(map) ?? isKetangpaiSuccess(map)),
      data: dataMap,
      message: _messageOf(map),
      code: code,
      state: state,
      raw: payload,
      authExpired: authExpired,
    );
  }

  @visibleForTesting
  static KetangpaiServiceResult<List<Map<String, dynamic>>> listResult(
    dynamic payload,
  ) {
    final map = asKetangpaiMap(payload);
    final authExpired = isKetangpaiAuthExpired(map);
    return KetangpaiServiceResult<List<Map<String, dynamic>>>(
      success: map == null ? false : !authExpired && isKetangpaiSuccess(map),
      data: extractKetangpaiList(payload),
      message: _messageOf(payload),
      code: _intOrNull(map?['code']),
      raw: payload,
      authExpired: authExpired,
    );
  }

  static Map<String, String> extractScanParams(String rawUrl) {
    final raw = rawUrl.trim();
    if (raw.isEmpty) {
      return const <String, String>{};
    }

    final normalized = raw.replaceAll('&amp;', '&');
    final uri = Uri.tryParse(normalized);

    String pick(String key) {
      final fromQuery = uri?.queryParameters[key];
      if (fromQuery != null && fromQuery.trim().isNotEmpty) {
        return Uri.decodeComponent(fromQuery).trim();
      }
      final match = RegExp(
        '(?:^|[?&#])$key=([^&#]*)',
        caseSensitive: false,
      ).firstMatch(normalized);
      return Uri.decodeComponent(match?.group(1) ?? '').trim();
    }

    return <String, String>{
      'ticketid': pick('ticketid'),
      'expire': pick('expire'),
      'sign': pick('sign'),
    };
  }

  static Future<Response<dynamic>> _postForCurrentUser(
    String endpoint, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    SignRequestProfile? signProfile,
    PlatformRequestOptions? platformOptions,
    bool timestampInSeconds = false,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw StateError('未登录课堂派账号');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      return context.sendRequest(
        endpoint,
        method: 'POST',
        body: _withTimestamp(body, seconds: timestampInSeconds),
        headers: headers,
        legacyHeaders: headers,
        signProfile: signProfile,
        platformOptions: platformOptions,
      );
    } finally {
      context.dispose();
    }
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> scanSign({
    required String rawQr,
    required String token,
  }) async {
    final params = extractScanParams(rawQr);
    final missing = <String>[
      if ((params['ticketid'] ?? '').isEmpty) 'ticketid',
      if ((params['expire'] ?? '').isEmpty) 'expire',
      if ((params['sign'] ?? '').isEmpty) 'sign',
    ];
    if (missing.isNotEmpty) {
      return KetangpaiServiceResult.failure('二维码参数缺失：${missing.join(', ')}');
    }

    final response = await _postForCurrentUser(
      '/AttenceApi/AttenceResult',
      body: <String, dynamic>{
        'ticketid': params['ticketid'],
        'expire': params['expire'],
        'sign': params['sign'],
      },
      headers: <String, String>{'token': token},
      timestampInSeconds: true,
      signProfile: SignRequestProfiles.ketangpaiAttendance(
        baseUrl: PlatformManager().ketangpaiBaseUrl,
      ),
      platformOptions: _signOptions('ketangpai.sign.scan'),
    );

    return mapResult(
      response.data,
      successWhen: (map) {
        final dataMap = asKetangpaiMap(map['data']);
        return _intOrNull(dataMap?['state']) == 8 || isKetangpaiSuccess(map);
      },
    );
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> getNumberCode({
    required String token,
    required String signId,
  }) async {
    final response = await _postForCurrentUser(
      '/AttenceApi/getDigitAttence',
      body: <String, dynamic>{'id': signId},
      headers: <String, String>{'token': token},
      signProfile: SignRequestProfiles.ketangpaiAttendance(
        baseUrl: PlatformManager().ketangpaiBaseUrl,
      ),
      platformOptions: _readOptions('ketangpai.sign.numberCode'),
    );
    return mapResult(response.data);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> numberSign({
    required String token,
    required String signId,
    required String code,
  }) async {
    final response = await _postForCurrentUser(
      '/AttenceApi/checkin',
      body: <String, dynamic>{'id': signId, 'code': code},
      headers: <String, String>{'token': token},
      signProfile: SignRequestProfiles.ketangpaiAttendance(
        baseUrl: PlatformManager().ketangpaiBaseUrl,
      ),
      platformOptions: _signOptions('ketangpai.sign.number'),
    );
    return mapResult(response.data);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> gpsSign({
    required String token,
    required String signId,
    required String latitude,
    required String longitude,
    String accuracy = '100',
  }) async {
    final response = await _postForCurrentUser(
      '/AttenceApi/checkin',
      body: <String, dynamic>{
        'id': signId,
        'code': '',
        'unusual': '',
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'clienttype': 1,
      },
      headers: <String, String>{'token': token},
      signProfile: SignRequestProfiles.ketangpaiAttendance(
        baseUrl: PlatformManager().ketangpaiBaseUrl,
      ),
      platformOptions: _signOptions('ketangpai.sign.gps'),
    );
    return mapResult(response.data);
  }

  static Future<KetangpaiServiceResult<List<Map<String, dynamic>>>>
  getExamList({required String courseId, int page = 1, int limit = 50}) async {
    final response = await _postForCurrentUser(
      '/FutureV2/CourseMeans/getCourseContent',
      body: <String, dynamic>{
        'courseid': courseId,
        'contenttype': 6,
        'dirid': 0,
        'lessonlink': <dynamic>[],
        'sort': <dynamic>[],
        'page': page,
        'limit': limit,
        'desc': 3,
        'courserole': 0,
        'vtr_type': '',
      },
      platformOptions: _readOptions('ketangpai.exam.list'),
    );
    return listResult(response.data);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> getExamDetail({
    required String courseId,
    required String testPaperId,
  }) async {
    final response = await _postForCurrentUser(
      '/TestpaperApi/testpaperdetails',
      body: <String, dynamic>{'courseid': courseId, 'testpaperid': testPaperId},
      platformOptions: _readOptions('ketangpai.exam.detail'),
    );
    return mapResult(response.data);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> getExamQuestions({
    required String courseId,
    required String testPaperId,
  }) async {
    final response = await _postForCurrentUser(
      '/TestpaperApi/doSubjectList',
      body: <String, dynamic>{
        'courseid': courseId,
        'testpaperid': testPaperId,
        'testCode': 'undefined',
      },
      platformOptions: _readOptions('ketangpai.exam.questions'),
    );
    return mapResult(response.data);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> saveAnswer({
    required String courseId,
    required String testPaperId,
    required String subjectId,
    required String answer,
    String attachment = '',
  }) async {
    final response = await _postForCurrentUser(
      '/TestpaperApi/saveAnswer',
      body: <String, dynamic>{
        'courseid': courseId,
        'testpaperid': testPaperId,
        'subjectid': subjectId,
        'answer': answer,
        'attachment': attachment,
      },
      platformOptions: _submitOptions('ketangpai.exam.saveAnswer'),
    );
    return mapResult(response.data);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> submitExam({
    required String courseId,
    required String testPaperId,
  }) async {
    final response = await _postForCurrentUser(
      '/TestpaperApi/handup',
      body: <String, dynamic>{'courseid': courseId, 'testpaperid': testPaperId},
      platformOptions: _submitOptions('ketangpai.exam.submit'),
    );
    return mapResult(response.data);
  }

  static void logResult(String operation, KetangpaiServiceResult result) {
    ApiService.appendExternalConsoleLog(
      '课堂派',
      '$operation: ${result.success ? "成功" : "失败"} ${result.message}',
    );
  }
}
