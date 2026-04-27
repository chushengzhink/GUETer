import 'package:dio/dio.dart';
import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';
import '../utils/user_agent.dart';

class TronclassSignApi {
  /// 二维码签到（使用独立 Dio 实例）
  static Future<Response> signQr({
    required String rollcallId,
    required String data,
    required String deviceId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.tronclass,
      userId: userId,
    );

    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    final headers = UserAgentHelper.getTronclassHeaders(userAgent, base);

    final url = '/api/rollcall/$rollcallId/answer_qr_rollcall';

    final body = {
      'data': data,
      'deviceId': deviceId,
    };

    return await context.sendRequest(
      url,
      method: 'PUT',
      headers: headers,
      body: body,
    );
  }

  /// 数字签到（使用独立 Dio 实例）
  static Future<Response> signNumber({
    required String rollcallId,
    required String numberCode,
    required String deviceId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.tronclass,
      userId: userId,
    );

    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    final headers = UserAgentHelper.getTronclassHeaders(userAgent, base);

    final url = '/api/rollcall/$rollcallId/answer_number_rollcall';

    final body = {
      'numberCode': numberCode,
      'deviceId': deviceId,
    };

    return await context.sendRequest(
      url,
      method: 'PUT',
      headers: headers,
      body: body,
    );
  }

  /// 雷达签到（使用独立 Dio 实例）
  static Future<Response> signRadar({
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
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.tronclass,
      userId: userId,
    );

    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    final headers = UserAgentHelper.getTronclassHeaders(userAgent, base);

    final url = '/api/rollcall/$rollcallId/answer?api_version=1.1.2';

    final body = {
      'deviceId': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accuracy': accuracy,
      'altitude': altitude,
      'altitudeAccuracy': altitudeAccuracy,
      'heading': heading,
    };

    return await context.sendRequest(
      url,
      method: 'PUT',
      headers: headers,
      body: body,
    );
  }

  /// 获取签到列表（使用独立 Dio 实例）
  static Future<Response> getRollcalls() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取签到列表');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.tronclass,
      userId: userId,
    );

    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    final headers = UserAgentHelper.getTronclassHeaders(userAgent, base);

    final url = '/api/radar/rollcalls?api_version=1.1.0';

    return await context.sendRequest(
      url,
      method: 'GET',
      headers: headers,
    );
  }

  /// 检查签到状态是否成功
  static bool isSignSuccess(Map<String, dynamic>? responseData) {
    if (responseData == null) return false;

    final status = responseData['status']?.toString().toLowerCase();
    return status == 'on_call' || status == 'on_call_fine';
  }

  /// 获取签到结果消息
  static String getSignMessage(Map<String, dynamic>? responseData, {bool success = false}) {
    if (success) {
      return '签到成功';
    }

    if (responseData == null) {
      return '签到失败，请稍后再试';
    }

    final message = responseData['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return _mapErrorMessage(message);
    }

    final status = responseData['status']?.toString();
    if (status != null) {
      return _mapStatusMessage(status);
    }

    return '签到失败，请稍后再试';
  }

  /// 映射错误消息
  static String _mapErrorMessage(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('ended') || lowerMessage.contains('closed')) {
      return '签到已结束';
    }
    if (lowerMessage.contains('not started')) {
      return '签到尚未开始';
    }
    if (lowerMessage.contains('already')) {
      return '您已签到，无需重复签到';
    }
    if (lowerMessage.contains('invalid') || lowerMessage.contains('wrong')) {
      return '签到码错误';
    }
    if (lowerMessage.contains('timeout')) {
      return '签到超时，请重试';
    }
    if (lowerMessage.contains('location') || lowerMessage.contains('distance')) {
      return '位置不符合要求';
    }

    return message;
  }

  /// 映射状态消息
  static String _mapStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'on_call':
      case 'on_call_fine':
      case 'present':
        return '签到成功';
      case 'late':
        return '迟到';
      case 'absent':
        return '缺席';
      case 'excused':
        return '请假';
      case 'ended':
      case 'closed':
        return '签到已结束';
      default:
        return '签到失败';
    }
  }
}
