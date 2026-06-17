import 'package:course_helper/api/sign_request_profile.dart';
import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/platform.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final loginBody = <String, String>{'username': 'u', 'password': 'p'};

void main() {
  tearDown(ApiService.resetForTests);

  const chaoxingContext = SignRequestContext(
    platform: PlatformType.chaoxing,
    url: 'https://mobilelearn.chaoxing.com/pptSign/stuSignajax',
    method: 'GET',
    baseUrl: 'https://mobilelearn.chaoxing.com',
    contentKind: SignRequestContentKind.form,
  );

  test('profile merge keeps explicit auth headers', () {
    final profile = SignRequestProfiles.ketangpaiAttendance(
      baseUrl: 'https://openapiv5.ketangpai.com',
    );

    final headers = profile.mergeHeaders({
      'token': 'local-token',
      'content-type': 'application/json',
    });

    expect(headers['token'], 'local-token');
    expect(headers['content-type'], 'application/json');
    expect(headers['Referer'], 'https://w.ketangpai.com/');
    expect(headers['Origin'], 'https://openapiv5.ketangpai.com');
  });

  test('context-aware headers keep explicit auth and csrf headers', () {
    final profile = SignRequestProfiles.rainClassroomCheckIn(
      referer: 'https://www.yuketang.cn/',
    );
    final headers = profile.mergeHeaders(
      const {
        'Cookie': 'csrftoken=abc',
        'X-CSRFToken': 'abc',
        'Authorization': 'Bearer local',
      },
      context: const SignRequestContext(
        platform: PlatformType.rainClassroom,
        url: 'https://changjiang.yuketang.cn/api/v3/lesson/checkin',
        method: 'POST',
        baseUrl: 'https://changjiang.yuketang.cn',
        contentKind: SignRequestContentKind.json,
      ),
    );

    expect(headers['Origin'], 'https://changjiang.yuketang.cn');
    expect(headers['Referer'], 'https://changjiang.yuketang.cn/');
    expect(headers['content-type'], 'application/json;charset=UTF-8');
    expect(headers['Cookie'], 'csrftoken=abc');
    expect(headers['X-CSRFToken'], 'abc');
    expect(headers['Authorization'], 'Bearer local');
  });

  test('chaoxing context builds mobilelearn origin and form content type', () {
    final headers = SignRequestProfiles.chaoxingMobileLearn().mergeHeaders(
      null,
      context: chaoxingContext,
    );

    expect(headers['Origin'], 'https://mobilelearn.chaoxing.com');
    expect(headers['Referer'], 'https://mobilelearn.chaoxing.com/');
    expect(headers['content-type'], 'application/x-www-form-urlencoded');
  });

  test('tronclass and ketangpai use runtime baseUrl context', () {
    final tronclassHeaders =
        SignRequestProfiles.tronclassRollcall(
          baseUrl: 'https://courses.guet.edu.cn',
        ).mergeHeaders(
          const {'x-session-id': 'sid'},
          context: const SignRequestContext(
            platform: PlatformType.tronclass,
            url: 'https://custom.tronclass.example/api/rollcall/1/answer',
            method: 'PUT',
            baseUrl: 'https://custom.tronclass.example',
            contentKind: SignRequestContentKind.json,
          ),
        );
    expect(tronclassHeaders['Origin'], 'https://custom.tronclass.example');
    expect(tronclassHeaders['Referer'], 'https://custom.tronclass.example/');
    expect(tronclassHeaders['x-session-id'], 'sid');

    final ketangpaiHeaders =
        SignRequestProfiles.ketangpaiAttendance(
          baseUrl: 'https://openapiv5.ketangpai.com',
        ).mergeHeaders(
          const {'token': 'local-token'},
          context: const SignRequestContext(
            platform: PlatformType.ketangpai,
            url: 'https://openapiv5.ketangpai.com/AttenceApi/checkin',
            method: 'POST',
            baseUrl: 'https://openapiv5.ketangpai.com',
            contentKind: SignRequestContentKind.json,
          ),
        );
    expect(ketangpaiHeaders['Origin'], 'https://openapiv5.ketangpai.com');
    expect(ketangpaiHeaders['Referer'], 'https://w.ketangpai.com/');
    expect(ketangpaiHeaders['token'], 'local-token');
  });

  test('multipart context does not inject content type boundary header', () {
    final headers =
        SignRequestProfiles.weizhuojiaoWechat(
          referer: 'https://v18.teachermate.cn/wechat/wechat/guide/signin',
        ).mergeHeaders(
          null,
          context: const SignRequestContext(
            platform: PlatformType.weizhuojiao,
            url:
                'https://v18.teachermate.cn/wechat-api/v1/class-attendance/student-sign-in',
            method: 'POST',
            baseUrl: 'https://v18.teachermate.cn',
            contentKind: SignRequestContentKind.multipart,
          ),
        );

    expect(
      headers.keys.any((key) => key.toLowerCase() == 'content-type'),
      isFalse,
    );
  });

  test('null profile bypasses enhanced header construction', () async {
    var calls = 0;
    final response = await SignRequestExecutor.run(
      profile: null,
      headers: const {'User-Agent': 'login-ua'},
      legacyHeaders: const {'User-Agent': 'legacy-ua'},
      operation: 'login should bypass profile',
      context: chaoxingContext,
      send: (headers) async {
        calls++;
        expect(headers, const {'User-Agent': 'login-ua'});
        return Response<dynamic>(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 200,
          data: 'ok',
        );
      },
    );

    expect(calls, 1);
    expect(response.data, 'ok');
  });

  test(
    'ApiService request without signProfile keeps core request unchanged',
    () async {
      ApiService.resetForTests();
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
            expect(url, '/login');
            expect(method, 'POST');
            expect(params, const {'service': 'portal'});
            expect(headers, const {'User-Agent': 'login-ua'});
            expect(body, same(loginBody));
            return Response<dynamic>(
              requestOptions: RequestOptions(path: url, method: method),
              statusCode: 200,
              data: {'ok': true},
            );
          };

      await ApiService.sendRequest(
        '/login',
        method: 'POST',
        params: const {'service': 'portal'},
        headers: const {'User-Agent': 'login-ua'},
        body: loginBody,
        skipCredentialValidation: true,
      );

      expect(calls, 1);
    },
  );

  test('executor does not fallback on success', () async {
    var calls = 0;
    final response = await SignRequestExecutor.run(
      profile: SignRequestProfiles.chaoxingMobileLearn(),
      headers: const {'Cookie': 'UID=1'},
      legacyHeaders: const {'Cookie': 'UID=1'},
      operation: 'test success',
      context: chaoxingContext,
      send: (headers) async {
        calls++;
        expect(headers, containsPair('Cookie', 'UID=1'));
        expect(
          headers,
          containsPair('Referer', 'https://mobilelearn.chaoxing.com/'),
        );
        return Response<dynamic>(
          requestOptions: RequestOptions(path: '/sign'),
          statusCode: 200,
          data: 'success',
        );
      },
    );

    expect(calls, 1);
    expect(response.data, 'success');
  });

  test('executor falls back once for 403 response', () async {
    var calls = 0;
    final response = await SignRequestExecutor.run(
      profile: SignRequestProfiles.tronclassRollcall(
        baseUrl: 'https://courses.guet.edu.cn',
      ),
      headers: const {'x-session-id': 'sid'},
      legacyHeaders: const {'x-session-id': 'sid'},
      operation: 'rollcall',
      context: const SignRequestContext(
        platform: PlatformType.tronclass,
        url: 'https://courses.guet.edu.cn/api/rollcall/1/answer',
        method: 'PUT',
        baseUrl: 'https://courses.guet.edu.cn',
        contentKind: SignRequestContentKind.json,
      ),
      send: (headers) async {
        calls++;
        if (calls == 1) {
          expect(
            headers,
            containsPair('Origin', 'https://courses.guet.edu.cn'),
          );
          return Response<dynamic>(
            requestOptions: RequestOptions(path: '/rollcall'),
            statusCode: 403,
            data: {'message': 'forbidden'},
          );
        }
        expect(headers, {'x-session-id': 'sid'});
        return Response<dynamic>(
          requestOptions: RequestOptions(path: '/rollcall'),
          statusCode: 200,
          data: {'status': 'on_call'},
        );
      },
    );

    expect(calls, 2);
    expect(response.data, {'status': 'on_call'});
  });

  test('executor logs sanitized fallback errors', () async {
    final logs = <String>[];
    var calls = 0;

    await SignRequestExecutor.run(
      profile: SignRequestProfiles.weizhuojiaoWechat(
        referer:
            'https://v18.teachermate.cn/wechat/wechat/guide/signin?openid=secret-openid',
      ),
      headers: const {'Cookie': 'token=secret-token'},
      legacyHeaders: const {'Cookie': 'token=secret-token'},
      operation: 'submit openid=secret-openid token=secret-token',
      context: const SignRequestContext(
        platform: PlatformType.weizhuojiao,
        url:
            'https://v18.teachermate.cn/wechat-api/v1/class-attendance/student-sign-in',
        method: 'POST',
        baseUrl: 'https://v18.teachermate.cn',
        referer:
            'https://v18.teachermate.cn/wechat/wechat/guide/signin?openid=secret-openid',
        contentKind: SignRequestContentKind.form,
      ),
      logSink: (tag, message) => logs.add('$tag $message'),
      send: (headers) async {
        calls++;
        if (calls == 1) {
          throw DioException(
            requestOptions: RequestOptions(path: '/student-sign-in'),
            type: DioExceptionType.connectionTimeout,
            message: 'token=secret-token openid=secret-openid',
          );
        }
        return Response<dynamic>(
          requestOptions: RequestOptions(path: '/student-sign-in'),
          statusCode: 200,
          data: 'ok',
        );
      },
    );

    expect(logs.single, isNot(contains('secret-token')));
    expect(logs.single, isNot(contains('secret-openid')));
    expect(logs.single, contains('<redacted>'));
  });
}
