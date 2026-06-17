import 'package:course_helper/api/tronclass_login_request_profile.dart';
import 'package:course_helper/tronclass_guet_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login profile uses reference WeChat H5 user agent', () {
    final headers = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.identityAuth,
    );

    expect(
      headers['User-Agent'],
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 micromessenger',
    );
    expect(headers['Accept-Language'], 'zh-CN,zh;q=0.9');
    expect(headers['Referer'], '${TronclassGuetConstants.mobileBaseUrl}/');
  });

  test('CAS submit profile keeps form content type and CAS context', () {
    const service =
        'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';

    final headers = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.casLoginSubmit,
      service: service,
    );

    expect(headers['Origin'], TronclassGuetConstants.casBaseUrl);
    expect(
      headers['Referer'],
      '${TronclassGuetConstants.casLoginUrl}?service=${Uri.encodeQueryComponent(service)}',
    );
    expect(headers['content-type'], 'application/x-www-form-urlencoded');
    expect(headers['Accept'], contains('text/html'));
  });

  test('token and portal session profiles build expected origins', () {
    final tokenHeaders = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.identityToken,
    );
    final portalHeaders = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.portalAccessTokenLogin,
    );

    expect(tokenHeaders['Origin'], TronclassGuetConstants.identityBaseUrl);
    expect(tokenHeaders['Referer'], '${TronclassGuetConstants.mobileBaseUrl}/');
    expect(tokenHeaders['content-type'], 'application/x-www-form-urlencoded');
    expect(portalHeaders['Origin'], TronclassGuetConstants.portalBaseUrl);
    expect(
      portalHeaders['Referer'],
      '${TronclassGuetConstants.portalBaseUrl}/',
    );
    expect(portalHeaders['Accept'], 'application/json, text/plain, */*');
  });

  test('explicit auth headers are never overwritten', () {
    final headers = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.portalAccessTokenLogin,
      explicitHeaders: const {
        'Cookie': 'sid=1',
        'x-session-id': 'session-id',
        'Authorization': 'Bearer token',
        'content-type': 'application/custom',
      },
    );

    expect(headers['Cookie'], 'sid=1');
    expect(headers['x-session-id'], 'session-id');
    expect(headers['Authorization'], 'Bearer token');
    expect(headers['content-type'], 'application/custom');
    expect(headers['Origin'], TronclassGuetConstants.portalBaseUrl);
  });

  test('MFA profiles build reauth referer and form headers', () {
    const service =
        'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
    final reauthReferer =
        '${TronclassGuetConstants.reauthLoginViewUrl}?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';

    final viewHeaders = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.casReauthView,
      service: service,
    );
    final dynamicHeaders = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.casDynamicCode,
      service: service,
    );
    final submitHeaders = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.casReauthSubmit,
      service: service,
    );

    expect(viewHeaders['Referer'], contains('/authserver/login?service='));
    expect(dynamicHeaders['Origin'], TronclassGuetConstants.casBaseUrl);
    expect(dynamicHeaders['Referer'], reauthReferer);
    expect(dynamicHeaders['X-Requested-With'], 'XMLHttpRequest');
    expect(dynamicHeaders['content-type'], 'application/x-www-form-urlencoded');
    expect(submitHeaders['Origin'], TronclassGuetConstants.casBaseUrl);
    expect(submitHeaders['Referer'], reauthReferer);
    expect(submitHeaders['content-type'], 'application/x-www-form-urlencoded');
  });

  test('fingerprint profile uses CAS referer and ajax headers', () {
    const service =
        'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state';
    final headers = TronclassLoginHeaders.build(
      stage: TronclassLoginRequestStage.casFingerprintReport,
      service: service,
    );

    expect(headers['Accept'], 'application/json, text/plain, */*');
    expect(headers['X-Requested-With'], 'XMLHttpRequest');
    expect(
      headers['Referer'],
      '${TronclassGuetConstants.casLoginUrl}?service=${Uri.encodeQueryComponent(service)}',
    );
  });

  test('stageForUrl detects login stages', () {
    expect(
      TronclassLoginHeaders.stageForUrl(
        TronclassGuetConstants.casLoginUrl,
        method: 'POST',
      ),
      TronclassLoginRequestStage.casLoginSubmit,
    );
    expect(
      TronclassLoginHeaders.stageForUrl(
        TronclassGuetConstants.casCheckNeedCaptchaUrl,
      ),
      TronclassLoginRequestStage.casCaptchaCheck,
    );
    expect(
      TronclassLoginHeaders.stageForUrl(
        TronclassGuetConstants.portalAccessTokenLoginUrl,
        method: 'POST',
      ),
      TronclassLoginRequestStage.portalAccessTokenLogin,
    );
    expect(
      TronclassLoginHeaders.stageForUrl(
        TronclassGuetConstants.reauthLoginViewUrl,
      ),
      TronclassLoginRequestStage.casReauthView,
    );
    expect(
      TronclassLoginHeaders.stageForUrl(TronclassGuetConstants.dynamicCodeUrl),
      TronclassLoginRequestStage.casDynamicCode,
    );
    expect(
      TronclassLoginHeaders.stageForUrl(
        '${TronclassGuetConstants.casBaseUrl}/authserver/bfp/info',
      ),
      TronclassLoginRequestStage.casFingerprintReport,
    );
    expect(
      TronclassLoginHeaders.stageForUrl(TronclassGuetConstants.reauthSubmitUrl),
      TronclassLoginRequestStage.casReauthSubmit,
    );
  });
}
