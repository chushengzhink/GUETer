import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';
import '../utils/rain_auth_manager.dart';

/// 雨课堂考试API（使用独立 Dio 实例）
class RainClassroomExamApi {
  /// 获取考试列表
  static Future<Map<String, dynamic>?> getExamList() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return {
        'code': 50000,
        'msg': '未登录',
        'data': null,
        'auth_expired': true,
      };
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final response = await context.sendRequest(
        '/api/v3/classroom/on-lesson-upcoming-exam',
      );

      if (response.data is Map<String, dynamic>) {
        final code = response.data['code'];
        final msg = response.data['msg']?.toString() ?? '';

        if (code == 50000 || msg.toUpperCase().contains('UNAUTHENTICATED')) {
          debugPrint('getExamList: 认证失效，需要重新登录');
          return {
            'code': 50000,
            'msg': '登录已过期，请重新登录雨课堂',
            'data': null,
            'auth_expired': true,
          };
        }
      }

      return response.data;
    } catch (e) {
      debugPrint('getExamList error: $e');
    }
    return null;
  }

  /// 获取考试封面信息
  static Future<Map<String, dynamic>?> getExamCover(String examId, String classroomId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final response = await context.sendRequest(
        '/v/exam/cover',
        params: {
          'exam_id': examId,
          'classroom_id': classroomId,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('getExamCover error: $e');
    }
    return null;
  }

  /// 生成考试Token
  static Future<Map<String, dynamic>?> generateExamToken(
    String examId,
    String classroomId,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return {
        'status': 401,
        'msg': '未登录',
        'data': null,
      };
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final headers = {
        'Accept': '*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Content-Type': 'application/json',
        'Referer': 'https://www.yuketang.cn/',
      };

      debugPrint('generateExamToken: exam_id=$examId, classroom_id=$classroomId');

      final response = await context.sendRequest(
        '/v/exam/gen_token',
        method: 'POST',
        headers: headers,
        body: {
          'exam_id': examId,
          'classroom_id': classroomId,
        },
      );

      debugPrint('generateExamToken: response status=${response.statusCode}');
      if (response.data != null) {
        debugPrint('generateExamToken: response data keys=${(response.data as Map).keys.join(", ")}');
      }

      return response.data;
    } catch (e) {
      debugPrint('generateExamToken error: $e');
      return {
        'status': 500,
        'msg': '网络请求失败: $e',
        'data': null,
      };
    }
  }

  /// 登录考试系统
  static Future<Map<String, dynamic>?> loginExamSystem({
    required String examId,
    required String userId,
    required String token,
    required String examHost,
  }) async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return {
        'status': 401,
        'msg': '未登录',
        'auth_expired': true,
      };
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: currentUserId,
      );

      final nextUrl = Uri.encodeComponent('$examHost/exam/$examId?isFrom=2');
      final url = '$examHost/login?exam_id=$examId&user_id=$userId&crypt=${Uri.encodeComponent(token)}&next=$nextUrl&language=zh';

      final response = await context.sendRequest(
        url,
        responseType: ResponseType.plain,
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('loginExamSystem: 认证失效 statusCode=${response.statusCode}');
        return {
          'status': response.statusCode,
          'msg': '考试系统登录失败，认证已过期',
          'auth_expired': true,
        };
      }

      final responseData = response.data;
      if (responseData is String) {
        final trimmed = responseData.trim();

        if (trimmed.startsWith('<!DOCTYPE') ||
            trimmed.startsWith('<html') ||
            trimmed.contains('<title>登录</title>') ||
            trimmed.contains('login') && trimmed.contains('<form')) {
          debugPrint('loginExamSystem: 返回HTML登录页，认证失效');
          RainAuthManager.markAuthExpired();
          return {
            'status': 401,
            'msg': '考试系统登录失败，认证已过期。请返回课程列表重新登录雨课堂',
            'auth_expired': true,
          };
        }

        try {
          final jsonData = jsonDecode(trimmed);
          return {
            'status': response.statusCode,
            'msg': 'OK',
            'data': jsonData,
          };
        } catch (e) {
          debugPrint('loginExamSystem: JSON解析失败，响应内容: ${trimmed.substring(0, trimmed.length > 200 ? 200 : trimmed.length)}');
          return {
            'status': 500,
            'msg': '考试系统返回格式错误，可能是认证失效',
            'auth_expired': true,
          };
        }
      }

      return {
        'status': response.statusCode,
        'msg': 'OK',
        'data': responseData,
      };
    } catch (e) {
      debugPrint('loginExamSystem error: $e');

      if (e.toString().contains('FormatException')) {
        return {
          'status': 401,
          'msg': '考试系统登录失败，认证已过期。请返回课程列表重新登录雨课堂',
          'auth_expired': true,
        };
      }

      return {
        'status': 500,
        'msg': '网络请求失败: $e',
      };
    }
  }

  /// 获取考试详情
  static Future<Map<String, dynamic>?> getExamDetail(String examId, String examHost) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/cover?exam_id=$examId';
      final response = await context.sendRequest(
        url,
        responseType: ResponseType.plain,
      );

      final responseData = response.data;
      if (responseData is String) {
        final trimmed = responseData.trim();

        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
          debugPrint('getExamDetail: 返回HTML，认证可能失效');
          return {
            'errcode': 401,
            'errmsg': '考试系统认证失效',
            'data': null,
          };
        }

        try {
          return jsonDecode(trimmed) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('getExamDetail: JSON解析失败 $e');
          return null;
        }
      }

      return responseData as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('getExamDetail error: $e');
    }
    return null;
  }

  /// 获取试卷内容
  static Future<Map<String, dynamic>?> getExamPaper(String examId, String examHost) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/show_paper?exam_id=$examId';
      final response = await context.sendRequest(
        url,
        responseType: ResponseType.plain,
      );

      final responseData = response.data;
      if (responseData is String) {
        final trimmed = responseData.trim();
        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
          debugPrint('getExamPaper: 返回HTML，认证失效');
          return {
            'errcode': 401,
            'errmsg': '考试系统认证失效',
            'data': null,
          };
        }
        try {
          return jsonDecode(trimmed) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('getExamPaper: JSON解析失败 $e');
          return null;
        }
      }

      return responseData as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('getExamPaper error: $e');
    }
    return null;
  }

  /// 获取缓存答案
  static Future<Map<String, dynamic>?> getCachedResults(String examId, String examHost) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/cache_results?exam_id=$examId';
      final response = await context.sendRequest(
        url,
        responseType: ResponseType.plain,
      );

      final responseData = response.data;
      if (responseData is String) {
        final trimmed = responseData.trim();
        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
          return {'errcode': 401, 'errmsg': '认证失效', 'data': null};
        }
        try {
          return jsonDecode(trimmed) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('getCachedResults: JSON解析失败 $e');
          return null;
        }
      }

      return responseData as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('getCachedResults error: $e');
    }
    return null;
  }

  /// 刷新考试时间
  static Future<Map<String, dynamic>?> refreshExamTime(String examId, String examHost) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/refresh_time?exam_id=$examId';
      final response = await context.sendRequest(
        url,
        responseType: ResponseType.plain,
      );

      final responseData = response.data;
      if (responseData is String) {
        final trimmed = responseData.trim();
        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
          return {'errcode': 401, 'errmsg': '认证失效', 'data': null};
        }
        try {
          return jsonDecode(trimmed) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('refreshExamTime: JSON解析失败 $e');
          return null;
        }
      }

      return responseData as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('refreshExamTime error: $e');
    }
    return null;
  }

  /// 保存/提交答案
  static Future<Map<String, dynamic>?> saveAnswer({
    required String examId,
    required String examHost,
    required List<Map<String, dynamic>> results,
    required List<int> record,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/answer_problem';
      final body = {
        'results': results,
        'exam_id': examId,
        'record': record,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      return response.data;
    } catch (e) {
      debugPrint('saveAnswer error: $e');
    }
    return null;
  }

  /// 提交试卷
  static Future<Map<String, dynamic>?> submitPaper({
    required String examId,
    required String examHost,
    required List<Map<String, dynamic>> results,
    required List<int> record,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/submit_paper';
      final body = {
        'results': results,
        'exam_id': examId,
        'record': record,
      };

      final response = await context.sendRequest(
        url,
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      return response.data;
    } catch (e) {
      debugPrint('submitPaper error: $e');
    }
    return null;
  }

  /// 获取考试结果
  static Future<Map<String, dynamic>?> getExamResult(String examId, String examHost) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/result?exam_id=$examId';
      final response = await context.sendRequest(url);
      return response.data;
    } catch (e) {
      debugPrint('getExamResult error: $e');
    }
    return null;
  }

  /// 获取考试统计信息
  static Future<Map<String, dynamic>?> getExamStatistics(String examId, String examHost) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      final url = '$examHost/exam_room/statistics?exam_id=$examId';
      final response = await context.sendRequest(url);
      return response.data;
    } catch (e) {
      debugPrint('getExamStatistics error: $e');
    }
    return null;
  }

  /// 上传图片到七牛云
  static Future<String?> uploadImage({
    required String examId,
    required String userId,
    required String imagePath,
    required String examHost,
  }) async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return null;
    }

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: currentUserId,
      );

      final tokenUrl = 'https://www.yuketang.cn/pc/generate_qiniu_token';
      final tokenResponse = await context.sendRequest(
        tokenUrl,
        method: 'POST',
        body: {'bucket_name': 'cms-attachment', 'expired_time': 3600},
      );

      if (tokenResponse.data == null || tokenResponse.data['success'] != true) {
        debugPrint('获取七牛云token失败');
        return null;
      }

      final token = tokenResponse.data['data']['token'];
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = '$timestamp${imagePath.split('/').last}';

      final uploadUrl = 'https://upload.qiniup.com/';
      final formData = {
        'file': imagePath,
        'token': token,
        'key': fileName,
      };

      final uploadResponse = await context.sendRequest(
        uploadUrl,
        method: 'POST',
        body: formData,
      );

      if (uploadResponse.data != null && uploadResponse.data['key'] != null) {
        return 'https://qn-scd1.yuketang.cn/${uploadResponse.data['key']}';
      }
      return null;
    } catch (e) {
      debugPrint('uploadImage error: $e');
    }
    return null;
  }
}
