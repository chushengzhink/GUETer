import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/login.dart';
import 'account.dart';
import 'tronclass_auth.dart';
import '../platform.dart';

class CookieInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.headers['Cookie'] == null) {
      final uri = options.uri;
      List<Cookie> cookies = [];
      CookieJar? cookieJar = CookieManager.isLoggingIn
          ? CookieManager.getTempCookieJar()
          : CookieManager.getCurrentUserCookieJar();
      if (cookieJar != null) {
        cookies = await cookieJar.loadForRequest(uri);
      }

      if (cookies.isNotEmpty) {
        final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
        options.headers['Cookie'] = cookieStr;

        if (PlatformManager().isRainClassroom) {
          final cookieMap = Map.fromEntries(
            cookies.map((c) => MapEntry(c.name, c.value)),
          );
          if (cookieMap.containsKey('sid')) {
            // APP
            options.headers['x-csrftoken'] = cookieMap['x-csrftoken'];
            options.headers['x-uid'] = cookieMap['x-uid'];
            options.headers['sessionid'] = cookieMap['sessionid'];
          } else {
            // Web
            options.headers['x-client'] = 'web';
            options.headers['xt-agent'] = 'web';
          }
        }
      }

      if (PlatformManager().isTronclass &&
          options.headers['x-session-id'] == null) {
        final sessionId = await TronclassAuthManager.getCurrentSessionId();
        if (sessionId != null && sessionId.isNotEmpty) {
          options.headers['x-session-id'] = sessionId;
        }
      }

      if (PlatformManager().isKetangpai && options.headers['token'] == null) {
        final currentUserId = AccountManager.currentSessionId;
        if (currentUserId != null && currentUserId.isNotEmpty) {
          final account = AccountManager.getAccountById(currentUserId);
          if (account != null && account.token.isNotEmpty) {
            options.headers['token'] = account.token;
          }
        }
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      final cookies = setCookieHeaders
          .map((s) => Cookie.fromSetCookieValue(s))
          .toList();

      if (CookieManager.isLoggingIn) {
        await CookieManager.tempSaveCookie(
          cookies,
          responseUri: response.requestOptions.uri,
        );
      } else {
        final cookieJar = CookieManager.getCurrentUserCookieJar();
        if (cookieJar != null) {
          await cookieJar.saveFromResponse(response.realUri, cookies);
          await CookieManager.saveCurrentUserCookies();
        }
      }
    }
    handler.next(response);
  }
}

class CookieManager {
  static const cxDomain = '.chaoxing.com';
  static const rcDomain = '.yuketang.cn';
  static const tcDomain = 'courses.guet.edu.cn';
  static bool isLoggingIn = false;
  static final Map<String, CookieJar> _userCookieJars = {};
  static CookieJar? _tempCookieJar; // 临时保存登录的 Cookie
  static late SharedPreferences _prefs;

  static int refreshCounts = 0; // 只为每个平台刷新一次

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await loadAllCookies(refreshOnlineState: false);
    // Avoid blocking first screen with network refresh; keep it running in background.
    unawaited(refreshAccountsInBackground());
  }

  static Future<void> refreshAccountsInBackground() async {
    if (refreshCounts < 3) {
      await _refreshAccounts();
    }
  }

  static Future<void> loadAllCookies({bool refreshOnlineState = true}) async {
    // 获取所有账号并预加载 CookieJar
    final accounts = AccountManager.getAllAccounts();
    if (accounts.isEmpty) {
      return;
    }

    await Future.wait<void>(
      accounts.map((user) async {
        try {
          await getCookieJarForUser(user.uid);
        } catch (e) {
          debugPrint('预加载账号 ${user.uid} 的 CookieJar 失败：$e');
        }
      }),
    );

    if (refreshOnlineState && refreshCounts < 3) {
      await _refreshAccounts();
    }
  }

  /// 刷新所有账号的Cookie和用户信息
  static Future<void> _refreshAccounts() async {
    refreshCounts++;
    final accounts = AccountManager.getAllAccounts();

    int successCount = 0;
    int failCount = 0;

    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null) return;

    if (PlatformManager().isTronclass) {
      return;
    }

    final getUserInfoApi = PlatformManager().isChaoxing
        ? CXLoginApi.getUserInfo
        : RCLoginApi.getUserInfo;

    for (final user in accounts) {
      try {
        AccountManager.setCurrentSessionTemp(user.uid);
        final refreshedUser = await getUserInfoApi();

        if (refreshedUser != null) {
          await AccountManager.addAccount(refreshedUser);
          successCount++;
        }
      } catch (e) {
        failCount++;
        debugPrint('刷新账号 ${user.name} 失败：$e');
      }
    }
    AccountManager.setCurrentSessionTemp(currentUserId);

    if (successCount > 0 || failCount > 0) {
      debugPrint('账号刷新完成：成功 $successCount 个，失败 $failCount 个');
    }
  }

  static Uri getDomainUri() {
    if (PlatformManager().isChaoxing) {
      return Uri.parse('https://${_normalizeCookieHost(cxDomain)}');
    }
    if (PlatformManager().isRainClassroom) {
      return Uri.parse('https://${_normalizeCookieHost(rcDomain)}');
    }
    return Uri.parse('https://$tcDomain');
  }

  static String _normalizeCookieHost(String? rawDomain) {
    final domain = rawDomain?.trim() ?? '';
    if (domain.isEmpty) {
      return '';
    }
    return domain.replaceFirst(RegExp(r'^\.+'), '');
  }

  /// 临时保存Cookie到内存
  static Future<void> tempSaveCookie(
    List<Cookie> cookies, {
    Uri? responseUri,
  }) async {
    _tempCookieJar ??= CookieJar();

    for (var cookie in cookies) {
      late Uri uri;
      if (cookie.domain != null && cookie.domain!.isNotEmpty) {
        final host = _normalizeCookieHost(cookie.domain);
        if (host.isNotEmpty) {
          uri = Uri.parse('https://$host');
        } else {
          uri = responseUri ?? getDomainUri();
          cookie.domain = uri.host;
        }
      } else {
        uri = responseUri ?? getDomainUri();
        cookie.domain = uri.host;
        // 某些平台的 Set-Cookie 不带 domain，使用当前响应域来避免跨域丢 Cookie。
      }
      await _tempCookieJar!.saveFromResponse(uri, [cookie]);
    }
  }

  /// 获取临时 CookieJar
  static CookieJar? getTempCookieJar() {
    return _tempCookieJar;
  }

  static void clearTempCookies() {
    _tempCookieJar = null;
  }

  static Future<CookieJar> getCookieJarForUser(String userId) async {
    if (_userCookieJars.containsKey(userId)) {
      return _userCookieJars[userId]!;
    }

    final cookieJar = CookieJar();
    _userCookieJars[userId] = cookieJar;
    await _loadCookiesForUser(userId, cookieJar);
    return cookieJar;
  }

  /// 加载用户的 Cookie
  static Future<void> _loadCookiesForUser(
    String userId,
    CookieJar cookieJar,
  ) async {
    final String? cookiesJson = _prefs.getString('cookies_$userId');
    if (cookiesJson == null) return;

    try {
      final List<dynamic> cookiesData = json.decode(cookiesJson);
      for (var cookieData in cookiesData) {
        final cookie = Cookie(
          cookieData['name'] as String,
          cookieData['value'] as String,
        );
        if (cookieData.containsKey('domain') && cookieData['domain'] != null) {
          cookie.domain = cookieData['domain'] as String;
        }
        if (cookieData.containsKey('path') && cookieData['path'] != null) {
          cookie.path = cookieData['path'] as String;
        }
        if (cookieData.containsKey('secure') && cookieData['secure'] != null) {
          cookie.secure = cookieData['secure'] as bool;
        }
        if (cookieData.containsKey('httpOnly') &&
            cookieData['httpOnly'] != null) {
          cookie.httpOnly = cookieData['httpOnly'] as bool;
        }

        if (cookie.domain != null && cookie.domain!.isNotEmpty) {
          final host = _normalizeCookieHost(cookie.domain);
          if (host.isNotEmpty) {
            final uri = Uri.parse('https://$host');
            await cookieJar.saveFromResponse(uri, [cookie]);
          }
        }
      }
    } catch (e) {
      debugPrint('用户 $userId 的 Cookie 加载失败：$e');
    }
  }

  /// 保存指定用户的 Cookie 到 SharedPreferences
  static Future<void> saveCookiesForUser(String userId) async {
    final jar = await getCookieJarForUser(userId);
    final domainUri = getDomainUri();
    final cookies = await jar.loadForRequest(domainUri);
    final List<Map<String, dynamic>> cookiesData = [];
    for (var cookie in cookies) {
      cookiesData.add({
        'name': cookie.name,
        'value': cookie.value,
        'domain':
            cookie.domain ??
            (() {
              final account = AccountManager.getAccountById(userId);
              if (account?.isRainClassroom ?? false) return rcDomain;
              if (account?.isTronclass ?? false) return tcDomain;
              if (account?.isKetangpai ?? false) {
                return 'openapiv5.ketangpai.com';
              }
              return cxDomain;
            })(),
        'path': cookie.path ?? '/',
        'secure': cookie.secure,
        'httpOnly': cookie.httpOnly,
      });
    }

    await _prefs.setString('cookies_$userId', json.encode(cookiesData));
  }

  /// 保存当前用户的 Cookie
  static Future<void> saveCurrentUserCookies() async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId != null) {
      await saveCookiesForUser(currentUserId);
    }
  }

  static CookieJar? getCurrentUserCookieJar() {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.isEmpty) {
      return null;
    }
    final cookieJar = _userCookieJars[currentUserId];

    return cookieJar;
  }

  /// 清除指定用户的所有 Cookie
  static Future<void> clearCookiesForUser(String userId) async {
    _userCookieJars.remove(userId);
    await _prefs.remove('cookies_$userId');
    await TronclassAuthManager.clearSessionIdForUser(userId);
  }

  /// 清除当前用户的 Cookie
  static Future<void> clearCurrentUserCookies() async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId != null) {
      await clearCookiesForUser(currentUserId);
    }
  }

  /// 临时Cookie保存到账号
  static Future<void> saveTempCookies(String userId) async {
    final tempJar = getTempCookieJar();
    if (tempJar == null) {
      debugPrint('没有临时 Cookie 需要迁移');
      return;
    }

    final targetJar = await getCookieJarForUser(userId);
    final probeUris = <Uri>[];
    if (PlatformManager().isRainClassroom) {
      probeUris.addAll([
        Uri.parse('https://www.yuketang.cn/'),
        Uri.parse('https://pro.yuketang.cn/'),
        Uri.parse('https://changjiang.yuketang.cn/'),
        Uri.parse('https://huanghe.yuketang.cn/'),
        Uri.parse('https://yuketang.cn/'),
      ]);
    } else if (PlatformManager().isChaoxing) {
      probeUris.addAll([
        Uri.parse('https://chaoxing.com/'),
        Uri.parse('https://passport2.chaoxing.com/'),
        Uri.parse('https://i.chaoxing.com/'),
      ]);
    } else {
      probeUris.add(getDomainUri());
    }

    final merged = <String, Cookie>{};
    for (final probe in probeUris) {
      final cookies = await tempJar.loadForRequest(probe);
      for (final cookie in cookies) {
        final host = _normalizeCookieHost(cookie.domain) == ''
            ? probe.host
            : _normalizeCookieHost(cookie.domain);
        final key = '${cookie.name}@$host';
        merged[key] = cookie;
      }
    }

    if (merged.isEmpty) {
      debugPrint('临时 Cookie 迁移失败：未在探测域名中读取到有效 cookie');
      clearTempCookies();
      return;
    }

    for (final cookie in merged.values) {
      final host = _normalizeCookieHost(cookie.domain);
      final uri = Uri.parse('https://${host.isNotEmpty ? host : getDomainUri().host}');
      await targetJar.saveFromResponse(uri, [cookie]);
    }

    await saveCookiesForUser(userId);
    clearTempCookies();
  }
}
