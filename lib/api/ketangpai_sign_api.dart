import 'package:dio/dio.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

/// 课堂派签到 API（参考 ktpwarp-server 实现）
class KetangpaiSignApi {
  /// 获取未完成的签到列表
  static Future<Response> getNotFinishAttence(String courseId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取签到列表');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    final url = '/AttenceApi/getNotFinishAttenceStudent';
    final body = {
      'courseid': courseId,
      'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return await context.sendRequest(
      url,
      method: 'POST',
      body: body,
    );
  }

  /// 数字签到 - 获取签到码
  static Future<Response> getDigitAttence(String attenceId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取签到码');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    final url = '/AttenceApi/getDigitAttence';
    final body = {
      'id': attenceId,
      'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return await context.sendRequest(
      url,
      method: 'POST',
      body: body,
    );
  }

  /// 执行签到（数字签到、GPS签到、签入签出）
  static Future<Response> checkin({
    required String attenceId,
    String code = '',
    String latitude = '',
    String longitude = '',
    String accuracy = '',
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    final url = '/AttenceApi/checkin';
    final body = {
      'id': attenceId,
      'code': code,
      'unusual': '',
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'clienttype': 1,
      'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return await context.sendRequest(
      url,
      method: 'POST',
      body: body,
    );
  }

  /// 二维码签到
  static Future<Response> attenceResult({
    required String ticketid,
    required String expire,
    required String sign,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    final url = '/AttenceApi/AttenceResult';
    final body = {
      'ticketid': ticketid,
      'expire': expire,
      'sign': sign,
      'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
    };

    return await context.sendRequest(
      url,
      method: 'POST',
      body: body,
    );
  }

  /// 检查签到状态是否成功
  static bool isSignSuccess(Map<String, dynamic>? responseData) {
    if (responseData == null) return false;

    // 数字签到、GPS签到、签入签出：state == 1
    // 二维码签到：state == 8
    final state = responseData['state'];
    return state == 1 || state == 8;
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
      return message;
    }

    return '签到失败';
  }
}
