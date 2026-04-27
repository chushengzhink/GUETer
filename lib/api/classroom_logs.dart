import 'package:dio/dio.dart';

import 'api_service.dart';

class ClassroomLogsApi {
  Future<Map<String, dynamic>> fetchClassroomLogs({
    required int courseId,
    required int classroomId,
  }) async {
    const url = 'https://www.yuketang.cn/v/course_meta/classroom_logs';
    try {
      final response = await ApiService.sendRequest(
        url,
        method: 'GET',
        params: {
          'course_id': courseId.toString(),
          'classroom_id': classroomId.toString(),
          'activity_type': '-1',
        },
        responseType: ResponseType.json,
      );

      final data = response.data;
      if (data is! Map) {
        throw Exception('Unexpected response format');
      }

      final mapped = Map<String, dynamic>.from(data);
      final success = mapped['success'];
      final errCode = mapped['errcode'] ?? mapped['code'];
      final isOk = response.statusCode == 200 &&
          (success == true || errCode == 0 || !mapped.containsKey('success'));

      if (!isOk) {
        throw Exception(
          mapped['msg'] ?? mapped['message'] ?? 'Failed to fetch data',
        );
      }
      return mapped;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  List<ClassroomActivity> parseActivities(Map<String, dynamic> responseData) {
    final data = _extractDataMap(responseData);
    final dynamic rawActivities = data['activities'];
    if (rawActivities is! List) {
      return const <ClassroomActivity>[];
    }

    final result = <ClassroomActivity>[];
    for (final bucket in rawActivities) {
      if (bucket is List) {
        for (final item in bucket) {
          if (item is Map) {
            result.add(
              ClassroomActivity.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
        continue;
      }
      if (bucket is Map) {
        result.add(
          ClassroomActivity.fromJson(Map<String, dynamic>.from(bucket)),
        );
      }
    }
    return result;
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> source) {
    final dynamic data = source['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return source;
  }
}

class ClassroomActivity {
  final int id;
  final String title;
  final int type;
  final int createTime;

  ClassroomActivity({
    required this.id,
    required this.title,
    required this.type,
    required this.createTime,
  });

  factory ClassroomActivity.fromJson(Map<String, dynamic> json) {
    int toInt(Object? value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ClassroomActivity(
      id: toInt(json['id']),
      title: json['title']?.toString() ?? '',
      type: toInt(json['type']),
      createTime: toInt(json['create_time']),
    );
  }
}

class ClassroomInfo {
  final String courseName;
  final String classroomName;
  final int studentsCount;

  ClassroomInfo({
    required this.courseName,
    required this.classroomName,
    required this.studentsCount,
  });

  factory ClassroomInfo.fromJson(Map<String, dynamic> json) {
    final payload = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    final course = payload['course'] is Map
        ? Map<String, dynamic>.from(payload['course'] as Map)
        : const <String, dynamic>{};
    final classroom = payload['classroom'] is Map
        ? Map<String, dynamic>.from(payload['classroom'] as Map)
        : const <String, dynamic>{};

    int toInt(Object? value) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ClassroomInfo(
      courseName: course['name']?.toString() ?? '',
      classroomName: classroom['name']?.toString() ?? '',
      studentsCount: toInt(payload['students_count']),
    );
  }
}
