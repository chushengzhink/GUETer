import 'package:dio/dio.dart';
import 'tronclass_client.dart';
import '../session/account.dart';
import '../utils/user_agent.dart';
import '../platform.dart';

class TronclassSignApi {
  /// 二维码签到（使用 TronclassClient）
  static Future<Response> signQr({
    required String rollcallId,
    required String data,
    required String deviceId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final client = await TronclassClient.getInstance(userId);
    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    final headers = UserAgentHelper.getTronclassHeaders(userAgent, base);

    final url = '/api/rollcall/$rollcallId/answer_qr_rollcall';

    final body = {
      'data': data,
      'deviceId': deviceId,
    };

    return await client.dio.put(
      url,
      data: body,
      options: Options(headers: headers),
    );
  }

  /// 数字签到（使用 TronclassClient）
  static Future<Response> signNumber({
    required String rollcallId,
    required String numberCode,
    required String deviceId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final client = await TronclassClient.getInstance(userId);
    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    final headers = UserAgentHelper.getTronclassHeaders(userAgent, base);

    final url = '/api/rollcall/$rollcallId/answer_number_rollcall';

    final body = {
      'numberCode': numberCode,
      'deviceId': deviceId,
    };

    return await client.dio.put(
      url,
      data: body,
      options: Options(headers: headers),
    );
  }

  /// 雷达签到（使用 TronclassClient）
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

    final client = await TronclassClient.getInstance(userId);
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

    return await client.dio.put(
      url,
      data: body,
      options: Options(headers: headers),
    );
  }

  /// 获取签到列表（使用 TronclassClient）
  static Future<Response> getRollcalls() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取签到列表');
    }

    final client = await TronclassClient.getInstance(userId);
    final userAgent = await UserAgentHelper.getTronclassUA();
    final base = PlatformManager().tronclassBaseUrl;
    final headers = UserAgentHelper.getTronclassHeaders(userAgent, base);

    final url = '/api/radar/rollcalls?api_version=1.1.0';

    return await client.dio.get(
      url,
      options: Options(headers: headers),
    );
  }

  /// 判断签到是否成功
  static bool isSignSuccess(Response response) {
    try {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final code = data['code'] ?? data['status'];
        return code == 0 || code == 200 || code == '0' || code == '200';
      }
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 获取签到响应消息
  static String getSignMessage(Response response) {
    try {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['message']?.toString() ??
               data['msg']?.toString() ??
               data['error']?.toString() ??
               '签到完成';
      }
      return '签到完成';
    } catch (e) {
      return '签到完成';
    }
  }
}
