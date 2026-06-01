import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

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

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final url = '/FutureV2/CourseMeans/getCourseContent';
      final body = {
        'courseid': courseId,
        'contenttype': 6, // 6 = 测试/考试
        'dirid': 0,
        'lessonlink': [],
        'sort': [],
        'page': page,
        'limit': limit,
        'desc': 3,
        'courserole': 0,
        'vtr_type': '',
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: body,
      );

      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        if (status == 1) {
          final data = response.data['data'];
          if (data is Map<String, dynamic>) {
            final list = data['list'];
            if (list is List) {
              return list
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          }
        }
      }

      return [];
    } finally {
      context.dispose();
    }
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

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final url = '/TestpaperApi/testpaperdetails';
      final body = {
        'courseid': courseId,
        'testpaperid': testPaperId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: body,
      );

      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        if (status == 1) {
          return response.data['data'];
        }
      }

      return null;
    } finally {
      context.dispose();
    }
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

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final url = '/TestpaperApi/doSubjectList';
      final body = {
        'courseid': courseId,
        'testpaperid': testPaperId,
        'testCode': 'undefined',
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: body,
      );

      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        if (status == 1) {
          return response.data['data'];
        }
      }

      return null;
    } finally {
      context.dispose();
    }
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

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final url = '/TestpaperApi/saveAnswer';
      final body = {
        'courseid': courseId,
        'testpaperid': testPaperId,
        'subjectid': subjectId,
        'answer': answer,
        'attachment': attachment,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: body,
      );

      if (response.data is Map<String, dynamic>) {
        final code = response.data['code'];
        return code == 10000;
      }

      return false;
    } finally {
      context.dispose();
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

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final url = '/TestpaperApi/handup';
      final body = {
        'courseid': courseId,
        'testpaperid': testPaperId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: body,
      );

      if (response.data is Map<String, dynamic>) {
        final code = response.data['code'];
        final message = response.data['message']?.toString() ?? '';
        return {
          'success': code == 10000,
          'message': message,
        };
      }

      return {
        'success': false,
        'message': '提交失败',
      };
    } finally {
      context.dispose();
    }
  }

  /// 解析题目类型
  static String parseQuestionType(int type) {
    switch (type) {
      case 1:
        return '单选题';
      case 2:
        return '多选题';
      case 3:
        return '判断题';
      case 4:
        return '填空题';
      case 5:
        return '简答题';
      default:
        return '未知题型';
    }
  }
}
