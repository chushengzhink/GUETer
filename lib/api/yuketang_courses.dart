import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'api_service.dart';

class YuketangCourse {
  final int classroomId;
  final String name;
  final String teacherName;
  final int studentsCount;
  final String courseName;

  YuketangCourse({
    required this.classroomId,
    required this.name,
    required this.teacherName,
    required this.studentsCount,
    required this.courseName,
  });

  factory YuketangCourse.fromJson(Map<String, dynamic> json) {
    final teacher = json['teacher'] as Map<String, dynamic>?;
    final course = json['course'] as Map<String, dynamic>?;

    int parseInt(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    return YuketangCourse(
      classroomId: parseInt(json['classroom_id']),
      name: json['name']?.toString() ?? '',
      teacherName: teacher?['name']?.toString() ?? '',
      studentsCount: parseInt(json['students_count']),
      courseName: course?['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'classroom_id': classroomId,
        'name': name,
        'teacher_name': teacherName,
        'students_count': studentsCount,
        'course_name': courseName,
      };
}

class YuketangApi {
  // 该接口要求携带登录会话（Cookie/Token），请确保 App 已登录并且 CookieManager 可用
  static const String _coursesUrl = 'https://www.yuketang.cn/v2/api/web/courses/list?identity=2';

  /// 获取当前用户已加入的所有课堂（不只在线上课的）
  static Future<List<YuketangCourse>> fetchAllCourses() async {
    try {
      debugPrint('[YuketangApi] 请求课程列表: $_coursesUrl');

      final resp = await ApiService.sendRequest(
        _coursesUrl,
        method: 'GET',
        responseType: ResponseType.json,
      );

      debugPrint('[YuketangApi] 响应状态码: ${resp.statusCode}');

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final data = resp.data;
      if (data is! Map) {
        throw Exception('Unexpected response format');
      }

      final errcode = data['errcode'] ?? data['error'] ?? data['code'] ?? 0;
      if (errcode is int && errcode != 0) {
        final errmsg = data['errmsg'] ?? data['message'] ?? data['msg'] ?? 'server error';
        debugPrint('[YuketangApi] 服务器错误: code=$errcode msg=$errmsg');
        throw Exception('Server error: $errmsg (code: $errcode)');
      }

      final list = <YuketangCourse>[];
      final rawList = (data['data'] is Map) ? (data['data']['list'] as List<dynamic>?) : (data['list'] as List<dynamic>?);
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            list.add(YuketangCourse.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      debugPrint('[YuketangApi] 成功获取 ${list.length} 个课程');
      return list;
    } on DioException catch (e) {
      debugPrint('[YuketangApi] 网络错误: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      debugPrint('[YuketangApi] 未知错误: $e');
      rethrow;
    }
  }
}
