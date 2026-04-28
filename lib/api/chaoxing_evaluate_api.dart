import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

/// 学习通评分 API（参考 yuketang 项目）
class ChaoxingEvaluateApi {
  /// 提交评分
  static Future<bool?> stuSubmitAnswer(
    String activeId,
    String classId,
    String courseId,
    int score, {
    String? content,
    List<int>? scoreList,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法提交评分');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/score/stuSubmitAnswer';
      final formData = {
        'classId': classId,
        'content': content ?? '',
        'score': score.toString(),
        'scoreList': jsonEncode(scoreList ?? []),
        'activeId': activeId,
        'courseId': courseId,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: formData,
      );

      return response.data['result'] == 1;
      // {"result": 1,"msg": "评分成功","data": {"activeId":},"errorMsg": null}
    } catch (e) {
      debugPrint('[ChaoxingEvaluateApi] stuSubmitAnswer error: $e');
      return null;
    }
  }

  /// 获取评分详细信息
  static Future<Map<String, dynamic>?> getStuScoreDetail(
    String activeId,
    String classId,
    String courseId,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取评分详情');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/score/getStuScoreDetail';
      final params = {
        'activeId': activeId,
        'classId': classId,
        'courseId': courseId,
      };

      final response = await context.sendRequest(
        url,
        method: 'GET',
        params: params,
      );

      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingEvaluateApi] getStuScoreDetail error: $e');
      return null;
    }
  }
}
