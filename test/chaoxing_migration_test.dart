import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/chaoxing_sign_api.dart';
import 'package:course_helper/api/course.dart';
import 'package:course_helper/api/platform_dio_manager.dart';
import 'package:course_helper/models/active.dart';
import 'package:course_helper/models/course.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiService.resetForTests();
    CookieManager.resetForTests();
    await CookieManager.initialize();
    await AccountManager.initialize();
  });

  tearDown(() {
    ApiService.resetForTests();
    CookieManager.resetForTests();
  });

  group('Chaoxing model parsing', () {
    test('parses course from channelList item', () {
      final course = Course.fromCXJson({
        'content': {
          'id': 456,
          'cpi': 789,
          'name': 'Class A',
          'state': 0,
          'beginDate': '2026-01-01',
          'endDate': '2026-06-01',
          'course': {
            'data': [
              {
                'id': 123,
                'name': 'Mobile Learning',
                'imageurl': '//img.example.com/course.png',
                'teacherfactor': 'Teacher Zhang',
                'schools': 'Test University',
              },
            ],
          },
        },
      });

      expect(course.courseId, '123');
      expect(course.classId, '456');
      expect(course.cpi, '789');
      expect(course.image, 'https://img.example.com/course.png');
      expect(course.name, 'Mobile Learning');
      expect(course.teacher, 'Teacher Zhang');
      expect(course.state, isTrue);
    });

    test('parses active sign type from otherId', () {
      final active = Active.fromJson({
        'id': 1001,
        'activeType': 2,
        'nameOne': 'Sign in',
        'nameTwo': '',
        'nameFour': 'QR sign',
        'status': 1,
        'otherId': 2,
      });

      expect(active.activeType, ActiveType.signIn);
      expect(active.signType, SignType.qrCode);
      expect(active.description, 'QR sign');
    });
  });

  group('Chaoxing sign helpers', () {
    test('classifies sign response text', () {
      expect(ChaoxingSignApi.isSignSuccess('success'), isTrue);
      expect(ChaoxingSignApi.isSignSuccess('success2'), isTrue);
      expect(ChaoxingSignApi.isSignSuccess('failed'), isFalse);
      expect(ChaoxingSignApi.needsValidate('validate_abc'), isTrue);
      expect(ChaoxingSignApi.extractEnc2('validate_abc'), 'abc');
      expect(ChaoxingSignApi.extractEnc2('success'), isNull);
      expect(ChaoxingSignApi.getSignMessage('validate_abc'), '需要验证码');
      expect(ChaoxingSignApi.getSignMessage('success'), '签到成功');
    });
  });

  group('Chaoxing cookie helpers', () {
    test('deduplicates cookies by name', () {
      final cookieHeader = CookieManager.stringifyCookies([
        Cookie('UID', 'old'),
        Cookie('fid', '100'),
        Cookie('UID', 'new'),
      ]);

      expect(cookieHeader, contains('UID=old'));
      expect(cookieHeader, isNot(contains('UID=new')));
      expect(cookieHeader, contains('fid=100'));
      expect('UID='.allMatches(cookieHeader), hasLength(1));
    });

    test('loads business domain cookies for request', () async {
      final jar = CookieJar();
      final apiCookie = Cookie('UID', 'api')
        ..domain = 'mooc1-api.chaoxing.com'
        ..path = '/';
      final commonCookie = Cookie('fid', '100')
        ..domain = 'chaoxing.com'
        ..path = '/';

      await jar.saveFromResponse(Uri.parse('https://mooc1-api.chaoxing.com/'), [
        apiCookie,
      ]);
      await jar.saveFromResponse(Uri.parse('https://chaoxing.com/'), [
        commonCookie,
      ]);

      final cookies = await CookieManager.loadChaoxingCookiesForRequest(
        jar,
        Uri.parse('https://mooc1-api.chaoxing.com/mycourse/backclazzdata'),
      );
      final header = CookieManager.stringifyCookies(cookies);

      expect(header, contains('UID=api'));
      expect(header, contains('fid=100'));
      expect('UID='.allMatches(header), hasLength(1));
    });
  });

  group('Chaoxing course API', () {
    test('uses ApiService endpoint and params for course list', () async {
      await AccountManager.setCurrentSession('403701235');
      String? capturedUrl;
      Map<String, String>? capturedParams;

      Future<Response<dynamic>> captureRequest(
        String url, {
        required String method,
        Map<String, String>? params,
        Map<String, String>? headers,
        dynamic body,
        ResponseType responseType = ResponseType.json,
        bool allowRedirects = true,
        bool skipCredentialValidation = false,
      }) async {
        capturedUrl = url;
        capturedParams = params;
        return Response<dynamic>(
          requestOptions: RequestOptions(path: url),
          statusCode: 200,
          data: '{"channelList":[]}',
        );
      }

      ApiService.debugSendRequestOverride = captureRequest;

      final data = await CXCourseApi.getCourses();

      expect(
        capturedUrl,
        'https://mooc1-api.chaoxing.com/mycourse/backclazzdata',
      );
      expect(capturedParams, {
        'view': 'json',
        'getTchClazzType': '1',
        'mcode': '',
      });
      expect(data, {'channelList': <dynamic>[]});
    });

    test('accepts string result when parsing course list', () async {
      await AccountManager.setCurrentSession('403701235');

      Future<Response<dynamic>> captureRequest(
        String url, {
        required String method,
        Map<String, String>? params,
        Map<String, String>? headers,
        dynamic body,
        ResponseType responseType = ResponseType.json,
        bool allowRedirects = true,
        bool skipCredentialValidation = false,
      }) async {
        return Response<dynamic>(
          requestOptions: RequestOptions(path: url),
          statusCode: 200,
          data: '''
{
  "result": "1",
  "channelList": [
    {
      "content": {
        "id": 456,
        "cpi": 789,
        "state": 0,
        "course": {
          "data": [
            {
              "id": 123,
              "name": "Mobile Learning",
              "teacherfactor": "Teacher Zhang"
            }
          ]
        }
      }
    }
  ]
}
''',
        );
      }

      ApiService.debugSendRequestOverride = captureRequest;

      final courses = await CXCourseApi.getCoursesList();

      expect(courses, hasLength(1));
      expect(courses!.single.courseId, '123');
    });
  });

  group('Chaoxing Dio manager', () {
    test('recreates cached Dio for chaoxing user', () async {
      final first = await PlatformDioManager.getDioForUser(
        platform: PlatformType.chaoxing,
        userId: '403701235',
      );
      final second = await PlatformDioManager.getDioForUser(
        platform: PlatformType.chaoxing,
        userId: '403701235',
      );

      expect(identical(first, second), isFalse);
    });
  });
}
