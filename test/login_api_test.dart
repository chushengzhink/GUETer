import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/login.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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

  group('Tronclass login next action', () {
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

    test('plain failures do not enter MFA resend dialog flow', () {
      final result = {'ok': false, 'message': 'send failed'};

      expect(shouldPromptTronclassMfaSendFailureDialog(result), isFalse);
      expect(canResumeTronclassMfaChallenge(result), isFalse);
    });

    test('classifies 206302 and login redirects as MFA session invalid', () {
      expect(
        isTronclassMfaSessionInvalidResponse({
          'errCode': '206302',
          'message': '请求超时重定向',
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
        isTronclassMfaSessionInvalidResponse({'message': '服务繁忙，请稍后重试'}),
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
                      '{"data":"https://cas.guet.edu.cn/authserver/login","errCode":"206302","message":"请求超时重定向","success":false}',
                );
              }
              throw StateError('Unexpected request: $method $url');
            };

        final result = await TCLoginApi.continueMfaChallenge(
          'user',
          password: 'password',
          captchaProvider: (_) async => '',
          mfaCodeProvider: (_, __) async => '123456',
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
