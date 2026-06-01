import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'course.dart';
import 'platform_request_context.dart';
import '../platform.dart';
import '../session/account.dart';
import '../utils/chaoxing_html_parser.dart';

class ChaoxingChapterApi {
  static List<Map<String, dynamic>> _normalizeMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<String?> resolveCourseCpi(
    String courseId,
    String classId,
  ) async {
    try {
      final coursesData = await CXCourseApi.getCourses();
      final channelList =
          coursesData?['channelList'] as List<dynamic>? ?? const [];

      for (final channel in channelList) {
        final content = channel['content'];
        if (content == null || content['course'] == null) {
          continue;
        }

        final channelClassId = content['id']?.toString() ?? '';
        final channelCourseId =
            content['course']?['data']?[0]?['id']?.toString() ?? '';
        if (channelCourseId != courseId || channelClassId != classId) {
          continue;
        }

        final cpi = content['cpi']?.toString() ?? channel['cpi']?.toString();
        if (cpi != null && cpi.trim().isNotEmpty) {
          return cpi.trim();
        }
      }
    } catch (e) {
      debugPrint('ChaoxingChapterApi.resolveCourseCpi error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getChapterList(
    String courseId,
    String classId,
  ) async {
    final cpi = await resolveCourseCpi(courseId, classId);
    if (cpi == null || cpi.isEmpty) {
      return {'hasLocked': false, 'points': <Map<String, dynamic>>[]};
    }

    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc2-ans.chaoxing.com/mooc2-ans/mycourse/studentcourse',
        params: {
          'courseid': courseId,
          'clazzid': classId,
          'cpi': cpi,
          'ut': 's',
        },
        responseType: ResponseType.plain,
      );

      return ChaoxingHtmlParser().parseCoursePoint(
        response.data?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('ChaoxingChapterApi.getChapterList error: $e');
      return {'hasLocked': false, 'points': <Map<String, dynamic>>[]};
    } finally {
      context.dispose();
    }
  }

  static Future<List<Map<String, dynamic>>> getUnfinishedTasks(
    String courseId,
    String classId,
    String cpi,
  ) async {
    final resolvedCpi = cpi.trim().isNotEmpty
        ? cpi.trim()
        : await resolveCourseCpi(courseId, classId) ?? '';
    if (resolvedCpi.isEmpty) {
      return [];
    }

    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final chapterData = await getChapterList(courseId, classId);
      final points = _normalizeMapList(chapterData?['points']);
      final tasks = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final point in points) {
        final pointId = point['id']?.toString() ?? '';
        if (pointId.isEmpty) {
          continue;
        }

        final jobList = await _getJobListForPoint(
          context: context,
          courseId: courseId,
          classId: classId,
          cpi: resolvedCpi,
          pointId: pointId,
        );

        for (final job in jobList) {
          final normalized = _normalizeTask(job, point);
          final uniqueId =
              normalized['objectId']?.toString() ??
              normalized['jobId']?.toString() ??
              normalized['workId']?.toString() ??
              '${pointId}_${normalized['type']}';
          if (uniqueId.isEmpty || seenIds.contains(uniqueId)) {
            continue;
          }
          seenIds.add(uniqueId);
          tasks.add(normalized);
        }

        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      return tasks;
    } catch (e) {
      debugPrint('ChaoxingChapterApi.getUnfinishedTasks error: $e');
      return [];
    } finally {
      context.dispose();
    }
  }

  static Future<List<Map<String, dynamic>>> _getJobListForPoint({
    required PlatformRequestContext context,
    required String courseId,
    required String classId,
    required String cpi,
    required String pointId,
  }) async {
    final allJobs = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    for (var index = 0; index <= 6; index++) {
      final response = await context.sendRequest(
        'https://mooc1.chaoxing.com/mooc-ans/knowledge/cards',
        params: {
          'clazzid': classId,
          'courseid': courseId,
          'knowledgeid': pointId,
          'ut': 's',
          'cpi': cpi,
          'v': '2025-0424-1038-3',
          'mooc2': '1',
          'num': '$index',
        },
        responseType: ResponseType.plain,
      );

      final parsed = ChaoxingHtmlParser().parseJobList(
        response.data?.toString() ?? '',
      );
      final jobInfo = parsed['jobInfo'] as Map<String, dynamic>? ?? const {};
      if (jobInfo['notOpen'] == true) {
        return <Map<String, dynamic>>[];
      }

      final jobs = _normalizeMapList(parsed['jobList']);
      for (final job in jobs) {
        final key =
            job['objectId']?.toString() ??
            job['jobId']?.toString() ??
            job['workId']?.toString() ??
            '${pointId}_${job['type']}';
        if (key.isEmpty || seenKeys.contains(key)) {
          continue;
        }
        seenKeys.add(key);
        allJobs.add(job);
      }
    }

    return allJobs;
  }

  static Map<String, dynamic> _normalizeTask(
    Map<String, dynamic> job,
    Map<String, dynamic> point,
  ) {
    final title = job['title']?.toString().trim().isNotEmpty == true
        ? job['title'].toString().trim()
        : '学习任务';

    return {
      ...job,
      'title': title,
      'chapterId': point['id']?.toString() ?? '',
      'chapterName': point['title']?.toString() ?? '',
      'needUnlock': point['need_unlock'] == true,
      'type': job['type']?.toString() ?? 'task',
      'objectId': job['objectId']?.toString() ?? '',
      'jobId': job['jobId']?.toString() ?? '',
      'workId': job['workId']?.toString() ?? '',
    };
  }
}
