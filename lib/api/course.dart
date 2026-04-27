import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

import 'api_service.dart';
import 'ketangpai_course.dart';
import '../session/account.dart';
import '../utils/encrypt.dart';
import '../models/active.dart';
import '../models/course.dart';

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
            'channel[$i].content keys: ${content is Map ? (content as Map).keys.toList() : 'not a map'}',
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

      if (courses == null || onLessonCourses == null) {
        return null;
      }

      Map<String, dynamic> coursesMap = {
        for (var courseItem in courses['data'])
          courseItem['course_id'].toString(): courseItem,
      };

      List<Course> contentList = [];

      final school = AccountManager.getAccountById(
        AccountManager.currentSessionId!,
      )!.school;

      for (var onLessonCourseItem
          in onLessonCourses['data']['onLessonClassrooms']) {
        final String courseId = onLessonCourseItem['courseId'];
        if (coursesMap.containsKey(courseId)) {
          var courseItem = coursesMap[courseId];
          courseItem['lesson_id'] = onLessonCourseItem['lessonId'];
          final courseObject = Course.fromRCJson(courseItem);
          courseObject.schools = school;
          contentList.add(courseObject);
        }
      }

      return contentList;
    } catch (e, stackTrace) {
      debugPrint('getCoursesList error: $e\n$stackTrace');
      return null;
    }
  }

  static Future<int?> checkIn(String lessonId) async {
    try {
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

      final int code = data['code'];
      if (code == 0) {
        // 为当前用户保存 bearerToken（从响应头获取）
        final bearerToken = response.headers.value('set-auth')!;
        final lessonToken = data['data']['lessonToken'];
        _setToken(bearerToken, lessonToken);
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

  static Future<int?> scan(String qrCodeUrl) async {
    try {
      final url = '/api/v3/app/scan';
      final jsonData = {'url': qrCodeUrl};
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );
      final data = response.data;

      final int code = data['code'];
      if (code == 0) {
        // {"code":0,"msg":"OK","data":{"type":"checkin","value":"1632189922935066880"}}
        final lessonId = data['data']['value'];
        final response = await checkIn(lessonId);
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
    return null;
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
      if (userId == null) return [];

      final url = 'https://courses.guet.edu.cn/api/users/$userId/courses';
      final params = {'page': '1', 'per_page': '50'};

      final response = await ApiService.sendRequest(
        url,
        method: 'GET',
        params: params,
      );
      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is List) {
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
      return [];
    } catch (e) {
      debugPrint('TCCourseApi.getCoursesList error: $e');
      return [];
    }
  }

  static Future<List<Active>> getSignActivities(String courseId) async {
    return [];
  }

  static Future<Map<String, dynamic>?> getRollcalls() async {
    try {
      final url = 'https://courses.guet.edu.cn/api/radar/rollcalls';
      final params = {'api_version': '1.1.0'};

      final response = await ApiService.sendRequest(
        url,
        method: 'GET',
        params: params,
      );
      if (response.data is Map<String, dynamic>) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('TCCourseApi.getRollcalls error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> sign(
    String rollcallId, {
    String? mode,
    String? qrPayload,
    String? signCode,
    String? numberCode,
    double? radarLatitude,
    double? radarLongitude,
    double? radarAccuracy,
    Map<String, dynamic>? data,
  }) async {
    try {
      final url =
          'https://courses.guet.edu.cn/api/radar/rollcalls/$rollcallId/sign';
      final body = <String, dynamic>{};

      if (mode != null) body['mode'] = mode;
      if (qrPayload != null) body['qr_payload'] = qrPayload;
      if (signCode != null) body['sign_code'] = signCode;
      if (numberCode != null) body['number_code'] = numberCode;
      if (radarLatitude != null) body['radar_latitude'] = radarLatitude;
      if (radarLongitude != null) body['radar_longitude'] = radarLongitude;
      if (radarAccuracy != null) body['radar_accuracy'] = radarAccuracy;
      if (data != null) body.addAll(data);

      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: body,
      );
      if (response.data is Map<String, dynamic>) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Invalid response'};
    } catch (e) {
      debugPrint('TCCourseApi.sign error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> getTodos() async {
    try {
      final url = 'https://courses.guet.edu.cn/api/todos';
      final response = await ApiService.sendRequest(url, method: 'GET');

      if (response.data is Map<String, dynamic>) {
        final data = response.data['data'];
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('TCCourseApi.getTodos error: $e');
      return [];
    }
  }
}

class KTCourseApi {
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
      final url =
          'https://openapiv5.ketangpai.com/CourseBigDataApi/getCourseBaseDataV2';
      final body = {
        'courseid': courseId,
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
      debugPrint('KTCourseApi.getCourseDetail error: $e');
      return null;
    }
  }

  static Future<List<Course>> getSigningCourses() async {
    return [];
  }

  static Future<List<dynamic>> getNotFinishSign(String courseId) async {
    try {
      final url =
          'https://openapiv5.ketangpai.com/AttenceApi/getNotFinishAttenceStudent';
      final body = {
        'courseid': courseId,
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: body,
      );
      if (response.data is Map<String, dynamic> &&
          response.data['status'] == 1) {
        final data = response.data['data'];
        if (data is List) {
          return data;
        }
      }
      return [];
    } catch (e) {
      debugPrint('KTCourseApi.getNotFinishSign error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCourseContent(String courseId) async {
    try {
      final url =
          'https://openapiv5.ketangpai.com/FutureV2/CourseMeans/getCourseContent';
      final body = {
        'courseid': courseId,
        'courserole': 0,
        'contenttype': 0,
        'dirid': '0',
        'lessonlink': [],
        'desc': '2',
        'page': 1,
        'limit': 50,
        'sort': [],
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
      debugPrint('KTCourseApi.getCourseContent error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getCourseContentList(
    String courseId, {
    int contentType = 0,
  }) async {
    try {
      final content = await getCourseContent(courseId);
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

  static Future<Map<String, dynamic>?> getHomeworkDetail(
    String homeworkId,
    String courseId,
  ) async {
    return null;
  }

  static Future<Map<String, dynamic>?> getSignStatus(String courseId) async {
    return null;
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
