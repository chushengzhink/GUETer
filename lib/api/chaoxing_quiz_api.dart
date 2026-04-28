import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

/// 学习通随堂练习/投票/问卷 API（参考 yuketang 项目）
class ChaoxingQuizApi {
  /// 检查练习是否开启
  static Future<bool?> checkStatus(String classId, String activeId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法检查练习状态');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/pptTestPaperStu/checkActiveStatus';
      final formData = {
        'classId': classId,
        'activePrimaryId': activeId,
        'appType': '15',
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: formData,
      );

      // {"status":1,"type":42,"source":15}
      if (response.data['status'] != null) {
        return response.data['status'] == 1;
      }
    } catch (e) {
      debugPrint('[ChaoxingQuizApi] checkStatus error: $e');
    }
    return null;
  }

  /// 提交答案（随堂练习）
  static Future<Map<String, dynamic>?> submitAnswer(
    String classId,
    String courseId,
    String activeId,
    String answer,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法提交答案');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/studentQuestion/doQuestionAnswering';
      final params = {
        'activeId': activeId,
        'courseId': courseId,
        'classId': classId,
        'DB_STRATEGY': 'PRIMARY_KEY',
        'STRATEGY_PARA': 'activeId',
      };
      final headers = {'Content-Type': 'application/json'};

      final response = await context.sendRequest(
        url,
        method: 'POST',
        params: params,
        headers: headers,
        body: answer,
      );

      // {"result":1,"msg":"success","data":null,"errorMsg":null}
      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingQuizApi] submitAnswer error: $e');
      return null;
    }
  }

  /// 向群聊发送回执消息（不必要）
  static Future<Map<String, dynamic>?> answerReceipt(
    String classId,
    String activeId,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法发送回执');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/pptTestPaperStu/answerReceipt';
      final params = {
        'classId': classId,
        'activePrimaryId': activeId,
        'uid': userId,
        'chatId': '',
        'appType': '15',
        'openChatView': 'false',
      };

      final response = await context.sendRequest(
        url,
        method: 'GET',
        params: params,
      );

      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingQuizApi] answerReceipt error: $e');
      return null;
    }
  }

  /// 获取测试详细（Web）
  /// 投票、问卷使用
  static Future<Map<String, dynamic>?> getQuizDetail(
    String activeId, [
    bool v2 = false,
  ]) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取测试详情');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url = v2
          ? 'https://mobilelearn.chaoxing.com/v2/apis/quiz/quizDetail?activeId=$activeId'
          : 'https://mobilelearn.chaoxing.com/v2/apis/quiz/quizDetail2?activeId=$activeId&moreClassAttendEnc=&DB_STRATEGY=PRIMARY_KEY&STRATEGY_PARA=activeId';

      // 两个接口返回内容相同，但是随堂练习用 v2
      // 该接口不会返回 isAnswer
      final response = await context.sendRequest(url, method: 'GET');
      return response.data['data'];
    } catch (e) {
      debugPrint('[ChaoxingQuizApi] getQuizDetail error: $e');
      return null;
    }
  }

  /// 投票提交
  static Future<Map<String, dynamic>?> submitVote(
    String courseId,
    String classId,
    String activeId,
    String questionId,
    String answer,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法提交投票');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/widget/quickvote/doQuestion';
      // WebAPI: https://mobilelearn.chaoxing.com/v2/apis/qvote/doQuestion
      // AppAPI 返回内容更少，更高效
      final formData = {
        'courseId': courseId,
        'classId': classId,
        'activeId': activeId,
        'questionId': questionId,
        'option': answer,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: formData,
      );

      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingQuizApi] submitVote error: $e');
      return null;
    }
  }

  /// 问卷提交
  static Future<Map<String, dynamic>?> submitQuestionnaire(
    String courseId,
    String classId,
    String activeId,
    Map<String, List<String>> answers,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法提交问卷');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/studentQuestion/doQuestion';
      // AppAPI: https://mobilelearn.chaoxing.com/pptTestPaperStu/doQuestion
      // AppAPI 参数较多

      var formData =
          'preventsubmit=1&courseId=$courseId&classId=$classId&activeId=$activeId';
      for (var entry in answers.entries) {
        formData += '&questionId=${entry.key}';
        for (var answer in entry.value) {
          formData += '&answer${entry.key}=$answer';
        }
      }

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: formData,
      );

      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingQuizApi] submitQuestionnaire error: $e');
      return null;
    }
  }
}
