import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:html/parser.dart' as html_parser;
import 'package:encrypt/encrypt.dart' as encrypt_pkg;

import '../api/api_service.dart';
import '../utils/encrypt.dart';
import '../session/cookie.dart';
import '../models/user.dart';
import '../platform.dart';

class CXLoginApi {
  /// Web登录
  static Future<Map<String, dynamic>?> loginWeb(
    String username,
    String password,
  ) async {
    try {
      final url = 'https://passport2.chaoxing.com/fanyalogin';

      final usernameCipher = EncryptionUtil.aesCbcEncrypt(
        password,
        Constant.webLoginKey,
      );
      final passwordCipher = EncryptionUtil.aesCbcEncrypt(
        password,
        Constant.webLoginKey,
      );

      final formData = {
        'fid': '-1',
        'uname': usernameCipher,
        'password': passwordCipher,
        't': 'true',
        'forbidotherlogin': '0',
        'validate': '',
      };
      final response = await ApiService.sendRequest(
        url,
        method: "POST",
        body: formData,
      );
      return response.data;
    } catch (e) {
      debugPrint('Login error: $e');
    }
    return null;
  }

  /// 发送验证码
  static Future<Map<String, dynamic>?> sendCaptcha(String phone) async {
    try {
      final url = 'https://passport2-api.chaoxing.com/api/sendcaptcha';

      final timestampMS = DateTime.now().millisecondsSinceEpoch.toString();
      final enc = EncryptionUtil.md5Hash(
        phone + Constant.sendCaptchaKey + timestampMS,
      );

      final formData = {
        'to': phone,
        'countrycode': '86',
        'time': timestampMS,
        'enc': enc,
      };

      final response = await ApiService.sendRequest(
        url,
        method: "POST",
        body: formData,
      );
      return response.data;
    } catch (e) {
      debugPrint('sendCaptcha error: $e');
    }
    return null;
  }

  /// APP 登录
  static Future<Map<String, dynamic>?> loginAPP(
    String loginType,
    String username,
    String code,
  ) async {
    try {
      final url =
          'https://passport2-api.chaoxing.com/v11/loginregister?cx_xxt_passport=json';

      final loginData = {'uname': username, 'code': code};
      final loginInfo = EncryptionUtil.aesEcbEncrypt(
        json.encode(loginData),
        Constant.appLoginKey,
      );

      Map<String, dynamic> formData = {
        'logininfo': loginInfo,
        'loginType': loginType,
        'roleSelect': 'true',
        'entype': "1",
      };
      if (loginType == '2') {
        formData['countrycode'] = '86';
      }

      CookieManager.isLoggingIn = true;
      final response = await ApiService.sendRequest(
        url,
        method: "POST",
        body: formData,
      );
      return response.data;
      // {"mes":"验证通过","type":1,"url":"https://sso.chaoxing.com/apis/login/userLogin4Uname.do","status":true}
    } catch (e) {
      debugPrint('Login error: $e');
    } finally {
      CookieManager.isLoggingIn = false;
    }
    return null;
  }

  /// 获取用户信息
  static Future<User?> getUserInfo() async {
    try {
      final url = 'https://sso.chaoxing.com/apis/login/userLogin4Uname.do';
      // POST https://sso.chaoxing.com/apis/login/userLogin.do?puid=&hddInfo=&len=
      // 用于在每次进入应用时刷新账号 hddInfo和data一致

      /*
      final deviceId = EncryptionUtil.getUniqueId();
      final deviceInfo = {
        "app_name": "com.chaoxing.mobile",
        "app_ver": "6.7.4",
        "board": "caiman",
        "brand": "google",
        "cdid": deviceId,
        "cdtype": "Pixel 9 Pro",
        "cpu_ar": "arm64-v8a,armeabi-v7a,armeabi",
        "device_id": deviceId,
        "dpi": "440",
        "hardware": "caiman",
        "mediaDrmId": "",
        "oaid": "1004",
        "os_lang": "",
        "os_name": "REL",
        "os_ver": "16",
        "platform": "android",
        "resolution": "1080*2243",
        "time_stamp": DateTime.now().millisecondsSinceEpoch
      };

      final formData = {'data': EncryptionUtil.rsaEncrypt(jsonEncode(deviceInfo), Constant.rsaPublicKey)};
      */

      final response = await ApiService.sendRequest(url);
      // final response = await ApiService.sendRequest(url, method: "POST", body: formData);

      final data = response.data['msg'];
      final user = User(
        uid: data['puid']?.toString() ?? '',
        name: data['name'] ?? '未知用户',
        avatar: data['pic'] ?? '',
        phone: data['phone'] ?? '未知手机号',
        school: data['schoolname'] ?? '未知学校',
        platform: 'chaoxing',
      );
      return user;
    } catch (e) {
      debugPrint('getUserInfo error: $e');
    }
    return null;
  }

  /// 获取二维码登录数据
  static Future<Map<String, dynamic>?> getQRCodeData() async {
    try {
      final loginPageUrl = 'https://passport2.chaoxing.com/login';
      final response = await ApiService.sendRequest(
        loginPageUrl,
        responseType: ResponseType.plain,
      );

      final html = response.data;

      // 提取uuid
      final uuidRegex = RegExp(r'value="(.+?)" id="uuid"');
      final uuidMatch = uuidRegex.firstMatch(html);
      final uuid = uuidMatch?.group(1);

      // 提取enc
      final encRegex = RegExp(r'value="(.+?)" id="enc"');
      final encMatch = encRegex.firstMatch(html);
      final enc = encMatch?.group(1);

      if (uuid != null && enc != null) {
        return {'uuid': uuid, 'enc': enc};
      }
    } catch (e) {
      debugPrint('getQRCodeData error: $e');
    }
    return null;
  }

  /// 检查二维码授权状态
  static Future<Map<String, dynamic>?> checkQRAuthStatus(
    String uuid,
    String enc,
  ) async {
    try {
      final authStatusUrl = 'https://passport2.chaoxing.com/getauthstatus/v2';

      final formData = {
        'enc': enc,
        'uuid': uuid,
        'doubleFactorLogin': '0',
        'forbidotherlogin': '0',
      };

      CookieManager.isLoggingIn = true;
      final response = await ApiService.sendRequest(
        authStatusUrl,
        method: "POST",
        body: formData,
      );
      return response.data;
    } catch (e) {
      debugPrint('checkQRAuthStatus error: $e');
    } finally {
      CookieManager.isLoggingIn = false;
    }
    return null;
  }
}

class RCLoginApi {
  /// 发送验证码
  static Future<Map<String, dynamic>?> sendCaptcha(
    String phone,
    String ticket,
    String rand,
  ) async {
    try {
      final url = '/api/v3/user/code/send';

      final jsonData = {
        'phoneNumber': phone,
        'email': '',
        'ticket': ticket,
        'rand': rand,
      };

      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );
      debugPrint('[RC][API.sendCaptcha] request=$jsonData response=${response.data}');
      return response.data;
    } catch (e) {
      debugPrint('[RC][API.sendCaptcha] error=$e');
      debugPrint('sendCaptcha error: $e');
    }
    return null;
  }

  /// 验证验证码
  static Future<Map<String, dynamic>?> verifyCaptcha(
    String phone,
    String code,
  ) async {
    try {
      final url = '/api/v3/user/code/verify';

      final jsonData = {'phoneNumber': phone, 'email': '', 'code': code};

      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );
      return response.data;
    } catch (e) {
      debugPrint('verifyCaptcha error: $e');
    }
    return null;
  }

  /// 验证码 密码登录
  static Future<Map<String, dynamic>?> login(
    int loginType,
    String account,
    String code,
    String ticket,
    String rand,
  ) async {
    try {
      final url = '/api/v3/user/login/app';

      final jsonData = {
        'type': loginType,
        'phoneNumber': '',
        'password': '',
        'email': '',
        'code': '',
        'pushDeviceId': '', // 密码登录会有
        'ticket': ticket,
        'rand': rand,
      };
      if (loginType == 2) {
        jsonData['password'] = code;
        if (account.contains('@')) {
          jsonData['email'] = account;
        } else {
          jsonData['type'] = 1;
          jsonData['phoneNumber'] = account;
        }
      } else if (loginType == 3) {
        jsonData['phoneNumber'] = account;
        jsonData['code'] = code;
      }

      CookieManager.isLoggingIn = true;
      final response = await ApiService.sendRequest(
        url,
        method: 'POST',
        body: jsonData,
      );
      return response.data;
    } catch (e) {
      debugPrint('login error: $e');
    } finally {
      CookieManager.isLoggingIn = false;
    }
    return null;
  }

  /// 获取用户信息
  static Future<User?> getUserInfo() async {
    try {
      final url = '/v/course_meta/user_info';

      final response = await ApiService.sendRequest(url);

      final userProfile = response.data['data']['user_profile'];
      final user = User(
        uid: userProfile['user_id']?.toString() ?? '',
        name: userProfile['name'] ?? '未知用户',
        avatar: userProfile['avatar'].isNotEmpty
            ? userProfile['avatar']
            : (userProfile['avatar_96'] ?? ''), // avatar_96为默认头像
        phone: userProfile['phone_number'] ?? '未知手机号',
        school: userProfile['school'] ?? '未知学校',
        platform: 'rainClassroom',
      );
      return user;
    } catch (e) {
      debugPrint('getUserInfo error: $e');
    }
    return null;
  }

  /// 获取微信登录二维码的UUID和state
  static Future<List<String>?> getQRCodeUuid() async {
    try {
      final authParamUrl = '/api/v3/user/login/wechat-auth-param';
      var response = await ApiService.sendRequest(
        authParamUrl,
        method: 'POST',
        body: {},
      );
      final data = response.data['data'];

      final qrConnectUrl = 'https://open.weixin.qq.com/connect/qrconnect';
      final String state = data['state'];
      final params = {
        'appid': data['appId'] as String,
        'scope': 'snsapi_login',
        'redirect_uri':
            '${data['redirectUri']}?path=%2Fauthorize%2Fwx-qrlogin%3Fsuccess%3D1',
        'state': state,
        'login_type': 'jssdk',
        'self_redirect': 'true',
        'f': 'xml', // 如果没有则输出html
      };
      response = await ApiService.sendRequest(
        qrConnectUrl,
        params: params,
        responseType: ResponseType.plain,
      );

      final xml = response.data;
      final uuidRegex = RegExp(
        r'<uuid><!\[CDATA\[(.+?)\]\]></uuid>',
        dotAll: true,
      );
      final uuidMatch = uuidRegex.firstMatch(xml);

      if (uuidMatch != null) {
        return [uuidMatch.group(1)!, state];
      }
    } catch (e) {
      debugPrint('getQRCodeUuid error: $e');
    }
    return null;
  }

  /// 检查微信二维码授权状态
  static Future<String?> checkQRAuthStatus(String uuid, String state) async {
    try {
      final connectUrl =
          'https://lp.open.weixin.qq.com/connect/l/qrconnect?uuid=$uuid';

      var response = await ApiService.sendRequest(
        connectUrl,
        responseType: ResponseType.plain,
      ); // 服务端在15秒后响应

      final html = response.data;
      final errorCodeRegex = RegExp(r'window\.wx_errcode=(\d+)');
      final codeRegex = RegExp(r"window\.wx_code='(.+?)'");

      final errorCodeMatch = errorCodeRegex.firstMatch(html);
      final codeMatch = codeRegex.firstMatch(html);

      if (errorCodeMatch != null) {
        final errorCode = errorCodeMatch.group(1);

        if (errorCode == '405') {
          // 已授权
          if (codeMatch != null) {
            final callbackUrl = '/api/v3/user/login/wechat-web-callback';
            final params = {
              'path': '/authorize/wx-qrlogin?success=1',
              'code': codeMatch.group(1)!,
              'state': state,
            };
            CookieManager.isLoggingIn = true;
            await ApiService.sendRequest(
              callbackUrl,
              params: params,
              responseType: ResponseType.plain,
            );
            // 重定向到 authorize/wx-qrlogin?success=1
            CookieManager.isLoggingIn = false;
          }
        }
        return errorCode;
      }
    } catch (e) {
      debugPrint('checkQRAuthStatus error: $e');
    }
    return null;
  }
}

class KTLoginApi {
  static const String _loginKey = 'ktp4567890123456';

  static Future<Map<String, dynamic>?> loginPassword(
    String account,
    String password,
    String verifyCode,
  ) async {
    try {
      final requestBody = {
        'mobile': account,
        'password': EncryptionUtil.aesCbcEncrypt(password, _loginKey),
        'encryption': '1',
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
        'email': account,
        'type': 'login',
        'remember': '0',
        'code': verifyCode,
      };

      final response = await ApiService.sendRequest(
        '/UserApi/login',
        method: 'POST',
        body: requestBody,
      );
      return response.data;
    } catch (e) {
      debugPrint('KTLoginApi.loginPassword error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> loginByMobile(
    String account,
    String verifyCode,
  ) async {
    try {
      final requestBody = {
        'mobile': account,
        'code': verifyCode,
        'type': 'login',
        'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await ApiService.sendRequest(
        '/UserApi/loginByMobile',
        method: 'POST',
        body: requestBody,
      );
      return response.data;
    } catch (e) {
      debugPrint('KTLoginApi.loginByMobile error: $e');
    }
    return null;
  }

  static Future<Uint8List?> getCaptchaImage(String sessionId) async {
    try {
      final response = await ApiService.sendRequest(
        '/UserApi/verify',
        method: 'GET',
        params: {'sessionid': sessionId},
        responseType: ResponseType.bytes,
      );

      final data = response.data;
      if (data is List<int>) {
        return Uint8List.fromList(data);
      }
      if (data is Uint8List) {
        return data;
      }
    } catch (e) {
      debugPrint('KTLoginApi.getCaptchaImage error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> sendCaptcha(
    String phone, {
    String? verify,
    String? sessionId,
  }) async {
    try {
      final body = <String, dynamic>{'mobile': phone, 'type': 'login'};

      if (verify != null && verify.trim().isNotEmpty) {
        body['verify'] = verify.trim();
      }
      if (sessionId != null && sessionId.trim().isNotEmpty) {
        body['sessionid'] = sessionId.trim();
      }

      final response = await ApiService.sendRequest(
        '/UserApi/sendCode',
        method: 'POST',
        body: body,
      );
      return response.data;
    } catch (e) {
      debugPrint('KTLoginApi.sendCaptcha error: $e');
    }
    return null;
  }

  static Future<User?> getUserInfo(String token, {String? fallbackUid}) async {
    try {
      final body = {'reqtimestamp': DateTime.now().millisecondsSinceEpoch};
      final basinResponse = await ApiService.sendRequest(
        '/UserApi/getUserBasinInfo',
        method: 'POST',
        body: body,
        headers: {'token': token},
      );
      final userResponse = await ApiService.sendRequest(
        '/UserApi/getUserInfo',
        method: 'POST',
        body: body,
        headers: {'token': token},
      );

      final basinData = basinResponse.data['data'] ?? {};
      final userData = userResponse.data['data'] ?? {};

      return User(
        uid: basinData['uid']?.toString() ?? fallbackUid ?? '',
        name:
            userData['username']?.toString() ??
            basinData['username']?.toString() ??
            '未知用户',
        avatar:
            userData['avatar']?.toString() ??
            basinData['avatar']?.toString() ??
            '',
        phone: basinData['mobile']?.toString() ?? '未知手机号',
        school:
            userData['school']?.toString() ??
            basinData['school']?.toString() ??
            '未知学校',
        platform: 'ketangpai',
        token: token,
      );
    } catch (e) {
      debugPrint('KTLoginApi.getUserInfo error: $e');
    }
    return null;
  }
}

class TCLoginApi {
  static const _identityAuthUrl =
      'https://identity.guet.edu.cn/auth/realms/guet/protocol/openid-connect/auth';
  static const _tokenUrl =
      'https://identity.guet.edu.cn/auth/realms/guet/protocol/openid-connect/token';
  static final List<String> _loginTrace = <String>[];

  static void _resetTrace() {
    _loginTrace
      ..clear()
      ..add('[TC] 开始畅课登录链路');
  }

  static void _trace(String message) {
    _loginTrace.add(message);
    if (_loginTrace.length > 80) {
      _loginTrace.removeAt(0);
    }
    debugPrint(message);
  }

  static String get lastLoginTrace => _loginTrace.join('\n');

  static Map<String, String> _authQueryParams() {
    return {
      'scope': 'openid',
      'response_type': 'code',
      'redirect_uri': 'https://mobile.guet.edu.cn/cas-callback?_h5=true',
      'client_id': 'TronClassH5',
      'autologin': 'true',
    };
  }

  static Uri buildAuthUri() {
    return Uri.parse(
      _identityAuthUrl,
    ).replace(queryParameters: _authQueryParams());
  }

  static Uri buildPortalSessionBootstrapUri(String sessionId) {
    final base = Uri.parse(PlatformManager().tronclassBaseUrl);
    return base.replace(
      path: '/api/login',
      queryParameters: {
        'login': 'session_id',
        'session_id': sessionId,
        'org_id': '1',
      },
    );
  }

  static bool _isReAuthUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.contains('/authserver/reauthcheck/reauthloginview.do') ||
        lower.contains('ismultifactor=true') ||
        lower.contains('reauthcheck');
  }

  static bool _looksLikeReAuthHtml(dynamic htmlContent) {
    final html = htmlContent?.toString().toLowerCase() ?? '';
    if (html.isEmpty) {
      return false;
    }
    return html.contains('reauthsubmit.do') ||
        html.contains('ismultifactor=true') ||
        html.contains('多因子认证') ||
        html.contains('dynamiccode') ||
        html.contains('reauthdynamiccodetype');
  }

  static bool _isReAuthResponse(Response response) {
    return _isReAuthUrl(response.requestOptions.uri.toString()) ||
        _isReAuthUrl(response.headers.value('location')) ||
        _looksLikeReAuthHtml(response.data);
  }

  static bool _isCasLoginUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.contains('cas.guet.edu.cn/authserver/login');
  }

  static Future<String?> _buildCasCookieHeader() async {
    try {
      final jar = CookieManager.getTempCookieJar();
      if (jar == null) {
        return null;
      }

      final probes = <Uri>[
        Uri.parse('https://cas.guet.edu.cn/'),
        Uri.parse('https://cas.guet.edu.cn/authserver/login'),
        Uri.parse(
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do',
        ),
        Uri.parse(
          'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthSubmit.do',
        ),
        Uri.parse(
          'https://cas.guet.edu.cn/authserver/dynamicCode/getDynamicCodeByReauth.do',
        ),
        Uri.parse('https://identity.guet.edu.cn/'),
        Uri.parse('https://guet.edu.cn/'),
      ];

      final merged = <String, String>{};
      for (final probe in probes) {
        final cookies = await jar.loadForRequest(probe);
        for (final cookie in cookies) {
          if (cookie.name.isEmpty) {
            continue;
          }
          merged[cookie.name] = cookie.value;
        }
      }

      if (merged.isEmpty) {
        return null;
      }

      final names = merged.keys.join(',');
      _trace('[TC][cookie] cas header cookies=[$names]');
      return merged.entries.map((e) => '${e.key}=${e.value}').join('; ');
    } catch (e) {
      _trace('[TC][cookie] build failed=$e');
      return null;
    }
  }

  static String? _extractReauthEntryUrl(
    Response response, {
    String? service,
  }) {
    if (service != null && service.isNotEmpty) {
      return 'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
    }

    final location = response.headers.value('location');
    if (location != null && location.isNotEmpty) {
      final resolved = _resolveUrlWithBase(response.requestOptions.uri, location);
      if (_isReAuthUrl(resolved)) {
        return resolved;
      }
    }

    final htmlRedirect = _resolveUrlWithBase(
      response.requestOptions.uri,
      _extractRedirectUrlFromHtml(response.data),
    );
    if (_isReAuthUrl(htmlRedirect)) {
      return htmlRedirect;
    }

    final current = response.requestOptions.uri.toString();
    if (_isReAuthUrl(current)) {
      return current;
    }

    final html = response.data?.toString() ?? '';
    final reauthRegex = RegExp(
      r'''https?://[^\s'"]+/authserver/reAuthCheck/reAuthLoginView\.do\?[^\s'"]+''',
      caseSensitive: false,
    );
    final reauthMatch = reauthRegex.firstMatch(html);
    final reauthUrl = reauthMatch?.group(0);
    if (reauthUrl != null && reauthUrl.isNotEmpty) {
      return reauthUrl;
    }
    return null;
  }

  static Map<String, dynamic>? _tryParseJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }

    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      // non-json response
    }

    try {
      // 兼容 jsonp / 包裹文本：例如 callback({...}) 或前后拼接文本
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final candidate = text.substring(start, end + 1);
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      }
    } catch (_) {
      // keep null on parse failure
    }
    return null;
  }

  static Future<Map<String, dynamic>> _sendDynamicCodeWithContext(
    String username, {
    String? reauthEntryUrl,
    String? service,
  }) async {
    final url =
        'https://cas.guet.edu.cn/authserver/dynamicCode/getDynamicCodeByReauth.do';
    final form = {
      'userName': username,
      'authCodeTypeName': 'reAuthDynamicCodeType',
      if (service != null && service.isNotEmpty) 'service': service,
      'isMultifactor': 'true',
    };

    final casCookieHeader = await _buildCasCookieHeader();
    final derivedReauthUrl =
        reauthEntryUrl ??
        (service != null && service.isNotEmpty
            ? 'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}'
            : null);

    if (reauthEntryUrl == null && derivedReauthUrl != null) {
      _trace('[TC][dynamicCode] derived reauthEntryUrl from service=$derivedReauthUrl');
    }

    // 先回打一次 reAuth 页面，尽量让 CAS 在当前会话里完成多因子上下文绑定。
    final warmupUrl = derivedReauthUrl;
    Future<void> warmupReauth({required bool followRedirects}) async {
      if (warmupUrl == null || warmupUrl.isEmpty) {
        return;
      }
      try {
        final warmHeaders = <String, String>{
          'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'origin': 'https://cas.guet.edu.cn',
          if (service != null && service.isNotEmpty)
            'referer': 'https://cas.guet.edu.cn/authserver/login?service=${Uri.encodeQueryComponent(service)}',
          if (casCookieHeader != null && casCookieHeader.isNotEmpty)
            'cookie': casCookieHeader,
        };
        final warm = await ApiService.sendRequest(
          warmupUrl,
          headers: warmHeaders,
          responseType: ResponseType.plain,
          allowRedirects: followRedirects,
        );
        final location = warm.headers.value('location') ?? '';
        _trace(
          '[TC][dynamicCode][warmup] follow=$followRedirects status=${warm.statusCode} uri=${warm.requestOptions.uri} location=$location',
        );
      } catch (e) {
        _trace('[TC][dynamicCode][warmup] failed=$e');
      }
    }

    await warmupReauth(followRedirects: false);

    final extraHeaders = <String, String>{
      'content-type': 'application/x-www-form-urlencoded',
      'accept': 'application/json, text/javascript, */*; q=0.01',
      'x-requested-with': 'XMLHttpRequest',
      'origin': 'https://cas.guet.edu.cn',
      if (warmupUrl != null && warmupUrl.isNotEmpty) 'referer': warmupUrl,
      if (casCookieHeader != null && casCookieHeader.isNotEmpty)
        'cookie': casCookieHeader,
    };

    bool sawLoginRedirect = false;

    Future<Map<String, dynamic>?> runAttempts(int round) async {
      final attempts = <Future<Response>>[
        ApiService.sendRequest(
          url,
          method: 'POST',
          headers: extraHeaders,
          body: form,
          responseType: ResponseType.plain,
          allowRedirects: false,
        ),
        ApiService.sendRequest(
          url,
          method: 'POST',
          headers: extraHeaders,
          body: form,
          responseType: ResponseType.plain,
          allowRedirects: true,
        ),
        ApiService.sendRequest(
          url,
          method: 'GET',
          params: {
            'userName': username,
            'authCodeTypeName': 'reAuthDynamicCodeType',
            if (service != null && service.isNotEmpty) 'service': service,
            'isMultifactor': 'true',
          },
          headers: {
            'accept': 'application/json, text/javascript, */*; q=0.01',
            'x-requested-with': 'XMLHttpRequest',
            if (warmupUrl != null && warmupUrl.isNotEmpty)
              'referer': warmupUrl,
            if (casCookieHeader != null && casCookieHeader.isNotEmpty)
              'cookie': casCookieHeader,
          },
          responseType: ResponseType.plain,
          allowRedirects: true,
        ),
      ];

      for (int i = 0; i < attempts.length; i++) {
        final resp = await attempts[i];
        final parsed = _tryParseJsonMap(resp.data);
        if (parsed != null) {
          final parsedCode = parsed['code']?.toString();
          final parsedStatus = parsed['status']?.toString();
          final parsedRes = parsed['res']?.toString();
          final parsedResult = parsed['result']?.toString();
          final parsedMsg = (parsed['returnMessage'] ?? parsed['msg'] ?? parsed['message'])
              ?.toString();
          _trace(
            '[TC][dynamicCode][round=${round + 1} try=${i + 1}] status=${resp.statusCode} parsed=ok code=$parsedCode statusField=$parsedStatus res=$parsedRes result=$parsedResult msg=${parsedMsg ?? ''}',
          );
          return parsed;
        }

        final location = resp.headers.value('location') ?? '';
        final body = resp.data?.toString() ?? '';
        final lowerBody = body.toLowerCase();
        final bodySnippet = body.replaceAll('\n', ' ');
        _trace(
          '[TC][sendDynamicCode][round=${round + 1} try=${i + 1}] status=${resp.statusCode} location=$location body=${bodySnippet.substring(0, bodySnippet.length > 160 ? 160 : bodySnippet.length)}',
        );

        final redirectedToLogin =
            location.toLowerCase().contains('authserver/login') ||
            lowerBody.contains('帐号登录或动态码登录') ||
            lowerBody.contains('账号登录或动态码登录') ||
            lowerBody.contains('id="casloginform"') ||
            lowerBody.contains("id='casloginform'");
        if (redirectedToLogin) {
          sawLoginRedirect = true;
          continue;
        }
      }
      return null;
    }

    final firstRound = await runAttempts(0);
    if (firstRound != null) {
      return firstRound;
    }

    if (sawLoginRedirect && warmupUrl != null && warmupUrl.isNotEmpty) {
      _trace('[TC][dynamicCode] 检测到登录页回落，尝试重建 reAuth 上下文后重试');
      await warmupReauth(followRedirects: true);
      final secondRound = await runAttempts(1);
      if (secondRound != null) {
        return secondRound;
      }
    }

    if (sawLoginRedirect) {
      return {
        'res': 'fail',
        'returnMessage': '动态码服务需要有效登录态，请返回后重新发起畅课登录',
        'mobile': '',
      };
    }

    return {
      'res': 'fail',
      'returnMessage': '动态码服务返回异常，请稍后重试',
      'mobile': '',
    };
  }

  static Future<Map<String, dynamic>> _reAuthCheck(
    String code, {
    String? service,
  }) async {
    final casCookieHeader = await _buildCasCookieHeader();
    final resp = await ApiService.sendRequest(
      'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthSubmit.do',
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        'accept': 'application/json, text/javascript, */*; q=0.01',
        'x-requested-with': 'XMLHttpRequest',
        if (service != null && service.isNotEmpty)
          'referer': 'https://cas.guet.edu.cn/authserver/reAuthCheck/reAuthLoginView.do?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}',
        if (casCookieHeader != null && casCookieHeader.isNotEmpty)
          'cookie': casCookieHeader,
      },
      body: {
        'service': service ?? '',
        'reAuthType': 3,
        'isMultifactor': true,
        'password': '',
        'dynamicCode': code,
        'uuid': '',
        'answer1': '',
        'answer2': '',
        'otpCode': '',
        'skipTmpReAuth': true,
      },
      responseType: ResponseType.json,
      allowRedirects: false,
    );

    final parsed = _tryParseJsonMap(resp.data);
    if (parsed != null) {
      _trace('[TC][reAuthCheck] status=${resp.statusCode} parsed=ok code=${parsed['code']}');
      return parsed;
    }
    _trace('[TC][reAuthCheck] invalid response: ${resp.data}');
    return {'code': 'reAuth_failed', 'msg': '动态码验证服务返回异常'};
  }

  static Future<Map<String, dynamic>> _handleMfaChallenge(
    String username, {
    Future<String?> Function(String? mobileHint, String? tip)? mfaCodeProvider,
    String? reauthEntryUrl,
    String? service,
  }) async {
    if (mfaCodeProvider == null) {
      return {
        'ok': false,
        'requireMfa': true,
        'message': '当前账号需要多因子动态验证码，请输入短信动态码后重试。',
      };
    }

    final dynamicCodeInfo = await _sendDynamicCodeWithContext(
      username,
      reauthEntryUrl: reauthEntryUrl,
      service: service,
    );

    final mobileHint =
      dynamicCodeInfo['mobile']?.toString() ??
      dynamicCodeInfo['phone']?.toString() ??
      dynamicCodeInfo['mobileMask']?.toString() ??
      dynamicCodeInfo['mobilePhone']?.toString();
    final tip =
      dynamicCodeInfo['returnMessage']?.toString() ??
      dynamicCodeInfo['msg']?.toString() ??
      dynamicCodeInfo['message']?.toString();

    final codeField = dynamicCodeInfo['code']?.toString().toLowerCase();
    final statusField = dynamicCodeInfo['status']?.toString().toLowerCase();
    final resField = dynamicCodeInfo['res']?.toString().toLowerCase();
    final resultField = dynamicCodeInfo['result']?.toString().toLowerCase();

    final codeSuccess =
      codeField == '0' || codeField == '200' || codeField == 'success';
    final statusSuccess =
      statusField == '0' ||
      statusField == '200' ||
      statusField == 'true' ||
      statusField == 'success';
    final resultSuccess =
      resultField == '0' ||
      resultField == '200' ||
      resultField == 'true' ||
      resultField == 'success';
    final sendOk =
      resField == 'success' ||
      resField == '0' ||
      resField == '200' ||
      codeSuccess ||
      statusSuccess ||
      resultSuccess ||
        (tip?.contains('已发送') ?? false);

    _trace(
      '[TC][dynamicCode] decision sendOk=$sendOk code=$codeField status=$statusField res=$resField result=$resultField tip=${tip ?? ''}',
    );

    if (!sendOk) {
      final message =
          (tip?.isNotEmpty == true ? tip : '动态码服务返回异常，请稍后重试')!;
      return {
        'ok': false,
        'message': message,
        'debug': lastLoginTrace,
      };
    }

    final mfaCode = await mfaCodeProvider(mobileHint, tip);
    if (mfaCode == null || mfaCode.trim().isEmpty) {
      return {
        'ok': false,
        'cancelledMfa': true,
        'message': '短信动态码已发送，但你取消了输入；请重新发起畅课登录后再验证',
        'debug': lastLoginTrace,
      };
    }

    final mfaResult = await _reAuthCheck(mfaCode.trim(), service: service);
    if (mfaResult['code']?.toString() != 'reAuth_success') {
      return {
        'ok': false,
        'message': (mfaResult['msg'] ?? '动态码验证失败').toString(),
        'debug': lastLoginTrace,
      };
    }

    final authAfterMfaResp = await ApiService.sendRequest(
      _identityAuthUrl,
      params: _authQueryParams(),
      responseType: ResponseType.plain,
      allowRedirects: true,
    );

    final codeAfterMfa =
        _extractAuthCode(authAfterMfaResp) ??
        authAfterMfaResp.requestOptions.uri.queryParameters['code'];
    if (codeAfterMfa == null || codeAfterMfa.isEmpty) {
      return {
        'ok': false,
        'message': '动态码验证成功，但未获取到畅课授权码',
        'debug': lastLoginTrace,
      };
    }

    return completeWithAuthCode(codeAfterMfa);
  }

  static Future<Map<String, dynamic>> completeWithAuthCode(String code) async {
    try {
      CookieManager.isLoggingIn = true;

      final tokenResp = await ApiService.sendRequest(
        _tokenUrl,
        method: 'POST',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': 'TronClassH5',
          'redirect_uri': 'https://mobile.guet.edu.cn/cas-callback?_h5=true',
          'code': code,
          'grant_type': 'authorization_code',
          'scope': 'openid',
        },
      );
      final accessToken = tokenResp.data['access_token'];
      if (accessToken == null || accessToken.toString().isEmpty) {
        return {'ok': false, 'message': '未获取到畅课访问令牌'};
      }

      final loginDesktopResp = await ApiService.sendRequest(
        '${PlatformManager().tronclassBaseUrl}/api/login?login=access_token',
        method: 'POST',
        body: {'access_token': accessToken, 'org_id': 1},
      );
      final sessionId = loginDesktopResp.headers.value('x-session-id');
      if (sessionId == null || sessionId.isEmpty) {
        return {'ok': false, 'message': '未获取到畅课会话ID'};
      }

      return {'ok': true, 'sessionId': sessionId};
    } catch (e) {
      debugPrint('tronclass auth completion error: $e');
      return {'ok': false, 'message': '畅课登录失败：$e'};
    } finally {
      CookieManager.isLoggingIn = false;
    }
  }

  static Future<bool> bootstrapPortalSession({String? sessionId}) async {
    try {
      final sid = sessionId?.trim();
      if (sid == null || sid.isEmpty) {
        return false;
      }

      final baseUrl = PlatformManager().tronclassBaseUrl;
      final probes = <Map<String, dynamic>>[
        {
          'url': '$baseUrl/api/login?login=session_id',
          'method': 'POST',
          'body': {'session_id': sid, 'org_id': 1},
        },
        {
          'url': '$baseUrl/api/login?login=session_id',
          'method': 'POST',
          'body': {'org_id': 1},
        },
        {'url': '$baseUrl/api/users/me', 'method': 'GET', 'body': null},
      ];

      for (final probe in probes) {
        try {
          final response = await ApiService.sendRequest(
            probe['url'].toString(),
            method: probe['method'].toString(),
            body: probe['body'],
          );

          final setCookie = response.headers['set-cookie'];
          if (setCookie != null && setCookie.isNotEmpty) {
            return true;
          }

          final data = response.data;
          if (response.statusCode != null &&
              response.statusCode! >= 200 &&
              response.statusCode! < 400) {
            if (data is! Map<String, dynamic>) {
              return true;
            }
            final ok =
                data['success'] == true ||
                data['ok'] == true ||
                data['result'] == true ||
                data['code'] == 0 ||
                data['code'] == '0';
            if (ok) {
              return true;
            }
          }
        } catch (_) {
          // continue probing
        }
      }
    } catch (_) {
      // ignore bootstrap errors
    }

    return false;
  }

  static Future<User?> getUserInfo({String? fallbackUid}) async {
    final candidates = <String>[
      '/api/users/me',
      '/api/user/me',
      '/api/user/profile',
      '/api/user',
      '/api/me',
    ];

    for (final endpoint in candidates) {
      try {
        final response = await ApiService.sendRequest(endpoint);
        final user = _parseTronclassUserFromPayload(
          response.data,
          fallbackUid: fallbackUid,
        );
        if (user != null) {
          return user;
        }
      } catch (_) {
        // ignore and continue probing
      }
    }

    return null;
  }

  static User? _parseTronclassUserFromPayload(
    dynamic payload, {
    String? fallbackUid,
  }) {
    Map<String, dynamic>? data;

    if (payload is Map<String, dynamic>) {
      if (payload['data'] is Map<String, dynamic>) {
        data = payload['data'] as Map<String, dynamic>;
      } else if (payload['user'] is Map<String, dynamic>) {
        data = payload['user'] as Map<String, dynamic>;
      } else {
        data = payload;
      }
    }

    if (data == null) {
      return null;
    }

    final uid =
        (data['id'] ??
                data['user_id'] ??
                data['uid'] ??
                data['account'] ??
                fallbackUid)
            ?.toString();
    if (uid == null || uid.isEmpty) {
      return null;
    }

    final name =
        (data['name'] ??
                data['real_name'] ??
                data['nickname'] ??
                data['username'] ??
                uid)
            .toString();
    final avatar = (data['avatar'] ?? data['avatar_url'] ?? '').toString();
    final phone =
        (data['mobile'] ?? data['phone'] ?? data['phone_number'] ?? '未知手机号')
            .toString();
    final school = (data['school'] ?? data['org_name'] ?? '桂林电子科技大学')
        .toString();

    return User(
      uid: uid,
      name: name,
      avatar: avatar,
      phone: phone,
      school: school,
      platform: 'tronclass',
    );
  }

  static String? _extractAuthCode(Response response) {
    final codeFromRealUri = response.realUri.queryParameters['code'];
    if (codeFromRealUri != null && codeFromRealUri.isNotEmpty) {
      return codeFromRealUri;
    }

    final location = response.headers.value('location');
    if (location != null && location.isNotEmpty) {
      try {
        return Uri.parse(location).queryParameters['code'];
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _extractService(Response response) {
    final fromRealUri = response.realUri.queryParameters['service'];
    if (fromRealUri != null && fromRealUri.isNotEmpty) {
      return fromRealUri;
    }

    final fromRequestUri =
        response.requestOptions.uri.queryParameters['service'];
    if (fromRequestUri != null && fromRequestUri.isNotEmpty) {
      return fromRequestUri;
    }

    final location = response.headers.value('location');
    if (location != null && location.isNotEmpty) {
      try {
        final parsedLocation = Uri.parse(location);
        final resolvedLocation = parsedLocation.hasScheme
            ? parsedLocation
            : response.realUri.resolveUri(parsedLocation);
        final fromLocation = resolvedLocation.queryParameters['service'];
        if (fromLocation != null && fromLocation.isNotEmpty) {
          return fromLocation;
        }
      } catch (_) {
        // ignore parse error
      }
    }
    return null;
  }

  static String? _extractServiceFromRawUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return null;
    }
    try {
      final parsed = Uri.parse(rawUrl);
      final direct = parsed.queryParameters['service'];
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }
    } catch (_) {
      // ignore parse error and fallback to regex
    }

    final serviceRegex = RegExp(r'[?&]service=([^&]+)');
    final match = serviceRegex.firstMatch(rawUrl);
    if (match == null) {
      return null;
    }
    final encoded = match.group(1);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return Uri.decodeQueryComponent(encoded);
    } catch (_) {
      return encoded;
    }
  }

  static String? _extractServiceFromHtml(dynamic htmlContent) {
    try {
      final doc = html_parser.parse(htmlContent.toString());

      // 常见场景1：隐藏字段中直接带 service
      final input = doc.querySelector('input[name="service"]');
      final value = input?.attributes['value'];
      if (value != null && value.isNotEmpty) {
        return value;
      }

      // 常见场景2：登录表单 action 上带 service 参数
      final form =
          doc.querySelector('form#casLoginForm') ?? doc.querySelector('form');
      final action = form?.attributes['action'];
      if (action != null && action.isNotEmpty) {
        final actionUri = Uri.parse(action);
        final actionService = actionUri.queryParameters['service'];
        if (actionService != null && actionService.isNotEmpty) {
          return actionService;
        }
      }

      // 常见场景3：页面脚本里存在 var service = ["..."]
      final html = htmlContent.toString();
      final scriptServiceRegex = RegExp(
        r'''var\s+service\s*=\s*\[\s*"([^"]+)"\s*\]''',
        caseSensitive: false,
      );
      final serviceMatch = scriptServiceRegex.firstMatch(html);
      final rawService = serviceMatch?.group(1);
      if (rawService != null && rawService.isNotEmpty) {
        final unescaped = rawService.replaceAll(r'\/', '/');
        return Uri.decodeFull(unescaped);
      }
    } catch (_) {
      // ignore parse error
    }
    return null;
  }

  static String? _extractRedirectUrlFromHtml(dynamic htmlContent) {
    final html = htmlContent?.toString() ?? '';
    if (html.isEmpty) {
      return null;
    }

    // window.location='...'
    final locationRegex = RegExp(
      r'''window\.location(?:\.href)?\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    );
    final locationMatch = locationRegex.firstMatch(html);
    final locationUrl = locationMatch?.group(1);
    if (locationUrl != null && locationUrl.isNotEmpty) {
      return locationUrl;
    }

    // meta refresh
    final refreshRegex = RegExp(
      r'''http-equiv=['"]refresh['"][^>]*content=['"][^'"]*url=([^'">]+)''',
      caseSensitive: false,
    );
    final refreshMatch = refreshRegex.firstMatch(html);
    final refreshUrl = refreshMatch?.group(1);
    if (refreshUrl != null && refreshUrl.isNotEmpty) {
      return refreshUrl.trim();
    }

    // fallback: scan authserver/login link in html
    final authserverRegex = RegExp(
      r'''https?://[^\s'"]+/authserver/login\?[^\s'"]+''',
      caseSensitive: false,
    );
    final authserverMatch = authserverRegex.firstMatch(html);
    final authserverUrl = authserverMatch?.group(0);
    if (authserverUrl != null && authserverUrl.isNotEmpty) {
      return authserverUrl;
    }

    return null;
  }

  static String? _resolveUrlWithBase(Uri base, String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final parsed = Uri.parse(raw);
      return (parsed.hasScheme ? parsed : base.resolveUri(parsed)).toString();
    } catch (_) {
      return null;
    }
  }

  static String? _extractLoginErrorTip(dynamic htmlContent) {
    try {
      final doc = html_parser.parse(htmlContent.toString());
      final errorTip = doc.querySelector('#showErrorTip')?.text.trim();
      if (errorTip != null && errorTip.isNotEmpty) {
        return errorTip;
      }
    } catch (_) {
      // ignore parse error
    }
    return null;
  }

  static Map<String, String?> _parseLoginHtml(String html) {
    final doc = html_parser.parse(html);

    String? extractFieldValue(String fieldName) {
      final selectors = <String>[
        '#$fieldName',
        'input#$fieldName',
        'input[name="$fieldName"]',
        "input[name='$fieldName']",
        '[name="$fieldName"]',
        "[name='$fieldName']",
      ];

      for (final selector in selectors) {
        final element = doc.querySelector(selector);
        final value = element?.attributes['value'];
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }

      final patterns = <RegExp>[
        RegExp(
          r'''(?:var\s+)?FIELD\s*=\s*['"]([^'"]+)['"]'''
              .replaceAll('FIELD', RegExp.escape(fieldName)),
          caseSensitive: false,
        ),
        RegExp(
          r'''name=['"]FIELD['"][^>]*value=['"]([^'"]+)['"]'''
              .replaceAll('FIELD', RegExp.escape(fieldName)),
          caseSensitive: false,
        ),
        RegExp(
          r'''['"]FIELD['"]\s*:\s*['"]([^'"]+)['"]'''
              .replaceAll('FIELD', RegExp.escape(fieldName)),
          caseSensitive: false,
        ),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(html);
        final value = match?.group(1);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }

      return null;
    }

    final aesKey = extractFieldValue('pwdEncryptSalt');
    final execution = extractFieldValue('execution');
    return {'aesKey': aesKey, 'execution': execution};
  }

  static String _encryptPassword(String password, List<int> key) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw ArgumentError('Key must be 16, 24, or 32 bytes long');
    }

    final random = Random.secure();
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final randomStr = List.generate(
      64,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    final plaintext = randomStr + password;
    final encryptKey = encrypt_pkg.Key(Uint8List.fromList(key));
    final ivKey = encrypt_pkg.IV(iv);
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(
        encryptKey,
        mode: encrypt_pkg.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );
    return encrypter.encrypt(plaintext, iv: ivKey).base64;
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    Future<String?> Function(Uint8List imageBytes)? captchaProvider,
    Future<String?> Function(String? mobileHint, String? tip)? mfaCodeProvider,
  }) async {
    try {
      _resetTrace();
      CookieManager.isLoggingIn = true;
      _trace('[TC] 请求 identity auth');

      final authResp = await ApiService.sendRequest(
        _identityAuthUrl,
        params: _authQueryParams(),
        responseType: ResponseType.plain,
        allowRedirects: true,
      );

      final redirectUri = authResp.requestOptions.uri;
      String? code =
          _extractAuthCode(authResp) ?? redirectUri.queryParameters['code'];
      String? service =
          _extractService(authResp) ?? _extractServiceFromHtml(authResp.data);
      service ??= _extractServiceFromRawUrl(
        authResp.requestOptions.uri.toString(),
      );
      _trace('[TC] authResp uri=${authResp.requestOptions.uri} code=${code != null} service=${service != null && service.isNotEmpty}');
      String probeUriInfo = authResp.requestOptions.uri.toString();

      if (code == null || code.isEmpty) {
        String? aesKey;
        String? execution;
        Uri loginSubmitUri = Uri.parse('https://cas.guet.edu.cn/authserver/login');

        // 优先复用首跳链路落到的 CAS 登录页，避免二次拼接 service 导致参数失真。
        if (_isCasLoginUrl(authResp.requestOptions.uri.toString())) {
          final parsedFromAuth = _parseLoginHtml(authResp.data.toString());
          final candidateAesKey = parsedFromAuth['aesKey'];
          final candidateExecution = parsedFromAuth['execution'];
          if (candidateAesKey != null && candidateExecution != null) {
            aesKey = candidateAesKey;
            execution = candidateExecution;
            loginSubmitUri = authResp.requestOptions.uri;
            _trace('[TC] 首跳已拿到 aesKey/execution');
          }
        }

        if (service == null || service.isEmpty) {
          // Keycloak broker 场景：首跳可能停在 /broker/cas-client/login，需要继续跟进 HTML/JS 跳转。
          final visited = <String>{authResp.requestOptions.uri.toString()};
          Response currentResp = authResp;

          for (int i = 0; i < 3 && (service == null || service.isEmpty); i++) {
            final htmlRedirectUrl = _resolveUrlWithBase(
              currentResp.requestOptions.uri,
              _extractRedirectUrlFromHtml(currentResp.data),
            );
            final locationUrl = _resolveUrlWithBase(
              currentResp.requestOptions.uri,
              currentResp.headers.value('location'),
            );
            final candidates = <String?>[
              htmlRedirectUrl,
              locationUrl,
            ].where((it) => it != null && it.isNotEmpty).toSet().toList();

            bool advanced = false;
            for (final candidate in candidates) {
              if (candidate == null || visited.contains(candidate)) {
                continue;
              }
              visited.add(candidate);

              final chaseResp = await ApiService.sendRequest(
                candidate,
                responseType: ResponseType.plain,
                allowRedirects: true,
              );

              currentResp = chaseResp;
              code =
                  _extractAuthCode(chaseResp) ??
                  chaseResp.requestOptions.uri.queryParameters['code'] ??
                  code;
              service =
                  _extractService(chaseResp) ??
                  _extractServiceFromHtml(chaseResp.data) ??
                  _extractServiceFromRawUrl(
                    chaseResp.requestOptions.uri.toString(),
                  ) ??
                  _extractServiceFromRawUrl(
                    chaseResp.headers.value('location'),
                  );
              probeUriInfo = chaseResp.requestOptions.uri.toString();
              _trace('[TC] chase uri=${chaseResp.requestOptions.uri} code=${code != null} service=${service != null && service.isNotEmpty}');
              advanced = true;
              if (service != null && service.isNotEmpty) {
                break;
              }
            }

            if (!advanced) {
              break;
            }
          }

          if (code != null && code.isNotEmpty) {
            return completeWithAuthCode(code);
          }

          // 与 guethub 一致：先跟随重定向获取 service；若失败再补一次不跟随重定向探测 Location。
          final probeResp = await ApiService.sendRequest(
            _identityAuthUrl,
            params: _authQueryParams(),
            responseType: ResponseType.plain,
            allowRedirects: false,
          );

          code = _extractAuthCode(probeResp) ?? code;
          service =
              _extractService(probeResp) ??
              _extractServiceFromHtml(probeResp.data);
          service ??= _extractServiceFromRawUrl(
            probeResp.headers.value('location'),
          );
          service ??= _extractServiceFromRawUrl(
            probeResp.requestOptions.uri.toString(),
          );
          probeUriInfo =
              probeResp.headers.value('location') ??
              probeResp.requestOptions.uri.toString();
        }

        if ((aesKey == null || execution == null) &&
            (service == null || service.isEmpty)) {
          final webHint = kIsWeb
              ? '（当前为Web调试，浏览器可能拦截跨域重定向；建议用 Windows/Android 运行）'
              : '';
          return {
            'ok': false,
            'debug': lastLoginTrace,
            'message':
                '未获取到畅课登录服务地址（CAS缺少service）$webHint。authUri=${authResp.requestOptions.uri} probeUri=$probeUriInfo',
          };
        }

        if (aesKey == null || execution == null) {
          final loginPageResp = await ApiService.sendRequest(
            'https://cas.guet.edu.cn/authserver/login',
            params: {'service': service!},
            responseType: ResponseType.plain,
            allowRedirects: false,
          );

          Response resolvedLoginResp = loginPageResp;
          for (int i = 0; i < 3; i++) {
            loginSubmitUri = resolvedLoginResp.requestOptions.uri;
            final parsed = _parseLoginHtml(resolvedLoginResp.data.toString());
            aesKey = parsed['aesKey'];
            execution = parsed['execution'];
            if (aesKey != null && execution != null) {
              _trace('[TC] redirect#$i 后拿到 aesKey/execution');
              break;
            }

            final location = resolvedLoginResp.headers.value('location');
            final nextUrl = _resolveUrlWithBase(
              resolvedLoginResp.requestOptions.uri,
              location,
            );
            if (nextUrl == null || nextUrl.isEmpty) {
              break;
            }

            resolvedLoginResp = await ApiService.sendRequest(
              nextUrl,
              responseType: ResponseType.plain,
              allowRedirects: false,
            );
          }
        }

        if (aesKey == null || execution == null) {
          _trace('[TC] 解析参数失败: aesKey/execution 为空');
          return {'ok': false, 'message': '解析畅课登录参数失败', 'debug': lastLoginTrace};
        }

        final checkNeedCaptchaResp = await ApiService.sendRequest(
          'https://cas.guet.edu.cn/authserver/checkNeedCaptcha.htl',
          params: {
            'username': username,
            '_': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          responseType: ResponseType.plain,
          allowRedirects: false,
        );
        final checkNeedCaptcha =
            _tryParseJsonMap(checkNeedCaptchaResp.data) ?? const {};
        _trace('[TC] checkNeedCaptcha=${checkNeedCaptcha.toString()}');
        String captcha = '';
        final needCaptcha =
            checkNeedCaptcha['isNeed'] == true ||
            checkNeedCaptcha['isNeed']?.toString().toLowerCase() == 'true';
        if (needCaptcha) {
          if (captchaProvider == null) {
            return {'ok': false, 'message': '当前账号需图形验证码，但未提供验证码处理器'};
          }

          final captchaImageResp = await ApiService.sendRequest(
            'https://cas.guet.edu.cn/authserver/getCaptcha.htl?${DateTime.now().millisecondsSinceEpoch}',
            responseType: ResponseType.bytes,
            allowRedirects: false,
          );

          final rawData = captchaImageResp.data;
          final Uint8List imageBytes;
          if (rawData is Uint8List) {
            imageBytes = rawData;
          } else if (rawData is List<int>) {
            imageBytes = Uint8List.fromList(rawData);
          } else {
            return {'ok': false, 'message': '获取图形验证码失败'};
          }

          final inputCaptcha = await captchaProvider(imageBytes);
          if (inputCaptcha == null || inputCaptcha.trim().isEmpty) {
            return {'ok': false, 'message': '已取消图形验证码输入'};
          }
          captcha = inputCaptcha.trim();
        }

        Response loginResp = await ApiService.sendRequest(
          loginSubmitUri.toString(),
          method: 'POST',
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          body: {
            'username': username,
            'password': _encryptPassword(password, utf8.encode(aesKey)),
            'rememberMe': true,
            'captcha': captcha,
            '_eventId': 'submit',
            'cllt': 'userNameLogin',
            'dllt': 'generalLogin',
            'lt': '',
            'execution': execution,
          },
          responseType: ResponseType.plain,
          allowRedirects: false,
        );

        code =
            _extractAuthCode(loginResp) ??
            loginResp.requestOptions.uri.queryParameters['code'];

        if ((code == null || code.isEmpty) && _isReAuthResponse(loginResp)) {
          _trace('[TC] 命中多因子认证分支');
          final reauthEntryUrl = _extractReauthEntryUrl(
            loginResp,
            service: service,
          );
          _trace('[TC] reauthEntryUrl=${reauthEntryUrl ?? 'null'}');
          return _handleMfaChallenge(
            username,
            mfaCodeProvider: mfaCodeProvider,
            reauthEntryUrl: reauthEntryUrl,
            service: service,
          );
        }

        if (code == null || code.isEmpty) {
          // CAS在高并发或重定向链波动时，可能已登录但当前响应未携带code，先回探一次授权链路。
          final retryAuthResp = await ApiService.sendRequest(
            _identityAuthUrl,
            params: _authQueryParams(),
            responseType: ResponseType.plain,
            allowRedirects: true,
          );
          final retryCode =
              _extractAuthCode(retryAuthResp) ??
              retryAuthResp.requestOptions.uri.queryParameters['code'];
          if (retryCode != null && retryCode.isNotEmpty) {
            return completeWithAuthCode(retryCode);
          }

          // 极少数情况下服务端未提前声明需要验证码，这里补一次验证码重试，减少误报账号密码错误。
          if (captcha.isEmpty && captchaProvider != null) {
            final captchaImageResp = await ApiService.sendRequest(
              'https://cas.guet.edu.cn/authserver/getCaptcha.htl?${DateTime.now().millisecondsSinceEpoch}',
              responseType: ResponseType.bytes,
              allowRedirects: false,
            );

            final rawData = captchaImageResp.data;
            final Uint8List? imageBytes = switch (rawData) {
              Uint8List data => data,
              List<int> data => Uint8List.fromList(data),
              _ => null,
            };

            if (imageBytes != null) {
              final forcedCaptcha = await captchaProvider(imageBytes);
              if (forcedCaptcha != null && forcedCaptcha.trim().isNotEmpty) {
                loginResp = await ApiService.sendRequest(
                  loginSubmitUri.toString(),
                  method: 'POST',
                  headers: {
                    'content-type': 'application/x-www-form-urlencoded',
                  },
                  body: {
                    'username': username,
                    'password': _encryptPassword(password, utf8.encode(aesKey)),
                    'rememberMe': true,
                    'captcha': forcedCaptcha.trim(),
                    '_eventId': 'submit',
                    'cllt': 'userNameLogin',
                    'dllt': 'generalLogin',
                    'lt': '',
                    'execution': execution,
                  },
                  responseType: ResponseType.plain,
                  allowRedirects: false,
                );

                code =
                    _extractAuthCode(loginResp) ??
                    loginResp.requestOptions.uri.queryParameters['code'];
                if (code != null && code.isNotEmpty) {
                  return completeWithAuthCode(code);
                }

                if (_isReAuthResponse(loginResp)) {
                  final reauthEntryUrl = _extractReauthEntryUrl(
                    loginResp,
                    service: service,
                  );
                  _trace('[TC] retry reauthEntryUrl=${reauthEntryUrl ?? 'null'}');
                  return _handleMfaChallenge(
                    username,
                    mfaCodeProvider: mfaCodeProvider,
                    reauthEntryUrl: reauthEntryUrl,
                    service: service,
                  );
                }
              }
            }
          }

          final loginErrorTip = _extractLoginErrorTip(loginResp.data);
          _trace('[TC] 未获取到授权码，errorTip=${loginErrorTip ?? ''}');
          return {
            'ok': false,
            'message': loginErrorTip ?? '未获取到畅课授权码',
            'debug': lastLoginTrace,
          };
        }
      }

      return completeWithAuthCode(code);
    } catch (e) {
      _trace('[TC] login exception=$e');
      return {'ok': false, 'message': '畅课登录失败：$e', 'debug': lastLoginTrace};
    } finally {
      CookieManager.isLoggingIn = false;
    }
  }
}
