import 'dart:io';

import 'package:dio/dio.dart';

import '../session/login_context.dart';
import '../tronclass_guet_constants.dart';
import 'api_service.dart';

const Set<String> tronclassStaleCasSessionCookieNames = {'JSESSIONID', 'route'};

String? preserveNestedCasService(String? rawUrl) {
  final rawService = _extractRawQueryValue(rawUrl, 'service');
  if (rawService == null || rawService.isEmpty) {
    return null;
  }
  try {
    return Uri.decodeQueryComponent(rawService);
  } catch (_) {
    return rawService;
  }
}

bool isBrokenCasServiceShape(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) {
    return false;
  }
  final lower = rawUrl.toLowerCase();
  if (!lower.contains('/authserver/login') ||
      !lower.contains('service=') ||
      (!lower.contains('/endpoint?state%3d') &&
          !lower.contains('%2fendpoint?state%3d'))) {
    return false;
  }
  return true;
}

String normalizeCasNestedServiceUrl(String rawUrl) {
  if (rawUrl.isEmpty || preserveNestedCasService(rawUrl) == null) {
    return rawUrl;
  }
  try {
    final parsed = Uri.parse(rawUrl);
    final rawQuery = parsed.query;
    if (rawQuery.isEmpty) {
      return rawUrl;
    }
    var changed = false;
    final parts = rawQuery
        .split('&')
        .map((part) {
          final separator = part.indexOf('=');
          if (separator < 0) {
            return part;
          }
          final key = part.substring(0, separator);
          if (Uri.decodeQueryComponent(key) != 'service') {
            return part;
          }
          final preserved = preserveNestedCasService(rawUrl);
          if (preserved == null || preserved.isEmpty) {
            return part;
          }
          changed = true;
          return '$key=${Uri.encodeQueryComponent(preserved)}';
        })
        .join('&');
    if (!changed) {
      return rawUrl;
    }
    return parsed.replace(query: parts).toString();
  } catch (_) {
    return rawUrl;
  }
}

String? _extractRawQueryValue(String? rawUrl, String key) {
  if (rawUrl == null || rawUrl.isEmpty) {
    return null;
  }
  final queryStart = rawUrl.indexOf('?');
  if (queryStart < 0 || queryStart == rawUrl.length - 1) {
    return null;
  }
  final rawQuery = rawUrl.substring(queryStart + 1);
  var cursor = 0;
  while (cursor <= rawQuery.length) {
    final next = rawQuery.indexOf('&', cursor);
    final end = next < 0 ? rawQuery.length : next;
    final part = rawQuery.substring(cursor, end);
    final separator = part.indexOf('=');
    if (separator >= 0) {
      final rawKey = part.substring(0, separator);
      try {
        if (Uri.decodeQueryComponent(rawKey) == key) {
          return part.substring(separator + 1);
        }
      } catch (_) {
        if (rawKey == key) {
          return part.substring(separator + 1);
        }
      }
    }
    if (next < 0) {
      break;
    }
    cursor = next + 1;
  }
  return null;
}

class TronclassCasResponseTrace {
  const TronclassCasResponseTrace({
    required this.stage,
    required this.statusCode,
    required this.uri,
    required this.location,
    required this.cookieCount,
  });

  final String stage;
  final int? statusCode;
  final Uri uri;
  final String? location;
  final int cookieCount;

  bool get returnedToLogin {
    final current = uri.toString().toLowerCase();
    final redirect = (location ?? '').toLowerCase();
    return current.contains('/authserver/login') ||
        redirect.contains('/authserver/login');
  }

  String toLogLine() {
    return 'casExecutor=true stage=$stage statusCode=$statusCode '
        'returnedToLogin=$returnedToLogin cookieCount=$cookieCount';
  }
}

class TronclassCasLoginHttp {
  TronclassCasLoginHttp({LoginContext? loginContext})
    : _loginContext = loginContext,
      _dio = Dio(
        BaseOptions(
          baseUrl: '${TronclassGuetConstants.casBaseUrl}/',
          followRedirects: false,
          validateStatus: (status) => status != null,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 10),
        ),
      ) {
    _dio.interceptors.add(_TronclassCasCookieInterceptor(_loginContext));
  }

  final LoginContext? _loginContext;
  final Dio _dio;

  Future<int> clearStaleCasSessionCookies({
    Set<String> names = tronclassStaleCasSessionCookieNames,
  }) async {
    final context = _loginContext;
    if (context == null) {
      return 0;
    }

    final casLoginUri = Uri.parse(TronclassGuetConstants.casLoginUrl);
    final existing = await context.tempCookieJar.loadForRequest(casLoginUri);
    if (existing.isEmpty) {
      return 0;
    }

    final keep = existing
        .where((cookie) => !names.contains(cookie.name))
        .toList(growable: false);
    final removedCount = existing.length - keep.length;
    if (removedCount == 0) {
      return 0;
    }

    await context.tempCookieJar.delete(casLoginUri);
    if (keep.isNotEmpty) {
      await context.tempCookieJar.saveFromResponse(casLoginUri, keep);
    }
    return removedCount;
  }

  Future<Response<dynamic>> request(
    String url, {
    String method = 'GET',
    Map<String, String>? params,
    Map<String, String>? headers,
    dynamic body,
    ResponseType responseType = ResponseType.json,
    bool allowRedirects = false,
  }) async {
    final normalizedUrl = normalizeCasNestedServiceUrl(url);
    final debugResponse = ApiService.dispatchDebugOverrideForLogin(
      _absoluteUrl(normalizedUrl),
      method: method,
      params: params,
      headers: headers,
      body: body,
      responseType: responseType,
      allowRedirects: allowRedirects,
    );
    if (debugResponse != null) {
      return debugResponse;
    }

    var response = await _sendOnce(
      normalizedUrl,
      method: method,
      params: params,
      headers: headers,
      body: body,
      responseType: responseType,
    );

    if (!allowRedirects) {
      return response;
    }

    final visited = <String>{response.requestOptions.uri.toString()};
    for (var i = 0; i < 10; i++) {
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        break;
      }
      final next = normalizeCasNestedServiceUrl(
        response.requestOptions.uri.resolve(location).toString(),
      );
      if (!visited.add(next)) {
        break;
      }
      response = await _sendOnce(
        next,
        method: 'GET',
        headers: headers,
        responseType: responseType,
      );
    }
    return response;
  }

  Future<TronclassCasResponseTrace> trace(
    String stage,
    Response<dynamic> response,
  ) async {
    final uri = response.requestOptions.uri;
    final cookies = await _loginContext?.tempCookieJar.loadForRequest(uri);
    return TronclassCasResponseTrace(
      stage: stage,
      statusCode: response.statusCode,
      uri: uri,
      location: response.headers.value('location'),
      cookieCount: cookies?.length ?? 0,
    );
  }

  Future<Response<dynamic>> _sendOnce(
    String url, {
    required String method,
    Map<String, String>? params,
    Map<String, String>? headers,
    dynamic body,
    required ResponseType responseType,
  }) {
    return _dio.request<dynamic>(
      _dioUrl(url),
      queryParameters: params,
      data: body,
      options: Options(
        method: method,
        headers: headers,
        responseType: responseType,
      ),
    );
  }

  String _dioUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return url;
    }
    if (uri.scheme == 'https' &&
        uri.host == Uri.parse(TronclassGuetConstants.casBaseUrl).host) {
      final query = uri.query.isEmpty ? '' : '?${uri.query}';
      return '${uri.path}$query';
    }
    return url;
  }

  String _absoluteUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      return url;
    }
    return TronclassGuetConstants.casBaseUri.resolve(url).toString();
  }
}

class _TronclassCasCookieInterceptor extends Interceptor {
  _TronclassCasCookieInterceptor(this._loginContext);

  final LoginContext? _loginContext;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final context = _loginContext;
    if (context != null && options.headers['Cookie'] == null) {
      final cookies = await context.tempCookieJar.loadForRequest(options.uri);
      if (cookies.isNotEmpty) {
        options.headers['Cookie'] = cookies
            .map((cookie) => '${cookie.name}=${cookie.value}')
            .join('; ');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final context = _loginContext;
    final setCookieHeaders = response.headers['set-cookie'];
    if (context != null &&
        setCookieHeaders != null &&
        setCookieHeaders.isNotEmpty) {
      context.setCookieHeaders = setCookieHeaders;
      final cookies = setCookieHeaders
          .map((value) => Cookie.fromSetCookieValue(value))
          .toList(growable: false);
      await context.tempCookieJar.saveFromResponse(
        response.requestOptions.uri,
        cookies,
      );
    }
    handler.next(response);
  }
}
