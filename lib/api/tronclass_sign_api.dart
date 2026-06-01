import 'package:dio/dio.dart';

import '../models/tronclass_rollcalls.dart';
import '../platform.dart';
import '../session/account.dart';
import '../utils/user_agent.dart';
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

  static Future<Response<Map<String, dynamic>>> signQr({
    required String rollcallId,
    required String data,
    required String deviceId,
  }) async {
    final client = await _client();
    final headers = await _headers();

    return client.dio.put<Map<String, dynamic>>(
      '/api/rollcall/$rollcallId/answer_qr_rollcall',
      data: {'data': data, 'deviceId': deviceId},
      options: Options(headers: headers, responseType: ResponseType.json),
    );
  }

  static Future<Response<Map<String, dynamic>>> signNumber({
    required String rollcallId,
    required String numberCode,
    required String deviceId,
  }) async {
    final client = await _client();
    final headers = await _headers();

    return client.dio.put<Map<String, dynamic>>(
      '/api/rollcall/$rollcallId/answer_number_rollcall',
      data: {'numberCode': numberCode, 'deviceId': deviceId},
      options: Options(headers: headers, responseType: ResponseType.json),
    );
  }

  static Future<Response<Map<String, dynamic>>> signRadar({
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

    return client.dio.put<Map<String, dynamic>>(
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
      options: Options(headers: headers, responseType: ResponseType.json),
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
    if (responseData is! Map<String, dynamic>) {
      return _mapMessage('retry');
    }

    final rawMessage =
        responseData['message']?.toString() ??
        responseData['msg']?.toString() ??
        responseData['error']?.toString();
    if (rawMessage != null && rawMessage.isNotEmpty) {
      return _mapMessage(rawMessage);
    }

    switch (responseData['status']?.toString()) {
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

  static String _mapMessage(String key) {
    return _messageMap[key] ?? key;
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
}
