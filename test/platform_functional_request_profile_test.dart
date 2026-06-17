import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/platform_functional_request_profile.dart';
import 'package:course_helper/api/platform_request_stability.dart';
import 'package:course_helper/api/sign_request_profile.dart';
import 'package:course_helper/platform.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ApiService.resetForTests();
    PlatformManager().setPlatformSync(PlatformType.chaoxing);
  });

  test(
    'tronclass profile builds stable WebView headers without pseudo headers',
    () {
      final profile = PlatformFunctionalRequestProfiles.tronclassWebView();
      final headers = profile.mergeHeaders(
        null,
        context: const PlatformFunctionalRequestContext(
          platform: PlatformType.tronclass,
          url: 'https://courses.guet.edu.cn/api/orgs/1/live-record-settings',
          method: 'GET',
          baseUrl: 'https://courses.guet.edu.cn',
          contentKind: PlatformFunctionalContentKind.unknown,
        ),
      );

      expect(headers['User-Agent'], contains('TronClass/common'));
      expect(headers['Accept-Language'], 'zh-Hans');
      expect(headers['X-Requested-With'], 'XMLHttpRequest');
      expect(headers['Origin'], 'http://localhost');
      expect(headers['Referer'], 'http://localhost/');
      expect(headers['sec-fetch-site'], 'cross-site');
      expect(headers['sec-fetch-mode'], 'cors');
      expect(headers['sec-fetch-dest'], 'empty');
      expect(headers['sec-ch-ua-platform'], '"Android"');
      expect(headers['priority'], 'u=1, i');
      expect(headers.keys.where((key) => key.startsWith(':')), isEmpty);
      expect(
        headers.keys.any((key) => key.toLowerCase() == 'accept-encoding'),
        isFalse,
      );
    },
  );

  test('functional profiles keep explicit auth and csrf headers', () {
    final profile = PlatformFunctionalRequestProfiles.ketangpaiWebApi();
    final headers = profile.mergeHeaders(
      const {
        'token': 'local-token',
        'Cookie': 'sid=1',
        'Authorization': 'Bearer local',
        'X-CSRFToken': 'csrf',
        'x-session-id': 'sid',
      },
      context: const PlatformFunctionalRequestContext(
        platform: PlatformType.ketangpai,
        url: 'https://openapiv5.ketangpai.com/CourseApi/semesterCourseList',
        method: 'POST',
        baseUrl: 'https://openapiv5.ketangpai.com',
        contentKind: PlatformFunctionalContentKind.json,
      ),
    );

    expect(headers['token'], 'local-token');
    expect(headers['Cookie'], 'sid=1');
    expect(headers['Authorization'], 'Bearer local');
    expect(headers['X-CSRFToken'], 'csrf');
    expect(headers['x-session-id'], 'sid');
    expect(headers['content-type'], 'application/json;charset=UTF-8');
    expect(headers['Origin'], 'https://w.ketangpai.com');
    expect(headers['Referer'], 'https://w.ketangpai.com/');
  });

  test(
    'ApiService without platformOptions keeps login headers unchanged',
    () async {
      var calls = 0;
      ApiService.debugSendRequestOverride =
          (
            url, {
            required String method,
            Map<String, String>? params,
            Map<String, String>? headers,
            dynamic body,
            ResponseType responseType = ResponseType.json,
            bool allowRedirects = true,
            bool skipCredentialValidation = false,
          }) async {
            calls++;
            expect(headers, const {'User-Agent': 'login-ua'});
            return Response<dynamic>(
              requestOptions: RequestOptions(path: url, method: method),
              statusCode: 200,
              data: {'ok': true},
            );
          };

      await ApiService.sendRequest(
        '/login',
        method: 'POST',
        headers: const {'User-Agent': 'login-ua'},
        body: const {'username': 'u'},
        skipCredentialValidation: true,
      );

      expect(calls, 1);
    },
  );

  test('ApiService read options apply functional profile', () async {
    var calls = 0;
    PlatformManager().setPlatformSync(PlatformType.tronclass);
    ApiService.debugSendRequestOverride =
        (
          url, {
          required String method,
          Map<String, String>? params,
          Map<String, String>? headers,
          dynamic body,
          ResponseType responseType = ResponseType.json,
          bool allowRedirects = true,
          bool skipCredentialValidation = false,
        }) async {
          calls++;
          expect(headers, isNotNull);
          expect(headers!['User-Agent'], contains('TronClass/common'));
          expect(headers['x-session-id'], 'sid');
          expect(headers['Origin'], 'http://localhost');
          return Response<dynamic>(
            requestOptions: RequestOptions(path: url, method: method),
            statusCode: 200,
            data: {'ok': true},
          );
        };

    await ApiService.sendRequest(
      'https://courses.guet.edu.cn/api/todos',
      headers: const {'x-session-id': 'sid'},
      skipCredentialValidation: true,
      platformOptions: const PlatformRequestOptions(
        operationId: 'tronclass.todo.read',
        requestKind: PlatformRequestKind.read,
      ),
    );

    expect(calls, 1);
  });

  test('signProfile request does not stack functional profile', () async {
    var calls = 0;
    PlatformManager().setPlatformSync(PlatformType.tronclass);
    ApiService.debugSendRequestOverride =
        (
          url, {
          required String method,
          Map<String, String>? params,
          Map<String, String>? headers,
          dynamic body,
          ResponseType responseType = ResponseType.json,
          bool allowRedirects = true,
          bool skipCredentialValidation = false,
        }) async {
          calls++;
          expect(headers, isNotNull);
          expect(headers!['User-Agent'], isNot(contains('TronClass/common')));
          expect(headers['Origin'], 'https://courses.guet.edu.cn');
          return Response<dynamic>(
            requestOptions: RequestOptions(path: url, method: method),
            statusCode: 200,
            data: {'ok': true},
          );
        };

    await ApiService.sendRequest(
      'https://courses.guet.edu.cn/api/rollcall/1/answer',
      method: 'POST',
      headers: const {'x-session-id': 'sid'},
      signProfile: SignRequestProfiles.tronclassRollcall(
        baseUrl: 'https://courses.guet.edu.cn',
      ),
      platformOptions: const PlatformRequestOptions(
        operationId: 'tronclass.sign.submit',
        requestKind: PlatformRequestKind.sign,
      ),
      skipCredentialValidation: true,
    );

    expect(calls, 1);
  });
}
