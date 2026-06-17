import 'dart:io';
import 'dart:typed_data';

import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/login.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:course_helper/session/credential_manager.dart';
import 'package:course_helper/session/login_context.dart';
import 'package:course_helper/tronclass_guet_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Response<dynamic> _plainResponse(
  String url, {
  int statusCode = 200,
  dynamic data = '',
  Map<String, List<String>>? headers,
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: url),
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(headers ?? const <String, List<String>>{}),
  );
}

bool _isTronclassBfpUrl(String url) {
  return url.contains('/authserver/bfp/info');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ApiService.initialize();
  });

  tearDown(ApiService.resetForTests);

  group('Chaoxing login payload', () {
    test('accepts mixed success flags', () {
      expect(isChaoxingLoginSuccessPayload({'status': true}), isTrue);
      expect(isChaoxingLoginSuccessPayload({'status': 'true'}), isTrue);
      expect(isChaoxingLoginSuccessPayload({'result': 1}), isTrue);
      expect(isChaoxingLoginSuccessPayload({'result': '1'}), isTrue);
      expect(isChaoxingLoginSuccessPayload({'code': 200}), isTrue);
      expect(isChaoxingLoginSuccessPayload('{"status":"true"}'), isTrue);
      expect(isChaoxingLoginSuccessPayload('{"result":"1"}'), isTrue);
      expect(isChaoxingLoginSuccessPayload('{"code":200}'), isTrue);
    });

    test('parses user from normalized payload', () {
      final user = parseChaoxingUserFromPayload({
        'result': '1',
        'msg': {
          'puid': '10001',
          'name': 'Alice',
          'pic': 'https://example.com/avatar.png',
          'phone': '13800000000',
          'schoolname': 'Test University',
        },
      });

      expect(user, isNotNull);
      expect(user!.uid, '10001');
      expect(user.name, 'Alice');
      expect(user.avatar, 'https://example.com/avatar.png');
      expect(user.phone, '13800000000');
      expect(user.school, 'Test University');
      expect(user.platform, 'chaoxing');
    });
  });

  group('Ketangpai login requests', () {
    Future<void> initializeKetangpaiManagers() async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'current_platform': 'ketangpai',
      });
      ApiService.resetForTests();
      CookieManager.resetForTests();
      await ApiService.initialize();
      await PlatformManager().initialize();
      await AccountManager.initialize();
      await CookieManager.initialize();
    }

    test('password login skips credential validation', () async {
      await initializeKetangpaiManagers();
      var sawRequest = false;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            sawRequest = true;
            expect(url, '/UserApi/login');
            expect(method, 'POST');
            expect(skipCredentialValidation, isTrue);
            return _plainResponse(
              url,
              data: <String, dynamic>{
                'status': 1,
                'data': <String, dynamic>{'token': 'kt-token'},
              },
            );
          };

      final result = await KTLoginApi.loginPassword(
        '13800000000',
        'pw',
        '1234',
      );

      expect(sawRequest, isTrue);
      expect(result?['data'], containsPair('token', 'kt-token'));
    });

    test('mobile login skips credential validation', () async {
      await initializeKetangpaiManagers();
      var sawRequest = false;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            sawRequest = true;
            expect(url, '/UserApi/loginByMobile');
            expect(method, 'POST');
            expect(skipCredentialValidation, isTrue);
            return _plainResponse(
              url,
              data: <String, dynamic>{
                'status': 1,
                'data': <String, dynamic>{'token': 'kt-token'},
              },
            );
          };

      final result = await KTLoginApi.loginByMobile('13800000000', '1234');

      expect(sawRequest, isTrue);
      expect(result?['data'], containsPair('token', 'kt-token'));
    });

    test('token status skips credential validation', () async {
      await initializeKetangpaiManagers();
      final requests = <String>[];

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            requests.add(url);
            expect(method, 'POST');
            expect(headers?['token'], 'kt-token');
            expect(skipCredentialValidation, isTrue);
            if (url == '/UserApi/getUserBasinInfo') {
              return _plainResponse(
                url,
                data: <String, dynamic>{
                  'status': 1,
                  'code': 10000,
                  'data': <String, dynamic>{'uid': 'kt-user'},
                },
              );
            }
            expect(url, '/CourseApi/semesterCourseList');
            return _plainResponse(
              url,
              data: <String, dynamic>{
                'status': 1,
                'code': 10000,
                'data': const <Map<String, dynamic>>[],
              },
            );
          };

      final healthy = await KTLoginApi.checkTokenStatus('kt-token');

      expect(requests, <String>[
        '/UserApi/getUserBasinInfo',
        '/CourseApi/semesterCourseList',
      ]);
      expect(healthy, isTrue);
    });

    test('token status fails when course business api is expired', () async {
      await initializeKetangpaiManagers();
      final requests = <String>[];

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            requests.add(url);
            expect(method, 'POST');
            expect(headers?['token'], 'kt-token');
            expect(skipCredentialValidation, isTrue);
            if (url == '/UserApi/getUserBasinInfo') {
              return _plainResponse(
                url,
                data: <String, dynamic>{
                  'status': 1,
                  'code': 10000,
                  'data': <String, dynamic>{'uid': 'kt-user'},
                },
              );
            }
            expect(url, '/CourseApi/semesterCourseList');
            return _plainResponse(
              url,
              data: <String, dynamic>{
                'status': 0,
                'code': 20003,
                'message': 'token expired',
                'data': <String, dynamic>{},
              },
            );
          };

      final healthy = await KTLoginApi.checkTokenStatus('kt-token');

      expect(requests, <String>[
        '/UserApi/getUserBasinInfo',
        '/CourseApi/semesterCourseList',
      ]);
      expect(healthy, isFalse);
    });

    test('getUserInfo skips credential validation for both requests', () async {
      await initializeKetangpaiManagers();
      final requests = <String>[];

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            requests.add(url);
            expect(method, 'POST');
            expect(headers?['token'], 'kt-token');
            expect(skipCredentialValidation, isTrue);
            if (url == '/UserApi/getUserBasinInfo') {
              return _plainResponse(
                url,
                data: <String, dynamic>{
                  'status': 1,
                  'data': <String, dynamic>{
                    'uid': 'kt-user',
                    'username': 'Fallback Name',
                    'mobile': '13800000000',
                  },
                },
              );
            }
            if (url == '/UserApi/getUserInfo') {
              return _plainResponse(
                url,
                data: <String, dynamic>{
                  'status': 1,
                  'data': <String, dynamic>{
                    'username': 'Ketangpai User',
                    'school': 'GUET',
                    'avatar': 'avatar.png',
                  },
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final user = await KTLoginApi.getUserInfo(
        'kt-token',
        fallbackUid: 'fallback',
      );

      expect(requests, <String>[
        '/UserApi/getUserBasinInfo',
        '/UserApi/getUserInfo',
      ]);
      expect(user, isNotNull);
      expect(user!.uid, 'kt-user');
      expect(user.name, 'Ketangpai User');
      expect(user.token, 'kt-token');
    });

    test(
      'credential refresh token check does not recurse into validation',
      () async {
        await initializeKetangpaiManagers();
        final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final user = User(
          uid: 'kt-user',
          name: 'Ketangpai User',
          avatar: '',
          phone: '13800000000',
          school: 'GUET',
          platform: 'ketangpai',
          token: 'kt-token',
          credentialExpiry: nowSeconds + 3600,
        );
        await AccountManager.addAccountForPlatformName(
          'ketangpai',
          user,
          notify: false,
          migrateTempCookies: false,
        );
        await AccountManager.setCurrentSessionForPlatformName(
          'ketangpai',
          user.uid,
          notify: false,
        );

        var validatorCalls = 0;
        var tokenStatusCalls = 0;
        ApiService.debugCredentialValidatorOverride = (userId) async {
          validatorCalls++;
          return CredentialManager.ensureCredentialValid(userId);
        };
        ApiService.debugSendRequestOverride =
            (
              url, {
              required method,
              params,
              headers,
              body,
              responseType = ResponseType.json,
              allowRedirects = true,
              skipCredentialValidation = false,
            }) async {
              if (url == '/business') {
                return _plainResponse(url, data: <String, dynamic>{'ok': true});
              }
              expect(skipCredentialValidation, isTrue);
              tokenStatusCalls++;
              if (url == '/CourseApi/semesterCourseList') {
                return _plainResponse(
                  url,
                  data: <String, dynamic>{
                    'status': 1,
                    'code': 10000,
                    'data': const <Map<String, dynamic>>[],
                  },
                );
              }
              expect(url, '/UserApi/getUserBasinInfo');
              return _plainResponse(
                url,
                data: <String, dynamic>{
                  'status': 1,
                  'code': 10000,
                  'data': <String, dynamic>{'uid': 'kt-user'},
                },
              );
            };

        final valid = await ApiService.sendRequest('/business');

        expect(valid.statusCode, 200);
        expect(validatorCalls, 1);
        expect(tokenStatusCalls, 2);
      },
    );
  });

  group('Tronclass login next action', () {
    test('parses internal uid and real student id separately', () {
      final user = TCLoginApi.parseTronclassUserFromPayload({
        'data': {'id': 117246, 'student_no': '2099000001', 'name': 'Test User'},
      });

      expect(user, isNotNull);
      expect(user!.uid, '117246');
      expect(user.studentId, '2099000001');
      expect(user.name, 'Test User');
    });

    test('uses login username as student id fallback when it looks valid', () {
      final user = TCLoginApi.parseTronclassUserFromPayload({
        'data': {'id': 117246, 'name': 'Test User'},
      }, fallbackUid: '2099000001');

      expect(user, isNotNull);
      expect(user!.uid, '117246');
      expect(user.studentId, '2099000001');
    });

    test('user json preserves student id', () {
      final user = TCLoginApi.parseTronclassUserFromPayload({
        'data': {'id': 117246, 'student_no': '2099000001', 'name': 'Test User'},
      })!;

      final restored = User.fromJson(user.copyWith().toJson());

      expect(restored.uid, '117246');
      expect(restored.studentId, '2099000001');
    });

    test('detects success states', () {
      expect(
        resolveTronclassLoginNextAction({'ok': true}),
        TronclassLoginNextAction.success,
      );
      expect(
        resolveTronclassLoginNextAction({'sessionId': 'sid-123'}),
        TronclassLoginNextAction.success,
      );
    });

    test('detects mfa and web reauth requirements', () {
      expect(
        resolveTronclassLoginNextAction({'requireMfa': true}),
        TronclassLoginNextAction.requireMfa,
      );
      expect(
        resolveTronclassLoginNextAction({'requireWebReauth': true}),
        TronclassLoginNextAction.requireWebReauth,
      );
    });

    test('falls back to failure', () {
      expect(
        resolveTronclassLoginNextAction({'ok': false}),
        TronclassLoginNextAction.failure,
      );
      expect(
        resolveTronclassLoginNextAction(null),
        TronclassLoginNextAction.failure,
      );
    });
  });

  group('Tronclass MFA resend state', () {
    test('shows failure dialog after auto retry exhaustion', () {
      final result = {
        'ok': false,
        'showMfaSendFailureDialog': true,
        'mfaSendFailedAfterRetries': true,
        'allowManualMfaRetry': true,
        'service': 'svc',
      };

      expect(shouldPromptTronclassMfaSendFailureDialog(result), isTrue);
      expect(canResumeTronclassMfaChallenge(result), isTrue);
    });

    test('manual retry failure keeps current MFA session context', () {
      final result = {
        'ok': false,
        'showMfaSendFailureDialog': true,
        'mfaSendRetryFailed': true,
        'allowManualMfaRetry': true,
        'reauthEntryUrl':
            'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do',
      };

      expect(shouldPromptTronclassMfaSendFailureDialog(result), isTrue);
      expect(canResumeTronclassMfaChallenge(result), isTrue);
      expect(
        resolveTronclassLoginNextAction(result),
        TronclassLoginNextAction.failure,
      );
    });

    test('invalid MFA session cannot resume the same reauth entry', () {
      final result = {
        'ok': false,
        'showMfaSendFailureDialog': true,
        'mfaSendRetryFailed': true,
        'allowManualMfaRetry': true,
        'mfaSessionInvalid': true,
        'reauthEntryUrl':
            'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do',
      };

      expect(shouldPromptTronclassMfaSendFailureDialog(result), isTrue);
      expect(canResumeTronclassMfaChallenge(result), isFalse);
    });

    test('password login clears stale CAS cookies and reports bfp before captcha', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final encodedService = Uri.encodeQueryComponent(service);
      final loginUrl =
          '${TronclassGuetConstants.casLoginUrl}?service=$encodedService';
      final context = LoginContextManager.instance.createContext(
        PlatformType.tronclass,
      );
      addTearDown(
        () => LoginContextManager.instance.removeContext(context.contextId),
      );
      final casLoginUri = Uri.parse(TronclassGuetConstants.casLoginUrl);
      await context.tempCookieJar.saveFromResponse(casLoginUri, <Cookie>[
        Cookie('JSESSIONID', 'old-session'),
        Cookie('route', 'old-route'),
        Cookie('CASTGC', 'ticket-granting-cookie'),
      ]);

      final events = <String>[];
      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url == TronclassGuetConstants.identityAuthUrl) {
              events.add('identityAuth');
              expect(
                headers?['Referer'],
                '${TronclassGuetConstants.mobileBaseUrl}/',
              );
              final cookies = await context.tempCookieJar.loadForRequest(
                casLoginUri,
              );
              final names = cookies.map((cookie) => cookie.name);
              expect(names, contains('CASTGC'));
              expect(names, isNot(contains('JSESSIONID')));
              expect(names, isNot(contains('route')));
              return _plainResponse(loginUrl);
            }
            if (url == TronclassGuetConstants.casLoginUrl && method == 'GET') {
              events.add('casLoginGet');
              expect(
                headers?['Referer'],
                '${TronclassGuetConstants.casLoginUrl}?service=$encodedService',
              );
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (url.contains('/authserver/bfp/info')) {
              events.add('bfp');
              expect(params?['bfp'], matches(RegExp(r'^[0-9A-F]{32}$')));
              expect(
                headers?['Referer'],
                '${TronclassGuetConstants.casLoginUrl}?service=$encodedService',
              );
              expect(headers?['X-Requested-With'], 'XMLHttpRequest');
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              events.add('captchaCheck');
              expect(events.indexOf('bfp'), lessThan(events.length - 1));
              expect(
                headers?['Referer'],
                '${TronclassGuetConstants.casLoginUrl}?service=$encodedService',
              );
              expect(headers?['X-Requested-With'], 'XMLHttpRequest');
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == TronclassGuetConstants.casLoginUrl && method == 'POST') {
              expect(headers?['Origin'], TronclassGuetConstants.casBaseUrl);
              expect(
                headers?['Referer'],
                '${TronclassGuetConstants.casLoginUrl}?service=$encodedService',
              );
              expect(
                headers?['content-type'],
                'application/x-www-form-urlencoded',
              );
              return _plainResponse(
                url,
                statusCode: 401,
                data:
                    '<html><div id="showErrorTip">invalid credentials</div></html>',
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        loginContext: context,
      );

      expect(result['ok'], isNot(true));
      expect(
        events,
        containsAllInOrder(<String>[
          'identityAuth',
          'casLoginGet',
          'bfp',
          'captchaCheck',
        ]),
      );
    });

    test('CAS bfp is stable per username and isolated by account', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final loginUrl =
          '${TronclassGuetConstants.casLoginUrl}?service=${Uri.encodeQueryComponent(service)}';
      final seenBfps = <String, List<String>>{};
      var bfpRequestCount = 0;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url == TronclassGuetConstants.identityAuthUrl) {
              return _plainResponse(loginUrl);
            }
            if (url == TronclassGuetConstants.casLoginUrl && method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              bfpRequestCount++;
              final username = bfpRequestCount <= 2 ? 'alice' : 'bob';
              seenBfps
                  .putIfAbsent(username, () => <String>[])
                  .add(params?['bfp']?.toString() ?? '');
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == TronclassGuetConstants.casLoginUrl && method == 'POST') {
              return _plainResponse(
                url,
                statusCode: 401,
                data:
                    '<html><div id="showErrorTip">invalid credentials</div></html>',
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      await TCLoginApi.login('alice', 'password');
      await TCLoginApi.login('alice', 'password');
      await TCLoginApi.login('bob', 'password');

      final aliceBfps = seenBfps['alice'] ?? const <String>[];
      final bobBfps = seenBfps['bob'] ?? const <String>[];
      expect(aliceBfps, hasLength(2));
      expect(bobBfps, hasLength(1));
      expect(aliceBfps.first, matches(RegExp(r'^[0-9A-F]{32}$')));
      expect(aliceBfps[1], aliceBfps.first);
      expect(bobBfps.first, matches(RegExp(r'^[0-9A-F]{32}$')));
      expect(bobBfps.first, isNot(aliceBfps.first));
    });

    test('plain failures do not enter MFA resend dialog flow', () {
      final result = {'ok': false, 'message': 'send failed'};

      expect(shouldPromptTronclassMfaSendFailureDialog(result), isFalse);
      expect(canResumeTronclassMfaChallenge(result), isFalse);
    });

    test('classifies 206302 and login redirects as MFA session invalid', () {
      expect(
        isTronclassMfaSessionInvalidResponse({
          'errCode': '206302',
          'message': 'session timeout',
        }),
        isTrue,
      );
      expect(
        isTronclassMfaSessionInvalidResponse({
          'data': 'https://cas.guet.edu.cn/authserver/login',
        }),
        isTrue,
      );
      expect(
        isTronclassMfaSessionInvalidResponse({'message': 'service busy'}),
        isFalse,
      );
    });

    test('login enters MFA stage even when image captcha is not required', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 401,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login('user', 'password');

      expect(result['requireMfa'], isTrue);
    });

    test(
      'CAS login page dynamicCode markup does not trigger MFA before POST',
      () async {
        const service =
            'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
        var checkNeedCaptchaCalls = 0;
        var casLoginPostCalls = 0;
        var dynamicCodeCalls = 0;

        ApiService.debugSendRequestOverride =
            (
              url, {
              required method,
              params,
              headers,
              body,
              responseType = ResponseType.json,
              allowRedirects = true,
              skipCredentialValidation = false,
            }) async {
              if (url.contains(
                '/auth/realms/guet/protocol/openid-connect/auth',
              )) {
                return _plainResponse(
                  'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
                );
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'GET') {
                return _plainResponse(
                  url,
                  data: '''
                    <html>
                      <form id="casLoginForm">
                        <input name="execution" value="e1s1" />
                        <input name="pwdEncryptSalt" value="1234567890abcdef" />
                      </form>
                      <script>
                        var authCodeTypeName = 'reAuthDynamicCodeType';
                        function dynamicCode() {}
                      </script>
                    </html>
                  ''',
                );
              }
              if (_isTronclassBfpUrl(url)) {
                return _plainResponse(url, data: '{}');
              }
              if (url.contains('checkNeedCaptcha.htl')) {
                checkNeedCaptchaCalls++;
                return _plainResponse(url, data: '{"isNeed":false}');
              }
              if (url.contains('getDynamicCodeByReauth.do')) {
                dynamicCodeCalls++;
                throw StateError('dynamicCode must not be sent before POST');
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'POST') {
                casLoginPostCalls++;
                return _plainResponse(
                  url,
                  statusCode: 200,
                  data:
                      '<html><span id="showErrorTip">invalid credentials</span></html>',
                );
              }
              throw StateError('Unexpected request: $method $url');
            };

        final result = await TCLoginApi.login('user', 'password');

        expect(result['ok'], isNot(true));
        expect(checkNeedCaptchaCalls, 1);
        expect(casLoginPostCalls, 1);
        expect(dynamicCodeCalls, 0);
      },
    );

    test('image captcha is requested once before MFA dynamic code is sent', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      var captchaProviderCalls = 0;
      var captchaImageCalls = 0;
      var casLoginGetCalls = 0;
      var casLoginPostCalls = 0;
      var dynamicCodeCalls = 0;
      var reauthPrimeCalls = 0;
      var reauthSubmitCalls = 0;
      var authCodeReady = false;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              if (authCodeReady) {
                return _plainResponse(
                  'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
                );
              }
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              casLoginGetCalls++;
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":true}');
            }
            if (url.contains('getCaptcha.htl')) {
              captchaImageCalls++;
              return _plainResponse(
                url,
                data: Uint8List.fromList(<int>[1, 2, 3]),
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              casLoginPostCalls++;
              expect((body as Map)['captcha'], 'abcd');
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 401,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url == reauthEntryUrl && method == 'GET') {
              reauthPrimeCalls++;
              return _plainResponse(
                reauthEntryUrl,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              dynamicCodeCalls++;
              expect((body as Map)['userName'], 'user');
              expect(body['authCodeTypeName'], 'reAuthDynamicCodeType');
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍?}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              reauthSubmitCalls++;
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        captchaProvider: (_) async {
          captchaProviderCalls++;
          return 'abcd';
        },
        mfaCodeProvider: (_, _) async => '123456',
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(result['tokenExchangeOk'], isTrue);
      expect(result['portalLoginOk'], isTrue);
      expect(result['sessionPersistable'], isTrue);
      expect(result['identityTokenStatus'], 200);
      expect(result['portalLoginStatus'], 200);
      expect(captchaProviderCalls, 1);
      expect(captchaImageCalls, 1);
      expect(casLoginGetCalls, 3);
      expect(casLoginPostCalls, 1);
      expect(reauthPrimeCalls, 0);
      expect(dynamicCodeCalls, 1);
      expect(reauthSubmitCalls, 1);
    });

    test('post-MFA 303 code completes login without broad auth crawl', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      final callbackUrl =
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code';
      var authCodeReady = false;
      var identityAfterMfaReplayCalls = 0;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              if (authCodeReady) {
                if (allowRedirects) {
                  identityAfterMfaReplayCalls++;
                } else {
                  throw StateError(
                    'Post-MFA flow must replay login, not probe',
                  );
                }
                return _plainResponse(
                  url,
                  statusCode: 303,
                  headers: <String, List<String>>{
                    'location': <String>[callbackUrl],
                  },
                );
              }
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 401,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url == reauthEntryUrl && method == 'GET') {
              return _plainResponse(
                reauthEntryUrl,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍?}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              expect((body as Map)['code'], 'auth-code');
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        mfaCodeProvider: (_, _) async => '123456',
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(identityAfterMfaReplayCalls, 1);
    });

    test('post-MFA replay handles CAS login page 302 callback code', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      const callbackUrl =
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=replayed-code';
      var authCodeReady = false;
      var replayCasLoginGetCalls = 0;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              if (authCodeReady) {
                replayCasLoginGetCalls++;
                return _plainResponse(
                  url,
                  statusCode: 302,
                  headers: const <String, List<String>>{
                    'location': <String>[callbackUrl],
                  },
                );
              }
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 401,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍?}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              expect((body as Map)['code'], 'replayed-code');
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        mfaCodeProvider: (_, _) async => '123456',
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(replayCasLoginGetCalls, 1);
    });

    test('post-MFA replays full CAS login with the same executor', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      const callbackUrl =
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=replayed-code';
      var authCodeReady = false;
      var casLoginGetCalls = 0;
      var casLoginPostCalls = 0;
      var dynamicCodeCalls = 0;
      var reauthSubmitCalls = 0;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              if (authCodeReady) {
                return _plainResponse(
                  'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
                );
              }
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              casLoginGetCalls++;
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              casLoginPostCalls++;
              if (authCodeReady) {
                return _plainResponse(callbackUrl);
              }
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 401,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url == reauthEntryUrl && method == 'GET') {
              return _plainResponse(
                reauthEntryUrl,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              dynamicCodeCalls++;
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍?}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              reauthSubmitCalls++;
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              expect((body as Map)['code'], 'replayed-code');
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        mfaCodeProvider: (_, _) async => '123456',
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(dynamicCodeCalls, 1);
      expect(reauthSubmitCalls, 1);
      expect(casLoginGetCalls, 6);
      expect(casLoginPostCalls, 2);
    });

    test('login POST MFA path sends dynamicCode without reauth view preflight', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      var dynamicCodeCalls = 0;
      var reauthViewCalls = 0;
      var reauthSubmitCalls = 0;
      var authCodeReady = false;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url == reauthEntryUrl && method == 'GET') {
              reauthViewCalls++;
              throw StateError('Unexpected reauth preflight');
            }
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              if (authCodeReady) {
                return _plainResponse(
                  'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
                );
              }
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 401,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              dynamicCodeCalls++;
              expect((body as Map)['userName'], 'user');
              expect(body['authCodeTypeName'], 'reAuthDynamicCodeType');
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍?}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              reauthSubmitCalls++;
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        mfaCodeProvider: (_, _) async => '123456',
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(reauthViewCalls, 0);
      expect(dynamicCodeCalls, 1);
      expect(reauthSubmitCalls, 1);
    });

    test('first utf8 credential 401 is replayed once and hidden from user', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      var casLoginPostCalls = 0;
      var dynamicCodeCalls = 0;
      var reauthSubmitCalls = 0;
      var authCodeReady = false;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              if (authCodeReady) {
                return _plainResponse(
                  'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
                );
              }
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              casLoginPostCalls++;
              if (casLoginPostCalls == 1) {
                return _plainResponse(
                  url,
                  statusCode: 401,
                  data:
                      '<html><div id="showErrorTip">\u60a8\u63d0\u4f9b\u7684\u7528\u6237\u540d\u6216\u8005\u5bc6\u7801\u6709\u8bef</div></html>',
                );
              }
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 302,
                headers: <String, List<String>>{
                  'location': <String>[reauthEntryUrl],
                },
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              dynamicCodeCalls++;
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"sent"}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              reauthSubmitCalls++;
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        mfaCodeProvider: (_, _) async => '123456',
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(casLoginPostCalls, 2);
      expect(dynamicCodeCalls, 1);
      expect(reauthSubmitCalls, 1);
    });

    test(
      'first credential 401 is replayed once with fresh CAS flow and suppressed',
      () async {
        const service =
            'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
        final reauthEntryUrl =
            'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
        var casLoginPostCalls = 0;
        var dynamicCodeCalls = 0;
        var reauthSubmitCalls = 0;
        var authCodeReady = false;

        ApiService.debugSendRequestOverride =
            (
              url, {
              required method,
              params,
              headers,
              body,
              responseType = ResponseType.json,
              allowRedirects = true,
              skipCredentialValidation = false,
            }) async {
              if (url.contains(
                '/auth/realms/guet/protocol/openid-connect/auth',
              )) {
                if (authCodeReady) {
                  return _plainResponse(
                    'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
                  );
                }
                return _plainResponse(
                  'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
                );
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'GET') {
                return _plainResponse(
                  url,
                  data:
                      '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
                );
              }
              if (_isTronclassBfpUrl(url)) {
                return _plainResponse(url, data: '{}');
              }
              if (url.contains('checkNeedCaptcha.htl')) {
                return _plainResponse(url, data: '{"isNeed":false}');
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'POST') {
                casLoginPostCalls++;
                if (casLoginPostCalls == 1) {
                  return _plainResponse(
                    url,
                    statusCode: 401,
                    data:
                        '<html><div id="showErrorTip">闂佽鍠撻崝宥堛亹娴ｅ湱鐟规繛鎴炵閻ｉ亶鏌ｉ～顒€濡介柛鈺傜洴瀹曘儱顓奸崱妤冧粣闂佸吋婢橀幊搴ㄦ儊閹达附鍎樺ù锝堫潐缁犳帡鎮?/div></html>',
                  );
                }
                return _plainResponse(
                  reauthEntryUrl,
                  statusCode: 302,
                  headers: <String, List<String>>{
                    'location': <String>[reauthEntryUrl],
                  },
                );
              }
              if (url.contains('getDynamicCodeByReauth.do')) {
                dynamicCodeCalls++;
                return _plainResponse(
                  url,
                  data:
                      '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍?}',
                );
              }
              if (url.contains('reAuthSubmit.do')) {
                reauthSubmitCalls++;
                authCodeReady = true;
                return _plainResponse(
                  url,
                  data: <String, dynamic>{'code': 'reAuth_success'},
                );
              }
              if (url.contains('/protocol/openid-connect/token')) {
                return _plainResponse(
                  url,
                  data: <String, dynamic>{'access_token': 'access-token'},
                );
              }
              if (url ==
                  'https://courses.guet.edu.cn/api/login?login=access_token') {
                return _plainResponse(
                  url,
                  data: <String, dynamic>{'ok': true},
                  headers: <String, List<String>>{
                    'x-session-id': <String>['session-id'],
                  },
                );
              }
              throw StateError('Unexpected request: $method $url');
            };

        final result = await TCLoginApi.login(
          'user',
          'password',
          mfaCodeProvider: (_, _) async => '123456',
        );

        expect(result['ok'], isTrue, reason: result.toString());
        expect(result['sessionId'], 'session-id');
        expect(casLoginPostCalls, 2);
        expect(dynamicCodeCalls, 1);
        expect(reauthSubmitCalls, 1);
      },
    );

    test('first plain-text credential 401 is replayed once', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      var casLoginPostCalls = 0;
      var dynamicCodeCalls = 0;
      var authCodeReady = false;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              if (authCodeReady) {
                return _plainResponse(
                  'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
                );
              }
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              casLoginPostCalls++;
              if (casLoginPostCalls == 1) {
                return _plainResponse(
                  url,
                  statusCode: 401,
                  data: '<html><body>invalid credentials</body></html>',
                );
              }
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 302,
                headers: <String, List<String>>{
                  'location': <String>[reauthEntryUrl],
                },
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              dynamicCodeCalls++;
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"sent"}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        mfaCodeProvider: (_, _) async => '123456',
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(casLoginPostCalls, 2);
      expect(dynamicCodeCalls, 1);
    });

    test('two credential 401 responses expose password error after replay', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      var casLoginPostCalls = 0;
      var dynamicCodeCalls = 0;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              casLoginPostCalls++;
              return _plainResponse(
                url,
                statusCode: 401,
                data:
                    '<html><div id="showErrorTip">闂佽鍠撻崝宥堛亹娴ｅ湱鐟规繛鎴炵閻ｉ亶鏌ｉ～顒€濡介柛鈺傜洴瀹曘儱顓奸崱妤冧粣闂佸吋婢橀幊搴ㄦ儊閹达附鍎樺ù锝堫潐缁犳帡鎮?/div></html>',
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              dynamicCodeCalls++;
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login('user', 'password');

      expect(result['ok'], isFalse);
      expect(result['credentialFailure'], isTrue);
      expect(result['message'], isNotEmpty);
      expect(casLoginPostCalls, 2);
      expect(dynamicCodeCalls, 0);
    });

    test('captcha-required credential 401 is not replayed', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      var casLoginPostCalls = 0;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":true}');
            }
            if (url.contains('getCaptcha.htl')) {
              return _plainResponse(
                url,
                data: Uint8List.fromList(<int>[1, 2, 3]),
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              casLoginPostCalls++;
              return _plainResponse(
                url,
                statusCode: 401,
                data: '<html><body>invalid credentials</body></html>',
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        captchaProvider: (_) async => 'abcd',
      );

      expect(result['ok'], isFalse);
      expect(result['retryableCredentialFailure'], isFalse);
      expect(casLoginPostCalls, 1);
    });

    test('MFA prompt exposes 120 second resend and resend primes context once', () async {
      const service =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
      final reauthEntryUrl =
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
      var dynamicCodeCalls = 0;
      var reauthViewCalls = 0;
      var reauthSubmitCalls = 0;
      var authCodeReady = false;
      var providerCalls = 0;
      Map<String, dynamic>? resendResult;

      ApiService.debugSendRequestOverride =
          (
            url, {
            required method,
            params,
            headers,
            body,
            responseType = ResponseType.json,
            allowRedirects = true,
            skipCredentialValidation = false,
          }) async {
            if (url == reauthEntryUrl && method == 'GET') {
              reauthViewCalls++;
              return _plainResponse(
                reauthEntryUrl,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url.contains(
              '/auth/realms/guet/protocol/openid-connect/auth',
            )) {
              if (authCodeReady) {
                return _plainResponse(
                  'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
                );
              }
              return _plainResponse(
                'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
              );
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'GET') {
              return _plainResponse(
                url,
                data:
                    '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
              );
            }
            if (_isTronclassBfpUrl(url)) {
              return _plainResponse(url, data: '{}');
            }
            if (url.contains('checkNeedCaptcha.htl')) {
              return _plainResponse(url, data: '{"isNeed":false}');
            }
            if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                method == 'POST') {
              return _plainResponse(
                reauthEntryUrl,
                statusCode: 401,
                data:
                    '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
              );
            }
            if (url.contains('getDynamicCodeByReauth.do')) {
              dynamicCodeCalls++;
              expect((body as Map)['userName'], 'user');
              expect(body['authCodeTypeName'], 'reAuthDynamicCodeType');
              return _plainResponse(
                url,
                data:
                    '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍褜鍏涘ù鍥吹閿曞倸绠ラ悗锝庡亝缁?,"codeTime":120}',
              );
            }
            if (url.contains('reAuthSubmit.do')) {
              reauthSubmitCalls++;
              authCodeReady = true;
              return _plainResponse(
                url,
                data: <String, dynamic>{'code': 'reAuth_success'},
              );
            }
            if (url.contains('/protocol/openid-connect/token')) {
              return _plainResponse(
                url,
                data: <String, dynamic>{'access_token': 'access-token'},
              );
            }
            if (url ==
                'https://courses.guet.edu.cn/api/login?login=access_token') {
              return _plainResponse(
                url,
                data: <String, dynamic>{'ok': true},
                headers: <String, List<String>>{
                  'x-session-id': <String>['session-id'],
                },
              );
            }
            throw StateError('Unexpected request: $method $url');
          };

      final result = await TCLoginApi.login(
        'user',
        'password',
        mfaPromptProvider: (context) async {
          providerCalls++;
          expect(context.mobileHint, '138****0000');
          expect(context.tip, isNotEmpty);
          expect(context.codeTimeSeconds, 120);
          resendResult = await context.resendCode();
          expect(resendResult?['codeTimeSeconds'], 120);
          return '123456';
        },
      );

      expect(result['ok'], isTrue, reason: result.toString());
      expect(result['sessionId'], 'session-id');
      expect(providerCalls, 1);
      expect(reauthViewCalls, 1);
      expect(dynamicCodeCalls, 2);
      expect(reauthSubmitCalls, 1);
      expect(resendResult?['res'], 'success');
    });

    test(
      'reAuthSubmit starts with empty service and retries original service once',
      () async {
        const service =
            'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
        final reauthEntryUrl =
            'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
        var authCodeReady = false;
        var reauthSubmitCalls = 0;
        final submittedServices = <String>[];

        ApiService.debugSendRequestOverride =
            (
              url, {
              required method,
              params,
              headers,
              body,
              responseType = ResponseType.json,
              allowRedirects = true,
              skipCredentialValidation = false,
            }) async {
              if (url.contains(
                '/auth/realms/guet/protocol/openid-connect/auth',
              )) {
                if (authCodeReady) {
                  return _plainResponse(
                    'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
                  );
                }
                return _plainResponse(
                  'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
                );
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'GET') {
                return _plainResponse(
                  url,
                  data:
                      '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
                );
              }
              if (_isTronclassBfpUrl(url)) {
                return _plainResponse(url, data: '{}');
              }
              if (url.contains('checkNeedCaptcha.htl')) {
                return _plainResponse(url, data: '{"isNeed":false}');
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'POST') {
                return _plainResponse(
                  reauthEntryUrl,
                  statusCode: 401,
                  data:
                      '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
                );
              }
              if (url.contains('getDynamicCodeByReauth.do')) {
                return _plainResponse(
                  url,
                  data:
                      '{"res":"success","mobile":"138****0000","returnMessage":"婵°倗濮撮惌渚€鎯佹径鎰剺濞达絿顭堥崵鎺楁煕濞嗘劕鐏撮柍?}',
                );
              }
              if (url.contains('reAuthSubmit.do')) {
                reauthSubmitCalls++;
                submittedServices.add((body as Map)['service'].toString());
                if (reauthSubmitCalls == 1) {
                  return _plainResponse(
                    url,
                    data: <String, dynamic>{
                      'code': 'reAuth_failed',
                      'msg': 'service session invalid',
                    },
                  );
                }
                authCodeReady = true;
                return _plainResponse(
                  url,
                  data: <String, dynamic>{'code': 'reAuth_success'},
                );
              }
              if (url.contains('/protocol/openid-connect/token')) {
                return _plainResponse(
                  url,
                  data: <String, dynamic>{'access_token': 'access-token'},
                );
              }
              if (url ==
                  'https://courses.guet.edu.cn/api/login?login=access_token') {
                return _plainResponse(
                  url,
                  data: <String, dynamic>{'ok': true},
                  headers: <String, List<String>>{
                    'x-session-id': <String>['session-id'],
                  },
                );
              }
              throw StateError('Unexpected request: $method $url');
            };

        final result = await TCLoginApi.login(
          'user',
          'password',
          mfaCodeProvider: (_, _) async => '123456',
        );

        expect(result['ok'], isTrue, reason: result.toString());
        expect(result['sessionId'], 'session-id');
        expect(reauthSubmitCalls, 2);
        expect(submittedServices, <String>['', service]);
      },
    );

    test(
      'continueMfaChallenge does not send dynamicCode when reauth prime falls back to login',
      () async {
        const service =
            'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
        final reauthEntryUrl =
            'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
        final loginRedirectUrl =
            'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}';
        var dynamicCodeCalls = 0;

        ApiService.debugSendRequestOverride =
            (
              url, {
              required method,
              params,
              headers,
              body,
              responseType = ResponseType.json,
              allowRedirects = true,
              skipCredentialValidation = false,
            }) async {
              if (url == reauthEntryUrl && method == 'GET') {
                return _plainResponse(
                  reauthEntryUrl,
                  statusCode: 302,
                  headers: <String, List<String>>{
                    'location': <String>[loginRedirectUrl],
                  },
                );
              }
              if (url.contains(
                '/auth/realms/guet/protocol/openid-connect/auth',
              )) {
                return _plainResponse(
                  'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
                );
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'GET') {
                return _plainResponse(
                  url,
                  data:
                      '<html><form id="casLoginForm"><input name="execution" value="e1s1" /><input name="pwdEncryptSalt" value="1234567890abcdef" /></form></html>',
                );
              }
              if (_isTronclassBfpUrl(url)) {
                return _plainResponse(url, data: '{}');
              }
              if (url.contains('checkNeedCaptcha.htl')) {
                return _plainResponse(url, data: '{"isNeed":false}');
              }
              if (url == 'https://cas.guet.edu.cn/authserver/login' &&
                  method == 'POST') {
                return _plainResponse(
                  reauthEntryUrl,
                  statusCode: 401,
                  data:
                      '<html><form action="/authserver/reAuthCheck/reAuthSubmit.do"><input name="dynamicCode" value="" /></form></html>',
                );
              }
              if (url.contains('getDynamicCodeByReauth.do')) {
                dynamicCodeCalls++;
                return _plainResponse(
                  url,
                  data:
                      '{"data":"https://cas.guet.edu.cn/authserver/login","errCode":"206302","message":"闁荤姴娲弨閬嶆儑閹殿喗鎯ラ柛娑卞枟椤ρ囨⒑閹绘帞孝闁伙綁绠栧畷?,"success":false}',
                );
              }
              throw StateError('Unexpected request: $method $url');
            };

        final result = await TCLoginApi.continueMfaChallenge(
          'user',
          password: 'password',
          captchaProvider: (_) async => '',
          mfaCodeProvider: (_, _) async => '123456',
          reauthEntryUrl: reauthEntryUrl,
          service: service,
        );

        expect(dynamicCodeCalls, 0);
        expect(result['mfaSessionInvalid'], isTrue);
        expect(result['verificationStage'], tronclassVerificationStageMfa);
      },
    );
  });
}
