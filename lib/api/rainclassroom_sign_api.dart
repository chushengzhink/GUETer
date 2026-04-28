import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

/// 雨课堂 API（仅核心功能，参考 yuketang 项目）
///
/// 核心功能：
/// 1. 动态二维码签到
/// 2. PPT 展示
/// 3. 课堂答题（支持延时提交）
class RainClassroomSignApi {
  // userId -> [bearerToken, lessonToken]
  static final Map<String, List<String>> _tokens = {};

  static String get _currentSessionId => AccountManager.currentSessionId!;

  /// 获取当前用户的 bearerToken
  static String? getBearerToken() {
    return _tokens[_currentSessionId]?[0];
  }

  /// 获取当前用户的 lessonToken
  static String? getLessonToken() {
    return _tokens[_currentSessionId]?[1];
  }

  /// 设置 token（内部使用）
  static void _setToken(String bearerToken, String lessonToken) {
    _tokens[_currentSessionId] = [bearerToken, lessonToken];
  }

  // ==================== 1. 动态二维码签到 ====================

  /// 扫描二维码
  /// 返回值：0 = 成功，51203 = 二维码过期，其他 = 错误码
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
      final url = '/api/v3/app/scan';
      final jsonData = {'url': qrCodeUrl};

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );

      final data = response.data;
      final int code = data['code'];

      if (code == 0) {
        // {"code":0,"msg":"OK","data":{"type":"checkin","value":"1632189922935066880"}}
        final lessonId = data['data']['value'];
        return await checkIn(lessonId);
      } else {
        // {"code":51203,"msg":"动态二维码过期","data":{"type":"default","value":""}}
        return code;
      }
    } catch (e) {
      debugPrint('[RainClassroomSignApi] scan error: $e');
      return null;
    }
  }

  /// 签到进入课堂
  /// 返回值：0 = 成功，50070 = 需要扫码，其他 = 错误码
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
      final url = '/api/v3/lesson/checkin';
      final jsonData = {
        'source': 21, // 21: 扫码跳转 23: 点击课堂
        'lessonId': lessonId,
        'joinIfNotIn': true,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );

      final data = response.data;
      final int code = data['code'];

      if (code == 0) {
        // 保存 bearerToken 和 lessonToken
        final bearerToken = response.headers.value('set-auth');
        final lessonToken = data['data']['lessonToken'];

        if (bearerToken != null && lessonToken != null) {
          _setToken(bearerToken, lessonToken);
        }

        return 0;
      } else {
        // {"code":50070,"msg":"DYNAMIC_QR_CHECK_IN_REFUSED","data":null}
        return code;
      }
    } catch (e) {
      debugPrint('[RainClassroomSignApi] checkIn error: $e');
      return null;
    }
  }

  // ==================== 2. PPT 展示 ====================

  /// 获取 PPT 内容
  static Future<Map<String, dynamic>?> getPresentation(
    String presentationId,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取 PPT');
    }

    final bearerToken = getBearerToken();
    if (bearerToken == null) {
      debugPrint('[RainClassroomSignApi] bearerToken 为空，请先签到');
      return null;
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.rainClassroom,
      userId: userId,
    );

    try {
      final url =
          '/api/v3/lesson/presentation/fetch?presentation_id=$presentationId';
      final headers = {'authorization': 'Bearer $bearerToken'};

      final response = await context.sendRequest(
        url,
        method: 'GET',
        headers: headers,
      );

      return response.data['data'];
    } catch (e) {
      debugPrint('[RainClassroomSignApi] getPresentation error: $e');
      return null;
    }
  }

  // ==================== 3. 课堂答题（支持延时提交）====================

  /// 提交答案
  ///
  /// [problemId] 问题 ID
  /// [problemType] 问题类型：1=单选 2=多选 3=投票 4=填空 5=主观 6=判断
  /// [retry] 是否为重试提交
  /// [time] 延时提交的时间戳（毫秒），null 表示立即提交
  /// [options] 选择题答案（单选/多选/判断）
  /// [content] 主观题文本内容
  /// [imageUrls] 主观题图片 URL 列表
  static Future<Map<String, dynamic>?> submitAnswer({
    required String problemId,
    required int problemType,
    bool retry = false,
    int? time,
    List<String>? options,
    String? content,
    List<String>? imageUrls,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法提交答案');
    }

    final bearerToken = getBearerToken();
    if (bearerToken == null) {
      debugPrint('[RainClassroomSignApi] bearerToken 为空，请先签到');
      return null;
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.rainClassroom,
      userId: userId,
    );

    try {
      final url = retry
          ? '/api/v3/lesson/problem/retry'
          : '/api/v3/lesson/problem/answer';

      final headers = {'authorization': 'Bearer $bearerToken'};

      final timestampMS = time ?? DateTime.now().millisecondsSinceEpoch;

      late dynamic result;
      if (problemType == 5) {
        var pics = [];
        if (imageUrls != null && imageUrls.isNotEmpty) {
          for (var imageUrl in imageUrls) {
            pics.add({
              'pic': imageUrl,
              'thumb': '$imageUrl?imageView2/2/w/568',
            });
          }
        } else {
          pics = [
            {'pic': '', 'thumb': ''},
          ];
        }

        result = {
          'content': content ?? '',
          'pics': pics,
          'videos': [],
        };
      } else {
        result = options;
      }

      var jsonData = {
        'problemId': problemId,
        'dt': timestampMS,
        'problemType': problemType,
        'result': result,
      };

      if (retry) {
        jsonData['retry_times'] = null;
        jsonData = {
          'problems': [jsonData],
        };
      }

      final response = await context.sendRequest(
        url,
        method: 'POST',
        headers: headers,
        body: jsonData,
      );

      return response.data;
    } catch (e) {
      debugPrint('[RainClassroomSignApi] submitAnswer error: $e');
      return null;
    }
  }

  // ==================== 辅助方法 ====================

  /// 检查签到状态是否成功
  static bool isSignSuccess(int? code) {
    return code == 0;
  }

  /// 获取签到结果消息
  static String getSignMessage(int? code) {
    if (code == null) {
      return '签到失败，请稍后再试';
    }

    switch (code) {
      case 0:
        return '签到成功';
      case 50070:
        return '该课堂已开启动态二维码签到，请扫码签到进班';
      case 51203:
        return '动态二维码已过期';
      default:
        return '签到失败，错误码：$code';
    }
  }

  /// 检查答题是否成功
  static bool isAnswerSuccess(Map<String, dynamic>? response) {
    if (response == null) return false;

    final code = response['code'];
    return code == 0;
  }

  /// 获取答题结果消息
  static String getAnswerMessage(Map<String, dynamic>? response) {
    if (response == null) {
      return '提交失败，请稍后再试';
    }

    final code = response['code'];
    if (code == 0) {
      return '提交成功';
    }

    final msg = response['msg'];
    return msg ?? '提交失败，错误码：$code';
  }
}
