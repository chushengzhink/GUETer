import 'dart:io';

import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/tronclass_cas_login_http.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/login_context.dart';
import 'package:course_helper/tronclass_guet_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Response<dynamic> _response(
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

  test(
    'debug override receives absolute CAS url for relative requests',
    () async {
      final context = LoginContextManager.instance.createContext(
        PlatformType.tronclass,
      );
      addTearDown(
        () => LoginContextManager.instance.removeContext(context.contextId),
      );
      final http = TronclassCasLoginHttp(loginContext: context);
      var seenUrl = '';

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
            seenUrl = url;
            return _response(url);
          };

      await http.request('authserver/login');

      expect(seenUrl, TronclassGuetConstants.casLoginUrl);
    },
  );

  test('service query keeps endpoint state separator intact', () {
    const service =
        'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state.TronclassH5';
    final loginUrl =
        '${TronclassGuetConstants.casLoginUrl}?service=${Uri.encodeQueryComponent(service)}';
    final parsed = Uri.parse(loginUrl);

    expect(parsed.queryParameters['service'], service);
    expect(parsed.queryParameters['service'], contains('endpoint?state='));
    expect(
      parsed.queryParameters['service'],
      isNot(contains('endpoint?state%')),
    );
  });

  test('preserves nested CAS service from encoded and mixed raw urls', () {
    const service =
        'https://identity.guet.edu.cn/auth/realms/guet/broker/cas-client/endpoint?state=test-state.TronclassH5';
    final encoded =
        '${TronclassGuetConstants.casLoginUrl}?service=${Uri.encodeQueryComponent(service)}';
    final mixed =
        '${TronclassGuetConstants.casLoginUrl}?service=https%3A%2F%2Fidentity.guet.edu.cn%2Fauth%2Frealms%2Fguet%2Fbroker%2Fcas-client%2Fendpoint?state%3Dtest-state.TronclassH5';
    final broken =
        '${TronclassGuetConstants.casLoginUrl}?service=https%3A%2F%2Fidentity.guet.edu.cn%2Fauth%2Frealms%2Fguet%2Fbroker%2Fcas-client%2Fendpoint?state%3Dtest-state.TronclassH5';

    expect(preserveNestedCasService(encoded), service);
    expect(preserveNestedCasService(mixed), service);
    expect(isBrokenCasServiceShape(broken), isTrue);
    expect(
      normalizeCasNestedServiceUrl(mixed),
      '${TronclassGuetConstants.casLoginUrl}?service=${Uri.encodeQueryComponent(service)}',
    );
  });

  test(
    'trace reports temporary cookie count without exposing values',
    () async {
      final context = LoginContextManager.instance.createContext(
        PlatformType.tronclass,
      );
      addTearDown(
        () => LoginContextManager.instance.removeContext(context.contextId),
      );
      await context.tempCookieJar.saveFromResponse(
        Uri.parse(TronclassGuetConstants.casLoginUrl),
        <Cookie>[Cookie('SESSION', 'secret')],
      );
      final http = TronclassCasLoginHttp(loginContext: context);
      final trace = await http.trace(
        'casLoginPage',
        _response(TronclassGuetConstants.casLoginUrl),
      );

      expect(trace.cookieCount, 1);
      expect(trace.toLogLine(), contains('casExecutor=true'));
      expect(trace.toLogLine(), contains('cookieCount=1'));
      expect(trace.toLogLine(), isNot(contains('secret')));
    },
  );

  test('clears only stale CAS session cookies before password login', () async {
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

    final http = TronclassCasLoginHttp(loginContext: context);
    final removed = await http.clearStaleCasSessionCookies();
    final remaining = await context.tempCookieJar.loadForRequest(casLoginUri);

    expect(removed, 2);
    expect(remaining.map((cookie) => cookie.name), contains('CASTGC'));
    expect(
      remaining.map((cookie) => cookie.name),
      isNot(contains('JSESSIONID')),
    );
    expect(remaining.map((cookie) => cookie.name), isNot(contains('route')));
  });
}
