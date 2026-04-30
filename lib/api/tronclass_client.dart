import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:html/parser.dart' as html_parser;
import 'package:encrypt/encrypt.dart' as encrypt_pkg;

import '../session/tronclass_auth.dart';

/// 畅课客户端 - 每用户独立实例管理
/// 借鉴 tronclass_plus 的 ChangkeClient 架构
class TronclassClient {
  TronclassClient._();

  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 micromessenger';

  // 多用户实例管理
  static final Map<String, TronclassClient> _instances = {};

  late final Dio _dio; // 用于 tronclass API
  late final Dio _casDio; // 用于 CAS 认证
  late final CookieJar _cookieJar;
  late final String _userId;
  String? _sessionId;

  Dio get dio => _dio;
  Dio get casDio => _casDio;
  CookieJar get cookieJar => _cookieJar;
  String get userId => _userId;
  String? get sessionId => _sessionId;
  bool get isLoggedIn => _sessionId != null;

  /// 获取按用户 ID 隔离的 CookieJar
  static Future<CookieJar> _getCookieJar(String userId) async {
    if (kIsWeb) {
      return CookieJar();
    }
    final dir = await getApplicationSupportDirectory();
    final cookiePath = path.join(dir.path, 'cookies', 'tronclass', userId);
    return PersistCookieJar(
      storage: FileStorage(cookiePath),
      ignoreExpires: false,
    );
  }

  /// 获取实例（按用户 ID 管理）
  static Future<TronclassClient> getInstance(String userId) async {
    if (_instances[userId] == null) {
      final instance = TronclassClient._();
      instance._userId = userId;
      instance._cookieJar = await _getCookieJar(userId);

      // 创建主 Dio 实例（用于 tronclass API）
      instance._dio = Dio(
        BaseOptions(
          baseUrl: 'https://courses.guet.edu.cn',
          headers: {'User-Agent': _userAgent},
          followRedirects: false,
          validateStatus: (status) => status != null,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      )..interceptors.addAll([
          _TronclassCookieInterceptor(instance._cookieJar),
          _TronclassAuthInterceptor(() => instance._sessionId),
        ]);

      // 创建 CAS Dio 实例（用于 CAS 认证）
      instance._casDio = Dio(
        BaseOptions(
          baseUrl: 'https://cas.guet.edu.cn/',
          headers: {'User-Agent': _userAgent},
          followRedirects: false,
          validateStatus: (status) => status != null,
          connectTimeout: const Duration(minutes: 1),
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      )..interceptors.add(_TronclassCookieInterceptor(instance._cookieJar));

      // 从 TronclassAuthManager 读取 session
      instance._sessionId = await TronclassAuthManager.getSessionIdForUser(userId);
      _instances[userId] = instance;
    }
    return _instances[userId]!;
  }

  /// 登录：获取并保存新的 session
  Future<String> login({
    required String username,
    required String password,
    required Future<String> Function(Uint8List image) captchaProvider,
  }) async {
    final sessionId = await _TronclassLoginService.login(
      _casDio,
      _dio,
      username: username,
      password: password,
      captchaHandler: captchaProvider,
    );
    await setSessionId(sessionId);
    return sessionId;
  }

  /// 登出：清除 session
  Future<void> logout() async {
    await setSessionId(null);
  }

  /// 设置 session ID
  Future<void> setSessionId(String? value) async {
    _sessionId = value;
    if (value != null) {
      await TronclassAuthManager.setSessionIdForUser(_userId, value);
    } else {
      await TronclassAuthManager.clearSessionIdForUser(_userId);
    }
  }

  /// 清除指定用户的实例
  static void clearInstance(String userId) {
    _instances.remove(userId);
  }

  /// 清除所有实例
  static void clearAll() {
    _instances.clear();
  }
}

/// Cookie 拦截器
class _TronclassCookieInterceptor extends Interceptor {
  final CookieJar cookieJar;

  _TronclassCookieInterceptor(this.cookieJar);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final cookies = await cookieJar.loadForRequest(options.uri);
    if (cookies.isNotEmpty) {
      final cookieStr = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      options.headers['Cookie'] = cookieStr;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final setCookieHeaders = response.headers['set-cookie'];
    if (setCookieHeaders != null) {
      final cookies = setCookieHeaders
          .map((s) => Cookie.fromSetCookieValue(s))
          .toList();
      await cookieJar.saveFromResponse(response.requestOptions.uri, cookies);
    }
    handler.next(response);
  }
}

/// 认证拦截器 - 自动注入 x-session-id
class _TronclassAuthInterceptor extends Interceptor {
  final String? Function() getSessionId;

  _TronclassAuthInterceptor(this.getSessionId);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final url = options.uri.toString();
    if (url.contains('courses.guet.edu.cn')) {
      final sessionId = getSessionId();
      if (sessionId != null) {
        options.headers['x-session-id'] = sessionId;
      }
    }
    handler.next(options);
  }
}

/// 畅课登录服务 - 借鉴 tronclass_plus 的 TronClassService
class _TronclassLoginService {
  /// 完整登录流程：OAuth code -> access_token -> session_id
  static Future<String> login(
    Dio casDio,
    Dio dio, {
    required String username,
    required String password,
    required Future<String> Function(Uint8List image) captchaHandler,
  }) async {
    final code = await _getLoginCode(casDio, username, password, captchaHandler);
    final token = await _getAccessToken(dio, code: code);
    final sessionId = await _loginDesktopEndpoint(dio, accessToken: token);
    return sessionId;
  }

  /// 步骤1: 获取 OAuth code
  static Future<String> _getLoginCode(
    Dio dio,
    String username,
    String password,
    Future<String> Function(Uint8List image) captchaHandler,
  ) async {
    final url = 'https://identity.guet.edu.cn/auth/realms/guet/protocol/openid-connect/auth';
    final params = {
      'scope': 'openid',
      'response_type': 'code',
      'redirect_uri': 'https://mobile.guet.edu.cn/cas-callback?_h5=true',
      'client_id': 'TronClassH5',
      'autologin': 'true',
    };

    final resp = await dio.get(url, queryParameters: params);
    final redirectUrl = resp.requestOptions.uri;
    final redirectUrlString = redirectUrl.toString();

    Uri callbackUrl;
    if (redirectUrlString.contains('https://mobile.guet.edu.cn/cas-callback?_h5=true')) {
      callbackUrl = redirectUrl;
    } else {
      final serviceUrl = redirectUrl.queryParameters['service'];
      if (serviceUrl == null) {
        throw Exception('TronclassLogin: service param is null');
      }

      final resp1 = await _loginCas(
        casDio: dio,
        username: username,
        password: password,
        service: serviceUrl,
        captchaHandler: captchaHandler,
      );
      callbackUrl = resp1.requestOptions.uri;
    }

    final code = callbackUrl.queryParameters['code'];
    if (code == null) {
      throw Exception('TronclassLogin: OAuth code is null');
    }
    return code;
  }

  /// 步骤2: code 换 access_token
  static Future<String> _getAccessToken(Dio dio, {required String code}) async {
    final url = 'https://identity.guet.edu.cn/auth/realms/guet/protocol/openid-connect/token';
    final params = {
      'client_id': 'TronClassH5',
      'redirect_uri': 'https://mobile.guet.edu.cn/cas-callback?_h5=true',
      'code': code,
      'grant_type': 'authorization_code',
      'scope': 'openid',
    };

    final resp = await dio.post(
      url,
      data: params,
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );

    final accessToken = resp.data['access_token'];
    if (accessToken == null) {
      throw Exception('TronclassLogin: access_token is null');
    }
    return accessToken;
  }

  /// 步骤3: access_token 换 session_id
  static Future<String> _loginDesktopEndpoint(Dio dio, {required String accessToken}) async {
    final url = 'https://courses.guet.edu.cn/api/login?login=access_token';
    final data = {'access_token': accessToken, 'org_id': 1};

    final resp = await dio.post(url, data: data);
    final sessionId = resp.headers.value('x-session-id');
    if (sessionId == null) {
      throw Exception('TronclassLogin: session_id is null');
    }
    return sessionId;
  }

  /// CAS 认证登录
  static Future<Response> _loginCas({
    required Dio casDio,
    required String username,
    required String password,
    required String service,
    required Future<String> Function(Uint8List image) captchaHandler,
  }) async {
    // 获取登录页面
    var resp = await casDio.get(
      'authserver/login',
      queryParameters: {'service': service},
    );

    // 解决 cookie 不够误报密码错误的问题
    for (int retryCount = 0; retryCount < 2; retryCount++) {
      resp = await casDio.get(
        'authserver/login',
        queryParameters: {'service': service},
      );
    }

    // 解析登录页面
    final doc = html_parser.parse(resp.data);
    final aesKey = doc.getElementById('pwdEncryptSalt')?.attributes['value'];
    final execution = doc.getElementById('execution')?.attributes['value'];

    if (aesKey == null || execution == null) {
      throw Exception('TronclassLogin: aesKey or execution is null');
    }

    // 获取验证码
    final captcha = await _getCaptcha(casDio, username, captchaHandler);

    // 提交登录
    final resp1 = await casDio.post(
      'authserver/login',
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        responseType: ResponseType.plain,
      ),
      queryParameters: {'service': service},
      data: {
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
    );

    // 检查登录结果
    if (resp1.statusCode == 401) {
      final errorDoc = html_parser.parse(resp1.data);
      final errorTip = errorDoc.querySelector('#showErrorTip')?.text;
      throw Exception('TronclassLogin: ${errorTip ?? "Login failed"}');
    }

    return resp1;
  }

  /// 获取验证码
  static Future<String> _getCaptcha(
    Dio dio,
    String username,
    Future<String> Function(Uint8List image) captchaHandler,
  ) async {
    final checkResp = await dio.get(
      'authserver/checkNeedCaptcha.htl',
      queryParameters: {
        'username': username,
        '_': DateTime.now().millisecondsSinceEpoch,
      },
      options: Options(responseType: ResponseType.plain),
    );

    final checkData = jsonDecode(checkResp.data);
    if (checkData['isNeed'] == true) {
      final imageResp = await dio.get(
        'authserver/getCaptcha.htl?${DateTime.now().millisecondsSinceEpoch}',
        options: Options(responseType: ResponseType.bytes),
      );
      return await captchaHandler(imageResp.data);
    }
    return '';
  }

  /// AES 加密密码
  static String _encryptPassword(String password, List<int> key) {
    if (key.length != 16 && key.length != 24 && key.length != 32) {
      throw ArgumentError('Key must be 16, 24, or 32 bytes long');
    }

    // 生成随机 IV
    final random = Random.secure();
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    // 生成 64 字节随机字符串
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final randomStr = List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();

    // 拼接并加密
    final plaintext = randomStr + password;
    final keyBytes = Uint8List.fromList(key);
    final encryptKey = encrypt_pkg.Key(keyBytes);
    final ivKey = encrypt_pkg.IV(iv);
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(encryptKey, mode: encrypt_pkg.AESMode.cbc, padding: 'PKCS7'),
    );
    final encrypted = encrypter.encrypt(plaintext, iv: ivKey);

    return encrypted.base64;
  }
}
