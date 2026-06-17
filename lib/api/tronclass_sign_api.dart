import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/tronclass_rollcalls.dart';
import '../platform.dart';
import '../session/account.dart';
import '../utils/user_agent.dart';
import 'api_service.dart';
import 'sign_request_profile.dart';
import 'tronclass_client.dart';

class TronclassSignApi {
  static const Map<String, String> _messageMap = {
    'rollcall_closed': '二维码签到已结束',
    'device_used': '该设备已签到，请更换设备重新扫描',
    'QR_code_expired': '签到二维码已过期',
    'unknown_student': '您还不是本课学生，请先加入课程',
    'failed': '签到失败，请及时告知老师',
    'wrongNumberCode': '签到密码错误，请重试',
    'rollcallFinished': '签到失败，点名已结束',
    'getPositionFailed': '获取位置信息失败',
    'getPositionFailedTimeout': '获取位置信息超时',
    'getPositionFailedPermissionDeined': '没有权限获取定位信息',
    'getPositionFailedUnavailable': '获取定位功能不可用',
    'retry': '签到失败，请重试',
    'outofScope': '当前位置异常，可能导致签到失败，请重新签到',
    'deviceAlreadyInUse': '已有学生使用该设备签到，请更换设备再试',
    'success': '签到成功',
  };

  static Future<Response<dynamic>> signQr({
    required String rollcallId,
    required String data,
    required String deviceId,
  }) async {
    final client = await _client();
    final headers = await _headers();

    return _sendRollcallRequest(
      profile: SignRequestProfiles.tronclassRollcall(
        baseUrl: PlatformManager().tronclassBaseUrl,
      ),
      headers: headers,
      send: (effectiveHeaders) {
        return client.dio.put<dynamic>(
          '/api/rollcall/$rollcallId/answer_qr_rollcall',
          data: {'data': data, 'deviceId': deviceId},
          options: Options(
            headers: effectiveHeaders,
            responseType: ResponseType.json,
          ),
        );
      },
    );
  }

  static Future<Response<dynamic>> signNumber({
    required String rollcallId,
    required String numberCode,
    required String deviceId,
  }) async {
    final client = await _client();
    final headers = await _headers();

    return _sendRollcallRequest(
      profile: SignRequestProfiles.tronclassRollcall(
        baseUrl: PlatformManager().tronclassBaseUrl,
      ),
      headers: headers,
      send: (effectiveHeaders) {
        return client.dio.put<dynamic>(
          '/api/rollcall/$rollcallId/answer_number_rollcall',
          data: {'numberCode': numberCode, 'deviceId': deviceId},
          options: Options(
            headers: effectiveHeaders,
            responseType: ResponseType.json,
          ),
        );
      },
    );
  }

  static Future<Response<dynamic>> signRadar({
    required String rollcallId,
    required String deviceId,
    required double latitude,
    required double longitude,
    required double accuracy,
    double altitude = 0,
    double? altitudeAccuracy,
    double? speed,
    String? heading,
  }) async {
    final client = await _client();
    final headers = await _headers();

    return _sendRollcallRequest(
      profile: SignRequestProfiles.tronclassRollcall(
        baseUrl: PlatformManager().tronclassBaseUrl,
      ),
      headers: headers,
      send: (effectiveHeaders) {
        return client.dio.put<dynamic>(
          '/api/rollcall/$rollcallId/answer?api_version=1.1.2',
          data: {
            'deviceId': deviceId,
            'latitude': latitude,
            'longitude': longitude,
            'speed': speed,
            'accuracy': accuracy,
            'altitude': altitude,
            'altitudeAccuracy': altitudeAccuracy,
            'heading': heading,
          },
          options: Options(
            headers: effectiveHeaders,
            responseType: ResponseType.json,
          ),
        );
      },
    );
  }

  static Future<RollcallsResponse> getRollcalls() async {
    final client = await _client();
    final headers = await _headers();

    final response = await client.dio.get<Map<String, dynamic>>(
      '/api/radar/rollcalls?api_version=1.1.0',
      options: Options(headers: headers, responseType: ResponseType.json),
    );

    final data = response.data;
    if (data == null) {
      throw Exception('获取签到列表失败');
    }
    return RollcallsResponse.fromJson(data);
  }

  static bool isSignSuccess(Response response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      return false;
    }
    return response.statusCode == 200 &&
        data['status']?.toString() == 'on_call';
  }

  static String getSignMessage(dynamic responseData) {
    final normalized = normalizeSignResponseData(responseData);
    if (normalized is! Map<String, dynamic>) {
      return '畅课返回异常，可能登录态失效';
    }

    final rawMessage =
        normalized['message']?.toString() ??
        normalized['msg']?.toString() ??
        normalized['error']?.toString();
    if (rawMessage != null && rawMessage.isNotEmpty) {
      return _mapMessage(rawMessage);
    }

    switch (normalized['status']?.toString()) {
      case 'on_call':
        return _mapMessage('success');
      case 'on_call_fine':
        return '已签到';
      case 'present':
        return '出席';
      case 'late':
        return '迟到';
      case 'excused':
        return '请假';
      case 'absent':
        return '缺席';
      default:
        return _mapMessage('retry');
    }
  }

  static bool isQrCodeExpired(dynamic responseData) {
    final normalized = normalizeSignResponseData(responseData);
    if (normalized is! Map<String, dynamic>) {
      return false;
    }
    final rawMessage =
        normalized['message']?.toString() ??
        normalized['msg']?.toString() ??
        normalized['error']?.toString();
    return rawMessage == 'QR_code_expired';
  }

  static String _mapMessage(String key) {
    return _messageMap[key] ?? key;
  }

  static dynamic normalizeSignResponseData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        return {'message': '畅课返回空响应，可能登录态失效', 'raw': ''};
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        // fall through to friendly non-JSON response
      }
      final snippet = trimmed.length > 120
          ? '${trimmed.substring(0, 120)}...'
          : trimmed;
      return {'message': '畅课返回非 JSON，可能登录态失效', 'raw': snippet};
    }
    if (data == null) {
      return {'message': '畅课返回空响应，可能登录态失效'};
    }
    return {'message': '畅课返回异常，可能登录态失效', 'raw': data.toString()};
  }

  static Future<TronclassClient> _client() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法访问畅课签到接口');
    }
    return TronclassClient.getInstance(userId);
  }

  static Future<Map<String, dynamic>> _headers() async {
    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    return UserAgentHelper.getTronclassHeaders(userAgent, base);
  }

  static Future<Response<dynamic>> _sendRollcallRequest({
    required SignRequestProfile profile,
    required Map<String, dynamic> headers,
    required Future<Response<dynamic>> Function(Map<String, dynamic>? headers)
    send,
  }) async {
    final response = await SignRequestExecutor.run(
      profile: profile,
      headers: headers.map((key, value) => MapEntry(key, value.toString())),
      legacyHeaders: headers.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      operation: 'tronclass rollcall',
      logSink: ApiService.appendExternalConsoleLog,
      send: (effectiveHeaders) => send(effectiveHeaders),
    );
    return Response<dynamic>(
      data: normalizeSignResponseData(response.data),
      headers: response.headers,
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      redirects: response.redirects,
      extra: response.extra,
      isRedirect: response.isRedirect,
    );
  }
}
