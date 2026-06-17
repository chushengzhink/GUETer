import '../tronclass_guet_constants.dart';

enum TronclassLoginRequestStage {
  identityAuth,
  casLoginPage,
  casFingerprintReport,
  casCaptchaCheck,
  casCaptchaImage,
  casLoginSubmit,
  casReauthView,
  casDynamicCode,
  casReauthSubmit,
  identityToken,
  portalAccessTokenLogin,
}

class TronclassLoginRequestProfile {
  const TronclassLoginRequestProfile({
    required this.profileName,
    required this.userAgent,
  });

  final String profileName;
  final String userAgent;
}

class TronclassLoginHeaders {
  TronclassLoginHeaders._();

  static const profile = TronclassLoginRequestProfile(
    profileName: 'tronclass-login-wechat-h5',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 micromessenger',
  );

  static Map<String, String> baseHeaders(Map<String, String>? explicitHeaders) {
    return _mergeExplicit({
      'User-Agent': profile.userAgent,
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }, explicitHeaders);
  }

  static Map<String, String> build({
    required TronclassLoginRequestStage stage,
    String? url,
    String? service,
    Map<String, String>? explicitHeaders,
  }) {
    final headers = <String, String>{
      'User-Agent': profile.userAgent,
      'Accept-Language': 'zh-CN,zh;q=0.9',
    };

    switch (stage) {
      case TronclassLoginRequestStage.identityAuth:
        headers.addAll({
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': '${TronclassGuetConstants.mobileBaseUrl}/',
        });
        break;
      case TronclassLoginRequestStage.casLoginPage:
        headers.addAll({
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': _casReferer(service),
        });
        break;
      case TronclassLoginRequestStage.casFingerprintReport:
        headers.addAll({
          'Accept': 'application/json, text/plain, */*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': _casReferer(service),
        });
        break;
      case TronclassLoginRequestStage.casCaptchaCheck:
        headers.addAll({
          'Accept': 'application/json, text/plain, */*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': _casReferer(service),
        });
        break;
      case TronclassLoginRequestStage.casCaptchaImage:
        headers.addAll({
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          'Referer': _casReferer(service),
        });
        break;
      case TronclassLoginRequestStage.casLoginSubmit:
        headers.addAll({
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Origin': TronclassGuetConstants.casBaseUrl,
          'Referer': _casReferer(service),
          'content-type': 'application/x-www-form-urlencoded',
        });
        break;
      case TronclassLoginRequestStage.casReauthView:
        headers.addAll({
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': _casReferer(service),
        });
        break;
      case TronclassLoginRequestStage.casDynamicCode:
        headers.addAll({
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Origin': TronclassGuetConstants.casBaseUrl,
          'Referer': _reauthReferer(service),
          'X-Requested-With': 'XMLHttpRequest',
          'content-type': 'application/x-www-form-urlencoded',
        });
        break;
      case TronclassLoginRequestStage.casReauthSubmit:
        headers.addAll({
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Origin': TronclassGuetConstants.casBaseUrl,
          'Referer': _reauthReferer(service),
          'X-Requested-With': 'XMLHttpRequest',
          'content-type': 'application/x-www-form-urlencoded',
        });
        break;
      case TronclassLoginRequestStage.identityToken:
        headers.addAll({
          'Accept': 'application/json, text/plain, */*',
          'Origin': TronclassGuetConstants.identityBaseUrl,
          'Referer': '${TronclassGuetConstants.mobileBaseUrl}/',
          'content-type': 'application/x-www-form-urlencoded',
        });
        break;
      case TronclassLoginRequestStage.portalAccessTokenLogin:
        headers.addAll({
          'Accept': 'application/json, text/plain, */*',
          'Origin': TronclassGuetConstants.portalBaseUrl,
          'Referer': '${TronclassGuetConstants.portalBaseUrl}/',
        });
        break;
    }

    return _mergeExplicit(headers, explicitHeaders);
  }

  static TronclassLoginRequestStage stageForUrl(
    String url, {
    String method = 'GET',
  }) {
    final lowerUrl = url.toLowerCase();
    final normalizedMethod = method.toUpperCase();
    if (lowerUrl.contains('/authserver/reauthcheck/reauthloginview.do')) {
      return TronclassLoginRequestStage.casReauthView;
    }
    if (lowerUrl.contains(
      '/authserver/dynamiccode/getdynamiccodebyreauth.do',
    )) {
      return TronclassLoginRequestStage.casDynamicCode;
    }
    if (lowerUrl.contains('/authserver/reauthcheck/reauthsubmit.do')) {
      return TronclassLoginRequestStage.casReauthSubmit;
    }
    if (lowerUrl.contains('/authserver/bfp/info')) {
      return TronclassLoginRequestStage.casFingerprintReport;
    }
    if (lowerUrl.contains('/authserver/checkneedcaptcha.htl')) {
      return TronclassLoginRequestStage.casCaptchaCheck;
    }
    if (lowerUrl.contains('/authserver/getcaptcha.htl')) {
      return TronclassLoginRequestStage.casCaptchaImage;
    }
    if (lowerUrl.contains('/authserver/login')) {
      return normalizedMethod == 'POST'
          ? TronclassLoginRequestStage.casLoginSubmit
          : TronclassLoginRequestStage.casLoginPage;
    }
    if (lowerUrl.contains('/protocol/openid-connect/token')) {
      return TronclassLoginRequestStage.identityToken;
    }
    if (lowerUrl.contains('/api/login?login=access_token')) {
      return TronclassLoginRequestStage.portalAccessTokenLogin;
    }
    return TronclassLoginRequestStage.identityAuth;
  }

  static String diagnosticSummary({
    required TronclassLoginRequestStage stage,
    required int headerCount,
    int? statusCode,
  }) {
    return 'stage=${stage.name} profileName=${profile.profileName} '
        'headerCount=$headerCount statusCode=${statusCode ?? '-'}';
  }

  static String _casReferer(String? service) {
    if (service == null || service.trim().isEmpty) {
      return TronclassGuetConstants.casLoginUrl;
    }
    return '${TronclassGuetConstants.casLoginUrl}?service=${Uri.encodeQueryComponent(service)}';
  }

  static String _reauthReferer(String? service) {
    if (service == null || service.trim().isEmpty) {
      return TronclassGuetConstants.reauthLoginViewUrl;
    }
    return '${TronclassGuetConstants.reauthLoginViewUrl}?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
  }

  static Map<String, String> _mergeExplicit(
    Map<String, String> defaults,
    Map<String, String>? explicitHeaders,
  ) {
    final merged = <String, String>{...defaults};
    if (explicitHeaders == null || explicitHeaders.isEmpty) {
      return merged;
    }
    for (final entry in explicitHeaders.entries) {
      final existingKey = _findHeaderKey(merged, entry.key);
      if (existingKey != null) {
        merged.remove(existingKey);
      }
      merged[entry.key] = entry.value;
    }
    return merged;
  }

  static String? _findHeaderKey(Map<String, String> headers, String key) {
    final lowerKey = key.toLowerCase();
    for (final existing in headers.keys) {
      if (existing.toLowerCase() == lowerKey) {
        return existing;
      }
    }
    return null;
  }
}
