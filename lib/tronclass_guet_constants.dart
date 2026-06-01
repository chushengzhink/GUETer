class TronclassGuetConstants {
  TronclassGuetConstants._();

  static const String portalBaseUrl = 'https://courses.guet.edu.cn';
  static const String casBaseUrl = 'https://cas.guet.edu.cn';
  static const String identityBaseUrl = 'https://identity.guet.edu.cn';
  static const String mobileBaseUrl = 'https://mobile.guet.edu.cn';

  static const String clientId = 'TronClassH5';
  static const String redirectUri = '$mobileBaseUrl/cas-callback?_h5=true';

  static const String identityAuthUrl =
      '$identityBaseUrl/auth/realms/guet/protocol/openid-connect/auth';
  static const String identityTokenUrl =
      '$identityBaseUrl/auth/realms/guet/protocol/openid-connect/token';

  static const String casLoginUrl = '$casBaseUrl/authserver/login';
  static const String casCheckNeedCaptchaUrl =
      '$casBaseUrl/authserver/checkNeedCaptcha.htl';
  static const String casCaptchaUrl = '$casBaseUrl/authserver/getCaptcha.htl';
  static const String reauthLoginViewUrl =
      '$casBaseUrl/authserver/reAuthCheck/reAuthLoginView.do';
  static const String reauthSubmitUrl =
      '$casBaseUrl/authserver/reAuthCheck/reAuthSubmit.do';
  static const String dynamicCodeUrl =
      '$casBaseUrl/authserver/dynamicCode/getDynamicCodeByReauth.do';

  static const String portalAccessTokenLoginUrl =
      '$portalBaseUrl/api/login?login=access_token';
  static const String portalSessionLoginUrl =
      '$portalBaseUrl/api/login?login=session_id';

  static final Uri portalBaseUri = Uri.parse('$portalBaseUrl/');
  static final Uri casBaseUri = Uri.parse('$casBaseUrl/');
  static final Uri identityBaseUri = Uri.parse('$identityBaseUrl/');
  static final Uri mobileBaseUri = Uri.parse('$mobileBaseUrl/');

  static final List<Uri> cookieProbeUris = <Uri>[
    portalBaseUri,
    casBaseUri,
    identityBaseUri,
    mobileBaseUri,
    Uri.parse(casLoginUrl),
    Uri.parse(reauthLoginViewUrl),
    Uri.parse(reauthSubmitUrl),
    Uri.parse(dynamicCodeUrl),
  ];

  static const String defaultCookieHost = 'courses.guet.edu.cn';
}
