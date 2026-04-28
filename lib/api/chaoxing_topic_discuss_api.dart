import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';
import '../utils/encrypt.dart';

/// 学习通主题讨论 API（参考 yuketang 项目）
class ChaoxingTopicDiscussApi {
  /// 获取主题讨论
  static Future<Map<String, dynamic>?> getTopic(String topicId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取主题讨论');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url = 'https://groupyd.chaoxing.com/apis/topic/getTopic';
      final params = EncryptionUtil.getEncParams({});
      final formData = {'puid': userId, 'maxW': '1080', 'topicId': topicId};

      final response = await context.sendRequest(
        url,
        method: 'POST',
        params: params,
        body: formData,
      );

      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingTopicDiscussApi] getTopic error: $e');
      return null;
    }
  }

  /// 获取回复
  static Future<Map<String, dynamic>?> getReplies(String uuid) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取回复');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url = 'https://groupyd.chaoxing.com/apis/invitation/getReplys2';
      final params = EncryptionUtil.getEncParams({});
      final formData = {
        'puid': userId,
        'uuid': uuid,
        'maxW': '1080',
        'lastValue': '',
        'lastAuxValue': '',
        'order': '0',
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        params: params,
        body: formData,
      );

      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingTopicDiscussApi] getReplies error: $e');
      return null;
    }
  }

  /// 添加回复
  static Future<Map<String, dynamic>?> addReply(
    String message,
    bool anonymous,
    String uuid,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法添加回复');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url = 'https://groupyd.chaoxing.com/apis/invitation/addReply';
      Map<String, String> params = {
        'puid': userId,
        'uuid': EncryptionUtil.getUuid(),
        'maxW': '1080',
        'topicUUID': uuid,
        'anonymous': anonymous ? '1' : '0',
      };
      params.addAll(EncryptionUtil.getEncParams(params));

      final formData = {'content': message};

      final response = await context.sendRequest(
        url,
        method: 'POST',
        params: params,
        body: formData,
      );

      return response.data;
      // {"result":0,"errorMsg":"该话题至少回复10字"}
    } catch (e) {
      debugPrint('[ChaoxingTopicDiscussApi] addReply error: $e');
      return null;
    }
  }
}
