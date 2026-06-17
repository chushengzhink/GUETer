import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:html/parser.dart' as html_parser;

import 'api_service.dart';
import 'login.dart';
import 'tronclass_login_request_profile.dart';

import '../session/tronclass_auth.dart';
import '../tronclass_guet_constants.dart';

/// Tronclass client with per-user isolated sessions.
class TronclassClient {
  TronclassClient._();

  static final Map<String, TronclassClient> _instances = {};

  late final Dio _dio; // 闂傚倷鐒﹀鍨焽閸ф绀夐悗锝庡墲婵?tronclass API
  late final Dio _casDio;
  late final CookieJar _cookieJar;
  late final String _userId;
  String? _sessionId;

  Dio get dio => _dio;
  Dio get casDio => _casDio;
  CookieJar get cookieJar => _cookieJar;
  String get userId => _userId;
  String? get sessionId => _sessionId;
  bool get isLoggedIn => _sessionId != null;

  /// 闂傚倷绀侀崥瀣磿閹惰棄搴婇柤鑹扮堪娴滃綊鏌涢妷顔煎缂佺姵婢橀…璺ㄦ崉閻戞ɑ鎷遍梺鍝勬缁绘﹢寮?ID 闂傚倸鍊搁崐鎼佸箠韫囨搩娼栧┑鐘冲焹閳ь剚鐗犲畷鍫曨敆娴ｇ澹?CookieJar
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

  static Future<TronclassClient> getInstance(String userId) async {
    if (_instances[userId] == null) {
      final instance = TronclassClient._();
      instance._userId = userId;
      instance._cookieJar = await _getCookieJar(userId);

      instance._dio =
          Dio(
              BaseOptions(
                baseUrl: TronclassGuetConstants.portalBaseUrl,
                headers: TronclassLoginHeaders.baseHeaders(null),
                followRedirects: false,
                validateStatus: (status) => status != null,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                responseType: ResponseType.json,
              ),
            )
            ..interceptors.addAll([
              _TronclassCookieInterceptor(instance._cookieJar),
              _TronclassAuthInterceptor(() => instance._sessionId),
            ]);

      instance._casDio = Dio(
        BaseOptions(
          baseUrl: '${TronclassGuetConstants.casBaseUrl}/',
          headers: TronclassLoginHeaders.baseHeaders(null),
          followRedirects: false,
          validateStatus: (status) => status != null,
          connectTimeout: const Duration(minutes: 1),
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      )..interceptors.add(_TronclassCookieInterceptor(instance._cookieJar));

      // 婵?TronclassAuthManager 闂備浇宕垫慨鏉懨洪埡鍜佹晪鐟滄垿濡?session
      instance._sessionId = await TronclassAuthManager.getSessionIdForUser(
        userId,
      );
      _instances[userId] = instance;
    }
    return _instances[userId]!;
  }

  /// 闂傚倷娴囬惃顐﹀幢閳轰焦顔勭紓鍌氬€哥粔瀵哥矓瑜版帒鏋佺€广儱鎷嬪鈺呮煕閹邦垰鐨烘い鏂挎濮婃椽宕ㄦ繝鍕櫗闂佺粯顨嗗ú鐔煎箠閻斿吋鍋勯柛婵勫劗閺€鍐测攽閻樼粯娑ф俊顐ｇ洴楠炴鎮╃紒妯煎幐闂佺鏈粙鎴λ夌€ｎ偆绠?session
  Future<String?> login({
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

  /// 闂傚倷娴囬惃顐﹀幢閳轰焦顔勯梻浣规偠閸娿倝宕ｉ崘顔兼瀬鐎广儱鎷嬪鈺傘亜閹捐泛顎屽ù鍏兼礋濮?session
  Future<void> logout() async {
    await setSessionId(null);
  }

  /// 闂備浇宕垫慨宕囩矆娴ｈ娅犲ù鐘差儐閸?session ID
  Future<void> setSessionId(String? value) async {
    _sessionId = value;
    if (value != null) {
      await TronclassAuthManager.setSessionIdForUser(_userId, value);
    } else {
      await TronclassAuthManager.clearSessionIdForUser(_userId);
    }
  }

  static void clearInstance(String userId) {
    _instances.remove(userId);
  }

  static void clearAll() {
    _instances.clear();
  }
}

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
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
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

/// 闂備浇宕垫慨鎶芥⒔瀹ュ纾规繛鎴欏灪閸庡﹤顭块懜闈涘缂佺媭鍨堕弻銊╁籍閸ヮ煈妫勯梺缁樺笒椤兘寮?- 闂傚倷鑳堕崢褔銆冩惔銏㈩洸婵犲﹤瀚崣蹇涙煃鏉炴媽顔夐柡瀣墵閺屾洘绻涢崹顔煎閻?x-session-id
class _TronclassAuthInterceptor extends Interceptor {
  final String? Function() getSessionId;

  _TronclassAuthInterceptor(this.getSessionId);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final url = options.uri.toString();
    if (url.contains('${TronclassGuetConstants.portalBaseUrl}/')) {
      final sessionId = getSessionId();
      if (sessionId != null) {
        options.headers['x-session-id'] = sessionId;
        ApiService.appendExternalConsoleLog(
          'tronclass',
          '[TronclassAuthInterceptor] injected x-session-id length= url=',
        );
      } else {
        ApiService.appendExternalConsoleLog(
          'tronclass',
          '[TronclassAuthInterceptor] missing x-session-id url=',
        );
      }
    }
    handler.next(options);
  }
}

/// 闂傚倷妞掔槐顔惧緤娴犲绠犻柟鐐た閺佸鏌熼幆鏉啃撻柛搴＄焸閹綊宕堕鍕缂備礁顦锟犲蓟閿熺姴閱囨繝闈涚唵閵忕姭鏀?- 闂傚倷鑳堕…鍫ユ晝閿曞倸绐楅柡宥冨妿閻?tronclass_plus 闂?TronClassService
class _TronclassLoginService {
  /// 闂備浇顕уù鐑藉箠閹捐瀚夋い鎺戝濮规煡鏌ㄥ┑鍡╂Ч闁稿骸鐭傞幃褰掑炊椤忓嫮姣㈢紓浣割槹鐎笛呮崲濞戞氨绀勯柣妯烘惈閸橈繝姊虹€圭媭鍤欓柕鍫熸倐瀵偄顓奸崪浣规〃闂佸憡鍨堕悰鐚糷 code -> access_token -> session_id
  static Future<String?> login(
    Dio casDio,
    Dio dio, {
    required String username,
    required String password,
    required Future<String> Function(Uint8List image) captchaHandler,
  }) async {
    final code = await _getLoginCode(
      casDio,
      username,
      password,
      captchaHandler,
    );
    final token = await _getAccessToken(dio, code: code);
    final sessionId = await _loginDesktopEndpoint(dio, accessToken: token);
    return sessionId;
  }

  /// 濠电姵顔栭崰妤冪紦閸ф纾块柣銏犲閺?: 闂傚倷绀侀崥瀣磿閹惰棄搴婇柤鑹扮堪娴?OAuth code
  static Future<String> _getLoginCode(
    Dio dio,
    String username,
    String password,
    Future<String> Function(Uint8List image) captchaHandler,
  ) async {
    final url = TronclassGuetConstants.identityAuthUrl;
    final params = {
      'scope': 'openid',
      'response_type': 'code',
      'redirect_uri': TronclassGuetConstants.redirectUri,
      'client_id': TronclassGuetConstants.clientId,
      'autologin': 'true',
    };

    final resp = await dio.get(
      url,
      queryParameters: params,
      options: Options(
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.identityAuth,
        ),
      ),
    );
    final redirectUrl = resp.requestOptions.uri;
    final redirectUrlString = redirectUrl.toString();

    Uri callbackUrl;
    if (redirectUrlString.contains(TronclassGuetConstants.redirectUri)) {
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

  /// 濠电姵顔栭崰妤冪紦閸ф纾块柣銏犲閺?: code 闂?access_token
  static Future<String> _getAccessToken(Dio dio, {required String code}) async {
    final url = TronclassGuetConstants.identityTokenUrl;
    final params = {
      'client_id': TronclassGuetConstants.clientId,
      'redirect_uri': TronclassGuetConstants.redirectUri,
      'code': code,
      'grant_type': 'authorization_code',
      'scope': 'openid',
    };

    final resp = await dio.post(
      url,
      data: params,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.identityToken,
          explicitHeaders: {
            'content-type': 'application/x-www-form-urlencoded',
          },
        ),
      ),
    );

    final accessToken = resp.data['access_token'];
    if (accessToken == null) {
      throw Exception('TronclassLogin: access_token is null');
    }
    return accessToken;
  }

  /// 濠电姵顔栭崰妤冪紦閸ф纾块柣銏犲閺?: access_token 闂?session_id
  static Future<String?> _loginDesktopEndpoint(
    Dio dio, {
    required String accessToken,
  }) async {
    final url = TronclassGuetConstants.portalAccessTokenLoginUrl;
    final data = {'access_token': accessToken, 'org_id': 1};

    final resp = await dio.post(
      url,
      data: data,
      options: Options(
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.portalAccessTokenLogin,
        ),
      ),
    );
    final sessionId = resp.headers.value('x-session-id')?.trim();
    if (sessionId != null && sessionId.isNotEmpty) {
      return sessionId;
    }
    if (isSuccessfulTronclassDesktopLoginResponse(resp)) {
      return null;
    }
    throw Exception('TronclassLogin: desktop login did not establish session');
  }

  /// CAS 闂備浇宕垫慨鎶芥⒔瀹ュ纾规繛鎴欏灪閸庡﹤顭块懜闈涘闁稿骸鐭傞幃褰掑炊椤忓嫮姣㈢紓?
  static Future<Response> _loginCas({
    required Dio casDio,
    required String username,
    required String password,
    required String service,
    required Future<String> Function(Uint8List image) captchaHandler,
  }) async {
    var resp = await casDio.get(
      'authserver/login',
      queryParameters: {'service': service},
      options: Options(
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.casLoginPage,
          service: service,
        ),
      ),
    );

    for (int retryCount = 0; retryCount < 2; retryCount++) {
      resp = await casDio.get(
        'authserver/login',
        queryParameters: {'service': service},
        options: Options(
          headers: TronclassLoginHeaders.build(
            stage: TronclassLoginRequestStage.casLoginPage,
            service: service,
          ),
        ),
      );
    }

    final doc = html_parser.parse(resp.data);
    final aesKey = doc.getElementById('pwdEncryptSalt')?.attributes['value'];
    final execution = doc.getElementById('execution')?.attributes['value'];

    if (aesKey == null || execution == null) {
      throw Exception('TronclassLogin: aesKey or execution is null');
    }

    final captcha = await _getCaptcha(
      casDio,
      username,
      captchaHandler,
      service: service,
    );

    // 闂傚倷绀佸﹢杈╁垝椤栫偛绀夐柟鐑樺焾濞尖晠鏌ㄩ弴鐐测偓褰掑磿瀹€鍕仯闁搞儺浜滈惃铏圭磼?
    final resp1 = await casDio.post(
      'authserver/login',
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        responseType: ResponseType.plain,
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.casLoginSubmit,
          service: service,
          explicitHeaders: {
            'content-type': 'application/x-www-form-urlencoded',
          },
        ),
      ),
      queryParameters: {'service': service},
      data: {
        'username': username,
        'password': encryptTronclassCasPasswordWithKey(
          password,
          utf8.encode(aesKey),
        ),
        'rememberMe': true,
        'captcha': captcha,
        '_eventId': 'submit',
        'cllt': 'userNameLogin',
        'dllt': 'generalLogin',
        'lt': '',
        'execution': execution,
      },
    );

    if (resp1.statusCode == 401) {
      final errorDoc = html_parser.parse(resp1.data);
      final errorTip = errorDoc.querySelector('#showErrorTip')?.text;
      throw Exception('TronclassLogin: ${errorTip ?? "Login failed"}');
    }

    return resp1;
  }

  static Future<String> _getCaptcha(
    Dio dio,
    String username,
    Future<String> Function(Uint8List image) captchaHandler, {
    String? service,
  }) async {
    final checkResp = await dio.get(
      'authserver/checkNeedCaptcha.htl',
      queryParameters: {
        'username': username,
        '_': DateTime.now().millisecondsSinceEpoch,
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.casCaptchaCheck,
          service: service,
        ),
      ),
    );

    final checkData = jsonDecode(checkResp.data);
    if (checkData['isNeed'] == true) {
      final imageResp = await dio.get(
        'authserver/getCaptcha.htl?${DateTime.now().millisecondsSinceEpoch}',
        options: Options(
          responseType: ResponseType.bytes,
          headers: TronclassLoginHeaders.build(
            stage: TronclassLoginRequestStage.casCaptchaImage,
            service: service,
          ),
        ),
      );
      return await captchaHandler(imageResp.data);
    }
    return '';
  }
}
