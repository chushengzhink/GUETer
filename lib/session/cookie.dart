import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/login.dart';
import '../api/api_service.dart';
import 'account.dart';
import 'tronclass_auth.dart';
import 'credential_manager.dart';
import 'login_context.dart';
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

        // 学习通特殊处理：从多个子域名加载Cookie
        if (PlatformManager().isChaoxing) {
          final probeUris = [
            Uri.parse('https://chaoxing.com'),
            Uri.parse('https://.chaoxing.com'),
            Uri.parse('https://passport2.chaoxing.com'),
            Uri.parse('https://sso.chaoxing.com'),
            Uri.parse('https://i.chaoxing.com'),
          ];

          final allCookies = <Cookie>[];
          for (final probe in probeUris) {
            final probeCookies = await cookieJar.loadForRequest(probe);
            allCookies.addAll(probeCookies);
          }

          if (allCookies.isNotEmpty) {
            cookies = allCookies;
          }
        }

        // 雨课堂特殊处理：如果当前域名没有Cookie，尝试从.yuketang.cn域加载
        if (cookies.isEmpty && PlatformManager().isRainClassroom) {
          final fallbackUri = Uri.parse('https://.yuketang.cn');
          cookies = await cookieJar.loadForRequest(fallbackUri);
        }
      }

      if (cookies.isNotEmpty) {
        final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
        options.headers['Cookie'] = cookieStr;

        if (PlatformManager().isChaoxing) {
          ApiService.appendExternalConsoleLog(
            '学习通',
            '已注入 Cookie，总长度: ${cookieStr.length}',
          );
        }

        if (PlatformManager().isRainClassroom) {
          final cookieMap = Map.fromEntries(
            cookies.map((c) => MapEntry(c.name, c.value)),
          );

          options.headers['xtbz'] = 'ykt';
          options.headers['x-client'] = 'web';
          options.headers['xt-agent'] = 'web';
          options.headers['university-id'] = cookieMap['university_id'] ?? '0';
          options.headers['uv-id'] = cookieMap['uv_id'] ?? '0';
          options.headers['accept'] = 'application/json, text/plain, */*';

          if (cookieMap.containsKey('classroom_id')) {
            options.headers['classroom-id'] = cookieMap['classroom_id'];
          }

          if (cookieMap.containsKey('sid')) {
            options.headers['x-csrftoken'] = cookieMap['x-csrftoken'];
            options.headers['x-uid'] = cookieMap['x-uid'];
            options.headers['sessionid'] = cookieMap['sessionid'];
          } else {
            if (cookieMap.containsKey('csrftoken')) {
              options.headers['x-csrftoken'] = cookieMap['csrftoken'];
              if (options.method.toUpperCase() == 'POST' ||
                  options.method.toUpperCase() == 'PUT' ||
                  options.method.toUpperCase() == 'DELETE') {
                options.headers['X-CSRFToken'] = cookieMap['csrftoken'];
              }
            }
            if (cookieMap.containsKey('sessionid')) {
              options.headers['sessionid'] = cookieMap['sessionid'];
            }
          }
        }
      }

      if (PlatformManager().isTronclass &&
          options.headers['x-session-id'] == null) {
        final url = options.uri.toString();
        if (url.contains('https://courses.guet.edu.cn/')) {
          final currentUserId = AccountManager.currentSessionId;
          final sessionId = await TronclassAuthManager.getCurrentSessionId();
          if (sessionId != null && sessionId.isNotEmpty) {
            options.headers['x-session-id'] = sessionId;
            debugPrint('[CookieInterceptor] 畅课请求已注入 x-session-id (userId=$currentUserId)');
          } else {
            debugPrint('[CookieInterceptor] 警告：畅课请求缺少 x-session-id (userId=$currentUserId)');
          }
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
        final platform = PlatformManager().currentPlatformName;
        ApiService.appendExternalConsoleLog(
          platform,
          '登录流程捕获到 Set-Cookie，数量: ${setCookieHeaders.length}',
        );
        ApiService.appendExternalConsoleLog(
          platform,
          '请求URL: ${response.requestOptions.uri}',
        );
        ApiService.appendExternalConsoleLog(
          platform,
          'Cookie名称: ${cookies.map((c) => c.name).join(", ")}',
        );

        await CookieManager.tempSaveCookie(
          cookies,
          responseUri: response.requestOptions.uri,
          setCookieHeaders: setCookieHeaders,
        );

        ApiService.appendExternalConsoleLog(
          platform,
          'Cookie已临时存储到内存，等待登录完成后迁移',
        );

        // 登录期间不检查认证状态，只保存 Cookie
        handler.next(response);
        return;
      } else {
        final cookieJar = CookieManager.getCurrentUserCookieJar();
        if (cookieJar != null) {
          await cookieJar.saveFromResponse(response.realUri, cookies);
          await CookieManager.saveCurrentUserCookies();
          await CookieManager.updateCredentialExpiryFromResponse(setCookieHeaders);
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

  @Deprecated('使用 LoginContextManager.instance.hasActiveContexts 代替')
  static bool isLoggingIn = false;

  static final Map<String, CookieJar> _userCookieJars = {};

  @Deprecated('使用 LoginContext.tempCookieJar 代替')
  static CookieJar? _tempCookieJar; // 临时保存登录的 Cookie

  static List<String>? _tempSetCookieHeaders;
  static bool _isMigratingCookies = false; // 防止 Cookie 迁移死循环 // 临时保存 Set-Cookie 头
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
    // 恢复原始会话（如果原始会话为空，则不恢复，避免退出登录后被错误恢复）
    if (currentUserId.isNotEmpty) {
      AccountManager.setCurrentSessionTemp(currentUserId);
    }

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

  /// Update credential expiry from Set-Cookie headers
  static Future<void> updateCredentialExpiryFromResponse(
    List<String> setCookieHeaders,
  ) async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null) return;

    final user = AccountManager.getAccountById(currentUserId);
    if (user == null) return;

    int? maxExpiry;
    for (final header in setCookieHeaders) {
      final expiry = CredentialManager.parseCookieExpiry(header);
      if (expiry != null) {
        if (maxExpiry == null || expiry > maxExpiry) {
          maxExpiry = expiry;
        }
      }
    }

    if (maxExpiry != null) {
      await CredentialManager.updateCredentialExpiry(
        user,
        expiryTimestamp: maxExpiry,
        extendDefault: false,
      );
    }
  }

  /// 临时保存Cookie到内存
  static Future<void> tempSaveCookie(
    List<Cookie> cookies, {
    Uri? responseUri,
    List<String>? setCookieHeaders,
  }) async {
    _tempCookieJar ??= CookieJar();

    if (setCookieHeaders != null && setCookieHeaders.isNotEmpty) {
      _tempSetCookieHeaders = setCookieHeaders;
    }

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
    _tempSetCookieHeaders = null;
  }

  static Future<CookieJar> getCookieJarForUser(String userId, {String? platformName}) async {
    // Cookie按 platform_userId 存储
    final platform = (platformName ?? PlatformManager().currentPlatformName).toLowerCase();
    final cookieKey = '${platform}_$userId';

    if (_userCookieJars.containsKey(cookieKey)) {
      return _userCookieJars[cookieKey]!;
    }

    final cookieJar = CookieJar();
    _userCookieJars[cookieKey] = cookieJar;
    await _loadCookiesForUser(cookieKey, cookieJar);
    return cookieJar;
  }

  /// 加载用户的 Cookie
  static Future<void> _loadCookiesForUser(
    String cookieKey,
    CookieJar cookieJar,
  ) async {
    final String? cookiesJson = _prefs.getString('cookies_$cookieKey');
    debugPrint('[CookieManager] 加载Cookie: key=cookies_$cookieKey, 存在=${cookiesJson != null}');
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
      debugPrint('用户 $cookieKey 的 Cookie 加载失败：$e');
    }
  }

  /// 保存指定用户的 Cookie 到 SharedPreferences
  static Future<void> saveCookiesForUser(String userId) async {
    final platform = PlatformManager().currentPlatformName.toLowerCase();
    final cookieKey = '${platform}_$userId';

    final jar = await getCookieJarForUser(userId);

    // 学习通需要从多个子域名收集Cookie
    final List<Cookie> allCookies = [];
    if (PlatformManager().isChaoxing) {
      final domains = [
        'https://chaoxing.com',
        'https://passport2.chaoxing.com',
        'https://sso.chaoxing.com',
        'https://i.chaoxing.com',
      ];
      for (final domain in domains) {
        final cookies = await jar.loadForRequest(Uri.parse(domain));
        allCookies.addAll(cookies);
      }
    } else if (PlatformManager().isRainClassroom) {
      final domains = [
        'https://www.yuketang.cn',
        'https://pro.yuketang.cn',
        'https://changjiang.yuketang.cn',
        'https://huanghe.yuketang.cn',
      ];
      for (final domain in domains) {
        final cookies = await jar.loadForRequest(Uri.parse(domain));
        allCookies.addAll(cookies);
      }
    } else {
      final domainUri = getDomainUri();
      final cookies = await jar.loadForRequest(domainUri);
      allCookies.addAll(cookies);
    }

    final List<Map<String, dynamic>> cookiesData = [];
    for (var cookie in allCookies) {
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

    await _prefs.setString('cookies_$cookieKey', json.encode(cookiesData));
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

    // Cookie按 platform_userId 存储，避免不同平台账号混用
    final platform = PlatformManager().currentPlatformName.toLowerCase();
    final cookieKey = '${platform}_$currentUserId';
    final cookieJar = _userCookieJars[cookieKey];

    return cookieJar;
  }

  /// 清除指定用户的所有 Cookie
  static Future<void> clearCookiesForUser(String userId) async {
    final platform = PlatformManager().currentPlatformName.toLowerCase();
    final cookieKey = '${platform}_$userId';

    _userCookieJars.remove(cookieKey);
    await _prefs.remove('cookies_$cookieKey');
    await TronclassAuthManager.clearSessionIdForUser(userId);
  }

  /// 清除当前用户的 Cookie
  static Future<void> clearCurrentUserCookies() async {
    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId != null) {
      await clearCookiesForUser(currentUserId);
    }
  }

  /// 临时Cookie保存到账号（旧方法，已弃用）
  @Deprecated('使用 saveTempCookiesFromContext(userId, context) 代替')
  static Future<void> saveTempCookies(String userId) async {
    if (_isMigratingCookies) {
      debugPrint('[CookieManager] 跳过重复的 Cookie 迁移调用');
      return;
    }

    final tempJar = getTempCookieJar();
    if (tempJar == null) {
      debugPrint('[学习通] 警告：没有临时 Cookie 需要迁移');
      return;
    }

    _isMigratingCookies = true;

    final platform = PlatformManager().currentPlatformName.toLowerCase();
    final cookieKey = '${platform}_$userId';

    ApiService.appendExternalConsoleLog(
      platform,
      '开始迁移临时Cookie到用户账号，存储Key: $cookieKey',
    );

    // Parse credential expiry from Set-Cookie headers
    int? credentialExpiry;
    if (_tempSetCookieHeaders != null && _tempSetCookieHeaders!.isNotEmpty) {
      for (final header in _tempSetCookieHeaders!) {
        final expiry = CredentialManager.parseCookieExpiry(header);
        if (expiry != null) {
          if (credentialExpiry == null || expiry > credentialExpiry) {
            credentialExpiry = expiry;
          }
        }
      }
    }

    // If no expiry found, use default 7 days
    credentialExpiry ??= CredentialManager.getDefaultExpiry();

    // 直接更新凭证过期时间，避免递归调用 addAccount
    final user = AccountManager.getAccountById(userId);
    if (user != null) {
      await CredentialManager.updateCredentialExpiry(
        user,
        expiryTimestamp: credentialExpiry,
        extendDefault: false,
      );
      ApiService.appendExternalConsoleLog(
        platform,
        '凭证已存储，过期时间: ${_formatExpiry(credentialExpiry)}',
      );
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
        Uri.parse('https://sso.chaoxing.com/'),
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
      ApiService.appendExternalConsoleLog(
        platform,
        '临时 Cookie 迁移失败：未在探测域名中读取到有效 cookie',
      );
      clearTempCookies();
      _isMigratingCookies = false;
      return;
    }

    ApiService.appendExternalConsoleLog(
      platform,
      'Cookie已成功存储，数量: ${merged.length}',
    );
    ApiService.appendExternalConsoleLog(
      platform,
      'Cookie键名: ${merged.keys.take(15).join(", ")}',
    );

    for (final cookie in merged.values) {
      final host = _normalizeCookieHost(cookie.domain);
      final uri = Uri.parse('https://${host.isNotEmpty ? host : getDomainUri().host}');
      await targetJar.saveFromResponse(uri, [cookie]);
    }

    await saveCookiesForUser(userId);
    clearTempCookies();
    _isMigratingCookies = false;

    ApiService.appendExternalConsoleLog(
      platform,
      'Cookie迁移完成，已持久化到SharedPreferences',
    );
  }

  static String _formatExpiry(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ==================== 新增：基于上下文的方法 ====================

  /// 从登录上下文迁移 Cookie 到用户账号（新方法）
  static Future<void> saveTempCookiesFromContext(
    String userId,
    LoginContext context,
  ) async {
    if (_isMigratingCookies) {
      debugPrint('[CookieManager] 跳过重复的 Cookie 迁移调用');
      return;
    }

    _isMigratingCookies = true;

    final platformName = _getPlatformNameFromType(context.platform);
    final cookieKey = '${platformName}_$userId';

    ApiService.appendExternalConsoleLog(
      platformName,
      '开始从上下文迁移Cookie到用户账号，存储Key: $cookieKey',
    );

    // 解析凭证过期时间
    int? credentialExpiry;
    if (context.setCookieHeaders != null && context.setCookieHeaders!.isNotEmpty) {
      for (final header in context.setCookieHeaders!) {
        final expiry = CredentialManager.parseCookieExpiry(header);
        if (expiry != null) {
          if (credentialExpiry == null || expiry > credentialExpiry) {
            credentialExpiry = expiry;
          }
        }
      }
    }

    credentialExpiry ??= CredentialManager.getDefaultExpiry();

    // 更新凭证过期时间
    final user = AccountManager.getAccountById(userId);
    if (user != null) {
      await CredentialManager.updateCredentialExpiry(
        user,
        expiryTimestamp: credentialExpiry,
        extendDefault: false,
      );
      ApiService.appendExternalConsoleLog(
        platformName,
        '凭证已存储，过期时间: ${_formatExpiry(credentialExpiry)}',
      );
    }

    // 从上下文的临时 CookieJar 迁移到用户 CookieJar
    final targetJar = await getCookieJarForUser(userId, platformName: platformName);
    final probeUris = _getProbeUrisForPlatform(context.platform);

    final merged = <String, Cookie>{};
    for (final probe in probeUris) {
      final cookies = await context.tempCookieJar.loadForRequest(probe);
      for (final cookie in cookies) {
        final host = _normalizeCookieHost(cookie.domain) == ''
            ? probe.host
            : _normalizeCookieHost(cookie.domain);
        final key = '${cookie.name}@$host';
        merged[key] = cookie;
      }
    }

    if (merged.isEmpty) {
      ApiService.appendExternalConsoleLog(
        platformName,
        '上下文 Cookie 迁移失败：未在探测域名中读取到有效 cookie',
      );
      _isMigratingCookies = false;
      return;
    }

    ApiService.appendExternalConsoleLog(
      platformName,
      'Cookie已成功存储，数量: ${merged.length}',
    );
    ApiService.appendExternalConsoleLog(
      platformName,
      'Cookie键名: ${merged.keys.take(15).join(", ")}',
    );

    for (final cookie in merged.values) {
      final host = _normalizeCookieHost(cookie.domain);
      final uri = Uri.parse('https://${host.isNotEmpty ? host : _getDefaultHostForPlatform(context.platform)}');
      await targetJar.saveFromResponse(uri, [cookie]);
    }

    await saveCookiesForUser(userId);
    _isMigratingCookies = false;

    ApiService.appendExternalConsoleLog(
      platformName,
      'Cookie迁移完成，已持久化到SharedPreferences',
    );
  }

  /// 检查是否有任何平台正在登录
  static bool isAnyLoginInProgress() {
    return LoginContextManager.instance.hasActiveContexts || isLoggingIn;
  }

  /// 辅助方法：从 PlatformType 获取平台名称
  static String _getPlatformNameFromType(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return 'chaoxing';
      case PlatformType.rainClassroom:
        return 'yuketang';
      case PlatformType.ketangpai:
        return 'ketangpai';
      case PlatformType.tronclass:
        return 'tronclass';
      case PlatformType.weizhuojiao:
        return 'weizhuojiao';
    }
  }

  /// 辅助方法：获取平台的探测 URI 列表
  static List<Uri> _getProbeUrisForPlatform(PlatformType platform) {
    switch (platform) {
      case PlatformType.rainClassroom:
        return [
          Uri.parse('https://www.yuketang.cn/'),
          Uri.parse('https://pro.yuketang.cn/'),
          Uri.parse('https://changjiang.yuketang.cn/'),
          Uri.parse('https://huanghe.yuketang.cn/'),
          Uri.parse('https://yuketang.cn/'),
        ];
      case PlatformType.chaoxing:
        return [
          Uri.parse('https://chaoxing.com/'),
          Uri.parse('https://passport2.chaoxing.com/'),
          Uri.parse('https://sso.chaoxing.com/'),
          Uri.parse('https://i.chaoxing.com/'),
        ];
      case PlatformType.ketangpai:
        return [Uri.parse('https://openapiv5.ketangpai.com/')];
      case PlatformType.tronclass:
        return [Uri.parse('https://www.tronclass.com.cn/')];
      case PlatformType.weizhuojiao:
        return [Uri.parse('https://www.weizhuojiao.com/')];
    }
  }

  /// 辅助方法：获取平台的默认主机名
  static String _getDefaultHostForPlatform(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return 'chaoxing.com';
      case PlatformType.rainClassroom:
        return 'yuketang.cn';
      case PlatformType.ketangpai:
        return 'openapiv5.ketangpai.com';
      case PlatformType.tronclass:
        return 'www.tronclass.com.cn';
      case PlatformType.weizhuojiao:
        return 'www.weizhuojiao.com';
    }
  }
}
