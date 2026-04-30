import 'package:dio/dio.dart';
import '../platform.dart';
import 'platform_request_context.dart';

/// 学习通课程 API（基于 HAR 抓包重建）
class ChaoxingCourseApi {
  /// 获取课程列表
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/mycourse/backclazzdata?view=json&getTchClazzType=1&mcode=
  static Future<Map<String, dynamic>> getCourseList(String userId) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/mycourse/backclazzdata',
        method: 'GET',
        params: {
          'view': 'json',
          'getTchClazzType': '1',
          'mcode': '',
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取课程列表失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }

  /// 获取课程详情（包含章节信息）
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/gas/clazz?id={classId}&personid={personId}&fields=...&view=json
  static Future<Map<String, dynamic>> getCourseDetail({
    required String userId,
    required String classId,
    required String personId,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final fields = 'id,bbsid,classscore,isstart,allowdownload,chatid,name,state,isfiled,visiblescore,hideclazz,begindate,forbidintoclazz,'
          'coursesetting.fields(id,courseid,hiddencoursecover,coursefacecheck),'
          'course.fields(id,belongschoolid,name,infocontent,objectid,app,appinfo,bulletformat,mappingcourseid,imageurl,teacherfactor,jobcount,'
          'knowledge.fields(id,name,indexOrder,parentnodeid,status,isReview,layer,label,jobcount,begintime,endtime,clickcount,finishcount,openlock,unfinishcount,newchapterrule,'
          'attachment.fields(id,type,objectid,extension).type(video)))';

      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/gas/clazz',
        method: 'GET',
        params: {
          'id': classId,
          'personid': personId,
          'fields': fields,
          'view': 'json',
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取课程详情失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }

  /// 获取作业/考试红点提示
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/api/workexam/redpoint?courseId={courseId}&classId={classId}&cpi={cpi}
  static Future<Map<String, dynamic>> getWorkExamRedpoint({
    required String userId,
    required String courseId,
    required String classId,
    required String cpi,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/api/workexam/redpoint',
        method: 'GET',
        params: {
          'courseId': courseId,
          'classId': classId,
          'cpi': cpi,
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取作业红点失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }

  /// 获取课程资料列表
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/phone/data/student-datalist?courseId={courseId}&rootId=null&require=&pageNum=1&classId={classId}&cpi={cpi}&microTopicId=
  static Future<Map<String, dynamic>> getCourseDataList({
    required String userId,
    required String courseId,
    required String classId,
    required String cpi,
    int pageNum = 1,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/phone/data/student-datalist',
        method: 'GET',
        params: {
          'courseId': courseId,
          'rootId': 'null',
          'require': '',
          'pageNum': pageNum.toString(),
          'classId': classId,
          'cpi': cpi,
          'microTopicId': '',
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取课程资料失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }

  /// 获取课程统计详情
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/phone/moocAnalysis/coursedetails-std-client?courseId={courseId}&classId={classId}&cpi={cpi}&view=json
  static Future<Map<String, dynamic>> getCourseAnalysis({
    required String userId,
    required String courseId,
    required String classId,
    required String cpi,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/phone/moocAnalysis/coursedetails-std-client',
        method: 'GET',
        params: {
          'courseId': courseId,
          'classId': classId,
          'cpi': cpi,
          'view': 'json',
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取课程统计失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }

  /// 获取作业列表
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/work/task-list?courseId={courseId}&classId={classId}&cpi={cpi}
  static Future<Map<String, dynamic>> getWorkList({
    required String userId,
    required String courseId,
    required String classId,
    required String cpi,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/work/task-list',
        method: 'GET',
        params: {
          'courseId': courseId,
          'classId': classId,
          'cpi': cpi,
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取作业列表失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }

  /// 获取考试列表（exam-ans）
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/exam-ans/exam/phone/task-list?courseId={courseId}&classId={classId}&cpi={cpi}
  static Future<Map<String, dynamic>> getExamList({
    required String userId,
    required String courseId,
    required String classId,
    required String cpi,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/task-list',
        method: 'GET',
        params: {
          'courseId': courseId,
          'classId': classId,
          'cpi': cpi,
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取考试列表失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }

  /// 获取MOOC考试列表（mooc-ans）
  /// 对应 HAR: GET https://mooc1-api.chaoxing.com/mooc-ans/exam/phone/task-list?courseId={courseId}&classId={classId}&cpi={cpi}
  static Future<Map<String, dynamic>> getMoocExamList({
    required String userId,
    required String courseId,
    required String classId,
    required String cpi,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final response = await context.sendRequest(
        'https://mooc1-api.chaoxing.com/mooc-ans/exam/phone/task-list',
        method: 'GET',
        params: {
          'courseId': courseId,
          'classId': classId,
          'cpi': cpi,
        },
        responseType: ResponseType.json,
      );

      if (response.statusCode == 200 && response.data is Map) {
        return response.data as Map<String, dynamic>;
      }

      throw Exception('获取MOOC考试列表失败: status=${response.statusCode}');
    } finally {
      context.dispose();
    }
  }
}
