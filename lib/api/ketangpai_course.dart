import '../session/sign_execution_context.dart';
import 'package:dio/dio.dart';
import 'platform_read_exception.dart';
import '../session/ketangpai_semester.dart';
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
  }) => _identity.run(() => _getCoursesList(semester: semester, term: term));

  static SignExecutionContext get _identity =>
      SignExecutionContext.current?.platform == PlatformType.ketangpai
      ? SignExecutionContext.current!
      : SignExecutionContext.capture(platform: PlatformType.ketangpai);

  static Future<List<Course>> _getCoursesList({
    String? semester,
    String? term,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw const PlatformReadException(PlatformReadFailure.auth);
    }
    final endpoint = PlatformManager().ketangpaiBaseUrl;
    final selected = await KetangpaiSemesterStore.instance.load(
      userId,
      endpoint,
    );
    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );
    try {
      final body = {
        'isstudy': '1',
        'search': '',
        'semester': semester ?? selected.semester,
        'term': term ?? selected.term.toString(),
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };
      ApiService.appendExternalConsoleLog(
        '课堂派',
        '获取课程 学年=${body['semester']} 学期=${body['term']}',
      );
      final response = await context.sendRequest(
        '/CourseApi/semesterCourseList',
        method: 'POST',
        body: body,
        platformOptions: _ketangpaiReadOptions('ketangpai.course.list'),
        headers: {
          'Referer': 'https://w.ketangpai.com/',
          'Origin': 'https://w.ketangpai.com',
        },
      );
      _logApiEndpoint(
        'response',
        '/CourseApi/semesterCourseList',
        data: response.data,
      );
      final courses = parseCourseList(response);
      return courses;
    } catch (error) {
      _logApiEndpoint('error', '/CourseApi/semesterCourseList', error: error);
      throw PlatformReadException.from(error);
    } finally {
      context.dispose();
    }
  }

  static List<Course> parseCourseList(Response response) =>
      parseReadList(response).map(Course.fromKTPJson).toList();

  static List<Map<String, dynamic>> parseReadList(Response response) {
    final payload = readPlatformObject(response);
    if (isKetangpaiAuthExpired(payload)) {
      throw const PlatformReadException(PlatformReadFailure.auth);
    }
    if (!isKetangpaiSuccess(payload) ||
        (payload['status'] != null && payload['status'].toString() != '1') ||
        (payload['code'] != null && payload['code'].toString() != '10000')) {
      throw const PlatformReadException(PlatformReadFailure.business);
    }
    dynamic list = payload['data'];
    if (list is Map) {
      list = [
        for (final key in ['list', 'lists', 'rows', 'data'])
          if (list[key] is List) list[key],
      ].firstOrNull;
    }
    if (list is! List || list.any((item) => item is! Map)) {
      throw const PlatformReadException(PlatformReadFailure.format);
    }
    return asKetangpaiMapList(list);
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
  static Future<List<Map<String, dynamic>>> getAllTodos() =>
      _identity.run(_getAllTodos);

  static Future<List<Map<String, dynamic>>> _getAllTodos() async {
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
          final contentType = int.tryParse('${item['contenttype']}');

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
      throw PlatformReadException.from(e);
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
  static Future<List<Course>> getOnlineCourses() =>
      _identity.run(_getOnlineCourses);

  static Future<List<Course>> _getOnlineCourses() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法获取在线课程');
      throw const PlatformReadException(PlatformReadFailure.auth);
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.ketangpai,
      userId: userId,
    );

    try {
      // Resolve the selected semester before the state request can outlive a switch.
      final allCourses = await getCoursesList();
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

      final onlineCourseIds = parseReadList(
        response,
      ).map((item) => item['courseid']?.toString()).whereType<String>().toSet();
      return allCourses
          .where((course) => onlineCourseIds.contains(course.courseId))
          .toList();
    } catch (e) {
      _logApiEndpoint('error', '/CourseApi/getCourseStateAll', error: e);
      debugPrint('KTPCourseApi.getOnlineCourses error: $e');
      throw PlatformReadException.from(e);
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
      throw const PlatformReadException(PlatformReadFailure.auth);
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

      _logApiEndpoint(
        'response',
        '/AttenceApi/getNotFinishAttenceStudent',
        data: response.data,
      );
      return parseReadList(response);
    } catch (e) {
      debugPrint('KTPCourseApi.getNotFinishSign error: $e');
      throw PlatformReadException.from(e);
    } finally {
      context.dispose();
    }
  }

  /// 获取正在签到的课程列表
  static Future<List<Map<String, dynamic>>> getSigningCourses() =>
      _identity.run(_getSigningCourses);

  static Future<List<Map<String, dynamic>>> _getSigningCourses() async {
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
      throw PlatformReadException.from(e);
    }
  }
}
