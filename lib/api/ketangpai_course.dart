import 'api_service.dart';
import 'platform_request_stability.dart';
import 'platform_request_context.dart';
import 'ketangpai_response.dart';
import '../models/course.dart';
import '../session/account.dart';
import '../platform.dart';
import 'package:flutter/foundation.dart' show debugPrint;

String _apiPayloadSummary(dynamic data) {
  if (data is Map<String, dynamic>) {
    final code = data['code'] ?? data['status'];
    final msg = data['msg'] ?? data['message'];
    final keys = data.keys.take(8).join(',');
    return 'code=$code msg=$msg keys=[$keys]';
  }

  if (data is List) {
    return 'listLength=${data.length}';
  }

  return 'type=${data.runtimeType}';
}

void _logApiEndpoint(
  String stage,
  String endpoint, {
  dynamic data,
  Object? error,
}) {
  final prefix = '[KTP][Endpoint][$stage] $endpoint';
  if (error != null) {
    final message = '$prefix error=$error';
    debugPrint(message);
    ApiService.appendExternalConsoleLog(
      'KTP',
      '[$stage] $endpoint error=$error',
    );
    return;
  }
  final summary = _apiPayloadSummary(data);
  debugPrint('$prefix $summary');
  ApiService.appendExternalConsoleLog('KTP', '[$stage] $endpoint $summary');
}

PlatformRequestOptions _ketangpaiReadOptions(String operationId) {
  return PlatformRequestOptions(
    operationId: operationId,
    requestKind: PlatformRequestKind.read,
    allowControlledParallelism: true,
  );
}

class KTPCourseApi {
  /// 获取当前学期课程列表（使用独立 Dio 实例）
  static Future<List<Course>> getCoursesList({
    String? semester,
    String? term,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法获取课程');
      return [];
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final account = AccountManager.getAccountById(userId);
      final tokenLength = account?.token.length ?? 0;
      ApiService.appendExternalConsoleLog('课堂派', '已注入 Token 总长度: $tokenLength');

      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      String defaultSemester;
      String defaultTerm;

      if (currentMonth >= 9) {
        defaultSemester = '$currentYear-${currentYear + 1}';
        defaultTerm = '1';
      } else if (currentMonth >= 2) {
        defaultSemester = '${currentYear - 1}-$currentYear';
        defaultTerm = '2';
      } else {
        defaultSemester = '${currentYear - 1}-$currentYear';
        defaultTerm = '1';
      }

      final finalSemester = semester ?? defaultSemester;
      final finalTerm = term ?? defaultTerm;

      const endpoint = '/CourseApi/semesterCourseList';
      final body = {
        'isstudy': '1',
        'search': '',
        'semester': finalSemester,
        'term': finalTerm,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _logApiEndpoint('request', endpoint, data: body);

      final response = await context.sendRequest(
        endpoint,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiReadOptions('ketangpai.course.list'),
        headers: {
          'Referer': 'https://w.ketangpai.com/',
          'Origin': 'https://w.ketangpai.com',
        },
      );

      _logApiEndpoint('response', endpoint, data: response.data);

      ApiService.appendExternalConsoleLog(
        '课堂派',
        '学期参数: $finalSemester 学期: $finalTerm',
      );

      debugPrint('[KTPCourseApi] 响应类型: ${response.data.runtimeType}');
      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        final code = response.data['code'];
        final message = response.data['message'];
        debugPrint('[KTPCourseApi] status=$status code=$code message=$message');

        // 课堂派 API 返回 status=1 且 code=10000 表示成功
        final isSuccess =
            (status == 1 && code == 10000) ||
            (status == 1 && code == null) ||
            (code == 10000 && status == null);
        debugPrint('[KTPCourseApi] isSuccess=$isSuccess');

        if (isSuccess) {
          final data = response.data['data'];
          debugPrint('[KTPCourseApi] data 类型: ${data.runtimeType}');
          debugPrint('[KTPCourseApi] data 值: $data');
          debugPrint('[KTPCourseApi] data == null: ${data == null}');

          if (data == null) {
            debugPrint('[KTPCourseApi] data 为 null，检查完整响应结构');
            debugPrint('[KTPCourseApi] 完整响应: ${response.data}');
            return [];
          }

          if (data is List) {
            debugPrint('[KTPCourseApi] 原始数据包含 ${data.length} 个课程对象');
            final courses = <Course>[];
            for (var i = 0; i < data.length; i++) {
              try {
                final item = data[i];
                debugPrint('[KTPCourseApi] 课程$i 原始数据: $item');
                if (item is Map) {
                  final course = Course.fromKTPJson(
                    Map<String, dynamic>.from(item),
                  );
                  courses.add(course);
                  debugPrint(
                    '[KTPCourseApi] 课程$i: id=${course.courseId} name=${course.name}',
                  );
                }
              } catch (e, stackTrace) {
                debugPrint('[KTPCourseApi] 解析课程$i失败: $e');
                debugPrint('[KTPCourseApi] StackTrace: $stackTrace');
              }
            }
            debugPrint('[KTPCourseApi] 成功解析 ${courses.length} 门课程');
            return courses;
          } else {
            debugPrint('[KTPCourseApi] data 不是 List，而是: ${data.runtimeType}');
            debugPrint('[KTPCourseApi] data 内容: $data');
            if (data is Map) {
              debugPrint(
                '[KTPCourseApi] data 是 Map，keys: ${data.keys.toList()}',
              );
              if (data.containsKey('list')) {
                debugPrint('[KTPCourseApi] data 包含 list 字段，尝试提取');
                final list = data['list'];
                if (list is List) {
                  debugPrint(
                    '[KTPCourseApi] 从 data.list 提取到 ${list.length} 个课程',
                  );
                  final courses = <Course>[];
                  for (var i = 0; i < list.length; i++) {
                    try {
                      final item = list[i];
                      if (item is Map) {
                        final course = Course.fromKTPJson(
                          Map<String, dynamic>.from(item),
                        );
                        courses.add(course);
                        debugPrint(
                          '[KTPCourseApi] 课程$i: id=${course.courseId} name=${course.name}',
                        );
                      }
                    } catch (e, stackTrace) {
                      debugPrint('[KTPCourseApi] 解析课程$i失败: $e');
                      debugPrint('[KTPCourseApi] StackTrace: $stackTrace');
                    }
                  }
                  return courses;
                }
              }
            }
          }
        } else {
          debugPrint('[KTPCourseApi] 状态检查失败: status=$status code=$code');
        }
      } else {
        debugPrint('[KTPCourseApi] 响应不是 Map，而是: ${response.data.runtimeType}');
      }
      return [];
    } catch (e) {
      _logApiEndpoint('error', '/CourseApi/semesterCourseList', error: e);
      debugPrint('KTPCourseApi.getCoursesList error: $e');
      return [];
    } finally {
      context.dispose();
    }
  }

  /// 获取课程内容（作业、测试、话题、资料）（使用独立 Dio 实例）
  static Future<List<Map<String, dynamic>>> getCourseContent(
    String courseId, {
    int contentType = 0, // 0=全部, 2=资料, 4=作业, 5=话题, 6=测试
    int page = 1,
    int limit = 50,
    Object dirId = '0',
    Object desc = '2',
    String vtrType = '',
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法获取课程内容');
      return [];
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      final account = AccountManager.getAccountById(userId);
      final tokenLength = account?.token.length ?? 0;
      ApiService.appendExternalConsoleLog('课堂派', '已注入 Token 总长度: $tokenLength');

      const endpoint = '/FutureV2/CourseMeans/getCourseContent';
      final body = {
        'courseid': courseId,
        'courserole': 0,
        'contenttype': contentType,
        'dirid': dirId,
        'lessonlink': [],
        'desc': desc,
        'page': page,
        'limit': limit,
        'sort': [],
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };
      if (vtrType.isNotEmpty) {
        body['vtr_type'] = vtrType;
      }

      _logApiEndpoint('request', endpoint, data: body);
      final response = await context.sendRequest(
        endpoint,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiReadOptions('ketangpai.course.content'),
      );
      _logApiEndpoint('response', endpoint, data: response.data);

      return extractKetangpaiList(response.data);
    } catch (e) {
      _logApiEndpoint(
        'error',
        '/FutureV2/CourseMeans/getCourseContent',
        error: e,
      );
      debugPrint('KTPCourseApi.getCourseContent error: $e');
      return [];
    } finally {
      context.dispose();
    }
  }

  static Future<List<Map<String, dynamic>>> getCourseContentAll(
    String courseId, {
    int contentType = 0,
    int limit = 50,
    int maxPages = 10,
    Object dirId = '0',
    Object desc = '2',
    String vtrType = '',
  }) async {
    final all = <Map<String, dynamic>>[];
    final safeLimit = limit <= 0 ? 50 : limit;
    final safeMaxPages = maxPages <= 0 ? 1 : maxPages;
    for (var page = 1; page <= safeMaxPages; page++) {
      final items = await getCourseContent(
        courseId,
        contentType: contentType,
        page: page,
        limit: safeLimit,
        dirId: dirId,
        desc: desc,
        vtrType: vtrType,
      );
      all.addAll(items);
      if (items.length < safeLimit) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 80));
    }
    return all;
  }

  /// 获取所有待办项（作业、测试、话题）（使用独立 Dio 实例）
  static Future<List<Map<String, dynamic>>> getAllTodos() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法获取待办');
      return [];
    }

    try {
      final courses = await getCoursesList();
      if (courses.isEmpty) {
        return [];
      }

      final allTodos = <Map<String, dynamic>>[];

      for (final course in courses) {
        final courseId = course.courseId;
        if (courseId.isEmpty) continue;

        final contents = await getCourseContentAll(courseId, contentType: 0);

        for (final item in contents) {
          final contentType = item['contenttype'];

          if (contentType == 4 || contentType == 5 || contentType == 6) {
            final todo = <String, dynamic>{
              ...item,
              'course_name': course.name,
              'course_id': courseId,
            };
            allTodos.add(todo);
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      ApiService.appendExternalConsoleLog(
        '课堂派',
        '获取待办成功，共 ${allTodos.length} 项',
      );
      return allTodos;
    } catch (e) {
      debugPrint('KTPCourseApi.getAllTodos error: $e');
      return [];
    }
  }

  /// 获取课程详情（使用独立 Dio 实例）
  static Future<Map<String, dynamic>?> getCourseDetail(String courseId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法获取课程详情');
      return null;
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      const endpoint = '/CourseBigDataApi/getCourseBaseDataV2';
      final body = {
        'courseid': courseId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _logApiEndpoint('request', endpoint, data: body);
      final response = await context.sendRequest(
        endpoint,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiReadOptions('ketangpai.course.detail'),
      );
      _logApiEndpoint('response', endpoint, data: response.data);

      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        if (status == 1) {
          return response.data['data'];
        }
      }
      return null;
    } catch (e) {
      _logApiEndpoint(
        'error',
        '/CourseBigDataApi/getCourseBaseDataV2',
        error: e,
      );
      debugPrint('KTPCourseApi.getCourseDetail error: $e');
      return null;
    } finally {
      context.dispose();
    }
  }

  /// 获取测试详情（使用独立 Dio 实例）
  static Future<Map<String, dynamic>?> getTestDetail(
    String courseId,
    String testPaperId,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法获取测试详情');
      return null;
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      const endpoint = '/TestpaperApi/setting';
      final body = {
        'courseid': courseId,
        'testpaperid': testPaperId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      _logApiEndpoint('request', endpoint, data: body);
      final response = await context.sendRequest(
        endpoint,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiReadOptions('ketangpai.test.detail'),
      );
      _logApiEndpoint('response', endpoint, data: response.data);

      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        if (status == 1) {
          return response.data['data'];
        }
      }
      return null;
    } catch (e) {
      _logApiEndpoint('error', '/TestpaperApi/setting', error: e);
      debugPrint('KTPCourseApi.getTestDetail error: $e');
      return null;
    } finally {
      context.dispose();
    }
  }

  /// 获取正在上课的课程列表
  static Future<List<Course>> getOnlineCourses() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法获取在线课程');
      return [];
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      const endpoint = '/CourseApi/getCourseStateAll';
      final body = {'reqtimestamp': DateTime.now().millisecondsSinceEpoch};

      _logApiEndpoint('request', endpoint, data: body);
      final response = await context.sendRequest(
        endpoint,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiReadOptions('ketangpai.course.online'),
      );
      _logApiEndpoint('response', endpoint, data: response.data);

      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        if (status == 1) {
          final data = response.data['data'];
          if (data is List) {
            // 提取正在上课的课程 ID
            final onlineCourseIds = <String>{};
            for (final item in data) {
              if (item is Map && item['courseid'] != null) {
                onlineCourseIds.add(item['courseid'].toString());
              }
            }

            // 获取所有课程并标记正在上课的
            final allCourses = await getCoursesList();
            final onlineCourses = allCourses.where((course) {
              return onlineCourseIds.contains(course.courseId);
            }).toList();

            ApiService.appendExternalConsoleLog(
              '课堂派',
              '正在上课的课程: ${onlineCourses.length}/${allCourses.length}',
            );
            return onlineCourses;
          }
        }
      }
      return [];
    } catch (e) {
      _logApiEndpoint('error', '/CourseApi/getCourseStateAll', error: e);
      debugPrint('KTPCourseApi.getOnlineCourses error: $e');
      return [];
    } finally {
      context.dispose();
    }
  }

  /// 获取未完成的签到列表
  static Future<List<Map<String, dynamic>>> getNotFinishSign(
    String courseId,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return [];
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      const endpoint = '/AttenceApi/getNotFinishAttenceStudent';
      final body = {
        'courseid': courseId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await context.sendRequest(
        endpoint,
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiReadOptions('ketangpai.sign.pending'),
      );

      if (response.data is Map<String, dynamic>) {
        final status = response.data['status'];
        if (status == 1) {
          final data = response.data['data'];
          if (data is List) {
            return data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      debugPrint('KTPCourseApi.getNotFinishSign error: $e');
      return [];
    } finally {
      context.dispose();
    }
  }

  /// 获取正在签到的课程列表
  static Future<List<Map<String, dynamic>>> getSigningCourses() async {
    try {
      final courses = await getCoursesList();
      final signingCourses = <Map<String, dynamic>>[];

      for (final course in courses) {
        final signs = await getNotFinishSign(course.courseId);
        if (signs.isNotEmpty) {
          for (final sign in signs) {
            signingCourses.add({
              'course': course,
              'signId': sign['id']?.toString() ?? '',
              'signType': int.tryParse(sign['type']?.toString() ?? '0') ?? 0,
              'signName': sign['name']?.toString() ?? '签到',
              'startTime': sign['starttime']?.toString() ?? '',
              'endTime': sign['endtime']?.toString() ?? '',
            });
          }
        }
        // 避免请求过快
        await Future.delayed(const Duration(milliseconds: 100));
      }

      ApiService.appendExternalConsoleLog(
        '课堂派',
        '正在签到的课程: ${signingCourses.length}',
      );
      return signingCourses;
    } catch (e) {
      debugPrint('KTPCourseApi.getSigningCourses error: $e');
      return [];
    }
  }
}
