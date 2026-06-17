import '../platform.dart';

enum PlatformFunctionalProfileKind {
  chaoxingMobileLearn,
  rainClassroomWeb,
  tronclassWebView,
  ketangpaiWebApi,
}

enum PlatformFunctionalContentKind { form, json, plain, multipart, unknown }

class PlatformFunctionalRequestContext {
  const PlatformFunctionalRequestContext({
    required this.platform,
    required this.url,
    required this.method,
    required this.contentKind,
    this.baseUrl,
    this.referer,
  });

  final PlatformType platform;
  final String url;
  final String method;
  final PlatformFunctionalContentKind contentKind;
  final String? baseUrl;
  final String? referer;

  Uri? get requestUri => Uri.tryParse(url);

  String? get origin {
    final uri = requestUri;
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return '${uri.scheme}://${uri.host}';
    }
    final base = baseUrl == null ? null : Uri.tryParse(baseUrl!);
    if (base != null && base.hasScheme && base.host.isNotEmpty) {
      return '${base.scheme}://${base.host}';
    }
    return null;
  }

  String? get effectiveReferer {
    if (referer != null && referer!.trim().isNotEmpty) {
      return referer!.trim();
    }
    final resolvedOrigin = origin;
    return resolvedOrigin == null ? null : '$resolvedOrigin/';
  }

  static PlatformFunctionalContentKind inferContentKind({
    required String method,
    required dynamic body,
    required Map<String, String>? headers,
  }) {
    final contentType = _headerValue(headers, 'content-type')?.toLowerCase();
    if (contentType != null) {
      if (contentType.contains('multipart/form-data')) {
        return PlatformFunctionalContentKind.multipart;
      }
      if (contentType.contains('application/json')) {
        return PlatformFunctionalContentKind.json;
      }
      if (contentType.contains('x-www-form-urlencoded')) {
        return PlatformFunctionalContentKind.form;
      }
      if (contentType.startsWith('text/')) {
        return PlatformFunctionalContentKind.plain;
      }
    }
    if (body is Map || body is List) return PlatformFunctionalContentKind.json;
    if (body is String) return PlatformFunctionalContentKind.plain;
    if (method.toUpperCase() == 'POST' ||
        method.toUpperCase() == 'PUT' ||
        method.toUpperCase() == 'PATCH') {
      return PlatformFunctionalContentKind.json;
    }
    return PlatformFunctionalContentKind.unknown;
  }

  static String? _headerValue(Map<String, String>? headers, String key) {
    if (headers == null) return null;
    final lowerKey = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }
    return null;
  }
}

class PlatformFunctionalRequestProfile {
  const PlatformFunctionalRequestProfile({
    required this.kind,
    required this.platformLabel,
    required this.profileName,
    required this.headers,
  });

  final PlatformFunctionalProfileKind kind;
  final String platformLabel;
  final String profileName;
  final Map<String, String> headers;

  Map<String, String> buildHeaders(PlatformFunctionalRequestContext context) {
    final merged = <String, String>{...headers};
    switch (kind) {
      case PlatformFunctionalProfileKind.chaoxingMobileLearn:
        _setHeader(merged, 'Origin', context.origin);
        _setHeader(merged, 'Referer', context.effectiveReferer);
        _setContentType(merged, context);
        break;
      case PlatformFunctionalProfileKind.rainClassroomWeb:
        _setHeader(merged, 'Origin', context.origin);
        _setHeader(merged, 'Referer', context.effectiveReferer);
        _setContentType(merged, context);
        break;
      case PlatformFunctionalProfileKind.tronclassWebView:
        _setContentType(merged, context);
        break;
      case PlatformFunctionalProfileKind.ketangpaiWebApi:
        _setHeader(merged, 'Origin', _ketangpaiOriginFor(context));
        _setHeader(merged, 'Referer', _ketangpaiRefererFor(context));
        _setContentType(merged, context);
        break;
    }
    return merged;
  }

  Map<String, String> mergeHeaders(
    Map<String, String>? explicitHeaders, {
    required PlatformFunctionalRequestContext context,
  }) {
    final merged = buildHeaders(context);
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

  static void _setHeader(
    Map<String, String> headers,
    String key,
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) return;
    final existingKey = _findHeaderKey(headers, key);
    if (existingKey != null) {
      headers.remove(existingKey);
    }
    headers[key] = value;
  }

  static void _setContentType(
    Map<String, String> headers,
    PlatformFunctionalRequestContext context,
  ) {
    if (context.contentKind == PlatformFunctionalContentKind.multipart) {
      final existingKey = _findHeaderKey(headers, 'content-type');
      if (existingKey != null) headers.remove(existingKey);
      return;
    }
    if (context.method.toUpperCase() == 'GET') return;
    _setHeader(headers, 'content-type', _contentTypeFor(context));
  }

  static String _contentTypeFor(PlatformFunctionalRequestContext context) {
    switch (context.contentKind) {
      case PlatformFunctionalContentKind.form:
        return 'application/x-www-form-urlencoded; charset=UTF-8';
      case PlatformFunctionalContentKind.json:
      case PlatformFunctionalContentKind.unknown:
        return 'application/json;charset=UTF-8';
      case PlatformFunctionalContentKind.plain:
        return 'text/plain; charset=UTF-8';
      case PlatformFunctionalContentKind.multipart:
        return 'multipart/form-data';
    }
  }

  static String _ketangpaiOriginFor(PlatformFunctionalRequestContext context) {
    final origin = context.origin;
    if (origin != null && origin.contains('openapiv5.ketangpai.com')) {
      return 'https://w.ketangpai.com';
    }
    return origin ?? 'https://w.ketangpai.com';
  }

  static String _ketangpaiRefererFor(PlatformFunctionalRequestContext context) {
    final origin = context.origin;
    if (origin != null && origin.contains('openapiv5.ketangpai.com')) {
      return 'https://w.ketangpai.com/';
    }
    return context.effectiveReferer ?? 'https://w.ketangpai.com/';
  }
}

class PlatformFunctionalRequestProfiles {
  PlatformFunctionalRequestProfiles._();

  static const String _androidWebViewUa =
      'Mozilla/5.0 (Linux; Android 15; PJD110 Build/AP3A.240617.008; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.135 Mobile Safari/537.36 TronClass/common';
  static const String _androidChromeUa =
      'Mozilla/5.0 (Linux; Android 16; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36';
  static const String _chaoxingMobileUa =
      'Dalvik/2.1.0 (Linux; U; Android 16; Pixel 9 Pro Build/BP4A.260205.002)';

  static const Map<String, String> _androidClientHints = {
    'sec-ch-ua-platform': '"Android"',
    'sec-ch-ua':
        '"Chromium";v="134", "Not:A-Brand";v="24", "Android WebView";v="134"',
    'sec-ch-ua-mobile': '?1',
    'sec-fetch-site': 'cross-site',
    'sec-fetch-mode': 'cors',
    'sec-fetch-dest': 'empty',
  };

  static PlatformFunctionalRequestProfile chaoxingMobileLearn() {
    return const PlatformFunctionalRequestProfile(
      kind: PlatformFunctionalProfileKind.chaoxingMobileLearn,
      platformLabel: 'chaoxing',
      profileName: 'chaoxing-functional-mobilelearn',
      headers: {
        'User-Agent': _chaoxingMobileUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Origin': 'https://mobilelearn.chaoxing.com',
        'Referer': 'https://mobilelearn.chaoxing.com/',
        'X-Requested-With': 'com.chaoxing.mobile',
      },
    );
  }

  static PlatformFunctionalRequestProfile rainClassroomWeb() {
    return const PlatformFunctionalRequestProfile(
      kind: PlatformFunctionalProfileKind.rainClassroomWeb,
      platformLabel: 'rainclassroom',
      profileName: 'rainclassroom-functional-web',
      headers: {
        'User-Agent': _androidChromeUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'X-Requested-With': 'XMLHttpRequest',
        'x-client': 'web',
        'xt-agent': 'web',
        'xtbz': 'ykt',
        ..._androidClientHints,
      },
    );
  }

  static PlatformFunctionalRequestProfile tronclassWebView() {
    return const PlatformFunctionalRequestProfile(
      kind: PlatformFunctionalProfileKind.tronclassWebView,
      platformLabel: 'tronclass',
      profileName: 'tronclass-functional-webview',
      headers: {
        'User-Agent': _androidWebViewUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-Hans',
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': 'http://localhost',
        'Referer': 'http://localhost/',
        'priority': 'u=1, i',
        ..._androidClientHints,
      },
    );
  }

  static PlatformFunctionalRequestProfile ketangpaiWebApi() {
    return const PlatformFunctionalRequestProfile(
      kind: PlatformFunctionalProfileKind.ketangpaiWebApi,
      platformLabel: 'ketangpai',
      profileName: 'ketangpai-functional-webapi',
      headers: {
        'User-Agent': _androidChromeUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': 'https://w.ketangpai.com',
        'Referer': 'https://w.ketangpai.com/',
        'priority': 'u=1, i',
        ..._androidClientHints,
      },
    );
  }

  static PlatformFunctionalRequestProfile forPlatform(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return chaoxingMobileLearn();
      case PlatformType.rainClassroom:
        return rainClassroomWeb();
      case PlatformType.tronclass:
        return tronclassWebView();
      case PlatformType.ketangpai:
        return ketangpaiWebApi();
      case PlatformType.weizhuojiao:
        return rainClassroomWeb();
    }
  }

  static String diagnosticSummary(PlatformType platform) {
    final profile = forPlatform(platform);
    return '${profile.platformLabel}: ${profile.profileName} / headers=${profile.headers.length}';
  }

  static String diagnosticDetails(PlatformType platform) {
    final profile = forPlatform(platform);
    final headers = profile.headers.keys.toList()..sort();
    return '${profile.platformLabel}: ${profile.profileName} '
        'kind=${profile.kind.name} headers=${headers.join(",")}';
  }
}
