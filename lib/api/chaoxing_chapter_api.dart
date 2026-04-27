import 'package:flutter/foundation.dart';

/// 学习通章节 API（占位实现）
class ChaoxingChapterApi {
  static Future<Map<String, dynamic>?> getChapterList(String courseId, String classId) async {
    debugPrint('ChaoxingChapterApi.getChapterList: courseId=$courseId classId=$classId');
    return null;
  }

  static Future<List<Map<String, dynamic>>> getUnfinishedTasks(String courseId, String classId, String cpi) async {
    debugPrint('ChaoxingChapterApi.getUnfinishedTasks: courseId=$courseId classId=$classId cpi=$cpi');
    return [];
  }
}
