import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';

import 'api_service.dart';
import '../session/account.dart';
import '../platform.dart';
import '../utils/encrypt.dart';
import '../utils/coord_transform.dart';
import '../models/active.dart';
import '../models/course.dart';

String _apiPayloadSummary(dynamic data) {
  if (data is Map<String, dynamic>) {
    final code =
        data['code'] ?? data['result'] ?? data['success'] ?? data['status'];
    final msg = data['msg'] ?? data['message'] ?? data['mes'];
    final keys = data.keys.take(8).join(',');
    return 'code=$code msg=$msg keys=[$keys]';
  }

  if (data is List) {
    return 'listLength=${data.length}';
  }

  return 'type=${data.runtimeType}';
}

void _logApiEndpoint(
  String tag,
  String stage,
  String endpoint, {
  dynamic data,
  Object? error,
}) {
  final prefix = '[$tag][Endpoint][$stage] $endpoint';
  if (error != null) {
    debugPrint('$prefix error=$error');
    return;
  }
  debugPrint('$prefix ${_apiPayloadSummary(data)}');
}

class CXCourseApi {
  /// 获取课程列表
  static Future<Map<String, dynamic>?> getCourses() async {
    try {
      final url =
          'https://mooc1-api.chaoxing.com/mycourse/backclazzdata?view=json&getTchClazzType=1&mcode=';

      _logApiEndpoint('CX', 'request', url);
      final response = await ApiService.sendRequest(url);
      _logApiEndpoint('CX', 'response', url, data: response.data);
      return response.data;
    } catch (e) {
      _logApiEndpoint('CX', 'error', 'mycourse/backclazzdata', error: e);
      debugPrint('getCourses error: $e');
    }
    return null;
  }

  /// 获取处理后的课程列表
  static Future<List<Course>?> getCoursesList() async {
    try {
      final coursesData = await getCourses();

      if (coursesData == null || coursesData['result'] != 1) {
        return null;
      }

      List<Course> courses = [];
      List<dynamic> channelList = coursesData['channelList'];

      for (var channel in channelList) {
        if (channel['content']['course'] != null) {
          // 自己创建的课程
          courses.add(Course.fromCXJson(channel));
        }
      }

      // 过滤已结课的课程
      return courses.where((course) => course.state).toList();
    } catch (e) {
      debugPrint('getCoursesList error: $e');
      return null;
    }
  }

  /// 获取加入课程时间作为参数
  //（其实没必要）
  static Future<String?> getJoinClassTime(
    String courseId,
    String classId,
    String cpi,
  ) async {
    try {
      final url = 'https://mooc1-api.chaoxing.com/gas/clazzperson';
      final currentUserId = AccountManager.currentSessionId ?? '';
      final params = {
        'courseid': courseId,
        'clazzid': classId,
        'userid': currentUserId,
        'personid': cpi,
        'view': 'json',
        'fields': 'clazzid,popupagreement,personid,clazzname,createtime',
      };

      final response = await ApiService.sendRequest(url, params: params);
      _logApiEndpoint('CX', 'response', '$url?courseid=$courseId&clazzid=$classId', data: response.data);

      final joinClassTime = response.data['data'][0]['createtime'];
      return joinClassTime;
      /*
      {
          "data": [
              {
                  "createtime": "2026-01-19 11:56:27",
                  "clazzid": 134316250,
                  "personid": 534239555,
                  "popupagreement": 0
              }
          ]
      }
       */
    } catch (e) {
      _logApiEndpoint('CX', 'error', 'gas/clazzperson', error: e);
      debugPrint('getJoinClassTime error: $e');
    }
    return null;
  }

  /// 获取任务活动列表
  static Future<Map<String, dynamic>?> getTaskActivityList(
    String courseId,
    String classId,
    String cpi,
    String joinClassTime,
  ) async {
    try {
      final url =
          'https://mobilelearn.chaoxing.com/ppt/activeAPI/taskactivelist';
      final currentUserId = AccountManager.currentSessionId ?? '';

      Map<String, String> params = {
        'courseId': courseId,
        'classId': classId,
        'uid': currentUserId,
        'cpi': cpi,
        'joinclasstime': joinClassTime,
      };
      params.addAll(EncryptionUtil.getEncParams(params));

      final response = await ApiService.sendRequest(
        url,
        method: 'GET',
        params: params,
      );
      _logApiEndpoint('CX', 'response', '$url?courseId=$courseId&classId=$classId', data: response.data);
      return response.data;
    } catch (e) {
      _logApiEndpoint('CX', 'error', 'ppt/activeAPI/taskactivelist', error: e);
      debugPrint('getTaskActivityList error: $e');
    }
    return null;
  }

  /// 获取任务活动列表（Web）
  static Future<Map<String, dynamic>?> getTaskActivityListWeb(
    String courseId,
    String classId,
  ) async {
    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/active/student/activelist';

      final timeStampMS = DateTime.now().millisecondsSinceEpoch.toString();
      // final fid = await CookieManager.getCookieValue('fid') ?? '';
      // 客户端登录的 Cookie 没有 fid
      final params = {
        'fid': '0',
        'courseId': courseId,
        'classId': classId,
        'showNotStartedActive': '0',
        '_': timeStampMS,
      };

      final response = await ApiService.sendRequest(
        url,
        method: 'GET',
        params: params,
      );
      _logApiEndpoint('CX', 'response', '$url?courseId=$courseId&classId=$classId', data: response.data);
      return response.data;
    } catch (e) {
      _logApiEndpoint('CX', 'error', 'v2/apis/active/student/activelist', error: e);
      debugPrint('getTaskActivityList error: $e');
    }
    return null;
  }

  /// 获取合并处理后的活动列表
  static Future<List<Active>?> getActiveList(
    String courseId,
    String classId,
    String cpi,
  ) async {
    try {
      // 自动获取加入课程时间
      final joinClassTime =
          await getJoinClassTime(courseId, classId, cpi) ?? '';

      final results = await Future.wait([
        getTaskActivityList(courseId, classId, cpi, joinClassTime),
        getTaskActivityListWeb(courseId, classId),
      ]);

      final taskData = results[0];
      final webTaskData = results[1];

      if (taskData == null || webTaskData == null) {
        return null;
      }

      List<Active> contentList = [];
      List<dynamic> activeList = taskData['activeList'];
      List<dynamic> webActiveList = webTaskData['data']['activeList'];

      // app 和 web 的 api 活动结束时间存在差异 顺序会匹配错误
      Map<String, dynamic> activeMap = {
        for (var activeItem in webActiveList)
          activeItem['id'].toString(): activeItem,
      };

      for (var activeData in activeList) {
        Active active = Active.fromJson(activeData);
        String activeId = activeData['id'].toString();

        if (activeMap.containsKey(activeId)) {
          var activeItem = activeMap[activeId];
          if (active.status) {
            if (active.description.isEmpty) {
              active.description = activeItem['nameFour'];
            }
          }

          if (active.activeType == ActiveType.signIn ||
              active.activeType == ActiveType.signOut) {
            final otherId = activeItem['otherId'];
            if (otherId != null) {
              try {
                active.signType = getSignTypeFromIndex(int.parse(otherId));
              } catch (e) {
                debugPrint('解析 otherId 失败：$otherId, 错误：$e');
              }
            }
          }
        }
        contentList.add(active);
      }

      return contentList;
    } catch (e) {
      debugPrint('getActiveList error: $e');
      return null;
    }
  }
}

class RCCourseApi {
  // userId -> [bearerToken, lessonToken]
  static final Map<String, List<String>> _tokens = {};

  static void _logRc(String message) {
    debugPrint('[RC][Course] $message');
  }

  static String get _currentSessionId => AccountManager.currentSessionId!;

  /// 获取当前用户的 bearerToken
  static String? getBearerToken() {
    return _tokens[_currentSessionId]?[0];
  }

  static String? getLessonToken() {
    return _tokens[_currentSessionId]?[1];
  }

  static void _setToken(String bearerToken, String lessonToken) {
    _tokens[_currentSessionId] = [bearerToken, lessonToken];
  }

  /// 上传图片到七牛云
  static Future<String?> uploadImageToQiniu(File imageFile) async {
    try {
      final tokenUrl = '/pc/generate_qiniu_token';
      final jsonData = {'bucket_name': 'cms-attachment', 'expired_time': 3600};
      final tokenResponse = await ApiService.sendRequest(
        tokenUrl,
        method: 'POST',
        body: jsonData,
      );
      _logApiEndpoint('RC', 'response', tokenUrl, data: tokenResponse.data);

      if (tokenResponse.data == null ||
          tokenResponse.data['success'] != true ||
          tokenResponse.data['data'] == null) {
        debugPrint('Failed to get qiniu token');
        return null;
      }

      final token = tokenResponse.data['data']['token'];

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final originalFileName = imageFile.path.split('/').last;
      final fileName = '$timestamp$originalFileName';

      final uploadUrl = 'https://upload.qiniup.com/';
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        'token': token,
        'key': fileName,
        'fname': originalFileName,
      });
      final uploadResponse = await ApiService.sendRequest(
        uploadUrl,
        method: 'POST',
        body: formData,
      );
      _logApiEndpoint('RC', 'response', uploadUrl, data: uploadResponse.data);

      if (uploadResponse.data == null ||
          uploadResponse.data['success'] != true) {
        debugPrint('Failed to upload to qiniu');
        return null;
      }

      final key = uploadResponse.data['key'];
      final imageUrl = 'https://qn-scd1.yuketang.cn/$key';
      return imageUrl;
    } catch (e) {
      debugPrint('uploadImageToQiniu error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCourses() async {
    const relativeCandidates = <String>[
      '/v/course_meta/learning_list/',
      '/api/v3/course_meta/learning_list/',
      '/api/v3/lesson/learning/list',
    ];
    const hosts = <String>[
      'https://www.yuketang.cn',
      'https://pro.yuketang.cn',
      'https://changjiang.yuketang.cn',
      'https://huanghe.yuketang.cn',
    ];

    final candidates = <String>[...relativeCandidates];
    for (final host in hosts) {
      for (final path in relativeCandidates) {
        candidates.add('$host$path');
      }
    }

    for (final path in candidates) {
      try {
        _logRc('getCourses try: $path');
        final response = await ApiService.sendRequest(path);
        final data = response.data;
        _logApiEndpoint('RC', 'response', path, data: data);
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          _logRc('getCourses success: $path keys=${data.keys.take(6).join(',')}');
          return data;
        }
      } catch (e) {
        _logApiEndpoint('RC', 'error', path, error: e);
        _logRc('getCourses failed: $path error=$e');
      }
    }
    _logRc('getCourses all candidates failed');
    return null;
  }

  static Future<Map<String, dynamic>?> getOnLessonAndUpcomingExam() async {
    const candidates = <String>[
      '/api/v3/classroom/on-lesson-upcoming-exam',
      'https://www.yuketang.cn/api/v3/classroom/on-lesson-upcoming-exam',
      'https://pro.yuketang.cn/api/v3/classroom/on-lesson-upcoming-exam',
      'https://changjiang.yuketang.cn/api/v3/classroom/on-lesson-upcoming-exam',
      'https://huanghe.yuketang.cn/api/v3/classroom/on-lesson-upcoming-exam',
    ];

    for (final path in candidates) {
      try {
        _logRc('getOnLessonAndUpcomingExam try: $path');
        final response = await ApiService.sendRequest(path);
        final data = response.data;
        _logApiEndpoint('RC', 'response', path, data: data);
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          _logRc('getOnLessonAndUpcomingExam success: $path keys=${data.keys.take(6).join(',')}');
          return data;
        }
      } catch (e) {
        _logApiEndpoint('RC', 'error', path, error: e);
        _logRc('getOnLessonAndUpcomingExam failed: $path error=$e');
      }
    }

    _logRc('getOnLessonAndUpcomingExam all candidates failed');
    return null;
  }

  static List<dynamic> _extractCourseItems(Map<String, dynamic>? courses) {
    if (courses == null) {
      return const [];
    }

    final data = courses['data'];
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final keys = <String>[
        'list',
        'course_list',
        'courseList',
        'courses',
        'learningList',
        'learning_list',
      ];
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return value;
        }
      }
    }

    final keys = <String>['list', 'course_list', 'courseList', 'courses'];
    for (final key in keys) {
      final value = courses[key];
      if (value is List) {
        return value;
      }
    }

    final recursive = _findCourseLikeList(courses);
    if (recursive.isNotEmpty) {
      return recursive;
    }

    return const [];
  }

  static bool _looksLikeCourseItem(Map<String, dynamic> map) {
    return map.containsKey('course_id') ||
        map.containsKey('courseId') ||
        map.containsKey('course_name') ||
        map.containsKey('courseName') ||
        map.containsKey('classroom_id') ||
        map.containsKey('classroomId') ||
        map.containsKey('teacher') ||
        map.containsKey('teacher_name');
  }

  static List<dynamic> _findCourseLikeList(dynamic node, {int depth = 0}) {
    if (depth > 4 || node == null) {
      return const [];
    }

    if (node is List) {
      if (node.isNotEmpty && node.first is Map) {
        final mapItems = node.whereType<Map>().take(20).map((e) {
          return e.map((k, v) => MapEntry(k.toString(), v));
        }).toList();
        if (mapItems.isNotEmpty && mapItems.any(_looksLikeCourseItem)) {
          return node;
        }
      }

      for (final item in node.take(20)) {
        final found = _findCourseLikeList(item, depth: depth + 1);
        if (found.isNotEmpty) {
          return found;
        }
      }
      return const [];
    }

    if (node is Map<String, dynamic>) {
      for (final key in node.keys) {
        final value = node[key];
        final found = _findCourseLikeList(value, depth: depth + 1);
        if (found.isNotEmpty) {
          return found;
        }
      }
    }

    return const [];
  }

  static List<dynamic> _extractOnLessonItems(Map<String, dynamic>? payload) {
    if (payload == null) {
      return const [];
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      final keys = <String>[
        'onLessonClassrooms',
        'on_lesson_classrooms',
        'onLessonCourses',
        'on_lesson_courses',
        'classrooms',
        'lessons',
      ];
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return value;
        }
      }

      final recursive = _findCourseLikeList(data);
      if (recursive.isNotEmpty) {
        return recursive;
      }
    }

    final recursive = _findCourseLikeList(payload);
    if (recursive.isNotEmpty) {
      return recursive;
    }
    return const [];
  }

  static Map<String, dynamic> _normalizeRcCourseItem(Map<String, dynamic> raw) {
    final teacherRaw = raw['teacher'];
    final teacher = teacherRaw is Map<String, dynamic>
        ? teacherRaw
        : <String, dynamic>{
            'name': raw['teacher_name'] ?? raw['teacherName'] ?? raw['teacher'],
            'avatar': raw['teacher_avatar'] ?? raw['teacherAvatar'],
          };

    return <String, dynamic>{
      ...raw,
      'course_id': raw['course_id'] ?? raw['courseId'] ?? raw['id'] ?? '',
      'classroom_id':
          raw['classroom_id'] ?? raw['classroomId'] ?? raw['lesson_id'] ?? '',
      'course_name': raw['course_name'] ?? raw['courseName'] ?? raw['name'] ?? '未知课程',
      'classroom_name': raw['classroom_name'] ?? raw['classroomName'] ?? raw['class_name'],
      'lesson_id': raw['lesson_id'] ?? raw['lessonId'],
      'teacher': teacher,
    };
  }

      static Map<String, dynamic> _normalizeRcOnLessonItem(Map<String, dynamic> raw) {
      final courseRaw = raw['course'];
      final course = courseRaw is Map<String, dynamic>
        ? courseRaw
        : <String, dynamic>{};

      final teacherRaw = raw['teacher'] ?? course['teacher'];
      final teacher = teacherRaw is Map<String, dynamic>
        ? teacherRaw
        : <String, dynamic>{
          'name': raw['teacherName'] ??
            raw['teacher_name'] ??
            raw['lecturer_name'] ??
            course['teacher_name'] ??
            course['teacherName'] ??
            raw['teacher'] ??
            course['teacher'],
          'avatar': raw['teacherAvatar'] ??
            raw['teacher_avatar'] ??
            course['teacher_avatar'] ??
            course['teacherAvatar'],
          };

      return <String, dynamic>{
        ...raw,
        'course_id': raw['courseId'] ??
          raw['course_id'] ??
          course['id'] ??
          course['course_id'] ??
          raw['id'] ??
          '',
        'classroom_id': raw['classroomId'] ??
          raw['classroom_id'] ??
          raw['lessonId'] ??
          raw['lesson_id'] ??
          raw['id'] ??
          '',
        'course_name': raw['courseName'] ??
          raw['course_name'] ??
          course['name'] ??
          course['course_name'] ??
          raw['name'] ??
          '未知课程',
        'classroom_name': raw['classroomName'] ??
          raw['classroom_name'] ??
          raw['class_name'] ??
          raw['name'] ??
          '',
        'lesson_id': raw['lessonId'] ??
            raw['lesson_id'] ??
            raw['lessonid'] ??
            raw['currentLessonId'] ??
            raw['current_lesson_id'],
        'teacher': teacher,
      };
      }

  /// 获取处理后的课程列表
  static Future<List<Course>?> getCoursesList([
    Map<String, dynamic>? onLessonCourses,
  ]) async {
    try {
      late Map<String, dynamic>? courses;
      if (onLessonCourses == null) {
        final results = await Future.wait([
          getCourses(),
          getOnLessonAndUpcomingExam(),
        ]);
        courses = results[0];
        onLessonCourses = results[1];
      } else {
        courses = await getCourses();
      }

      if (courses == null) {
        _logRc('getCoursesList abort: courses payload is null');
        return null;
      }

      final school =
          AccountManager.getAccountById(AccountManager.currentSessionId!)?.school;

      final courseItems = _extractCourseItems(courses);
      final onLessonItems = _extractOnLessonItems(onLessonCourses);
      _logRc('getCoursesList parsed courseItems=${courseItems.length} onLessonItems=${onLessonItems.length}');

      final lessonByCourseId = <String, dynamic>{};
      for (final item in onLessonItems) {
        if (item is! Map) {
          continue;
        }
        final map = item.map((k, v) => MapEntry(k.toString(), v));
        final cid = (map['courseId'] ?? map['course_id'] ?? map['id'])?.toString();
        final lessonId = (map['lessonId'] ?? map['lesson_id'])?.toString();
        if (cid != null && cid.isNotEmpty && lessonId != null && lessonId.isNotEmpty) {
          lessonByCourseId[cid] = lessonId;
        }
      }

      final seen = <String>{};
      final contentList = <Course>[];
      for (final item in courseItems) {
        if (item is! Map) {
          continue;
        }
        final normalized = _normalizeRcCourseItem(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );

        final cid = normalized['course_id']?.toString() ?? '';
        if (cid.isEmpty || seen.contains(cid)) {
          continue;
        }
        seen.add(cid);

        final merged = <String, dynamic>{...normalized};
        if ((merged['lesson_id'] == null || merged['lesson_id'].toString().isEmpty) &&
            lessonByCourseId.containsKey(cid)) {
          merged['lesson_id'] = lessonByCourseId[cid];
        }

        final course = Course.fromRCJson(merged);
        course.schools = school;
        contentList.add(course);
      }

      if (contentList.isEmpty && onLessonItems.isNotEmpty) {
        _logRc('getCoursesList fallback: build from onLessonItems');
        for (final item in onLessonItems) {
          if (item is! Map) {
            continue;
          }
          final normalized = _normalizeRcOnLessonItem(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
          final cid = normalized['course_id']?.toString() ?? '';
          if (cid.isEmpty || seen.contains(cid)) {
            continue;
          }
          seen.add(cid);

          final merged = <String, dynamic>{...normalized};
          if ((merged['lesson_id'] == null || merged['lesson_id'].toString().isEmpty) &&
              lessonByCourseId.containsKey(cid)) {
            merged['lesson_id'] = lessonByCourseId[cid];
          }

          final course = Course.fromRCJson(merged);
          course.schools = school;
          contentList.add(course);
        }
      }

      _logRc('getCoursesList result count=${contentList.length}');

      return contentList;
    } catch (e, stackTrace) {
      _logRc('getCoursesList error: $e\n$stackTrace');
      return null;
    }
  }

  static Future<int?> checkIn(String lessonId) async {
    try {
      _logRc('checkIn start lessonId=$lessonId');
      final url = '/api/v3/lesson/checkin';
      final jsonData = {
        'source': 21, // 21: 扫码跳转 23: 点击课堂
        'lessonId': lessonId,
        'joinIfNotIn': true,
      };
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );
      final data = response.data;
      _logApiEndpoint('RC', 'response', url, data: data);

      final int code = data['code'];
      if (code == 0) {
        // 为当前用户保存 bearerToken（从响应头获取）
        final bearerToken = response.headers.value('set-auth')!;
        final lessonToken = data['data']['lessonToken'];
        _setToken(bearerToken, lessonToken);
        _logRc('checkIn success lessonId=$lessonId');
        return 0;
      } else {
        // {"code":50070,"msg":"DYNAMIC_QR_CHECK_IN_REFUSED","data":null}
        _logRc('checkIn failed lessonId=$lessonId code=$code msg=${data['msg']}');
        return code;
      }
    } catch (e) {
      _logRc('checkIn error lessonId=$lessonId error=$e');
    }
    return null;
  }

  static Future<int?> scan(String qrCodeUrl) async {
    try {
      final scanUrl = '/api/v3/app/scan';
      final candidates = <String>{};

      final normalizedInput = qrCodeUrl.trim();
      candidates.add(normalizedInput);
      if (normalizedInput.startsWith('http://')) {
        candidates.add('https://${normalizedInput.substring('http://'.length)}');
      }

      final resolved = await _resolveRainQrUrl(normalizedInput);
      if (resolved != null && resolved.isNotEmpty) {
        candidates.add(resolved);
        if (resolved.startsWith('http://')) {
          candidates.add('https://${resolved.substring('http://'.length)}');
        }
      }

      _logRc('scan start candidateCount=${candidates.length} raw=${normalizedInput.length > 90 ? '${normalizedInput.substring(0, 90)}...' : normalizedInput}');

      int? lastCode;
      for (final candidate in candidates) {
        _logRc('scan try candidate=${candidate.length > 120 ? '${candidate.substring(0, 120)}...' : candidate}');
        final response = await ApiService.sendRequest(
          scanUrl,
          method: 'POST',
          body: {'url': candidate},
        );
        final data = response.data;
        _logApiEndpoint('RC', 'response', '$scanUrl -> $candidate', data: data);
        final code = data['code'] as int?;
        lastCode = code;
        _logRc('scan response code=$code msg=${data['msg']}');

        if (code == 0) {
          // {"code":0,"msg":"OK","data":{"type":"checkin","value":"1632189922935066880"}}
          final lessonId = data['data']?['value']?.toString();
          if (lessonId != null && lessonId.isNotEmpty) {
            _logRc('scan parsed lessonId=$lessonId');
            final checkResult = await checkIn(lessonId);
            if (checkResult == 0) {
              _logRc('scan final success lessonId=$lessonId');
              return 0;
            }
            // If checkIn failed but we still have alternative candidate URLs, keep trying.
            lastCode = checkResult ?? lastCode;
            _logRc('scan continue after checkIn failure checkResult=$checkResult');
            continue;
          }
        }
      }

      // {"code":51203,"msg":"动态二维码过期","data":{"type":"default","value":""}}
      _logRc('scan finished failed lastCode=$lastCode');
      return lastCode;
    } catch (e) {
      _logRc('scan error: $e');
    }
    return null;
  }

  static bool _isRainQrUri(Uri uri) {
    return uri.path == '/api/v3/lesson/check-in/dynamic-qr-code' &&
        uri.host.contains('yuketang.cn');
  }

  static Uri? _extractRainQrUriFromText(String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final normalized = text.replaceAll('&amp;', '&');
    final regex = RegExp(
      "https?://[^\\s\"']+/api/v3/lesson/check-in/dynamic-qr-code\\?[^\\s\"']+",
      caseSensitive: false,
    );
    final match = regex.firstMatch(normalized);
    if (match != null) {
      final candidate = match.group(0)!;
      try {
        return Uri.parse(candidate);
      } catch (_) {
        try {
          return Uri.parse(Uri.decodeFull(candidate));
        } catch (_) {
          return null;
        }
      }
    }

    try {
      final decoded = Uri.decodeComponent(normalized);
      if (decoded != normalized) {
        return _extractRainQrUriFromText(decoded);
      }
    } catch (_) {
      // ignore malformed encoding
    }
    return null;
  }

  static Future<String?> _resolveRainQrUrl(String rawUrl) async {
    Uri? uri;
    try {
      uri = Uri.parse(rawUrl);
    } catch (_) {
      return null;
    }

    if (_isRainQrUri(uri)) {
      return uri.toString();
    }

    // Try API service redirect chain first.
    try {
      final resp = await ApiService.sendRequest(
        rawUrl,
        responseType: ResponseType.plain,
        allowRedirects: true,
      );
      final finalUri = resp.requestOptions.uri;
      if (_isRainQrUri(finalUri)) {
        return finalUri.toString();
      }
      final fromBody = _extractRainQrUriFromText(resp.data?.toString());
      if (fromBody != null) {
        return fromBody.toString();
      }
    } catch (_) {
      // continue with raw resolver
    }

    // Raw redirect resolver fallback, independent from app interceptors.
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      var current = rawUrl;
      for (int i = 0; i < 8; i++) {
        final resp = await dio.get(
          current,
          options: Options(
            responseType: ResponseType.plain,
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36',
            },
          ),
        );

        final reqUri = resp.requestOptions.uri;
        if (_isRainQrUri(reqUri)) {
          return reqUri.toString();
        }

        final fromBody = _extractRainQrUriFromText(resp.data?.toString());
        if (fromBody != null) {
          return fromBody.toString();
        }

        final location = resp.headers.value('location');
        if (location == null || location.isEmpty) {
          break;
        }

        final currentUri = Uri.parse(current);
        final locationUri = Uri.parse(location);
        current = locationUri.hasScheme
            ? locationUri.toString()
            : currentUri.resolveUri(locationUri).toString();

        final fromLocation = _extractRainQrUriFromText(location);
        if (fromLocation != null) {
          return fromLocation.toString();
        }
      }
    } catch (_) {
      // keep null on failure
    }

    // Last fallback: attempt extraction from original raw content.
    final fromRaw = _extractRainQrUriFromText(rawUrl);
    return fromRaw?.toString();
  }

  static Future<Map<String, dynamic>?> getPresentation(
    String presentationId,
  ) async {
    try {
      final url =
          '/api/v3/lesson/presentation/fetch?presentation_id=$presentationId';
      final bearerToken = getBearerToken();
      if (bearerToken == null) {
        debugPrint('bearerToken 为空');
        return null;
      }
      final headers = {'authorization': 'Bearer $bearerToken'};
      final response = await ApiService.sendRequest(url, headers: headers);
      _logApiEndpoint('RC', 'response', url, data: response.data);
      return response.data['data'];
    } catch (e) {
      _logApiEndpoint('RC', 'error', 'lesson/presentation/fetch', error: e);
      debugPrint('getPresentation error: $e');
    }
    return null;
  }

  /// 提交答案
  /// 在answer提交失败后会反复进行retry
  static Future<Map<String, dynamic>?> answer(
    String problemId,
    int problemType, {
    bool retry = false,
    int? time,
    List<String>? options,
    String? content,
    List<String>? imageUrls,
  }) async {
    try {
      final url = retry
          ? '/api/v3/lesson/problem/retry'
          : '/api/v3/lesson/problem/answer';
      final bearerToken = getBearerToken();
      if (bearerToken == null) {
        debugPrint('bearerToken 为空');
        return null;
      }
      final headers = {'authorization': 'Bearer $bearerToken'};
      final timestampMS = (time == null)
          ? DateTime.now().millisecondsSinceEpoch
          : time;
      late dynamic result;
      if (problemType == 5) {
        // 主观题
        var pics = [];
        if (imageUrls != null) {
          for (var imageUrl in imageUrls) {
            pics.add({
              'pic': imageUrl, // https://qn-v.yuketang.cn/tmp_.jpg
              'thumb': '$imageUrl?imageView2/2/w/568',
            });
          }
        } else {
          pics = [
            {
              'pic': '', // https://qn-v.yuketang.cn/tmp_.jpg
              'thumb': '',
            },
          ];
        }
        result = {
          'content': content ?? '',
          'pics': pics,
          'videos': [], // 雨课堂对视频的支持不好 不做处理了
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
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        headers: headers,
        body: jsonData,
      );
      _logApiEndpoint('RC', 'response', url, data: response.data);
      return response.data;
    } catch (e) {
      _logApiEndpoint('RC', 'error', 'lesson/problem/answer', error: e);
      debugPrint('answer error: $e');
    }
    return null;
  }
}

class TCCourseApi {
  static void _logTc(String stage, String endpoint, {dynamic data, Object? error}) {
    _logApiEndpoint('TC', stage, endpoint, data: data, error: error);
  }

  static Future<Map<String, dynamic>?> getRollcalls() async {
    try {
      const endpoint = '/api/radar/rollcalls';
      _logTc('request', endpoint);
      final response = await ApiService.sendRequest(
        endpoint,
        params: {'api_version': '1.1.0'},
      );
      _logTc('response', endpoint, data: response.data);
      return response.data;
    } catch (e) {
      _logTc('error', '/api/radar/rollcalls', error: e);
      debugPrint('getRollcalls error: $e');
    }
    return null;
  }

  static Future<List<Course>?> getCoursesList() async {
    try {
      final data = await getRollcalls();
      if (data == null || data['rollcalls'] is! List) {
        return [];
      }

      final List<dynamic> rollcalls = data['rollcalls'];
      final Map<String, Course> courseMap = {};

      for (final item in rollcalls) {
        if (item is! Map<String, dynamic>) continue;

        final String courseId = (item['course_id'] ?? '').toString();
        if (courseId.isEmpty) continue;

        final String courseTitle = (item['course_title'] ?? '未知课程').toString();
        final String className = (item['class_name'] ?? '').toString();
        final String teacherName = (item['created_by_name'] ?? '未知教师')
            .toString();
        final String avatar = (item['avatar_big_url'] ?? '').toString();

        courseMap[courseId] ??= Course(
          courseId: courseId,
          classId: className,
          image: avatar,
          name: courseTitle,
          teacher: teacherName,
          note: className,
          schools: '桂林电子科技大学',
          state: true,
          lessonId: null,
        );
      }

      return courseMap.values.toList();
    } catch (e) {
      debugPrint('tronclass getCoursesList error: $e');
      return [];
    }
  }

  static Future<List<Active>> getSignActivities(String courseId) async {
    try {
      final data = await getRollcalls();
      if (data == null || data['rollcalls'] is! List) {
        return [];
      }

      final List<dynamic> rollcalls = data['rollcalls'];
      final List<Active> activities = [];

      for (final item in rollcalls) {
        if (item is! Map<String, dynamic>) continue;
        if ((item['course_id'] ?? '').toString() != courseId) continue;

        final rollcallId =
            (item['rollcall_id'] ?? item['id'] ?? item['activity_id'] ?? '')
                .toString();
        if (rollcallId.isEmpty) continue;

        final title =
            (item['title'] ??
                    item['rollcall_title'] ??
                    item['course_title'] ??
                    '课堂签到')
                .toString();
        final description =
            (item['class_name'] ?? item['created_by_name'] ?? '').toString();

        final signTypeIndex =
            int.tryParse(
              (item['sign_type'] ??
                      item['rollcall_type'] ??
                      item['checkin_type'] ??
                      0)
                  .toString(),
            ) ??
            0;

        final bool signed = _detectSigned(item);
        final String mode = _detectSignMode(item);

        final rollcallStatus = (item['rollcall_status'] ?? item['status'] ?? '')
            .toString()
            .toLowerCase();
        final bool isExpired = item['is_expired'] == true;
        final bool isOpenByStatus =
            rollcallStatus == 'in_progress' ||
            rollcallStatus == 'open' ||
            rollcallStatus == 'opened' ||
            rollcallStatus == 'active' ||
            rollcallStatus == 'ongoing' ||
            rollcallStatus == 'on_call';
        final bool open = !isExpired && isOpenByStatus;

        activities.add(
          Active(
            type: 2,
            id: rollcallId,
            name: title,
            description: description,
            startTime: 0,
            url: '',
            status: open,
            extras: {
              ...item,
              '_signed': signed,
              '_open': open,
              '_mode': mode,
              '_rollcall_status': rollcallStatus,
              '_status': (item['status'] ?? '').toString().toLowerCase(),
            },
            signType: getSignTypeFromIndex(signTypeIndex),
          ),
        );
      }

      activities.sort((a, b) => b.id.compareTo(a.id));
      return activities;
    } catch (e) {
      debugPrint('tronclass getSignActivities error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> sign(
    String rollcallId, {
    String? signCode,
    String? mode,
    String? qrPayload,
    String? numberCode,
    double? radarLatitude,
    double? radarLongitude,
    double? radarAccuracy,
  }) async {
    final normalizedMode = (mode ?? '').toLowerCase();
    final normalizedNumber = numberCode?.trim() ?? signCode?.trim();
    final deviceId = EncryptionUtil.getUniqueId();

    final candidates = <Map<String, dynamic>>[];
    if (normalizedMode == 'qrcode') {
      candidates.add({
        'url': '/api/rollcall/$rollcallId/answer_qr_rollcall',
        'method': 'PUT',
        'body': <String, dynamic>{'data': qrPayload, 'deviceId': deviceId},
      });
    } else if (normalizedMode == 'number') {
      candidates.add({
        'url': '/api/rollcall/$rollcallId/answer_number_rollcall',
        'method': 'PUT',
        'body': <String, dynamic>{
          'numberCode': normalizedNumber,
          'deviceId': deviceId,
        },
      });
    } else if (normalizedMode == 'radar') {
      final latitude = radarLatitude ?? 0;
      final longitude = radarLongitude ?? 0;
      final transformed = CoordTransform.bd09ToGcj02(latitude, longitude);
      final accuracy = radarAccuracy ?? 0;
      candidates.add({
        'url': '/api/rollcall/$rollcallId/answer?api_version=1.1.2',
        'method': 'PUT',
        'body': <String, dynamic>{
          'deviceId': deviceId,
          'latitude': transformed[0],
          'longitude': transformed[1],
          'accuracy': accuracy,
          'altitude': 0,
        },
      });
    }

    // 兼容历史接口，防止服务端环境差异
    candidates.addAll([
      {
        'url': '/api/radar/rollcalls/$rollcallId/checkin',
        'method': 'POST',
        'body': <String, dynamic>{
          if (normalizedNumber != null && normalizedNumber.isNotEmpty)
            'sign_code': normalizedNumber,
          if (qrPayload != null && qrPayload.isNotEmpty) 'data': qrPayload,
        },
      },
      {
        'url': '/api/radar/rollcalls/checkin',
        'method': 'POST',
        'body': <String, dynamic>{
          'rollcall_id': rollcallId,
          if (normalizedNumber != null && normalizedNumber.isNotEmpty)
            'sign_code': normalizedNumber,
          if (qrPayload != null && qrPayload.isNotEmpty) 'data': qrPayload,
        },
      },
    ]);

    String? lastError;
    for (final req in candidates) {
      try {
        final endpoint = req['url'].toString();
        _logTc('request', endpoint, data: req['body']);
        final response = await ApiService.sendRequest(
          endpoint,
          method: req['method'].toString(),
          body: req['body'],
        );
        final data = response.data;
        _logTc('response', endpoint, data: data);
        if (_isSignSuccess(data)) {
          return {'ok': true, 'message': '签到成功'};
        }
        lastError = _extractSignErrorMessage(data) ?? '签到失败';
      } catch (e) {
        _logTc('error', req['url'].toString(), error: e);
        lastError = e.toString();
      }
    }

    return {'ok': false, 'message': lastError ?? '签到失败，接口未返回可用结果'};
  }

  static bool _isSignSuccess(dynamic data) {
    if (data is! Map<String, dynamic>) return false;

    if (data['success'] == true || data['result'] == true) {
      return true;
    }

    final code = data['code'];
    if (code == 0 || code == '0' || code == 200 || code == '200') {
      return true;
    }

    final msg = (data['msg'] ?? data['message'] ?? '').toString();
    if (msg.contains('成功') || msg.toLowerCase().contains('success')) {
      return true;
    }

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'on_call' || status == 'on_call_fine') {
      return true;
    }

    return false;
  }

  static bool _detectSigned(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    if (status == 'on_call_fine' ||
        status == 'present' ||
        status == 'late' ||
        status == 'excused') {
      return true;
    }

    final boolKeys = <String>[
      'signed',
      'is_signed',
      'has_signed',
      'checked',
      'checked_in',
      'is_checked_in',
      'attended',
      'has_attended',
      'user_signed',
      'is_user_signed',
      'is_checkin',
      'checkin',
    ];

    for (final key in boolKeys) {
      if (!item.containsKey(key)) continue;
      final value = item[key];
      if (value == true) return true;
      if (value is num && value > 0) return true;
      final text = value?.toString().toLowerCase() ?? '';
      if (text == 'true' ||
          text == '1' ||
          text == 'signed' ||
          text == 'checked') {
        return true;
      }
    }

    final statusFields = <String>[
      'attend_status',
      'checkin_status',
      'user_status',
      'status_text',
    ];
    for (final key in statusFields) {
      if (!item.containsKey(key)) continue;
      final text = (item[key] ?? '').toString().toLowerCase();
      if (text.contains('已签到') ||
          text.contains('signed') ||
          text.contains('checked')) {
        return true;
      }
    }

    return false;
  }

  static String _detectSignMode(Map<String, dynamic> item) {
    final isNumber = item['is_number'] == true;
    if (isNumber) {
      return 'number';
    }

    final isRadar = item['is_radar'] == true;
    if (isRadar) {
      return 'radar';
    }

    final type = (item['type'] ?? '').toString().toLowerCase();
    if (type.contains('qr_rollcall') || type.contains('manual_rollcall')) {
      return 'qrcode';
    }

    final source = (item['source'] ?? '').toString().toLowerCase();
    if (source == 'qr') {
      return 'qrcode';
    }

    final rawType =
        (item['sign_type'] ??
                item['rollcall_type'] ??
                item['checkin_type'] ??
                '')
            .toString()
            .toLowerCase();

    if (rawType.contains('qr') || rawType.contains('qrcode')) {
      return 'qrcode';
    }
    if (rawType.contains('radar') || rawType.contains('beacon')) {
      return 'radar';
    }
    if (rawType.contains('number') ||
        rawType.contains('digit') ||
        rawType.contains('code')) {
      return 'number';
    }

    final typeAsInt = int.tryParse(rawType);
    if (typeAsInt != null) {
      if (typeAsInt == 2) return 'qrcode';
      if (typeAsInt == 4) return 'radar';
      if (typeAsInt == 5 || typeAsInt == 6) return 'number';
    }

    final mergedText = [
      item['title'],
      item['rollcall_title'],
      item['name'],
      item['desc'],
      item['description'],
    ].join(' ').toLowerCase();

    if (mergedText.contains('二维码') || mergedText.contains('扫码')) {
      return 'qrcode';
    }
    if (mergedText.contains('雷达') || mergedText.contains('定位')) {
      return 'radar';
    }
    if (mergedText.contains('数字') || mergedText.contains('签到码')) {
      return 'number';
    }

    return 'unknown';
  }

  static String? _extractSignErrorMessage(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final msg = data['msg'] ?? data['message'] ?? data['error'];
    if (msg == null) return null;
    final text = msg.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class KTCourseApi {
  static final Map<String, Map<String, dynamic>> _courseDetailCache =
      <String, Map<String, dynamic>>{};
  static final Map<String, int> _courseDetailCacheTs = <String, int>{};
  static const int _courseDetailCacheTtlMs = 8 * 60 * 1000;

  static void _logKt(String stage, String endpoint, {dynamic data, Object? error}) {
    _logApiEndpoint('KT', stage, endpoint, data: data, error: error);
  }

  static String _text(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _normalizeImageUrl(dynamic value) {
    final raw = _text(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    if (raw.startsWith('/')) {
      return '${PlatformManager().ketangpaiBaseUrl}$raw';
    }
    return raw;
  }

  static List<Map<String, dynamic>> _extractCourseItems(dynamic data) {
    dynamic source = data;
    if (source is Map<String, dynamic> && source['data'] != null) {
      source = source['data'];
    }

    if (source is List) {
      return source
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (source is Map<String, dynamic>) {
      const candidates = ['list', 'topcourses', 'courses', 'courseList'];
      for (final key in candidates) {
        final v = source[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  static bool _isUnknownCourse(Course course) {
    final name = course.name.trim();
    return name.isEmpty || name == '未知课程';
  }

  static Course _mergeCourseWithDetail(
    Course base,
    Map<String, dynamic> detail,
  ) {
    final name = _text(detail['coursename'], base.name);
    final className = _text(
      detail['classname'] ??
          detail['class_name'] ??
          detail['classroom_name'] ??
          detail['classroomName'],
      base.note ?? '',
    );
    final classId = _text(
      detail['classid'] ??
          detail['classId'] ??
          detail['classroomid'] ??
          detail['classroom_id'] ??
          detail['classroomId'],
      base.classId,
    );
    final teacherMap = detail['teacher'] is Map<String, dynamic>
        ? detail['teacher'] as Map<String, dynamic>
        : null;
    final teacherList = detail['teacherlist'] ?? detail['teacherList'];
    final teacherName = _text(teacherMap?['name'], base.teacher);
    final teacherAvatar = _normalizeImageUrl(
      teacherMap?['avatar'] ??
          (teacherList is List &&
                  teacherList.isNotEmpty &&
                  teacherList.first is Map<String, dynamic>
              ? (teacherList.first as Map<String, dynamic>)['avatar']
              : null),
    );
    final schoolName = _text(
      detail['schoolname'] ??
          detail['schoolName'] ??
          detail['school'] ??
          detail['schools'],
      base.schools ?? '',
    );
    final code = _text(
      detail['code'] ?? detail['coursecode'] ?? detail['courseCode'],
    );
    final lessonId = _text(
      detail['lesson_id'] ?? detail['lessonId'] ?? detail['lessonid'],
      base.lessonId ?? '',
    );

    final theme = detail['theme'] is Map<String, dynamic>
        ? detail['theme'] as Map<String, dynamic>
        : null;
    final themeImage = _normalizeImageUrl(
      theme?['minpic'] ??
          theme?['middlepic'] ??
          theme?['studentminpic'] ??
          theme?['teacherbgpic'],
    );

    return Course(
      courseId: base.courseId,
      classId: classId.isEmpty ? base.classId : classId,
      cpi: base.cpi,
      image: base.image.isNotEmpty
          ? base.image
          : (teacherAvatar.isNotEmpty ? teacherAvatar : themeImage),
      name: name,
      teacher: teacherName,
      schools: schoolName.isEmpty ? base.schools : schoolName,
      note: className.isNotEmpty
          ? className
          : (code.isNotEmpty ? code : base.note),
      state: base.state,
      beginDate: base.beginDate,
      endDate: base.endDate,
      lessonId: lessonId.isEmpty ? base.lessonId : lessonId,
    );
  }

  static bool _needsCourseEnrichment(Course course) {
    final teacherMissing =
        course.teacher.trim().isEmpty || course.teacher == '未知教师';
    final imageMissing = course.image.trim().isEmpty;
    final schoolMissing = (course.schools ?? '').trim().isEmpty;
    final noteMissing = (course.note ?? '').trim().isEmpty;
    final classMissing = course.classId.trim().isEmpty;
    final lessonMissing = (course.lessonId ?? '').trim().isEmpty;
    return _isUnknownCourse(course) ||
        teacherMissing ||
        imageMissing ||
        schoolMissing ||
        noteMissing ||
        classMissing ||
        lessonMissing;
  }

  static Future<Map<String, dynamic>?> _getCourseDetailCached(
    String courseId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _courseDetailCache[courseId];
    final ts = _courseDetailCacheTs[courseId] ?? 0;
    if (cached != null && now - ts <= _courseDetailCacheTtlMs) {
      return cached;
    }

    final detailResp = await getCourseDetail(courseId);
    if (detailResp == null) return null;
    final detailData = detailResp['data'];
    if (detailData is Map<String, dynamic>) {
      _courseDetailCache[courseId] = detailData;
      _courseDetailCacheTs[courseId] = now;
      return detailData;
    }
    return null;
  }

  static Course _pickBetterCourse(Course a, Course b) {
    final aUnknown = _isUnknownCourse(a);
    final bUnknown = _isUnknownCourse(b);
    if (aUnknown != bUnknown) {
      return aUnknown ? b : a;
    }
    if (a.image.isEmpty && b.image.isNotEmpty) {
      return b;
    }
    if ((a.note ?? '').isEmpty && (b.note ?? '').isNotEmpty) {
      return b;
    }
    return a;
  }

  static String _courseKey(Course course, Map<String, dynamic> source) {
    if (course.courseId.isNotEmpty) return course.courseId;
    if (course.classId.isNotEmpty) return 'class_${course.classId}';
    final sourceId = _text(source['id']);
    if (sourceId.isNotEmpty) return sourceId;
    return source.toString();
  }

  static Future<Map<String, dynamic>?> getSemesterCourseList({
    String? semester,
    String? term,
    String isStudy = '1',
  }) async {
    try {
      const endpoint = '/CourseApi/semesterCourseList';
      final body = {'semester': semester, 'term': term, 'isstudy': isStudy};
      _logKt('request', endpoint, data: body);
      final response = await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: body,
      );
      _logKt('response', endpoint, data: response.data);
      return response.data;
    } catch (e) {
      _logKt('error', '/CourseApi/semesterCourseList', error: e);
      debugPrint('KTCourseApi.getSemesterCourseList error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getCourseStateAll() async {
    try {
      const endpoint = '/CourseApi/getCourseStateAll';
      _logKt('request', endpoint);
      final response = await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: const <String, dynamic>{},
      );
      _logKt('response', endpoint, data: response.data);
      return response.data;
    } catch (e) {
      _logKt('error', '/CourseApi/getCourseStateAll', error: e);
      debugPrint('KTCourseApi.getCourseStateAll error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> _collectCourseSourceItems({
    String? semester,
    String? term,
  }) async {
    final results = await Future.wait<dynamic>([
      getSemesterCourseList(semester: semester, term: term, isStudy: '1'),
      getSemesterCourseList(semester: semester, term: term, isStudy: '0'),
      getCourseStateAll(),
    ]);

    final merged = <Map<String, dynamic>>[];
    for (final result in results) {
      if (result is! Map<String, dynamic>) continue;
      final primary = _extractCourseItems(result['data']);
      if (primary.isNotEmpty) {
        merged.addAll(primary);
      }
      final secondary = _extractCourseItems(result);
      if (secondary.isNotEmpty) {
        merged.addAll(secondary);
      }
    }
    return merged;
  }

  static Future<List<Course>> getCoursesList({
    String? semester,
    String? term,
  }) async {
    try {
      _logKt('request', 'getCoursesList aggregate', data: {
        'semester': semester,
        'term': term,
      });
      final items = await _collectCourseSourceItems(
        semester: semester,
        term: term,
      );
      if (items.isEmpty) {
        _logKt('response', 'getCoursesList aggregate', data: const {'items': 0});
        return [];
      }

      final map = <String, Course>{};
      for (final item in items) {
        final course = Course.fromKTPJson(item);
        final key = _courseKey(course, item);
        if (map.containsKey(key)) {
          map[key] = _pickBetterCourse(map[key]!, course);
        } else {
          map[key] = course;
        }
      }

      final courses = map.values.toList();

      // 为保证信息完整，对关键字段不全的课程执行受控补全（缓存 + 小间隔）。
      final needEnrich = courses
          .where((c) => c.courseId.isNotEmpty && _needsCourseEnrichment(c))
          .toList();
      for (final course in needEnrich) {
        final detail = await _getCourseDetailCached(course.courseId);
        if (detail == null) continue;
        final index = courses.indexWhere((c) => c.courseId == course.courseId);
        if (index < 0) continue;
        courses[index] = _mergeCourseWithDetail(courses[index], detail);
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      courses.sort((a, b) {
        final aUnknown = _isUnknownCourse(a);
        final bUnknown = _isUnknownCourse(b);
        if (aUnknown != bUnknown) {
          return aUnknown ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });

      _logKt('response', 'getCoursesList aggregate', data: {
        'items': items.length,
        'courses': courses.length,
      });

      return courses;
    } catch (e) {
      _logKt('error', 'getCoursesList aggregate', error: e);
      debugPrint('KTCourseApi.getCoursesList error: $e');
      return [];
    }
  }

  static Future<List<Course>> getSigningCourses({
    String? semester,
    String? term,
  }) async {
    try {
      final courses = await getCoursesList(semester: semester, term: term);
      final signingCourses = <Course>[];

      for (final course in courses) {
        final signInfo = await getNotFinishSign(course.courseId);
        if (signInfo.isNotEmpty) {
          signingCourses.add(course);
        }
      }
      return signingCourses;
    } catch (e) {
      debugPrint('KTCourseApi.getSigningCourses error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getNotFinishSign(
    String courseId,
  ) async {
    try {
      const endpoint = '/AttenceApi/getNotFinishAttenceStudent';
      _logKt('request', endpoint, data: {'courseid': courseId});
      final response = await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: {
          'courseid': courseId,
          'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      _logKt('response', endpoint, data: response.data);
      final data = response.data;
      final lists = data['data']?['lists'];
      if (lists is List) {
        return lists
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      _logKt('error', '/AttenceApi/getNotFinishAttenceStudent', error: e);
      debugPrint('KTCourseApi.getNotFinishSign error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getCourseDetail(String courseId) async {
    try {
      const endpoint = '/CourseBigDataApi/getCourseBaseDataV2';
      _logKt('request', endpoint, data: {'courseid': courseId});
      final response = await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: {
          'courseid': courseId,
          'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      _logKt('response', endpoint, data: response.data);
      return response.data;
    } catch (e) {
      _logKt('error', '/CourseBigDataApi/getCourseBaseDataV2', error: e);
      debugPrint('KTCourseApi.getCourseDetail error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getSignStatus(String courseId) async {
    try {
      final response = await ApiService.sendRequest(
        '/SummaryApi/attence',
        method: 'POST',
        body: {'courseid': courseId, 'page': 1, 'size': 10},
      );
      return response.data;
    } catch (e) {
      debugPrint('KTCourseApi.getSignStatus error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getCourseContentList(
    String courseId,
  ) async {
    try {
      final response = await ApiService.sendRequest(
        '/FutureV2/CourseMeans/getCourseContent',
        method: 'POST',
        body: {
          'courseid': courseId,
          'contenttype': 6,
          'dirid': 0,
          'lessonlink': [],
          'sort': [],
          'page': 1,
          'limit': 50,
          'desc': 3,
          'courserole': 0,
          'vtr_type': '',
          'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      final data = response.data['data'];
      if (data is Map<String, dynamic> && data['list'] is List) {
        return (data['list'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('KTCourseApi.getCourseContentList error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getExamInfo(
    String courseId,
    String paperId,
  ) async {
    try {
      final response = await ApiService.sendRequest(
        '/TestpaperApi/testpaperdetails',
        method: 'POST',
        body: {
          'courseid': courseId,
          'testpaperid': paperId,
          'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('KTCourseApi.getExamInfo error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getExamQuestions(
    String courseId,
    String testPaperId,
  ) async {
    try {
      final response = await ApiService.sendRequest(
        '/TestpaperApi/doSubjectList',
        method: 'POST',
        body: {
          'courseid': courseId,
          'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
          'testCode': 'undefined',
          'testpaperid': testPaperId,
        },
      );
      return response.data;
    } catch (e) {
      debugPrint('KTCourseApi.getExamQuestions error: $e');
    }
    return null;
  }

  static Future<bool> submitExamAnswer({
    required String courseId,
    required String testPaperId,
    required String subjectId,
    required String answer,
  }) async {
    try {
      final response = await ApiService.sendRequest(
        '/TestpaperApi/saveAnswer',
        method: 'POST',
        body: {
          'courseid': courseId,
          'testpaperid': testPaperId,
          'subjectid': subjectId,
          'answer': answer,
          'attachment': '',
          'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return response.data['code'] == 10000;
    } catch (e) {
      debugPrint('KTCourseApi.submitExamAnswer error: $e');
    }
    return false;
  }

  static Future<bool> submitExamPaper(
    String courseId,
    String testPaperId,
  ) async {
    try {
      final response = await ApiService.sendRequest(
        '/TestpaperApi/handup',
        method: 'POST',
        body: {
          'courseid': courseId,
          'testpaperid': testPaperId,
          'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return response.data['code'] == 10000;
    } catch (e) {
      debugPrint('KTCourseApi.submitExamPaper error: $e');
    }
    return false;
  }
}
