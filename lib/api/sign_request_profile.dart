import 'dart:async';

import 'package:dio/dio.dart';

import '../platform.dart';

enum SignRequestProfileKind {
  chaoxingMobileLearn,
  rainClassroomCheckIn,
  tronclassRollcall,
  ketangpaiAttendance,
  weizhuojiaoWechat,
}

enum SignRequestContentKind { form, json, plain, multipart, unknown }

class SignRequestContext {
  const SignRequestContext({
    required this.platform,
    required this.url,
    required this.method,
    required this.contentKind,
    this.baseUrl,
    this.referer,
    this.csrfTokenHint,
  });

  final PlatformType platform;
  final String url;
  final String method;
  final String? baseUrl;
  final String? referer;
  final SignRequestContentKind contentKind;
  final String? csrfTokenHint;

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

  static SignRequestContentKind inferContentKind({
    required String method,
    required dynamic body,
    required Map<String, String>? headers,
  }) {
    final contentType = _headerValue(headers, 'content-type')?.toLowerCase();
    if (contentType != null) {
      if (contentType.contains('multipart/form-data')) {
        return SignRequestContentKind.multipart;
      }
      if (contentType.contains('application/json')) {
        return SignRequestContentKind.json;
      }
      if (contentType.contains('x-www-form-urlencoded')) {
        return SignRequestContentKind.form;
      }
      if (contentType.startsWith('text/')) {
        return SignRequestContentKind.plain;
      }
    }
    if (body is FormData) return SignRequestContentKind.multipart;
    if (body is Map || body is List) return SignRequestContentKind.json;
    if (body is String) return SignRequestContentKind.plain;
    if (method.toUpperCase() == 'POST' ||
        method.toUpperCase() == 'PUT' ||
        method.toUpperCase() == 'PATCH') {
      return SignRequestContentKind.form;
    }
    return SignRequestContentKind.unknown;
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

class SignRequestProfile {
  const SignRequestProfile({
    required this.kind,
    required this.platformLabel,
    required this.profileName,
    required this.headers,
  });

  final SignRequestProfileKind kind;
  final String platformLabel;
  final String profileName;
  final Map<String, String> headers;

  Map<String, String> buildHeaders(SignRequestContext context) {
    final merged = <String, String>{...headers};
    switch (kind) {
      case SignRequestProfileKind.chaoxingMobileLearn:
        _setHeader(
          merged,
          'Referer',
          _chaoxingRefererForContext(merged, context),
        );
        _setHeader(merged, 'Origin', context.origin);
        _setContentType(merged, context);
        break;
      case SignRequestProfileKind.rainClassroomCheckIn:
        _setHeader(merged, 'Referer', context.effectiveReferer);
        _setHeader(merged, 'Origin', context.origin);
        _setContentType(merged, context);
        break;
      case SignRequestProfileKind.tronclassRollcall:
        _setHeader(merged, 'Referer', context.effectiveReferer);
        _setHeader(merged, 'Origin', context.origin);
        _setContentType(merged, context);
        break;
      case SignRequestProfileKind.ketangpaiAttendance:
        final origin = context.origin ?? _originFromHeader(merged, 'Origin');
        _setHeader(merged, 'Origin', origin);
        _setHeader(merged, 'Referer', _ketangpaiRefererForOrigin(origin));
        _setContentType(merged, context);
        break;
      case SignRequestProfileKind.weizhuojiaoWechat:
        _setHeader(merged, 'Referer', _refererForContext(merged, context));
        _setHeader(merged, 'Origin', context.origin);
        _setContentType(merged, context);
        break;
    }
    return merged;
  }

  Map<String, String> mergeHeaders(
    Map<String, String>? explicitHeaders, {
    SignRequestContext? context,
  }) {
    final merged = context == null
        ? <String, String>{...headers}
        : buildHeaders(context);
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

  static String? _originFromHeader(Map<String, String> headers, String key) {
    final existingKey = _findHeaderKey(headers, key);
    return existingKey == null ? null : headers[existingKey];
  }

  static String? _refererForContext(
    Map<String, String> headers,
    SignRequestContext context,
  ) {
    if (context.referer != null && context.referer!.trim().isNotEmpty) {
      return context.referer!.trim();
    }
    return _originFromHeader(headers, 'Referer') ?? context.effectiveReferer;
  }

  static String? _chaoxingRefererForContext(
    Map<String, String> headers,
    SignRequestContext context,
  ) {
    if (context.referer != null && context.referer!.trim().isNotEmpty) {
      return context.referer!.trim();
    }
    final existing = _originFromHeader(headers, 'Referer');
    if (existing != null && existing.contains('/newsign/signDetail')) {
      return existing;
    }
    return context.effectiveReferer;
  }

  static void _setContentType(
    Map<String, String> headers,
    SignRequestContext context,
  ) {
    final existingKey = _findHeaderKey(headers, 'content-type');
    if (context.contentKind == SignRequestContentKind.multipart) {
      if (existingKey != null) {
        headers.remove(existingKey);
      }
      return;
    }
    _setHeader(headers, 'content-type', _contentTypeFor(context));
  }

  static String _contentTypeFor(SignRequestContext context) {
    switch (context.contentKind) {
      case SignRequestContentKind.json:
        return 'application/json;charset=UTF-8';
      case SignRequestContentKind.multipart:
        return 'multipart/form-data';
      case SignRequestContentKind.plain:
        return 'text/plain; charset=UTF-8';
      case SignRequestContentKind.form:
      case SignRequestContentKind.unknown:
        if (context.method.toUpperCase() == 'GET') {
          return 'application/x-www-form-urlencoded';
        }
        return 'application/x-www-form-urlencoded; charset=UTF-8';
    }
  }

  static String _ketangpaiRefererForOrigin(String? origin) {
    if (origin == null || origin.isEmpty) {
      return 'https://w.ketangpai.com/';
    }
    final host = Uri.tryParse(origin)?.host.toLowerCase() ?? '';
    if (host == 'openapiv5.ketangpai.com') {
      return 'https://w.ketangpai.com/';
    }
    if (host.endsWith('ketangpai.com')) {
      return '$origin/';
    }
    return 'https://w.ketangpai.com/';
  }
}

class SignRequestProfiles {
  SignRequestProfiles._();

  static const String _androidChromeUa =
      'Mozilla/5.0 (Linux; Android 16; Pixel 9 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Mobile Safari/537.36';
  static const String _iosWechatUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.49 NetType/WIFI Language/zh_CN';
  static const String _chaoxingAppUa =
      'Dalvik/2.1.0 (Linux; U; Android 16; Pixel 9 Pro Build/BP4A.260205.002)';

  static SignRequestProfile chaoxingMobileLearn({
    String referer = 'https://mobilelearn.chaoxing.com/',
  }) {
    return SignRequestProfile(
      kind: SignRequestProfileKind.chaoxingMobileLearn,
      platformLabel: 'chaoxing',
      profileName: 'chaoxing-mobilelearn-compatible',
      headers: {
        'User-Agent': _chaoxingAppUa,
        'Accept': 'text/plain,application/json,*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Accept-Encoding': 'gzip',
        'Referer': referer,
        'Origin': 'https://mobilelearn.chaoxing.com',
        'content-type': 'application/x-www-form-urlencoded',
      },
    );
  }

  static SignRequestProfile rainClassroomCheckIn({
    String referer = 'https://www.yuketang.cn/',
  }) {
    return SignRequestProfile(
      kind: SignRequestProfileKind.rainClassroomCheckIn,
      platformLabel: 'rainclassroom',
      profileName: 'rainclassroom-checkin-compatible',
      headers: {
        'User-Agent': _androidChromeUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': referer,
        'Origin': 'https://www.yuketang.cn',
        'content-type': 'application/json;charset=UTF-8',
        'x-client': 'web',
        'xt-agent': 'web',
        'xtbz': 'ykt',
      },
    );
  }

  static SignRequestProfile tronclassRollcall({required String baseUrl}) {
    final normalized = _trimTrailingSlash(baseUrl);
    return SignRequestProfile(
      kind: SignRequestProfileKind.tronclassRollcall,
      platformLabel: 'tronclass',
      profileName: 'tronclass-rollcall-compatible',
      headers: {
        'User-Agent': _androidChromeUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': '$normalized/',
        'Origin': normalized,
        'content-type': 'application/json;charset=UTF-8',
      },
    );
  }

  static SignRequestProfile ketangpaiAttendance({required String baseUrl}) {
    final normalized = _trimTrailingSlash(baseUrl);
    return SignRequestProfile(
      kind: SignRequestProfileKind.ketangpaiAttendance,
      platformLabel: 'ketangpai',
      profileName: 'ketangpai-attendance-compatible',
      headers: {
        'User-Agent': _androidChromeUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': SignRequestProfile._ketangpaiRefererForOrigin(normalized),
        'Origin': normalized,
        'content-type': 'application/json;charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
  }

  static SignRequestProfile weizhuojiaoWechat({required String referer}) {
    return SignRequestProfile(
      kind: SignRequestProfileKind.weizhuojiaoWechat,
      platformLabel: 'weizhuojiao',
      profileName: 'weizhuojiao-wechat-compatible',
      headers: {
        'User-Agent': _iosWechatUa,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Referer': referer,
        'Origin': 'https://v18.teachermate.cn',
        'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Host': 'v18.teachermate.cn',
      },
    );
  }

  static SignRequestProfile forPlatform(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return chaoxingMobileLearn();
      case PlatformType.rainClassroom:
        return rainClassroomCheckIn();
      case PlatformType.tronclass:
        return tronclassRollcall(baseUrl: 'https://courses.guet.edu.cn');
      case PlatformType.ketangpai:
        return ketangpaiAttendance(baseUrl: 'https://openapiv5.ketangpai.com');
      case PlatformType.weizhuojiao:
        return weizhuojiaoWechat(
          referer: 'https://v18.teachermate.cn/wechat/wechat/guide/signin',
        );
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

  static String _trimTrailingSlash(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}

class SignRequestFallbackResult {
  const SignRequestFallbackResult({
    required this.usedFallback,
    required this.reason,
    required this.statusCode,
  });

  final bool usedFallback;
  final String reason;
  final int? statusCode;
}

class SignRequestSafetyGuard {
  SignRequestSafetyGuard._();

  static bool sameBusinessPayload({
    required Map<String, String>? beforeQuery,
    required Map<String, String>? afterQuery,
    required dynamic beforeBody,
    required dynamic afterBody,
  }) {
    return _mapEquals(beforeQuery, afterQuery) &&
        identical(beforeBody, afterBody);
  }

  static bool _mapEquals(Map<String, String>? a, Map<String, String>? b) {
    if (a == null || a.isEmpty) {
      return b == null || b.isEmpty;
    }
    if (b == null || a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

typedef SignRequestSender =
    Future<Response<dynamic>> Function(Map<String, String>? headers);
typedef SignRequestLogSink = void Function(String tag, String message);

class SignRequestExecutor {
  SignRequestExecutor._();

  static Future<Response<dynamic>> run({
    required SignRequestProfile? profile,
    required Map<String, String>? headers,
    required Map<String, String>? legacyHeaders,
    required String operation,
    required SignRequestSender send,
    SignRequestContext? context,
    SignRequestLogSink? logSink,
  }) async {
    if (profile == null) {
      return send(headers);
    }

    final enhancedHeaders = profile.mergeHeaders(headers, context: context);
    try {
      final response = await send(enhancedHeaders);
      final reason = fallbackReasonForResponse(response);
      if (reason == null) {
        _log(
          logSink,
          profile,
          operation,
          '${_contextLog(context)} usedFallback=false enhanced-ok status=${response.statusCode ?? 0}',
        );
        return response;
      }
      _log(
        logSink,
        profile,
        operation,
        '${_contextLog(context)} usedFallback=true fallback-by-response status=${response.statusCode ?? 0} reason=$reason',
      );
      return send(legacyHeaders ?? headers);
    } catch (error) {
      final reason = fallbackReasonForError(error);
      if (reason == null) {
        rethrow;
      }
      _log(
        logSink,
        profile,
        operation,
        '${_contextLog(context)} usedFallback=true fallback-by-error reason=$reason error=${_sanitize(error.toString())}',
      );
      return send(legacyHeaders ?? headers);
    }
  }

  static String? fallbackReasonForResponse(Response<dynamic> response) {
    final status = response.statusCode;
    if (status == 401 || status == 403 || status == 429) {
      return 'http-$status';
    }
    if (response.data == null) {
      return 'empty-response';
    }
    final data = response.data;
    if (data is Map) {
      final code = data['code'] ?? data['errcode'] ?? data['status'];
      final message =
          data['message'] ?? data['msg'] ?? data['errmsg'] ?? data['error'];
      final lower = message?.toString().toLowerCase() ?? '';
      if (code == 401 ||
          code == 403 ||
          code == 429 ||
          lower.contains('unauthorized') ||
          lower.contains('forbidden')) {
        return 'platform-auth-reject';
      }
    }
    return null;
  }

  static String? fallbackReasonForError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return error.type.name;
      }
      final status = error.response?.statusCode;
      if (status == 401 || status == 403 || status == 429) {
        return 'http-$status';
      }
    }
    return null;
  }

  static void _log(
    SignRequestLogSink? logSink,
    SignRequestProfile profile,
    String operation,
    String message,
  ) {
    logSink?.call(
      profile.platformLabel,
      '[SignRequestProfile] profileKind=${profile.kind.name} '
      'profileName=${profile.profileName} operation=${_sanitize(operation)} $message',
    );
  }

  static String _contextLog(SignRequestContext? context) {
    if (context == null) {
      return 'contextOrigin=- contextReferer=- contentKind=-';
    }
    return 'contextOrigin=${_sanitize(context.origin ?? "-")} '
        'contextReferer=${_sanitize(context.effectiveReferer ?? "-")} '
        'contentKind=${context.contentKind.name}';
  }

  static String _sanitize(String value) {
    var text = value;
    text = text.replaceAll(
      RegExp(
        r'(token|cookie|sessionid|openid|authorization)=?[^\s,;&]+',
        caseSensitive: false,
      ),
      r'$1=<redacted>',
    );
    text = text.replaceAll(RegExp(r'([?&]url=)[^&\s]+'), r'$1<redacted>');
    return text;
  }
}
