import 'package:course_helper/pages/tronclass_web_login.dart';
import 'package:course_helper/services/tronclass_qq_auth_callback_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tronclass QQ login bridge', () {
    test('resolves OAuth return strategy conservatively', () {
      expect(
        resolveQqLoginStrategy(appLinkVerified: false),
        QqLoginStrategy.browserReturnRequired,
      );
      expect(
        resolveQqLoginStrategy(appLinkVerified: true),
        QqLoginStrategy.verifiedHttpsSupported,
      );
      expect(
        resolveQqLoginStrategy(
          appLinkVerified: false,
          nativeRedirectSupported: true,
        ),
        QqLoginStrategy.nativeRedirectSupported,
      );
    });

    test('resolves redirect capability conservatively', () {
      expect(
        resolveQqRedirectCapability(
          customRedirectAccepted: true,
          appLinkVerified: false,
        ),
        QqRedirectCapability.customRedirectAccepted,
      );
      expect(
        resolveQqRedirectCapability(
          customRedirectAccepted: false,
          appLinkVerified: true,
        ),
        QqRedirectCapability.verifiedAppLink,
      );
      expect(
        resolveQqRedirectCapability(
          customRedirectAccepted: false,
          appLinkVerified: false,
        ),
        QqRedirectCapability.browserRecoveryOnly,
      );
    });

    test('classifies custom redirect probe responses', () {
      expect(
        classifyCustomRedirectAccepted(
          statusCode: 302,
          responseUri:
              'https://identity.guet.edu.cn/auth/realms/guet/protocol/openid-connect/auth',
          location: 'https://cas.guet.edu.cn/authserver/login?service=x',
          body: '',
        ),
        isTrue,
      );
      expect(
        classifyCustomRedirectAccepted(
          statusCode: 400,
          responseUri:
              'https://identity.guet.edu.cn/auth/realms/guet/protocol/openid-connect/auth',
          location: null,
          body: 'invalid_redirect_uri',
        ),
        isFalse,
      );
    });

    test('prefers Chrome for QQ OAuth browser container', () {
      final browser = resolvePreferredQqOAuthBrowser(const [
        QqOAuthBrowserChoice(
          packageName: 'com.brave.browser',
          displayName: 'Brave',
          isInstalled: true,
          isRecommended: false,
        ),
        QqOAuthBrowserChoice(
          packageName: 'com.android.chrome',
          displayName: 'Chrome',
          isInstalled: true,
          isRecommended: true,
        ),
      ]);

      expect(browser.packageName, 'com.android.chrome');
      expect(browser.displayName, 'Chrome');
      expect(browser.isRecommended, isTrue);
    });

    test('uses default browser when Chrome is unavailable', () {
      final browser = resolvePreferredQqOAuthBrowser(const [
        QqOAuthBrowserChoice(
          packageName: 'com.brave.browser',
          displayName: 'Brave',
          isInstalled: true,
          isRecommended: false,
          isDefault: true,
        ),
      ]);

      expect(browser.packageName, 'com.brave.browser');
      expect(browser.isDefault, isTrue);
      expect(browser.displayName, 'Brave');
    });

    test(
      'uses first installed browser when Chrome and default are unavailable',
      () {
        final browser = resolvePreferredQqOAuthBrowser(const [
          QqOAuthBrowserChoice(
            packageName: 'com.tencent.mtt',
            displayName: 'QQ 浏览器',
            isInstalled: true,
            isRecommended: false,
          ),
          QqOAuthBrowserChoice(
            packageName: 'com.brave.browser',
            displayName: 'Brave',
            isInstalled: true,
            isRecommended: false,
          ),
        ]);

        expect(browser.packageName, 'com.tencent.mtt');
        expect(browser.displayName, 'QQ 浏览器');
        expect(browser.isRecommended, isFalse);
      },
    );
    test('recognizes CAS and QQ authorization urls from mobile flow', () {
      expect(
        isTronclassCasQqLoginUrl(
          'https://cas.guet.edu.cn/authserver/combinedLogin.do?type=qq',
        ),
        isTrue,
      );
      expect(
        isTronclassCasQqLoginUrl(
          'https://graph.qq.com/oauth2.0/authorize?client_id=102146781&redirect_uri=https%3A%2F%2Fcas.guet.edu.cn%2Fauthserver%2Fcallback&response_type=code&state=s',
        ),
        isTrue,
      );
      expect(
        isTronclassCasQqLoginUrl(
          'https://xui.ptlogin2.qq.com/cgi-bin/xlogin?client_id=102146781',
        ),
        isTrue,
      );
      expect(
        isTronclassCasQqLoginUrl(
          'https://cas.guet.edu.cn/authserver/callback?code=qq-code&state=s',
        ),
        isTrue,
      );
    });

    test('builds external QQ bootstrap urls from Tronclass OAuth only', () {
      final uris = buildTronclassQqExternalBootstrapUris();
      expect(uris, hasLength(1));
      expect(uris.first.host, 'identity.guet.edu.cn');
      expect(uris.first.path, '/auth/realms/guet/protocol/openid-connect/auth');
      expect(uris.first.queryParameters['client_id'], 'TronClassH5');
      expect(uris.first.queryParameters['redirect_uri'], contains('mobile'));

      final customUris = buildTronclassQqExternalBootstrapUris(
        redirectUriOverride: tronclassQqCustomRedirectUri,
      );
      expect(customUris, hasLength(1));
      expect(
        customUris.first.queryParameters['redirect_uri'],
        tronclassQqCustomRedirectUri,
      );
    });

    test('recognizes QQ client schemes for external launch', () {
      expect(
        isTronclassExternalQqScheme('mqqapi://forward/url?src_type=web'),
        isTrue,
      );
      expect(
        isTronclassExternalQqScheme('mqq://im/chat?chat_type=wpa'),
        isTrue,
      );
      expect(
        isTronclassExternalQqScheme('tencent://message/?uin=10000'),
        isTrue,
      );
      expect(
        isTronclassExternalQqScheme('wtloginmqq://ptlogin/qlogin?q=1'),
        isTrue,
      );
      expect(
        isTronclassExternalQqScheme(
          'https://graph.qq.com/oauth2.0/authorize?client_id=102146781',
        ),
        isFalse,
      );
      expect(isTronclassExternalQqScheme('not a url'), isFalse);
    });

    test('recognizes QR authorize page and builds xlogin URL', () {
      const authorizeUrl =
          'https://graph.qq.com/oauth2.0/authorize?client_id=102146781&redirect_uri=https%3A%2F%2Fcas.guet.edu.cn%2Fauthserver%2Fcallback&response_type=code&state=qq-state&scope=get_user_info';
      final xlogin = buildQqClientXloginUrl(authorizeUrl);
      expect(xlogin, isNotNull);
      expect(xlogin!.host, 'xui.ptlogin2.qq.com');
      expect(xlogin.path, '/cgi-bin/xlogin');
      expect(xlogin.queryParameters['pt_3rd_aid'], '102146781');
      expect(xlogin.queryParameters['client_id'], '102146781');
      expect(
        xlogin.queryParameters['redirect_uri'],
        'https://cas.guet.edu.cn/authserver/callback',
      );
      expect(xlogin.queryParameters['state'], 'qq-state');
      expect(xlogin.queryParameters['style'], '35');
      expect(xlogin.queryParameters['loginty'], '3');

      expect(
        isQqQrAuthorizePage(
          'https://graph.qq.com/oauth2.0/show?client_id=102146781&state=qq-state',
        ),
        isTrue,
      );
      expect(
        buildQqClientXloginUrl('https://graph.qq.com/oauth2.0/show'),
        isNull,
      );
    });

    test(
      'recognizes QQ jump and separates CAS QQ code from Tronclass code',
      () {
        expect(
          isQqJumpUrl(
            'https://ssl.ptlogin2.qq.com/jump?keyindex=19&clientuin=10000',
          ),
          isTrue,
        );
        expect(
          isQqJumpUrl('https://xui.ptlogin2.qq.com/cgi-bin/xlogin'),
          isFalse,
        );

        const casCallback =
            'https://cas.guet.edu.cn/authserver/callback?code=qq-code&state=s';
        expect(extractCasQqCode(casCallback), 'qq-code');
        expect(extractTronclassExactAuthCodeFromUrl(casCallback), isNull);
      },
    );

    test('tracks external QQ launch and replay urls', () {
      final state = QqExternalLaunchState();
      const authorizeUrl =
          'https://graph.qq.com/oauth2.0/authorize?client_id=102146781&redirect_uri=https%3A%2F%2Fcas.guet.edu.cn%2Fauthserver%2Fcallback&response_type=code&state=qq-state';
      const showUrl =
          'https://graph.qq.com/oauth2.0/show?client_id=102146781&redirect_uri=https%3A%2F%2Fcas.guet.edu.cn%2Fauthserver%2Fcallback&response_type=code&state=qq-state';
      const xloginUrl =
          'https://xui.ptlogin2.qq.com/cgi-bin/xlogin?client_id=102146781&state=qq-state';
      const schemeUrl = 'mqqapi://forward/url?src_type=web';

      expect(state.rememberAuthorizationUrl(authorizeUrl), isTrue);
      expect(state.rememberAuthorizationUrl(showUrl), isTrue);
      expect(state.rememberAuthorizationUrl(xloginUrl), isTrue);
      expect(state.shouldLaunchScheme(schemeUrl), isTrue);
      state.markLaunched(schemeUrl);
      expect(state.hasLaunch, isTrue);
      expect(state.shouldLaunchScheme(schemeUrl), isFalse);
      expect(state.nextReplayUrl(), xloginUrl);
      expect(state.nextReplayUrl(), xloginUrl);
      expect(state.nextReplayUrl(), isNull);

      state.clearLaunch();
      expect(state.hasLaunch, isFalse);
    });

    test('extracts only exact auth code query parameter', () {
      expect(
        extractTronclassExactAuthCodeFromUrl(
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
        ),
        'auth-code',
      );
      expect(
        extractTronclassExactAuthCodeFromUrl(
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/login?session_code=not-auth-code&client_id=TronclassH5',
        ),
        isNull,
      );
      expect(
        extractTronclassExactAuthCodeFromUrl(
          'https://cas.guet.edu.cn/authserver/oauth2.0/authorize?client_id=abc&state=state-only',
        ),
        isNull,
      );
      expect(
        extractTronclassExactAuthCodeFromUrl(
          'https://portal.guet.edu.cn/ywtbcallback?code=portal-code&state=s',
        ),
        isNull,
      );
    });

    test('detects portal callback that is not a Tronclass auth callback', () {
      expect(
        isTronclassPortalCallbackWithoutAuthCode(
          'https://portal.guet.edu.cn/ywtbcallback?code=portal-code&state=s',
        ),
        isTrue,
      );
      expect(
        isTronclassPortalCallbackWithoutAuthCode(
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=tronclass-code',
        ),
        isFalse,
      );
    });

    test('detects and consumes native deep link callbacks once', () {
      TronclassQqAuthCallbackBridge.resetForTests();
      const mobileCallback =
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code';
      const casCallback =
          'https://cas.guet.edu.cn/authserver/callback?code=qq-code&state=s';
      const portalCallback =
          'https://portal.guet.edu.cn/ywtbcallback?code=portal-code&state=s';
      const identityCallback =
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=s&code=identity-code';
      const customCallback =
          'gueter://tronclass-qq-callback?code=custom-code&state=s';

      expect(isTronclassQqAuthCallbackUrl(mobileCallback), isTrue);
      expect(isTronclassQqAuthCallbackUrl(casCallback), isTrue);
      expect(isTronclassQqAuthCallbackUrl(identityCallback), isTrue);
      expect(isTronclassQqAuthCallbackUrl(customCallback), isTrue);
      expect(isTronclassQqAuthCallbackUrl(portalCallback), isFalse);
      expect(
        isTronclassQqAuthCallbackUrl(
          'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/login?session_code=x',
        ),
        isFalse,
      );

      expect(
        TronclassQqAuthCallbackBridge.consumeCallbackUrl(mobileCallback),
        isFalse,
      );
      TronclassQqAuthCallbackBridge.beginQqLoginAttempt(
        browserPackage: 'com.android.chrome',
        launchSource: 'test',
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeCallbackUrl(mobileCallback),
        isTrue,
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeCallbackUrl(mobileCallback),
        isFalse,
      );
      TronclassQqAuthCallbackBridge.beginQqLoginAttempt(
        browserPackage: 'com.android.chrome',
        launchSource: 'test',
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeCallbackUrl(identityCallback),
        isTrue,
      );
      TronclassQqAuthCallbackBridge.beginQqLoginAttempt(
        browserPackage: 'com.android.chrome',
        launchSource: 'test',
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeCallbackUrl(customCallback),
        isTrue,
      );
    });

    test('classifies browser returned QQ callback urls', () {
      final mobile = parseQqReturnedBrowserUrl(
        'https://mobile.guet.edu.cn/cas-callback?_h5=true&session_state=s&code=auth-code',
      );
      expect(mobile.type, QqReturnedBrowserUrlType.tronclassCallback);
      expect(mobile.code, 'auth-code');
      expect(mobile.isFinalTronclassCallback, isTrue);

      final identity = parseQqReturnedBrowserUrl(
        'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=s&code=identity-code',
      );
      expect(identity.type, QqReturnedBrowserUrlType.identityEndpoint);
      expect(identity.code, 'identity-code');
      expect(identity.isFinalTronclassCallback, isTrue);

      final custom = parseQqReturnedBrowserUrl(
        'gueter://tronclass-qq-callback?state=s&code=custom-code',
      );
      expect(custom.type, QqReturnedBrowserUrlType.customSchemeCallback);
      expect(custom.code, 'custom-code');
      expect(custom.isFinalTronclassCallback, isTrue);

      final cas = parseQqReturnedBrowserUrl(
        'https://cas.guet.edu.cn/authserver/callback?code=qq-code&state=s',
      );
      expect(cas.type, QqReturnedBrowserUrlType.casQqCallback);
      expect(cas.isFinalTronclassCallback, isFalse);

      final portal = parseQqReturnedBrowserUrl(
        'https://portal.guet.edu.cn/ywtbcallback?code=portal-code&state=s',
      );
      expect(portal.type, QqReturnedBrowserUrlType.portalOnly);

      final portalMobileHome = parseQqReturnedBrowserUrl(
        'https://portal.guet.edu.cn/sopplus/_web/customized/portalWechat/app/mobile/index.jsp?_p=YXQ9MSZwPTEmbT1OJg__&iportal.uid=667500&iportal.signature=sig',
      );
      expect(portalMobileHome.type, QqReturnedBrowserUrlType.portalMobileHome);
      expect(portalMobileHome.hasCode, isFalse);
      expect(portalMobileHome.isFinalTronclassCallback, isFalse);

      final sessionCodeOnly = parseQqReturnedBrowserUrl(
        'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/login?session_code=not-auth-code',
      );
      expect(sessionCodeOnly.type, QqReturnedBrowserUrlType.invalid);
    });

    test('requires active QQ login attempt for final callbacks', () {
      TronclassQqAuthCallbackBridge.resetForTests();
      const callback =
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&session_state=s&code=fresh-code';

      expect(
        TronclassQqAuthCallbackBridge.canConsumeReturnedUrlForActiveAttempt(
          callback,
        ),
        isFalse,
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedUrl(callback),
        isFalse,
      );

      TronclassQqAuthCallbackBridge.beginQqLoginAttempt(
        browserPackage: 'com.android.chrome',
        launchSource: 'test',
      );
      expect(
        TronclassQqAuthCallbackBridge.canConsumeReturnedUrlForActiveAttempt(
          callback,
        ),
        isTrue,
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedUrl(callback),
        isTrue,
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedUrl(callback),
        isFalse,
      );

      TronclassQqAuthCallbackBridge.completeQqLoginAttempt();
      const replayCallback =
          'https://mobile.guet.edu.cn/cas-callback?_h5=true&session_state=s2&code=replay-code';
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedUrl(replayCallback),
        isFalse,
      );
    });

    test('extracts supported callback url from shared or clipboard text once', () {
      TronclassQqAuthCallbackBridge.resetForTests();
      const embedded =
          '授权完成：https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code，请复制给 GUETer';

      expect(
        extractFirstSupportedQqReturnedUrl(embedded),
        'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedText(embedded),
        isNull,
      );
      TronclassQqAuthCallbackBridge.beginQqLoginAttempt(
        browserPackage: 'com.android.chrome',
        launchSource: 'test',
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedText(embedded),
        'https://mobile.guet.edu.cn/cas-callback?_h5=true&code=auth-code',
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedText(embedded),
        isNull,
      );
      expect(
        TronclassQqAuthCallbackBridge.consumeReturnedText(
          'https://example.com/?code=wrong',
        ),
        isNull,
      );
      expect(
        extractFirstSupportedQqReturnedUrl(
          'done gueter://tronclass-qq-callback?code=custom-code&state=s',
        ),
        'gueter://tronclass-qq-callback?code=custom-code&state=s',
      );
      expect(
        extractFirstSupportedQqReturnedUrl(
          'browser https://portal.guet.edu.cn/sopplus/_web/customized/portalWechat/app/mobile/index.jsp?_p=x&iportal.uid=1&iportal.signature=sig',
        ),
        'https://portal.guet.edu.cn/sopplus/_web/customized/portalWechat/app/mobile/index.jsp?_p=x&iportal.uid=1&iportal.signature=sig',
      );
    });
  });
}
