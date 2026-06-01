import 'package:flutter/foundation.dart';

import 'chaoxing_chapter_api.dart';

class ChaoxingHomeworkApi {
  static Future<List<Map<String, dynamic>>> getHomeworkList(
    String courseId,
    String classId,
  ) async {
    try {
      final cpi = await ChaoxingChapterApi.resolveCourseCpi(courseId, classId);
      if (cpi == null || cpi.isEmpty) {
        return [];
      }

      final tasks = await ChaoxingChapterApi.getUnfinishedTasks(
        courseId,
        classId,
        cpi,
      );
      return tasks.where((item) => item['type']?.toString() == 'work').toList();
    } catch (e) {
      debugPrint('ChaoxingHomeworkApi.getHomeworkList error: $e');
      return [];
    }
  }
}
