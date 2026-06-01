import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import 'api_service.dart';
import 'ketangpai_attendance_api.dart';
import 'ketangpai_course.dart';
import 'tronclass_sign_api.dart';
import 'tronclass_client.dart';
import '../session/account.dart';
import '../utils/encrypt.dart';
import '../models/active.dart';
import '../models/course.dart';
import '../models/tronclass_rollcalls.dart';

class CXCourseApi {
  /// 获取课程列表
  static Future<Map<String, dynamic>?> getCourses() async {
    try {
      final url =
          'https://mooc1-api.chaoxing.com/mycourse/backclazzdata?view=json&getTchClazzType=1&mcode=';

      final response = await ApiService.sendRequest(
        url,
        responseType: ResponseType.plain,
      );

      ApiService.appendExternalConsoleLog(
        '学习通',
        '响应状态码: ${response.statusCode}',
      );
      ApiService.appendExternalConsoleLog(
        '学习通',
        '响应数据类型: ${response.data.runtimeType}',
      );
      ApiService.appendExternalConsoleLog(
        '学习通',
        '响应数据前500字符: ${response.data.toString().substring(0, response.data.toString().length > 500 ? 500 : response.data.toString().length)}',
      );

      // 检查是否返回 HTML（登录失效）
      if (response.data is String &&
          response.data.toString().trim().startsWith('<!')) {
        ApiService.appendExternalConsoleLog(
          '学习通',
          '接口返回 HTML，可能是登录态失效或 Cookie 无效',
        );
        return null;
      }

      // 手动解析 JSON
      if (response.data is String) {
        try {
          final jsonData = jsonDecode(response.data);
          if (jsonData is Map<String, dynamic>) {
            return jsonData;
          }
        } catch (e) {
          ApiService.appendExternalConsoleLog('学习通', 'JSON 解析失败: $e');
          return null;
        }
      }

      return response.data;
    } catch (e) {
      ApiService.appendExternalConsoleLog('学习通', 'getCourses error: $e');
      debugPrint('getCourses error: $e');
    }
    return null;
  }

  /// 获取处理后的课程列表
  static Future<List<Course>?> getCoursesList() async {
    try {
      final coursesData = await getCourses();

      ApiService.appendExternalConsoleLog('学习通', '完整响应体: $coursesData');

      if (coursesData == null) {
        ApiService.appendExternalConsoleLog('学习通', 'coursesData 为 null');
        return null;
      }

      final result = coursesData['result'];
      ApiService.appendExternalConsoleLog('学习通', 'result=$result');

      if (result != 1) {
        ApiService.appendExternalConsoleLog('学习通', 'result != 1，返回 null');
        return null;
      }

      final channelList = coursesData['channelList'];
      ApiService.appendExternalConsoleLog(
        '学习通',
        'channelList 类型: ${channelList.runtimeType}',
      );
      ApiService.appendExternalConsoleLog(
        '学习通',
        'channelList 长度: ${channelList is List ? channelList.length : 0}',
      );

      if (channelList is! List) {
        ApiService.appendExternalConsoleLog('学习通', 'channelList 不是 List');
        return null;
      }

      List<Course> courses = [];

      for (var i = 0; i < channelList.length; i++) {
        final channel = channelList[i];

        if (channel is Map) {
          final content = channel['content'];
          ApiService.appendExternalConsoleLog(
            '学习通',
            'channel[$i].content keys: ${content is Map ? content.keys.toList() : 'not a map'}',
          );

          if (content is Map && content['course'] != null) {
            try {
              final course = Course.fromCXJson(
                Map<String, dynamic>.from(channel),
              );
              courses.add(course);
              ApiService.appendExternalConsoleLog(
                '学习通',
                '成功解析课程[$i]: ${course.name}, state=${course.state}',
              );
            } catch (e) {
              ApiService.appendExternalConsoleLog('学习通', '解析课程[$i]失败: $e');
            }
          } else {
            ApiService.appendExternalConsoleLog(
              '学习通',
              'channel[$i] 没有 content.course',
            );
          }
        }
      }

      ApiService.appendExternalConsoleLog('学习通', '解析到 ${courses.length} 门课程');

      // 过滤已结课的课程
      final activeCourses = courses.where((course) => course.state).toList();
      ApiService.appendExternalConsoleLog(
        '学习通',
        '过滤后剩余 ${activeCourses.length} 门进行中的课程',
      );

      return activeCourses;
    } catch (e, stackTrace) {
      ApiService.appendExternalConsoleLog('学习通', 'getCoursesList error: $e');
      debugPrint('[CX] StackTrace: $stackTrace');
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
      return response.data;
    } catch (e) {
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
      return response.data;
    } catch (e) {
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
  static Map<String, dynamic>? _lastCourseDebugSummary;

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

  @visibleForTesting
  static String buildLessonPageReferer(String lessonId) {
    return 'https://www.yuketang.cn/lesson/student/v3/$lessonId?source=12';
  }

  @visibleForTesting
  static String buildMiniProgramReferer() {
    return 'https://servicewechat.com/wxdff6636b7cf6907d/207/page-frame.html';
  }

  @visibleForTesting
  static Map<String, dynamic> buildCheckInRequestBody(
    String lessonId, {
    required int source,
    bool joinIfNotIn = false,
  }) {
    final body = <String, dynamic>{'source': source, 'lessonId': lessonId};
    if (joinIfNotIn) {
      body['joinIfNotIn'] = true;
    }
    return body;
  }

  @visibleForTesting
  static Map<String, String> buildCheckInHeaders({
    String? referer,
    String? bearerToken,
  }) {
    final headers = <String, String>{};
    if (referer != null && referer.isNotEmpty) {
      headers['Referer'] = referer;
    }
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $bearerToken';
    }
    return headers;
  }

  static Future<Map<String, dynamic>?> getCourses() async {
    try {
      final response = await ApiService.sendRequest(
        '/v/course_meta/learning_list/',
      );
      return response.data;
    } catch (e) {
      debugPrint('getCourses error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getOnLessonAndUpcomingExam() async {
    try {
      final response = await ApiService.sendRequest(
        '/api/v3/classroom/on-lesson-upcoming-exam',
      );
      return response.data;
    } catch (e) {
      debugPrint('getOnLessonAndUpcomingExam error: $e');
    }
    return null;
  }

  static Map<String, dynamic> _normalizeStringMap(Map source) {
    return source.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _asTrimmedString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static Map<String, dynamic> _cloneCourseItem(
    Map<String, dynamic> courseItem,
  ) {
    final cloned = Map<String, dynamic>.from(courseItem);
    final teacher = cloned['teacher'];
    if (teacher is Map) {
      cloned['teacher'] = _normalizeStringMap(teacher);
    }
    return cloned;
  }

  static void _updateCourseDebugSummary(Map<String, dynamic> patch) {
    final next = Map<String, dynamic>.from(_lastCourseDebugSummary ?? const {});
    next.addAll(patch);
    _lastCourseDebugSummary = next;
  }

  static Course _buildRainCourse(
    Map<String, dynamic> courseItem, {
    String? school,
    String? lessonId,
    required String logTag,
  }) {
    final normalized = _cloneCourseItem(courseItem);
    if (lessonId != null && lessonId.trim().isNotEmpty) {
      normalized['lesson_id'] = lessonId.trim();
    }

    final course = Course.fromRCJson(normalized);
    if (school != null) {
      course.schools = school;
    }

    debugPrint(
      '[YKT][$logTag] name=${course.name} '
      'course_id=${course.courseId} '
      'classroom_id=${course.classId} '
      'lesson_id=${course.lessonId ?? ''}',
    );
    return course;
  }

  /// 获取处理后的课程列表
  static Future<List<Course>?> getCoursesList([
    Map<String, dynamic>? onLessonCourses,
  ]) async {
    try {
      if (DateTime.now().millisecondsSinceEpoch >= 0) {
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

        if (courses == null || onLessonCourses == null) {
          return null;
        }

        final courseListRaw = courses['data'];
        final onLessonListRaw = onLessonCourses['data']?['onLessonClassrooms'];
        if (courseListRaw is! List || onLessonListRaw is! List) {
          _updateCourseDebugSummary({
            'ok': false,
            'reason': 'invalid course payload',
            'courseItems': 0,
            'onLessonItems': 0,
            'mergedResult': 0,
          });
          return null;
        }

        final rawCourseItems = courseListRaw
            .whereType<Map>()
            .map(_normalizeStringMap)
            .toList();
        final onLessonItems = onLessonListRaw
            .whereType<Map>()
            .map(_normalizeStringMap)
            .toList();

        final coursesByClassroomId = <String, Map<String, dynamic>>{};
        final coursesByCourseId = <String, Map<String, dynamic>>{};
        for (final courseItem in rawCourseItems) {
          final classroomId = _asTrimmedString(courseItem['classroom_id']);
          final courseId = _asTrimmedString(courseItem['course_id']);
          if (classroomId.isNotEmpty) {
            coursesByClassroomId[classroomId] = courseItem;
          }
          if (courseId.isNotEmpty) {
            coursesByCourseId.putIfAbsent(courseId, () => courseItem);
          }
        }

        final school =
            AccountManager.getAccountById(
              AccountManager.currentSessionId!,
            )?.school ??
            'Unknown School';

        var lessonByCourseId = 0;
        var lessonByCourseAndClassId = 0;
        final contentList = <Course>[];

        for (final onLessonItem in onLessonItems) {
          final courseId = _asTrimmedString(onLessonItem['courseId']);
          final classroomId = _asTrimmedString(onLessonItem['classroomId']);
          final lessonId = _asTrimmedString(onLessonItem['lessonId']);

          Map<String, dynamic>? matched;
          if (classroomId.isNotEmpty) {
            matched = coursesByClassroomId[classroomId];
          }
          if (matched != null) {
            lessonByCourseAndClassId++;
          } else if (courseId.isNotEmpty) {
            matched = coursesByCourseId[courseId];
            if (matched != null) {
              lessonByCourseId++;
            }
          }

          if (matched == null) {
            debugPrint(
              '[YKT][course-detail] unmatched course_id=$courseId classroom_id=$classroomId lesson_id=$lessonId',
            );
            continue;
          }

          contentList.add(
            _buildRainCourse(
              matched,
              school: school,
              lessonId: lessonId,
              logTag: 'merged',
            ),
          );
        }

        _updateCourseDebugSummary({
          'ok': true,
          'reason': '',
          'courseItems': rawCourseItems.length,
          'onLessonItems': onLessonItems.length,
          'mergedResult': contentList.length,
          'lessonByCourseId': lessonByCourseId,
          'lessonByCourseAndClassId': lessonByCourseAndClassId,
          'courseCode': courses['errcode'] ?? courses['code'] ?? 0,
          'onLessonCode': onLessonCourses['code'] ?? 0,
          'authExpired': false,
        });

        return contentList;
      }

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

      if (courses == null || onLessonCourses == null) {
        return null;
      }

      // 验证 courses 数据结构
      if (courses['data'] == null || courses['data'] is! List) {
        debugPrint('getCoursesList: courses[\'data\'] is null or not a list');
        return null;
      }

      // 验证 onLessonCourses 数据结构
      if (onLessonCourses['data'] == null ||
          onLessonCourses['data']['onLessonClassrooms'] == null ||
          onLessonCourses['data']['onLessonClassrooms'] is! List) {
        debugPrint('getCoursesList: onLessonCourses structure invalid');
        return null;
      }

      final rawCourseItems = courses['data']
          .whereType<Map>()
          .map(_normalizeStringMap)
          .toList();
      final onLessonItems =
          (onLessonCourses['data']['onLessonClassrooms'] as List)
              .whereType<Map>()
              .map(_normalizeStringMap)
              .toList();

      final coursesByClassroomId = <String, Map<String, dynamic>>{};
      final coursesByCourseId = <String, Map<String, dynamic>>{};
      for (final courseItem in rawCourseItems) {
        final classroomId = _asTrimmedString(courseItem['classroom_id']);
        final courseId = _asTrimmedString(courseItem['course_id']);
        if (classroomId.isNotEmpty) {
          coursesByClassroomId[classroomId] = courseItem;
        }
        if (courseId.isNotEmpty) {
          coursesByCourseId.putIfAbsent(courseId, () => courseItem);
        }
      }

      List<Course> contentList = [];
      var lessonByCourseId = 0;
      var lessonByCourseAndClassId = 0;

      final school = AccountManager.getAccountById(
        AccountManager.currentSessionId!,
      )!.school;

      for (final onLessonCourseItem in onLessonItems) {
        final courseId = _asTrimmedString(onLessonCourseItem['courseId']);
        final classroomId = _asTrimmedString(onLessonCourseItem['classroomId']);
        final lessonId = _asTrimmedString(onLessonCourseItem['lessonId']);

        Map<String, dynamic>? courseItem;
        if (classroomId.isNotEmpty) {
          courseItem = coursesByClassroomId[classroomId];
        }
        if (courseItem != null) {
          lessonByCourseAndClassId++;
        } else if (courseId.isNotEmpty) {
          courseItem = coursesByCourseId[courseId];
          if (courseItem != null) {
            lessonByCourseId++;
          }
        }

        if (courseItem == null) {
          debugPrint(
            '[YKT][online-match] skip unmatched onLesson '
            'course_id=$courseId classroom_id=$classroomId lesson_id=$lessonId',
          );
          continue;
        }

        contentList.add(
          _buildRainCourse(
            courseItem,
            school: school,
            lessonId: lessonId,
            logTag: 'online-merged',
          ),
        );
      }

      _updateCourseDebugSummary({
        'ok': true,
        'reason': '',
        'courseItems': rawCourseItems.length,
        'onLessonItems': onLessonItems.length,
        'mergedResult': contentList.length,
        'lessonByCourseId': lessonByCourseId,
        'lessonByCourseAndClassId': lessonByCourseAndClassId,
        'courseCode': courses['errcode'] ?? courses['code'] ?? 0,
        'onLessonCode': onLessonCourses['code'] ?? 0,
        'authExpired': false,
      });

      return contentList;
    } catch (e, stackTrace) {
      _updateCourseDebugSummary({'ok': false, 'reason': e.toString()});
      debugPrint('getCoursesList error: $e\n$stackTrace');
      return null;
    }
  }

  static Future<int?> checkIn(
    String lessonId, {
    required int source,
    bool joinIfNotIn = false,
    String? referer,
    String? bearerToken,
  }) async {
    try {
      final url = '/api/v3/lesson/checkin';
      final jsonData = {
        'source': 21, // 21: 扫码跳转 23: 点击课堂
        'lessonId': lessonId,
        'joinIfNotIn': true,
      };
      jsonData['source'] = source;
      if (!joinIfNotIn) {
        jsonData.remove('joinIfNotIn');
      }
      final headers = buildCheckInHeaders(
        referer: referer,
        bearerToken: bearerToken,
      );
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        headers: headers,
        body: jsonData,
      );
      final data = response.data;

      if (data == null || data['code'] == null) {
        debugPrint('checkIn: invalid response structure');
        return null;
      }

      final int code = data['code'];
      if (code == 0) {
        // 为当前用户保存 bearerToken（从响应头获取）
        final responseBearerToken = response.headers.value('set-auth');
        final lessonToken = data['data']?['lessonToken'];

        if (responseBearerToken != null && lessonToken != null) {
          _setToken(responseBearerToken, lessonToken);
        } else {
          debugPrint('checkIn: missing bearerToken or lessonToken');
        }
        return 0;
      } else {
        // {"code":50070,"msg":"DYNAMIC_QR_CHECK_IN_REFUSED","data":null}
        return code;
      }
    } catch (e) {
      debugPrint('checkIn error: $e');
    }
    return null;
  }

  static Future<int?> checkInFromLessonPage(String lessonId) async {
    return checkIn(
      lessonId,
      source: 12,
      referer: buildLessonPageReferer(lessonId),
      bearerToken: getBearerToken(),
    );
  }

  static Future<int?> checkInFromMiniProgram(String lessonId) async {
    return checkIn(lessonId, source: 11, referer: buildMiniProgramReferer());
  }

  static Future<int?> scanDynamicQr(String qrCodeUrl) async {
    try {
      final url = '/api/v3/app/scan';
      final jsonData = {'url': qrCodeUrl};
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );
      final data = response.data;

      if (data == null || data['code'] == null) {
        debugPrint('scan: invalid response structure');
        return null;
      }

      final int code = data['code'];
      if (code == 0) {
        // {"code":0,"msg":"OK","data":{"type":"checkin","value":"1632189922935066880"}}
        final lessonId = data['data']?['value'];
        if (lessonId == null) {
          debugPrint('scan: missing lessonId in response');
          return null;
        }
        final response = await checkIn(
          lessonId.toString(),
          source: 21,
          joinIfNotIn: true,
          bearerToken: getBearerToken(),
        );
        return response;
      } else {
        // {"code":51203,"msg":"动态二维码过期","data":{"type":"default","value":""}}
        return code;
      }
    } catch (e) {
      debugPrint('scan error: $e');
    }
    return null;
  }

  static Future<int?> scan(String qrCodeUrl) async {
    return scanDynamicQr(qrCodeUrl);
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
      return response.data['data'];
    } catch (e) {
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
      return response.data;
    } catch (e) {
      debugPrint('answer error: $e');
    }
    return null;
  }

  static Future<List<Course>?> getOnlineCoursesList() async {
    debugPrint('[YKT] getOnlineCoursesList 开始');
    try {
      if (DateTime.now().millisecondsSinceEpoch >= 0) {
        final results = await Future.wait([
          ApiService.sendRequest(
            '/v2/api/web/courses/list?identity=2',
            method: 'GET',
          ),
          getOnLessonAndUpcomingExam(),
        ]);

        final coursesResponse = results[0] as Response;
        final onLessonData = results[1] as Map<String, dynamic>?;

        if (coursesResponse.data == null) {
          debugPrint('[YKT] 响应数据为空');
          return [];
        }

        if (coursesResponse.data is! Map) {
          debugPrint('[YKT] 响应格式错误');
          return [];
        }

        final data = _normalizeStringMap(coursesResponse.data as Map);
        final errcode = data['errcode'] ?? 0;
        if (errcode != 0) {
          debugPrint('[YKT] API 返回错误: errcode=$errcode');
          return [];
        }

        final listData = data['data']?['list'];
        if (listData is! List) {
          debugPrint('[YKT] 课程列表为空或格式错误');
          return [];
        }

        final rawCourseItems = listData
            .whereType<Map>()
            .map(_normalizeStringMap)
            .toList();
        final onLessonItems =
            ((onLessonData?['data']?['onLessonClassrooms']) as List?)
                ?.whereType<Map>()
                .map(_normalizeStringMap)
                .toList() ??
            <Map<String, dynamic>>[];

        final coursesByClassroomId = <String, Map<String, dynamic>>{};
        final coursesByCourseId = <String, Map<String, dynamic>>{};
        for (final courseItem in rawCourseItems) {
          final classroomId = _asTrimmedString(courseItem['classroom_id']);
          final courseId = _asTrimmedString(courseItem['course_id']);
          if (classroomId.isNotEmpty) {
            coursesByClassroomId[classroomId] = courseItem;
          }
          if (courseId.isNotEmpty) {
            coursesByCourseId.putIfAbsent(courseId, () => courseItem);
          }
        }

        final school =
            AccountManager.getAccountById(
              AccountManager.currentSessionId!,
            )?.school ??
            '未知学校';

        var lessonByCourseId = 0;
        var lessonByCourseAndClassId = 0;
        final onlineCourses = <Course>[];

        for (final onLessonItem in onLessonItems) {
          final courseId = _asTrimmedString(onLessonItem['courseId']);
          final classroomId = _asTrimmedString(onLessonItem['classroomId']);
          final lessonId = _asTrimmedString(onLessonItem['lessonId']);

          Map<String, dynamic>? matched;
          if (classroomId.isNotEmpty) {
            matched = coursesByClassroomId[classroomId];
          }
          if (matched != null) {
            lessonByCourseAndClassId++;
          } else if (courseId.isNotEmpty) {
            matched = coursesByCourseId[courseId];
            if (matched != null) {
              lessonByCourseId++;
            }
          }

          if (matched == null) {
            debugPrint(
              '[YKT][online-list] unmatched course_id=$courseId classroom_id=$classroomId lesson_id=$lessonId',
            );
            continue;
          }

          onlineCourses.add(
            _buildRainCourse(
              matched,
              school: school,
              lessonId: lessonId,
              logTag: 'online-list',
            ),
          );
        }

        _updateCourseDebugSummary({
          'ok': true,
          'reason': '',
          'onlineRawCourses': rawCourseItems.length,
          'onlineLessonItems': onLessonItems.length,
          'onlineResult': onlineCourses.length,
          'onlineLessonByCourseId': lessonByCourseId,
          'onlineLessonByCourseAndClassId': lessonByCourseAndClassId,
          'onlineCourseCode': errcode,
          'onlinePayloadCode': onLessonData?['code'] ?? 0,
        });

        debugPrint('[YKT] 成功解析 ${onlineCourses.length} 门在线课程');
        return onlineCourses;
      }

      // 获取所有课程和正在上课的课程
      final results = await Future.wait([
        ApiService.sendRequest(
          '/v2/api/web/courses/list?identity=2',
          method: 'GET',
        ),
        getOnLessonAndUpcomingExam(),
      ]);

      final coursesResponse = results[0] as Response;
      final onLessonData = results[1] as Map<String, dynamic>?;

      if (coursesResponse.data == null) {
        debugPrint('[YKT] 响应数据为空');
        return [];
      }

      debugPrint('[YKT] courses/list 响应: ${coursesResponse.data}');

      if (coursesResponse.data is! Map) {
        debugPrint('[YKT] 响应格式错误');
        return [];
      }

      final data = coursesResponse.data as Map<String, dynamic>;
      final errcode = data['errcode'] ?? 0;

      if (errcode != 0) {
        debugPrint('[YKT] API 返回错误: errcode=$errcode');
        return [];
      }

      final listData = data['data']?['list'];
      if (listData is! List) {
        debugPrint('[YKT] 课程列表为空或格式错误');
        return [];
      }

      // 提取正在上课的 classroom_id 集合
      final onLessonClassroomIds = <String>{};
      if (onLessonData != null && onLessonData['data'] != null) {
        final dataMap = onLessonData['data'] as Map<String, dynamic>?;
        if (dataMap != null) {
          final onLessonClassrooms = dataMap['onLessonClassrooms'];
          if (onLessonClassrooms is List) {
            for (var item in onLessonClassrooms) {
              if (item is Map && item['classroomId'] != null) {
                onLessonClassroomIds.add(item['classroomId'].toString());
              }
            }
          }
        }
      }

      debugPrint('[YKT] 正在上课的课堂 ID: $onLessonClassroomIds');

      final school =
          AccountManager.getAccountById(
            AccountManager.currentSessionId!,
          )?.school ??
          '未知学校';

      // 筛选出在线课程（classroom_id 在 onLessonClassroomIds 中的课程）
      final onlineCourses = listData
          .whereType<Map<String, dynamic>>()
          .where((courseItem) {
            final classroomId = courseItem['classroom_id']?.toString();
            return classroomId != null &&
                onLessonClassroomIds.contains(classroomId);
          })
          .map((courseItem) {
            return Course.fromRCJson(courseItem)..schools = school;
          })
          .toList();

      debugPrint('[YKT] 成功解析 ${onlineCourses.length} 门在线课程');
      return onlineCourses;
    } catch (e, stackTrace) {
      debugPrint('[YKT] getOnlineCoursesList 错误: $e');
      debugPrint('[YKT] StackTrace: $stackTrace');
      return [];
    }
  }

  static Future<List<Course>?> getOfflineCoursesList() async {
    debugPrint('[YKT] getOfflineCoursesList 开始');
    try {
      if (DateTime.now().millisecondsSinceEpoch >= 0) {
        final response = await ApiService.sendRequest(
          '/v2/api/web/courses/list?identity=2',
          method: 'GET',
        );

        debugPrint('[YKT] courses/list 响应: ${response.data}');

        if (response.data is! Map) {
          debugPrint('[YKT] 响应格式错误');
          return [];
        }

        final data = _normalizeStringMap(response.data as Map);
        final errcode = data['errcode'] ?? 0;
        if (errcode != 0) {
          debugPrint('[YKT] API 返回错误: errcode=$errcode');
          return [];
        }

        final listData = data['data']?['list'];
        if (listData is! List) {
          debugPrint('[YKT] 课程列表为空或格式错误');
          return [];
        }

        final school =
            AccountManager.getAccountById(
              AccountManager.currentSessionId!,
            )?.school ??
            '未知学校';

        final rawCourseItems = listData
            .whereType<Map>()
            .map(_normalizeStringMap)
            .toList();
        final offlineCourses = rawCourseItems
            .map(
              (courseItem) => _buildRainCourse(
                courseItem,
                school: school,
                logTag: 'offline-list',
              ),
            )
            .toList();

        _updateCourseDebugSummary({
          'ok': true,
          'reason': '',
          'offlineRawCourses': rawCourseItems.length,
          'offlineResult': offlineCourses.length,
          'offlineCourseCode': errcode,
        });

        debugPrint('[YKT] 成功解析 ${offlineCourses.length} 门离线课程');
        return offlineCourses;
      }

      // 获取所有课程
      final response = await ApiService.sendRequest(
        '/v2/api/web/courses/list?identity=2',
        method: 'GET',
      );

      debugPrint('[YKT] courses/list 响应: ${response.data}');

      if (response.data is! Map) {
        debugPrint('[YKT] 响应格式错误');
        return [];
      }

      final data = response.data as Map<String, dynamic>;
      final errcode = data['errcode'] ?? 0;

      if (errcode != 0) {
        debugPrint('[YKT] API 返回错误: errcode=$errcode');
        return [];
      }

      final listData = data['data']?['list'];
      if (listData is! List) {
        debugPrint('[YKT] 课程列表为空或格式错误');
        return [];
      }

      final school =
          AccountManager.getAccountById(
            AccountManager.currentSessionId!,
          )?.school ??
          '未知学校';

      // 离线课程列表包含所有课程（包括正在上课的）
      final offlineCourses = listData.whereType<Map<String, dynamic>>().map((
        courseItem,
      ) {
        return Course.fromRCJson(courseItem)..schools = school;
      }).toList();

      debugPrint('[YKT] 成功解析 ${offlineCourses.length} 门离线课程');
      return offlineCourses;
    } catch (e, stackTrace) {
      debugPrint('[YKT] getOfflineCoursesList 错误: $e');
      debugPrint('[YKT] StackTrace: $stackTrace');
      return [];
    }
  }

  static Map<String, dynamic>? getLastCourseDebugSummary() {
    final summary = _lastCourseDebugSummary;
    if (summary == null) {
      return null;
    }
    return Map<String, dynamic>.from(summary);
  }

  static Future<String?> uploadImageToQiniu(dynamic file) async {
    debugPrint('uploadImageToQiniu not implemented');
    return null;
  }
}

class TCCourseApi {
  static Future<List<Course>?> getCoursesList() async {
    try {
      final userId = AccountManager.currentSessionId;
      if (userId == null || userId.isEmpty) {
        debugPrint('[TCCourseApi] getCoursesList: userId is null or empty');
        return [];
      }

      final client = await TronclassClient.getInstance(userId);
      final response = await client.dio.get(
        '/api/users/$userId/courses',
        queryParameters: const {'page': '1', 'per_page': '50'},
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is List) {
          debugPrint(
            '[TCCourseApi] getCoursesList: found ${data.length} courses',
          );
          return data.whereType<Map<String, dynamic>>().map((e) {
            return Course(
              courseId: e['id']?.toString() ?? '',
              classId: e['id']?.toString() ?? '',
              image: e['cover_url'] ?? '',
              name: e['name'] ?? '未知课程',
              teacher: e['teacher']?['name'] ?? '未知教师',
              state: true,
            );
          }).toList();
        }
      }

      debugPrint('[TCCourseApi] getCoursesList: no valid data in response');
      return [];
    } catch (e, stackTrace) {
      debugPrint('[TCCourseApi] getCoursesList error: $e');
      debugPrint('[TCCourseApi] StackTrace: $stackTrace');
      return [];
    }
  }

  static Future<List<Active>> getSignActivities(String courseId) async {
    try {
      final response = await TronclassSignApi.getRollcalls();
      final activities = <Active>[];

      for (final rollcall in response.rollcalls) {
        if (courseId.isNotEmpty && rollcall.courseId.toString() != courseId) {
          continue;
        }

        activities.add(
          Active(
            type: 2,
            id: rollcall.rollcallId.toString(),
            name: rollcall.title.isEmpty ? '签到' : rollcall.title,
            description: rollcall.courseTitle,
            startTime: 0,
            url: '',
            status: rollcall.isInProgress,
            extras: {
              '_mode': rollcall.mode,
              '_signed': rollcall.status == 'on_call_fine',
              'rollcall_status': rollcall.rollcallStatus,
              'rollcall_time': rollcall.rollcallTime,
              'status': rollcall.status,
              'class_name': rollcall.className,
              'created_by_name': rollcall.createdByName,
              'course_title': rollcall.courseTitle,
              'course_id': rollcall.courseId,
              'updated_at': rollcall.rollcallTime,
              'created_at': rollcall.rollcallTime,
            },
          ),
        );
      }

      debugPrint(
        '[TCCourseApi] getSignActivities: courseId=$courseId, parsed ${activities.length} activities',
      );
      return activities;
    } catch (e, stackTrace) {
      debugPrint('[TCCourseApi] getSignActivities error: $e');
      debugPrint('[TCCourseApi] StackTrace: $stackTrace');
      return [];
    }
  }

  static Future<RollcallsResponse?> getRollcalls() async {
    try {
      return await TronclassSignApi.getRollcalls();
    } catch (e) {
      debugPrint('TCCourseApi.getRollcalls error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getTodos() async {
    try {
      final userId = AccountManager.currentSessionId;
      if (userId == null || userId.isEmpty) {
        debugPrint('[TCCourseApi] getTodos: userId is null or empty');
        return [];
      }

      final client = await TronclassClient.getInstance(userId);
      final response = await client.dio.get('/api/todos');

      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is List) {
          debugPrint('[TCCourseApi] getTodos: found ${data.length} todos');
          return data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      debugPrint('[TCCourseApi] getTodos: no valid data in response');
      return [];
    } catch (e, stackTrace) {
      debugPrint('[TCCourseApi] getTodos error: $e');
      debugPrint('[TCCourseApi] StackTrace: $stackTrace');
      return [];
    }
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Map<String, dynamic>> _extractTronclassCourses(
    dynamic responseData,
  ) {
    final root = _asStringMap(responseData);
    if (root == null) return const [];

    final candidates = <dynamic>[
      root['courses'],
      root['data'],
      _asStringMap(root['data'])?['list'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList();
      }
    }
    return const [];
  }

  static String _tronclassResponseShape(dynamic responseData) {
    final root = _asStringMap(responseData);
    if (root == null) return 'type=${responseData.runtimeType}';
    final data = root['data'];
    final dataShape = data is Map
        ? 'data.keys=[${data.keys.take(8).join(',')}]'
        : 'data=${data.runtimeType}';
    return 'keys=[${root.keys.take(12).join(',')}], $dataShape';
  }

  static DateTime? _parseTronclassDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == 'null') return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static DateTime? _firstTronclassDate(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final parsed = _parseTronclassDate(source[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String evaluateTronclassInteractionState(
    Map<String, dynamic> classroom, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final finishAt = _parseTronclassDate(classroom['finish_at']);
    if (finishAt != null) return '已结束';
    final status = classroom['status']?.toString().trim().toLowerCase() ?? '';
    if (status.isNotEmpty && status != 'start') return '已结束';

    final deadline = _firstTronclassDate(classroom, const [
      'end_time',
      'end_at',
      'deadline',
      'closed_at',
      'close_at',
      'due_at',
    ]);
    if (deadline != null) {
      return deadline.isBefore(current) ? '已过截止时间' : '进行中';
    }

    return '未设置截止';
  }

  static bool isTronclassInteractionOngoing(
    Map<String, dynamic> classroom, {
    DateTime? now,
  }) {
    return tronclassInteractionSkipReason(classroom, now: now) == null;
  }

  static String? tronclassInteractionSkipReason(
    Map<String, dynamic> classroom, {
    DateTime? now,
  }) {
    final status = classroom['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'start') {
      return status.isEmpty ? 'status empty' : 'status=$status';
    }

    final finishAtRaw = classroom['finish_at']?.toString().trim() ?? '';
    if (finishAtRaw.isNotEmpty && finishAtRaw != 'null') {
      return 'finish_at=$finishAtRaw';
    }

    final current = now ?? DateTime.now();
    final deadline = _firstTronclassDate(classroom, const [
      'end_time',
      'end_at',
      'deadline',
      'closed_at',
      'close_at',
      'due_at',
    ]);
    if (deadline != null && deadline.isBefore(current)) {
      return 'deadline expired=${deadline.toIso8601String()}';
    }

    return null;
  }

  static Future<List<TronclassInteractionItem>> getOngoingInteractions() async {
    try {
      final userId = AccountManager.currentSessionId;
      if (userId == null || userId.isEmpty) {
        debugPrint(
          '[TCCourseApi] getOngoingInteractions: userId is null or empty',
        );
        return [];
      }

      final client = await TronclassClient.getInstance(userId);
      final coursesResponse = await client.dio.get(
        '/api/users/$userId/courses',
        queryParameters: const {'page': '1', 'per_page': '50'},
      );

      debugPrint(
        '[TCCourseApi] getOngoingInteractions: course response ${_tronclassResponseShape(coursesResponse.data)}',
      );

      final coursesData = _extractTronclassCourses(coursesResponse.data);
      if (coursesData.isEmpty) {
        debugPrint('[TCCourseApi] getOngoingInteractions: no valid courses');
        return [];
      }

      final items = <TronclassInteractionItem>[];
      for (final course in coursesData) {
        final courseId = course['id']?.toString() ?? '';
        if (courseId.isEmpty) continue;
        final courseName = course['name']?.toString() ?? '未知课程';

        try {
          final classroomResponse = await client.dio.get(
            '/api/courses/$courseId/classroom-list',
          );
          final classroomRoot = _asStringMap(classroomResponse.data);
          final classrooms = classroomRoot?['classrooms'];
          if (classrooms is! List) continue;

          for (final classroomData in classrooms.whereType<Map>()) {
            final classroom = classroomData.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            final id = classroom['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final skipReason = tronclassInteractionSkipReason(classroom);
            if (skipReason != null) {
              debugPrint(
                '[TCCourseApi] skip interaction id=$id title=${classroom['title']} '
                'status=${classroom['status']} start_at=${classroom['start_at']} '
                'finish_at=${classroom['finish_at']} '
                'updated_status_at=${classroom['updated_status_at']} '
                'skipReason=$skipReason',
              );
              continue;
            }

            final status = classroom['status']?.toString() ?? '';
            final stateLabel = evaluateTronclassInteractionState(classroom);

            debugPrint(
              '[TCCourseApi] interaction id=$id title=${classroom['title']} '
              'status=$status start_at=${classroom['start_at']} '
              'finish_at=${classroom['finish_at']} duration=${classroom['duration']} '
              'updated_status_at=${classroom['updated_status_at']} state=$stateLabel',
            );

            items.add(
              TronclassInteractionItem(
                id: id,
                title: classroom['title']?.toString() ?? '课堂互动',
                courseId: courseId,
                courseName: courseName,
                startAt: classroom['start_at']?.toString() ?? '',
                status: status,
                stateLabel: stateLabel,
              ),
            );
          }
        } catch (e) {
          debugPrint(
            '[TCCourseApi] getOngoingInteractions: course $courseId error: $e',
          );
        }
      }

      items.sort((a, b) => b.startAt.compareTo(a.startAt));
      debugPrint(
        '[TCCourseApi] getOngoingInteractions: found ${items.length} items',
      );
      return items;
    } catch (e, stackTrace) {
      debugPrint('[TCCourseApi] getOngoingInteractions error: $e');
      debugPrint('[TCCourseApi] StackTrace: $stackTrace');
      return [];
    }
  }
}

class TronclassInteractionItem {
  const TronclassInteractionItem({
    required this.id,
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.startAt,
    required this.status,
    required this.stateLabel,
  });

  final String id;
  final String title;
  final String courseId;
  final String courseName;
  final String startAt;
  final String status;
  final String stateLabel;

  Map<String, dynamic> toTodoMap() => {
    'id': id,
    'title': title,
    'type': 'classroom',
    'course_id': courseId,
    'course_name': courseName,
    'start_time': startAt,
    'end_time': '',
    'interaction_state': stateLabel,
    'is_locked': false,
  };
}

class KTCourseApi {
  static int _contentTypeOf(Map<String, dynamic> item) {
    return int.tryParse(
          item['contenttype']?.toString() ??
              item['contentType']?.toString() ??
              '',
        ) ??
        -1;
  }

  static String _searchableTextOf(Map<String, dynamic> item) {
    final parts = <String>[
      item['title']?.toString() ?? '',
      item['name']?.toString() ?? '',
      item['activitylabel']?.toString() ?? '',
      item['description']?.toString() ?? '',
      item['summary']?.toString() ?? '',
      item['typename']?.toString() ?? '',
      item['type_name']?.toString() ?? '',
      item['introduce']?.toString() ?? '',
    ];
    return parts
        .where((part) => part.trim().isNotEmpty)
        .join(' ')
        .toLowerCase();
  }

  static List<Map<String, dynamic>> _filterKetangpaiContent(
    List<Map<String, dynamic>> items,
    bool Function(Map<String, dynamic> item, int contentType, String text)
    matcher,
  ) {
    return items.where((item) {
      final contentType = _contentTypeOf(item);
      final text = _searchableTextOf(item);
      return matcher(item, contentType, text);
    }).toList();
  }

  static Future<List<Course>> getCoursesList() async {
    try {
      debugPrint('[KTCourseApi] 直接调用 KTPCourseApi');
      final courses = await KTPCourseApi.getCoursesList();
      debugPrint('[KTCourseApi] KTPCourseApi 返回 ${courses.length} 门课程');
      return courses;
    } catch (e, stackTrace) {
      debugPrint('KTCourseApi.getCoursesList error: $e');
      debugPrint('StackTrace: $stackTrace');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCourseDetail(String courseId) async {
    try {
      return await KTPCourseApi.getCourseDetail(courseId);
    } catch (e) {
      debugPrint('KTCourseApi.getCourseDetail error: $e');
      return null;
    }
  }

  static Future<List<Course>> getSigningCourses() async {
    try {
      debugPrint('[KTCourseApi] 调用 KTPCourseApi.getSigningCourses');
      final signingCourses = await KTPCourseApi.getSigningCourses();
      debugPrint('[KTCourseApi] 返回 ${signingCourses.length} 个正在签到的课程');
      return signingCourses
          .map<Course>((data) => data['course'] as Course)
          .toList();
    } catch (e, stackTrace) {
      debugPrint('KTCourseApi.getSigningCourses error: $e');
      debugPrint('StackTrace: $stackTrace');
      return [];
    }
  }

  static Future<List<Course>> getOnlineCourses() async {
    try {
      debugPrint('[KTCourseApi] 调用 KTPCourseApi.getOnlineCourses');
      final onlineCourses = await KTPCourseApi.getOnlineCourses();
      debugPrint('[KTCourseApi] 返回 ${onlineCourses.length} 门在线课程');
      return onlineCourses;
    } catch (e, stackTrace) {
      debugPrint('KTCourseApi.getOnlineCourses error: $e');
      debugPrint('StackTrace: $stackTrace');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>>
  getSigningCoursesWithDetails() async {
    try {
      return await KTPCourseApi.getSigningCourses();
    } catch (e) {
      debugPrint('KTCourseApi.getSigningCoursesWithDetails error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getNotFinishSign(String courseId) async {
    try {
      return await KTPCourseApi.getNotFinishSign(courseId);
    } catch (e) {
      debugPrint('KTCourseApi.getNotFinishSign error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCourseContent(
    String courseId, {
    int contentType = 0,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final list = await KTPCourseApi.getCourseContent(
        courseId,
        contentType: contentType,
        page: page,
        limit: limit,
      );
      return {
        'list': list,
        'contentType': contentType,
        'page': page,
        'limit': limit,
      };
    } catch (e) {
      debugPrint('KTCourseApi.getCourseContent error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getCourseContentList(
    String courseId, {
    int contentType = 0,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final content = await getCourseContent(
        courseId,
        contentType: contentType,
        page: page,
        limit: limit,
      );
      if (content != null && content['list'] is List) {
        return (content['list'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('KTCourseApi.getCourseContentList error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getHomeworkList(
    String courseId,
  ) async {
    return getCourseContentList(courseId, contentType: 4);
  }

  static Future<List<Map<String, dynamic>>> getAnnouncementList(
    String courseId,
  ) async {
    final items = await getCourseContentList(courseId, contentType: 0);
    return _filterKetangpaiContent(items, (item, contentType, text) {
      return text.contains('公告') ||
          text.contains('通知') ||
          text.contains('announcement') ||
          text.contains('notice');
    });
  }

  static Future<List<Map<String, dynamic>>> getAnswerQuestionList(
    String courseId,
  ) async {
    final items = await getCourseContentList(courseId, contentType: 0);
    return _filterKetangpaiContent(items, (item, contentType, text) {
      return text.contains('互动答题') ||
          text.contains('抢答') ||
          text.contains('答题') ||
          text.contains('question') ||
          text.contains('作答');
    });
  }

  static Future<List<Map<String, dynamic>>> getSourceList(
    String courseId,
  ) async {
    return getCourseContentList(courseId, contentType: 2);
  }

  static Future<List<Map<String, dynamic>>> getCourseWareList(
    String courseId,
  ) async {
    final items = await getCourseContentList(courseId, contentType: 0);
    return _filterKetangpaiContent(items, (item, contentType, text) {
      return text.contains('课件') ||
          text.contains('ppt') ||
          text.contains('slides') ||
          text.contains('讲义') ||
          text.contains('幻灯');
    });
  }

  static Future<List<Map<String, dynamic>>> getTopicList(
    String courseId,
  ) async {
    return getCourseContentList(courseId, contentType: 5);
  }

  static Future<Map<String, dynamic>?> getHomeworkDetail(
    String courseId,
    String homeworkId,
  ) async {
    try {
      final homeworks = await getHomeworkList(courseId);
      Map<String, dynamic>? matched;
      for (final item in homeworks) {
        final itemId =
            item['id']?.toString() ?? item['homeworkid']?.toString() ?? '';
        if (itemId == homeworkId) {
          matched = item;
          break;
        }
      }

      if (matched == null) {
        return null;
      }

      return {
        'status': 1,
        'data': {'homework': matched},
      };
    } catch (e) {
      debugPrint('KTCourseApi.getHomeworkDetail error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSignStatus(String courseId) async {
    try {
      final stats = await KetangpaiAttendanceApi.getAttendanceStats(courseId);
      final history = await KetangpaiAttendanceApi.getAttendanceHistory(
        courseId: courseId,
        page: 1,
        limit: 20,
      );

      return {
        'status': 1,
        'data': {
          'attenceCount': stats['attendance'] ?? 0,
          'lateCount': stats['late'] ?? 0,
          'absentCount': stats['absent'] ?? 0,
          'leaveEarlyCount': stats['leaveEarly'] ?? 0,
          'pleaseCount': stats['leave'] ?? 0,
          'total': history.length,
          'lists': history,
        },
      };
    } catch (e) {
      debugPrint('KTCourseApi.getSignStatus error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getExamInfo(
    String examId,
    String courseId,
  ) async {
    try {
      final url =
          'https://openapiv5.ketangpai.com/TestpaperApi/testpaperdetails';
      final body = {
        'courseid': courseId,
        'testpaperid': examId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: body,
      );
      if (response.data is Map<String, dynamic> &&
          response.data['status'] == 1) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('KTCourseApi.getExamInfo error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getExamQuestions(
    String examId,
    String courseId,
  ) async {
    try {
      final url = 'https://openapiv5.ketangpai.com/TestpaperApi/doSubjectList';
      final body = {
        'courseid': courseId,
        'testpaperid': examId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: body,
      );
      if (response.data is Map<String, dynamic> &&
          response.data['status'] == 1) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      debugPrint('KTCourseApi.getExamQuestions error: $e');
      return null;
    }
  }

  static Future<bool> submitExamAnswer({
    required String testPaperId,
    required String courseId,
    required String subjectId,
    required String answer,
  }) async {
    try {
      final url = 'https://openapiv5.ketangpai.com/TestpaperApi/saveAnswer';
      final body = {
        'courseid': courseId,
        'testpaperid': testPaperId,
        'subjectid': subjectId,
        'answer': answer,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: body,
      );
      return response.data is Map<String, dynamic> &&
          response.data['status'] == 1;
    } catch (e) {
      debugPrint('KTCourseApi.submitExamAnswer error: $e');
      return false;
    }
  }

  static Future<bool> submitExamPaper(String courseId, String examId) async {
    try {
      final url = 'https://openapiv5.ketangpai.com/TestpaperApi/handup';
      final body = {
        'courseid': courseId,
        'testpaperid': examId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: body,
      );
      return response.data is Map<String, dynamic> &&
          response.data['status'] == 1;
    } catch (e) {
      debugPrint('KTCourseApi.submitExamPaper error: $e');
      return false;
    }
  }
}
