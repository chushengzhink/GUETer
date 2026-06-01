import 'dart:async';

import 'dart:io';

import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/login.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:course_helper/session/login_context.dart';
import 'package:course_helper/tronclass_guet_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _bootstrapManagers({
  Map<String, Object> initialValues = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  ApiService.resetForTests();
  CookieManager.resetForTests();
  await ApiService.initialize();
  await PlatformManager().initialize();
  await AccountManager.initialize();
  await CookieManager.initialize();
}

User _testUser(String uid) {
  return User(
    uid: uid,
    name: 'User $uid',
    avatar: '',
    phone: '13800000000',
    school: 'Test University',
    platform: 'tronclass',
    credentialExpiry:
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  );
}

Future<void> _seedTronclassAccounts() async {
  await AccountManager.addAccountForPlatformName(
    'tronclass',
    _testUser('u1'),
    notify: false,
    migrateTempCookies: false,
  );
  await AccountManager.addAccountForPlatformName(
    'tronclass',
    _testUser('u2'),
    notify: false,
    migrateTempCookies: false,
  );
  await AccountManager.setCurrentSession('u1', notify: false);
}

Response _okResponse(String url, {Map<String, List<String>>? headers}) {
  return Response(
    requestOptions: RequestOptions(path: url),
    statusCode: 200,
    data: <String, dynamic>{'ok': true},
    headers: Headers.fromMap(headers ?? const <String, List<String>>{}),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _bootstrapManagers(
      initialValues: <String, Object>{'current_platform': 'tronclass'},
    );
  });

  test('loads persisted startup logs into request console', () async {
    await _bootstrapManagers(
      initialValues: <String, Object>{
        'current_platform': 'tronclass',
        ApiService.startupLastLogsKey: <String>['[00:00:00] last step'],
        ApiService.startupActiveLogsKey: <String>['[00:00:01] incomplete step'],
      },
    );

    final messages = ApiService.getConsoleLogs()
        .map((entry) => entry['message'])
        .whereType<String>()
        .toList();

    expect(messages, contains('[LastStartup] [00:00:00] last step'));
    expect(
      messages,
      contains('[LastStartup/Incomplete] [00:00:01] incomplete step'),
    );
  });

  test('sendRequest skips credential validation when requested', () async {
    await _seedTronclassAccounts();

    var validationCalls = 0;
    ApiService.debugCredentialValidatorOverride = (userId) async {
      validationCalls++;
      return true;
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
        }) async => _okResponse(url);

    await ApiService.sendRequest('/skip', skipCredentialValidation: true);
    expect(validationCalls, 0);

    await ApiService.sendRequest('/check');
    expect(validationCalls, 1);
  });

  test(
    'bootstrapPortalSession does not recurse into credential validation',
    () async {
      await _seedTronclassAccounts();

      var validationCalls = 0;
      ApiService.debugCredentialValidatorOverride = (userId) async {
        validationCalls++;
        return true;
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
          }) async => _okResponse(
            url,
            headers: const <String, List<String>>{
              'set-cookie': <String>['sid=test'],
            },
          );

      final bootstrapped = await TCLoginApi.bootstrapPortalSession(
        sessionId: 'session-1',
      );

      expect(bootstrapped, isTrue);
      expect(validationCalls, 0);
    },
  );

  test(
    'restoreCookiesForStartup clears stalled current session and continues',
    () async {
      await _seedTronclassAccounts();
      await ApiService.beginStartupRecoverySession(reason: 'test');

      final visitedKeys = <String>[];
      CookieManager.debugLoadCookiesOverride = (cookieKey, cookieJar) async {
        visitedKeys.add(cookieKey);
        if (cookieKey == 'tronclass_u1') {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      };

      await CookieManager.restoreCookiesForStartup(
        perAccountTimeout: const Duration(milliseconds: 10),
      );

      expect(AccountManager.currentSessionId, isNull);
      expect(
        visitedKeys,
        containsAll(<String>['tronclass_u1', 'tronclass_u2']),
      );
    },
  );

  test(
    'getCookieJarForUser reuses in-flight loads for same storage key',
    () async {
      var loadCalls = 0;
      final completer = Completer<void>();

      CookieManager.debugLoadCookiesOverride = (cookieKey, cookieJar) async {
        loadCalls++;
        await completer.future;
      };

      final first = CookieManager.getCookieJarForUser(
        'u1',
        platformName: 'tronclass',
      );
      final second = CookieManager.getCookieJarForUser(
        'u1',
        platformName: 'tronclass',
      );

      await Future<void>.delayed(Duration.zero);
      expect(loadCalls, 1);

      completer.complete();
      final jars = await Future.wait([first, second]);
      expect(identical(jars[0], jars[1]), isTrue);
    },
  );

  test(
    'saveTempCookiesFromContext migrates and persists tronclass multi-domain cookies',
    () async {
      await _seedTronclassAccounts();
      final context = LoginContextManager.instance.createContext(
        PlatformType.tronclass,
      );

      final cookiesByUri = <Uri, Cookie>{
        TronclassGuetConstants.portalBaseUri: Cookie('portal_session', 'p1'),
        TronclassGuetConstants.casBaseUri: Cookie('cas_jsessionid', 'c1'),
        TronclassGuetConstants.identityBaseUri: Cookie('identity_auth', 'i1'),
        TronclassGuetConstants.mobileBaseUri: Cookie('mobile_state', 'm1'),
      };

      for (final entry in cookiesByUri.entries) {
        entry.value
          ..domain = entry.key.host
          ..path = '/';
        await context.tempCookieJar.saveFromResponse(entry.key, [entry.value]);
      }

      await CookieManager.saveTempCookiesFromContext('u1', context);

      CookieManager.resetForTests();
      await CookieManager.initialize();

      final jar = await CookieManager.getCookieJarForUser(
        'u1',
        platformName: 'tronclass',
      );

      for (final entry in cookiesByUri.entries) {
        final restored = await jar.loadForRequest(entry.key);
        expect(
          restored.any(
            (cookie) =>
                cookie.name == entry.value.name &&
                cookie.value == entry.value.value,
          ),
          isTrue,
          reason: 'missing cookie for ${entry.key.host}',
        );
      }
    },
  );
}
