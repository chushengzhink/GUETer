import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

class RainClassroomCourseApi {
  /// 存储每个用户的 bearerToken 和 lessonToken
  static final Map<String, List<String>> _tokens = {};

  static Future<Map<String, dynamic>?> getCourses() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取课程列表');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.rainClassroom,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        '/v/course_meta/learning_list/',
        method: 'GET',
      );

      return response.data;
    } catch (e) {
      debugPrint('[RainClassroomCourseApi] getCourses error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getOnLessonAndUpcomingExam() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取课程信息');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.rainClassroom,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        '/api/v3/classroom/on-lesson-upcoming-exam',
        method: 'GET',
      );

      return response.data;
    } catch (e) {
      debugPrint('[RainClassroomCourseApi] getOnLessonAndUpcomingExam error: $e');
      return null;
    }
  }

  /// 雨课堂动态二维码签到 - 扫描二维码
  /// 返回值：0=成功，51203=二维码过期，其他=错误码，null=异常
  static Future<int?> scan(String qrCodeUrl) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法扫描二维码');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.rainClassroom,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        '/api/v3/app/scan',
        method: 'POST',
        body: {'url': qrCodeUrl},
      );

      final data = response.data;
      if (data == null || data['code'] == null) {
        debugPrint('[RainClassroomCourseApi] scan: invalid response structure');
        return null;
      }

      final int code = data['code'];
      if (code == 0) {
        // {"code":0,"msg":"OK","data":{"type":"checkin","value":"1632189922935066880"}}
        final lessonId = data['data']?['value'];
        if (lessonId == null) {
          debugPrint('[RainClassroomCourseApi] scan: missing lessonId in response');
          return null;
        }
        // 扫描成功后自动签到
        return await checkIn(lessonId);
      } else {
        // {"code":51203,"msg":"动态二维码过期","data":{"type":"default","value":""}}
        return code;
      }
    } catch (e) {
      debugPrint('[RainClassroomCourseApi] scan error: $e');
      return null;
    }
  }

  /// 雨课堂签到
  /// 返回值：0=成功，50070=签到被拒绝，其他=错误码，null=异常
  static Future<int?> checkIn(String lessonId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.rainClassroom,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        '/api/v3/lesson/checkin',
        method: 'POST',
        body: {
          'source': 21, // 21: 扫码跳转 23: 点击课堂
          'lessonId': lessonId,
          'joinIfNotIn': true,
        },
      );

      final data = response.data;
      if (data == null || data['code'] == null) {
        debugPrint('[RainClassroomCourseApi] checkIn: invalid response structure');
        return null;
      }

      final int code = data['code'];
      if (code == 0) {
        // 签到成功，保存 bearerToken 和 lessonToken
        final bearerToken = response.headers.value('set-auth');
        final lessonToken = data['data']?['lessonToken'];

        if (bearerToken != null && lessonToken != null) {
          _setToken(userId, bearerToken, lessonToken);
        } else {
          debugPrint('[RainClassroomCourseApi] checkIn: missing bearerToken or lessonToken');
        }
        return 0;
      } else {
        // {"code":50070,"msg":"DYNAMIC_QR_CHECK_IN_REFUSED","data":null}
        return code;
      }
    } catch (e) {
      debugPrint('[RainClassroomCourseApi] checkIn error: $e');
      return null;
    }
  }

  /// 获取指定用户的 bearerToken
  static String? getBearerToken(String userId) {
    return _tokens[userId]?[0];
  }

  /// 获取指定用户的 lessonToken
  static String? getLessonToken(String userId) {
    return _tokens[userId]?[1];
  }

  /// 保存用户的 token
  static void _setToken(String userId, String bearerToken, String lessonToken) {
    _tokens[userId] = [bearerToken, lessonToken];
  }

  /// 清除指定用户的 token
  static void clearTokens(String userId) {
    _tokens.remove(userId);
  }
}
