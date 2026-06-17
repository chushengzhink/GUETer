import 'ketangpai_service.dart';
import '../models/ketangpai_exam.dart';
import '../session/account.dart';

/// 课堂派考试 API
class KetangpaiExamApi {
  /// 获取考试列表
  static Future<List<Map<String, dynamic>>> getExamList({
    required String courseId,
    int page = 1,
    int limit = 50,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取考试列表');
    }

    try {
      final result = await KetangpaiService.getExamList(
        courseId: courseId,
        page: page,
        limit: limit,
      );
      if (!result.success) {
        return [];
      }
      return result.data ?? const <Map<String, dynamic>>[];
    } catch (_) {
      return [];
    }
  }

  static Future<List<KetangpaiExamSummary>> getExamSummariesTyped({
    required String courseId,
    int page = 1,
    int limit = 50,
  }) async {
    final list = await getExamList(
      courseId: courseId,
      page: page,
      limit: limit,
    );
    return list.map(KetangpaiExamSummary.fromJson).toList();
  }

  /// 获取考试详情
  static Future<Map<String, dynamic>?> getExamDetail({
    required String courseId,
    required String testPaperId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取考试详情');
    }

    try {
      final result = await KetangpaiService.getExamDetail(
        courseId: courseId,
        testPaperId: testPaperId,
      );
      if (!result.success) {
        return null;
      }
      return result.data;
    } catch (_) {
      return null;
    }
  }

  static Future<KetangpaiExamDetail?> getExamDetailTyped({
    required String courseId,
    required String testPaperId,
  }) async {
    final data = await getExamDetail(
      courseId: courseId,
      testPaperId: testPaperId,
    );
    if (data == null) return null;
    return KetangpaiExamDetail.fromJson(data);
  }

  /// 获取考试题目列表
  static Future<Map<String, dynamic>?> getExamQuestions({
    required String courseId,
    required String testPaperId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取考试题目');
    }

    try {
      final result = await KetangpaiService.getExamQuestions(
        courseId: courseId,
        testPaperId: testPaperId,
      );
      if (!result.success) {
        return null;
      }
      return result.data;
    } catch (_) {
      return null;
    }
  }

  static Future<KetangpaiExamPaper?> getExamQuestionsTyped({
    required String courseId,
    required String testPaperId,
  }) async {
    final data = await getExamQuestions(
      courseId: courseId,
      testPaperId: testPaperId,
    );
    if (data == null) return null;
    return KetangpaiExamPaper.fromJson(data);
  }

  /// 保存答案
  static Future<bool> saveAnswer({
    required String courseId,
    required String testPaperId,
    required String subjectId,
    required String answer,
    String attachment = '',
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法保存答案');
    }

    try {
      final result = await KetangpaiService.saveAnswer(
        courseId: courseId,
        testPaperId: testPaperId,
        subjectId: subjectId,
        answer: answer,
        attachment: attachment,
      );
      return result.success;
    } catch (_) {
      return false;
    }
  }

  /// 提交试卷
  static Future<Map<String, dynamic>> submitExam({
    required String courseId,
    required String testPaperId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法提交试卷');
    }

    try {
      final result = await KetangpaiService.submitExam(
        courseId: courseId,
        testPaperId: testPaperId,
      );
      return {'success': result.success, 'message': result.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 解析题目类型
  static String parseQuestionType(int type) {
    return KetangpaiQuestionType.fromCode(type).label;
  }
}
