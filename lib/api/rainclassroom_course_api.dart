import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

class RainClassroomCourseApi {
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
}
