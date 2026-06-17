import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:html/parser.dart' as html_parser;
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_service.dart';
import '../api/platform_dio_manager.dart';
import '../utils/encrypt.dart';
import '../session/cookie.dart';
import '../session/login_context.dart';
import '../models/user.dart';
import '../platform.dart';
import '../tronclass_guet_constants.dart';
import 'ketangpai_response.dart';
import 'tronclass_cas_login_http.dart';
import 'tronclass_login_request_profile.dart';

const String _tronclassCasBfpPrefix = 'tronclass_cas_bfp_';
const String _tronclassCasCryptoChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

final Random _tronclassCasCryptoRandom = Random.secure();

String encryptTronclassCasPassword(String password, String salt) {
  return encryptTronclassCasPasswordWithKey(password, utf8.encode(salt));
}

String encryptTronclassCasPasswordWithKey(String password, List<int> key) {
  if (key.length != 16 && key.length != 24 && key.length != 32) {
    throw ArgumentError('Key must be 16, 24, or 32 bytes long');
  }

  final ivStr = List.generate(
    16,
    (_) =>
        _tronclassCasCryptoChars[_tronclassCasCryptoRandom.nextInt(
          _tronclassCasCryptoChars.length,
        )],
  ).join();
  final randomStr = List.generate(
    64,
    (_) =>
        _tronclassCasCryptoChars[_tronclassCasCryptoRandom.nextInt(
          _tronclassCasCryptoChars.length,
        )],
  ).join();

  final encryptKey = encrypt_pkg.Key(Uint8List.fromList(key));
  final ivKey = encrypt_pkg.IV(Uint8List.fromList(ivStr.codeUnits));
  final encrypter = encrypt_pkg.Encrypter(
    encrypt_pkg.AES(
      encryptKey,
      mode: encrypt_pkg.AESMode.cbc,
      padding: 'PKCS7',
    ),
  );
  return encrypter.encrypt(randomStr + password, iv: ivKey).base64;
}

String _loginPayloadSummary(dynamic data) {
  if (data is Map<String, dynamic>) {
    final code =
        data['code'] ?? data['result'] ?? data['status'] ?? data['success'];
    final msg = data['msg'] ?? data['message'] ?? data['mes'];
    final keys = data.keys.take(8).join(',');
    return 'code=$code msg=$msg keys=[$keys]';
  }
  if (data is List) {
    return 'listLength=${data.length}';
  }
  return 'type=${data.runtimeType}';
}

Map<String, dynamic>? _normalizeStringKeyedMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  if (data is String) {
    final text = data.trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

bool isSuccessfulTronclassDesktopLoginResponse(Response response) {
  final statusCode = response.statusCode ?? 0;
  if (statusCode < 200 || statusCode >= 300) {
    return false;
  }

  final payload = _normalizeStringKeyedMap(response.data);
  final hasUserId = payload?['user_id']?.toString().trim().isNotEmpty == true;
  if (hasUserId) {
    return true;
  }

  final setCookieHeaders = response.headers['set-cookie'] ?? const <String>[];
  for (final header in setCookieHeaders) {
    final firstSegment = header.split(';').first.trim();
    final separator = firstSegment.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final cookieName = firstSegment
        .substring(0, separator)
        .trim()
        .toLowerCase();
    if (cookieName == 'session') {
      return true;
    }
  }

  return false;
}

bool _isTruthyLoginValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value == 1 || value == 200;
  }
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' ||
      text == '1' ||
      text == '200' ||
      text == 'success' ||
      text == 'ok';
}

bool isChaoxingLoginSuccessPayload(dynamic payload) {
  final data = _normalizeStringKeyedMap(payload);
  if (data == null) {
    return false;
  }
  return _isTruthyLoginValue(data['status']) ||
      _isTruthyLoginValue(data['result']) ||
      _isTruthyLoginValue(data['code']);
}

User? parseChaoxingUserFromPayload(dynamic payload) {
  final data = _normalizeStringKeyedMap(payload);
  if (data == null) {
    return null;
  }

  final result = data['result'];
  if (result != null && !_isTruthyLoginValue(result)) {
    return null;
  }

  final userData =
      _normalizeStringKeyedMap(data['msg']) ??
      _normalizeStringKeyedMap(data['data']);
  if (userData == null) {
    return null;
  }

  final uid = userData['puid']?.toString() ?? '';
  if (uid.isEmpty) {
    return null;
  }

  return User(
    uid: uid,
    name: (userData['name'] ?? 'Unknown User').toString(),
    avatar: (userData['pic'] ?? '').toString(),
    phone: (userData['phone'] ?? 'Unknown Phone').toString(),
    school: (userData['schoolname'] ?? 'Unknown School').toString(),
    platform: 'chaoxing',
  );
}

enum TronclassLoginNextAction { success, requireMfa, requireWebReauth, failure }

class TronclassMfaPromptContext {
  const TronclassMfaPromptContext({
    this.mobileHint,
    this.tip,
    this.codeTimeSeconds,
    required Future<Map<String, dynamic>?> Function() resendCode,
  }) : _resendCode = resendCode;

  final String? mobileHint;
  final String? tip;
  final int? codeTimeSeconds;
  final Future<Map<String, dynamic>?> Function() _resendCode;

  Future<Map<String, dynamic>?> resendCode() => _resendCode();
}

@visibleForTesting
const String tronclassVerificationStageNone = 'none';

@visibleForTesting
const String tronclassVerificationStageCaptcha = 'captcha';

@visibleForTesting
const String tronclassVerificationStageMfa = 'mfa';

TronclassLoginNextAction resolveTronclassLoginNextAction(
  Map<String, dynamic>? result,
) {
  if (result == null) {
    return TronclassLoginNextAction.failure;
  }

  final sessionId = (result['sessionId'] ?? '').toString().trim();
  if (result['ok'] == true || sessionId.isNotEmpty) {
    return TronclassLoginNextAction.success;
  }
  if (result['requireWebReauth'] == true) {
    return TronclassLoginNextAction.requireWebReauth;
  }
  if (result['requireMfa'] == true) {
    return TronclassLoginNextAction.requireMfa;
  }
  return TronclassLoginNextAction.failure;
}

bool shouldPromptTronclassMfaSendFailureDialog(Map<String, dynamic>? result) {
  return result != null && result['showMfaSendFailureDialog'] == true;
}

bool canResumeTronclassMfaChallenge(Map<String, dynamic>? result) {
  if (result == null || result['allowManualMfaRetry'] != true) {
    return false;
  }
  final service = (result['service'] ?? '').toString().trim();
  final reauthEntryUrl = (result['reauthEntryUrl'] ?? '').toString().trim();
  return service.isNotEmpty || reauthEntryUrl.isNotEmpty;
}

@visibleForTesting
bool isTronclassMfaSessionInvalidResponse(Map<String, dynamic>? response) {
  if (response == null) {
    return false;
  }

  final errCode = (response['errCode'] ?? response['errorCode'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final code = (response['code'] ?? '').toString().trim().toLowerCase();
  final data = (response['data'] ?? '').toString().trim().toLowerCase();
  final redirectUrl = (response['redirectUrl'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final responseUri = (response['responseUri'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final message =
      (response['returnMessage'] ??
              response['msg'] ??
              response['message'] ??
              '')
          .toString()
          .trim()
          .toLowerCase();

  if (response['mfaSessionInvalid'] == true) {
    return true;
  }

  if (errCode == '206302') {
    return true;
  }

  if (code == 'session_invalid') {
    return true;
  }

  bool pointsBackToCasLogin(String value) {
    return value.contains('/authserver/login') && !value.contains('reauth');
  }

  return pointsBackToCasLogin(data) ||
      pointsBackToCasLogin(redirectUrl) ||
      pointsBackToCasLogin(responseUri) ||
      message.contains('重定向') ||
      message.contains('会话');
}

void _logLoginEndpoint(
  String tag,
  String stage,
  String endpoint, {
  dynamic data,
  Object? error,
}) {
  final prefix = '[$tag][Login][$stage] $endpoint';
  if (error != null) {
    debugPrint('$prefix error=$error');
    return;
  }
  debugPrint('$prefix ${_loginPayloadSummary(data)}');
}

class CXLoginApi {
  /// Web鐧诲綍
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
      _logLoginEndpoint('CX', 'response', url, data: response.data);
      return response.data;
    } catch (e) {
      _logLoginEndpoint('CX', 'error', 'fanyalogin', error: e);
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
      _logLoginEndpoint('CX', 'response', url, data: response.data);
      return response.data;
    } catch (e) {
      _logLoginEndpoint('CX', 'error', 'api/sendcaptcha', error: e);
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
      ApiService.appendExternalConsoleLog('学习通', '开始验证码登录请求: $url');

      final response = await ApiService.sendRequest(
        url,
        method: "POST",
        body: formData,
      );
      final payload = _normalizeStringKeyedMap(response.data) ?? response.data;

      _logLoginEndpoint('CX', 'response', url, data: payload);
      ApiService.appendExternalConsoleLog(
        '学习通',
        'loginregister响应: ${_loginPayloadSummary(response.data)}',
      );

      return response.data;
      // {"mes":"验证通过","type":1,"url":"https://sso.chaoxing.com/apis/login/userLogin4Uname.do","status":true}
    } catch (e) {
      _logLoginEndpoint('CX', 'error', 'v11/loginregister', error: e);
      debugPrint('Login error: $e');
      CookieManager.isLoggingIn = false;
    }
    return null;
  }

  /// 获取用户信息
  static Future<User?> getUserInfo() async {
    try {
      final url = 'https://sso.chaoxing.com/apis/login/userLogin4Uname.do';
      ApiService.appendExternalConsoleLog('学习通', '开始获取用户信息请求: $url');

      final response = await ApiService.sendRequest(url);
      final payload = _normalizeStringKeyedMap(response.data) ?? response.data;

      _logLoginEndpoint('CX', 'response', url, data: payload);

      if (!isChaoxingLoginSuccessPayload(payload)) {
        final result = _normalizeStringKeyedMap(payload)?['result'];
        ApiService.appendExternalConsoleLog(
          '学习通',
          'userLogin4Uname返回失败: result=$result',
        );
        CookieManager.isLoggingIn = false;
        return null;
      }

      final user = parseChaoxingUserFromPayload(payload);
      if (user == null) {
        ApiService.appendExternalConsoleLog('学习通', 'userLogin4Uname响应解析用户信息失败');
        CookieManager.isLoggingIn = false;
        return null;
      }

      CookieManager.isLoggingIn = false;
      ApiService.appendExternalConsoleLog(
        '学习通',
        '用户信息获取完成: uid=${user.uid}, name=${user.name}',
      );

      return user;
    } catch (e) {
      _logLoginEndpoint('CX', 'error', 'userLogin4Uname.do', error: e);
      debugPrint('getUserInfo error: $e');
      CookieManager.isLoggingIn = false;
    }
    return null;
  }

  static Future<User?> getUserInfoForAccount(String userId) async {
    try {
      final dio = await PlatformDioManager.getDioForUser(
        platform: PlatformType.chaoxing,
        userId: userId,
      );
      final response = await dio.get(
        'https://sso.chaoxing.com/apis/login/userLogin4Uname.do',
      );
      return parseChaoxingUserFromPayload(response.data);
    } catch (e) {
      _logLoginEndpoint('CX', 'error', 'userLogin4Uname.do', error: e);
      debugPrint('getUserInfoForAccount error: $e');
      return null;
    }
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

      // 提取 uuid
      final uuidRegex = RegExp(r'value="(.+?)" id="uuid"');
      final uuidMatch = uuidRegex.firstMatch(html);
      final uuid = uuidMatch?.group(1);

      // 提取 enc
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
      _logLoginEndpoint('CX', 'response', authStatusUrl, data: response.data);

      final result = response.data;
      final isSuccess = result?['status'] == true || result?['result'] == 1;

      if (isSuccess) {
        ApiService.appendExternalConsoleLog(
          '学习通',
          '二维码授权成功，保持 isLoggingIn=true 以捕获后续 Cookie',
        );
      } else {
        CookieManager.isLoggingIn = false;
      }

      return result;
    } catch (e) {
      _logLoginEndpoint('CX', 'error', 'getauthstatus/v2', error: e);
      debugPrint('checkQRAuthStatus error: $e');
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
      _logLoginEndpoint('RC', 'response', url, data: response.data);
      debugPrint(
        '[RC][API.sendCaptcha] request=$jsonData response=${response.data}',
      );
      return response.data;
    } catch (e) {
      _logLoginEndpoint('RC', 'error', 'user/code/send', error: e);
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
      _logLoginEndpoint('RC', 'response', url, data: response.data);
      return response.data;
    } catch (e) {
      _logLoginEndpoint('RC', 'error', 'user/code/verify', error: e);
      debugPrint('verifyCaptcha error: $e');
    }
    return null;
  }

  /// 验证码/密码登录
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
      _logLoginEndpoint('RC', 'response', url, data: response.data);
      return response.data;
    } catch (e) {
      _logLoginEndpoint('RC', 'error', 'user/login/app', error: e);
      debugPrint('login error: $e');
    }
    return null;
  }

  /// 获取用户信息
  static Future<User?> getUserInfo() async {
    try {
      final url = '/v/course_meta/user_info';

      final response = await ApiService.sendRequest(url);
      _logLoginEndpoint('RC', 'response', url, data: response.data);

      final payload = response.data;
      final userProfile = payload is Map<String, dynamic>
          ? payload['data'] is Map<String, dynamic>
                ? (payload['data'] as Map<String, dynamic>)['user_profile']
                : null
          : null;
      if (userProfile is! Map<String, dynamic>) {
        return null;
      }

      final avatarRaw = userProfile['avatar'];
      final avatarText = avatarRaw == null ? '' : avatarRaw.toString();
      final avatar96Raw = userProfile['avatar_96'];
      final avatar96Text = avatar96Raw == null ? '' : avatar96Raw.toString();
      final user = User(
        uid: userProfile['user_id']?.toString() ?? '',
        name: userProfile['name'] ?? '未知用户',
        avatar: avatarText.isNotEmpty ? avatarText : avatar96Text,
        phone: userProfile['phone_number'] ?? '未知手机号',
        school: userProfile['school'] ?? '未知学校',
        platform: 'rainclassroom',
      );
      return user;
    } catch (e) {
      _logLoginEndpoint('RC', 'error', 'course_meta/user_info', error: e);
      debugPrint('getUserInfo error: $e');
    }
    return null;
  }

  static Future<User?> getUserInfoForAccount(String userId) async {
    try {
      final dio = await PlatformDioManager.getDioForUser(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );
      final response = await dio.get('/v/course_meta/user_info');

      final payload = response.data;
      final userProfile = payload is Map<String, dynamic>
          ? payload['data'] is Map<String, dynamic>
                ? (payload['data'] as Map<String, dynamic>)['user_profile']
                : null
          : null;
      if (userProfile is! Map<String, dynamic>) {
        return null;
      }

      final avatarRaw = userProfile['avatar'];
      final avatarText = avatarRaw == null ? '' : avatarRaw.toString();
      final avatar96Raw = userProfile['avatar_96'];
      final avatar96Text = avatar96Raw == null ? '' : avatar96Raw.toString();
      return User(
        uid: userProfile['user_id']?.toString() ?? '',
        name: (userProfile['name'] ?? 'Unknown User').toString(),
        avatar: avatarText.isNotEmpty ? avatarText : avatar96Text,
        phone: (userProfile['phone_number'] ?? 'Unknown Phone').toString(),
        school: (userProfile['school'] ?? 'Unknown School').toString(),
        platform: 'rainclassroom',
      );
    } catch (e) {
      _logLoginEndpoint('RC', 'error', 'course_meta/user_info', error: e);
      debugPrint('getUserInfoForAccount error: $e');
      return null;
    }
  }

  /// 获取微信登录二维码的 UUID 和 state
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
        'f': 'xml', // 如果没有则输出 html
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
      ); // 服务端在 15 秒后响应

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
        skipCredentialValidation: true,
      );
      _logLoginEndpoint(
        'KT',
        'response',
        '/UserApi/login',
        data: response.data,
      );
      return response.data;
    } catch (e) {
      _logLoginEndpoint('KT', 'error', '/UserApi/login', error: e);
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
        skipCredentialValidation: true,
      );
      _logLoginEndpoint(
        'KT',
        'response',
        '/UserApi/loginByMobile',
        data: response.data,
      );
      return response.data;
    } catch (e) {
      _logLoginEndpoint('KT', 'error', '/UserApi/loginByMobile', error: e);
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
      _logLoginEndpoint(
        'KT',
        'response',
        '/UserApi/sendCode',
        data: response.data,
      );
      return response.data;
    } catch (e) {
      _logLoginEndpoint('KT', 'error', '/UserApi/sendCode', error: e);
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
        skipCredentialValidation: true,
      );
      _logLoginEndpoint(
        'KT',
        'response',
        '/UserApi/getUserBasinInfo',
        data: basinResponse.data,
      );
      final userResponse = await ApiService.sendRequest(
        '/UserApi/getUserInfo',
        method: 'POST',
        body: body,
        headers: {'token': token},
        skipCredentialValidation: true,
      );
      _logLoginEndpoint(
        'KT',
        'response',
        '/UserApi/getUserInfo',
        data: userResponse.data,
      );

      final basinData = basinResponse.data['data'] ?? {};
      final userData = userResponse.data['data'] ?? {};

      final user = User(
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

      return user;
    } catch (e) {
      _logLoginEndpoint('KT', 'error', 'getUserInfo aggregate', error: e);
      debugPrint('KTLoginApi.getUserInfo error: $e');
    }
    return null;
  }

  static Future<bool> checkTokenStatus(String token) async {
    if (token.trim().isEmpty) {
      return false;
    }

    try {
      final basinResponse = await ApiService.sendRequest(
        '/UserApi/getUserBasinInfo',
        method: 'POST',
        body: {'reqtimestamp': DateTime.now().millisecondsSinceEpoch},
        headers: {'token': token},
        skipCredentialValidation: true,
      );

      final basinData = _normalizeStringKeyedMap(basinResponse.data);
      if (basinData == null || isKetangpaiAuthExpired(basinData)) {
        return false;
      }

      var basinHealthy = isKetangpaiSuccess(basinData);
      final basin = basinData['data'];
      if (basin is Map<String, dynamic>) {
        final remoteToken = basin['token']?.toString() ?? '';
        if (remoteToken.isNotEmpty) {
          basinHealthy = true;
        }

        final uid = basin['uid']?.toString() ?? '';
        if (uid.isNotEmpty) {
          basinHealthy = true;
        }
      } else if (basin is Map) {
        final remoteToken = basin['token']?.toString() ?? '';
        final uid = basin['uid']?.toString() ?? '';
        basinHealthy = basinHealthy || remoteToken.isNotEmpty || uid.isNotEmpty;
      }

      if (!basinHealthy) {
        return false;
      }

      final courseResponse = await ApiService.sendRequest(
        '/CourseApi/semesterCourseList',
        method: 'POST',
        body: _ketangpaiCurrentSemesterBody(),
        headers: {'token': token},
        skipCredentialValidation: true,
      );
      final courseData = _normalizeStringKeyedMap(courseResponse.data);
      if (courseData == null || isKetangpaiAuthExpired(courseData)) {
        ApiService.appendExternalConsoleLog('课堂派', '课堂派业务接口登录态已过期，请重新登录');
        return false;
      }
      return isKetangpaiSuccess(courseData);
    } catch (e) {
      _logLoginEndpoint('KT', 'error', 'checkTokenStatus', error: e);
    }
    return false;
  }

  static Map<String, dynamic> _ketangpaiCurrentSemesterBody() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    final semester = currentMonth >= 9
        ? '$currentYear-${currentYear + 1}'
        : '${currentYear - 1}-$currentYear';
    final term = currentMonth >= 9
        ? '1'
        : currentMonth >= 2
        ? '2'
        : '1';
    return <String, dynamic>{
      'isstudy': '1',
      'search': '',
      'semester': semester,
      'term': term,
      'reqtimestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

class TCLoginApi {
  static const _identityAuthUrl = TronclassGuetConstants.identityAuthUrl;
  static const _tokenUrl = TronclassGuetConstants.identityTokenUrl;
  static const int _dynamicCodeAutoRetryAttempts = 3;
  static const Duration _dynamicCodeRetryInterval = Duration(seconds: 10);
  static const Duration _mfaInitialSendDelay = Duration(milliseconds: 3600);
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

  static Map<String, String> _authQueryParams({String? redirectUriOverride}) {
    final redirectUri = redirectUriOverride?.trim().isNotEmpty == true
        ? redirectUriOverride!.trim()
        : TronclassGuetConstants.redirectUri;
    return {
      'scope': 'openid',
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'client_id': TronclassGuetConstants.clientId,
      'autologin': 'true',
    };
  }

  static Uri buildAuthUri({String? redirectUriOverride}) {
    return Uri.parse(_identityAuthUrl).replace(
      queryParameters: _authQueryParams(
        redirectUriOverride: redirectUriOverride,
      ),
    );
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

  static bool _isReAuthContextReady(
    Response response, {
    String? resolvedLocation,
  }) {
    final currentUrl = response.requestOptions.uri.toString();
    if (_isCasLoginUrl(resolvedLocation) || _isCasLoginUrl(currentUrl)) {
      return false;
    }
    if (_looksLikeCasLoginHtml(response.data) &&
        !_looksLikeReAuthHtml(response.data)) {
      return false;
    }
    return _isReAuthUrl(currentUrl) ||
        _isReAuthUrl(resolvedLocation) ||
        _looksLikeReAuthHtml(response.data);
  }

  static bool _isRetryableDynamicCodeTip(String? tip) {
    if (tip == null) return false;
    final normalized = tip.trim();
    return normalized.contains('请求超时重定向') ||
        normalized.contains('请求过快') ||
        normalized.contains('重试');
  }

  static bool _isCasLoginUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.contains(
      TronclassGuetConstants.casLoginUrl.replaceFirst('https://', ''),
    );
  }

  static bool _looksLikeCasLoginHtml(dynamic htmlContent) {
    final html = htmlContent?.toString().toLowerCase() ?? '';
    if (html.isEmpty) {
      return false;
    }
    return html.contains('casloginform') ||
        html.contains('pwdencryptsalt') ||
        html.contains('name="execution"') ||
        html.contains("name='execution'") ||
        html.contains('showerrortip');
  }

  static String? _buildReauthEntryUrl(String? service) {
    if (service == null || service.isEmpty) {
      return null;
    }
    return '${TronclassGuetConstants.reauthLoginViewUrl}?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}';
  }

  static Future<Map<String, dynamic>> _primeReauthSession({
    String? reauthEntryUrl,
    String? service,
    LoginContext? loginContext,
  }) async {
    final targetUrl = (reauthEntryUrl != null && reauthEntryUrl.isNotEmpty)
        ? reauthEntryUrl
        : _buildReauthEntryUrl(service);
    if (targetUrl == null || targetUrl.isEmpty) {
      _trace('[TC][MFA] skip reauth prime: missing target url');
      return {
        'reauthEntryUrl': reauthEntryUrl,
        'mfaContextReady': false,
        'mfaSessionInvalid': true,
        'message': '缺少短信验证页面入口，无法建立短信验证上下文',
      };
    }

    try {
      final resp = await ApiService.sendRequest(
        targetUrl,
        responseType: ResponseType.plain,
        allowRedirects: false,
        loginContext: loginContext,
        headers: {
          'accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      final location = _resolveUrlWithBase(
        resp.requestOptions.uri,
        resp.headers.value('location'),
      );
      final resolvedReauthUrl =
          _extractReauthEntryUrl(resp, service: service) ?? targetUrl;
      final ready = _isReAuthContextReady(resp, resolvedLocation: location);
      final returnedToLogin =
          _isCasLoginUrl(location) ||
          _isCasLoginUrl(resp.requestOptions.uri.toString()) ||
          (_looksLikeCasLoginHtml(resp.data) &&
              !_looksLikeReAuthHtml(resp.data));
      final sessionInvalid = !ready || returnedToLogin;
      final message = sessionInvalid
          ? '短信验证会话未就绪或已失效，请重新进入短信验证页面后再发送验证码'
          : null;
      _trace(
        '[TC][MFA] reauth prime ready=$ready returnedToLogin=$returnedToLogin status=${resp.statusCode} uri=${resp.requestOptions.uri} location=${location ?? ''} resolved=$resolvedReauthUrl',
      );
      return {
        'reauthEntryUrl': resolvedReauthUrl,
        'mfaContextReady': ready && !returnedToLogin,
        'mfaSessionInvalid': sessionInvalid,
        ...?message == null ? null : {'message': message},
      };
    } catch (e) {
      _trace('[TC][MFA] reauth prime failed=$e');
      return {
        'reauthEntryUrl': targetUrl,
        'mfaContextReady': false,
        'mfaSessionInvalid': true,
        'message': '短信验证会话预热失败，请重新进入短信验证页面后再发送验证码',
      };
    }
  }

  static String? _extractReauthEntryUrl(Response response, {String? service}) {
    final reauthUrlFromService = _buildReauthEntryUrl(service);
    if (reauthUrlFromService != null && reauthUrlFromService.isNotEmpty) {
      return reauthUrlFromService;
    }

    final location = response.headers.value('location');
    if (location != null && location.isNotEmpty) {
      final resolved = _resolveUrlWithBase(
        response.requestOptions.uri,
        location,
      );
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
      // 兼容 jsonp / 包裹文本，例如 callback({...}) 或前后拼接文本
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

  // ignore: unused_element
  static Future<Map<String, dynamic>> _sendDynamicCodeWithContextLegacy(
    String username, {
    String? reauthEntryUrl,
  }) async {
    _trace('[TC] 准备发送短信验证码，username=$username');

    final url = TronclassGuetConstants.dynamicCodeUrl;
    final headers = <String, String>{
      'content-type': 'application/x-www-form-urlencoded',
      'accept': 'application/json, text/javascript, */*; q=0.01',
      'x-requested-with': 'XMLHttpRequest',
      if (reauthEntryUrl != null && reauthEntryUrl.isNotEmpty)
        'referer': reauthEntryUrl,
    };

    _trace('[TC] 发送短信验证码请求');

    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      final nextDelaySeconds = (retryCount + 1) * 2;
      try {
        final resp = await ApiService.sendRequest(
          url,
          method: 'POST',
          headers: headers,
          body: {
            'userName': username,
            'authCodeTypeName': 'reAuthDynamicCodeType',
          },
          responseType: ResponseType.plain,
          allowRedirects: false,
        );

        _trace('[TC] 短信验证码响应: status=${resp.statusCode} data=${resp.data}');

        final parsed = _tryParseJsonMap(resp.data);
        if (parsed != null) {
          final parsedMsg =
              (parsed['returnMessage'] ?? parsed['msg'] ?? parsed['message'])
                  ?.toString();
          final codeField = parsed['code']?.toString().toLowerCase();
          final statusField = parsed['status']?.toString().toLowerCase();
          final resField = parsed['res']?.toString().toLowerCase();
          final resultField = parsed['result']?.toString().toLowerCase();
          final parsedSuccess =
              resField == 'success' ||
              codeField == '0' ||
              codeField == '200' ||
              codeField == 'success' ||
              statusField == '0' ||
              statusField == '200' ||
              statusField == 'true' ||
              statusField == 'success' ||
              resultField == '0' ||
              resultField == '200' ||
              resultField == 'true' ||
              resultField == 'success' ||
              (parsedMsg?.contains('已发送') ?? false);
          final parsedRetryable = _isRetryableDynamicCodeTip(parsedMsg);
          _trace(
            '[TC][dynamicCode] parsed=ok code=${parsed['code']} res=${parsed['res']} msg=${parsedMsg ?? ''}',
          );
          if (!parsedSuccess && parsedRetryable && retryCount < maxRetries) {
            _trace(
              '[TC] 动态码服务繁忙，$nextDelaySeconds 秒后重试 (${retryCount + 1}/$maxRetries)',
            );
            await Future.delayed(Duration(seconds: nextDelaySeconds));
            retryCount++;
            continue;
          }
          return parsed;
        }

        final body = resp.data?.toString() ?? '';
        final bodySnippet = _shortText(body);
        _trace('[TC][dynamicCode] 无法解析为 JSON body=$bodySnippet');

        if (_isRetryableDynamicCodeTip(body) && retryCount < maxRetries) {
          _trace(
            '[TC] 检测到超时错误，$nextDelaySeconds 秒后重试 (${retryCount + 1}/$maxRetries)',
          );
          await Future.delayed(Duration(seconds: nextDelaySeconds));
          retryCount++;
          continue;
        }

        final tip = _isRetryableDynamicCodeTip(body)
            ? '请求超时重定向'
            : (body.trim().isNotEmpty ? body.trim() : '动态码服务返回异常，请稍后重试');

        return {'res': 'fail', 'returnMessage': tip, 'mobile': ''};
      } catch (e) {
        _trace('[TC] 短信验证码请求异常: $e');
        if (retryCount < maxRetries) {
          _trace('[TC] $nextDelaySeconds 秒后重试 (${retryCount + 1}/$maxRetries)');
          await Future.delayed(Duration(seconds: nextDelaySeconds));
          retryCount++;
          continue;
        }
        return {'res': 'fail', 'returnMessage': '网络请求失败: $e', 'mobile': ''};
      }
    }

    return {'res': 'fail', 'returnMessage': '请求超时，请稍后重试', 'mobile': ''};
  }

  static bool _isDynamicCodeSendSuccess(Map<String, dynamic>? response) {
    if (response == null) {
      return false;
    }
    final tip = _extractDynamicCodeTip(response);
    final codeField = response['code']?.toString().toLowerCase();
    final statusField = response['status']?.toString().toLowerCase();
    final resField = response['res']?.toString().toLowerCase();
    final resultField = response['result']?.toString().toLowerCase();

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

    return resField == 'success' ||
        resField == '0' ||
        resField == '200' ||
        codeSuccess ||
        statusSuccess ||
        resultSuccess ||
        (tip?.contains('宸插彂閫?') ?? false);
  }

  static String? _extractDynamicCodeTip(Map<String, dynamic>? response) {
    return (response?['returnMessage'] ??
            response?['msg'] ??
            response?['message'])
        ?.toString();
  }

  static String? _extractDynamicCodeMobileHint(Map<String, dynamic>? response) {
    return (response?['mobile'] ??
            response?['phone'] ??
            response?['mobileMask'] ??
            response?['mobilePhone'])
        ?.toString();
  }

  static Map<String, dynamic> _finalizeDynamicCodeResult(
    Map<String, dynamic> response, {
    required int attempt,
    required int maxAttempts,
    required bool manualSendOnly,
    required bool retryableFailure,
    String? reauthEntryUrl,
    String? service,
    bool? mfaContextReady,
  }) {
    final sessionInvalid = isTronclassMfaSessionInvalidResponse(response);
    response['attempt'] = attempt;
    response['maxAttempts'] = maxAttempts;
    response['manualSendOnly'] = manualSendOnly;
    response['retryableMfaSendFailure'] = retryableFailure;
    response['reauthEntryUrl'] = reauthEntryUrl;
    response['service'] = service;
    response['mfaSessionInvalid'] = sessionInvalid;
    response['mfaContextReady'] = mfaContextReady ?? !sessionInvalid;
    response['verificationStage'] = tronclassVerificationStageMfa;
    if (!_isDynamicCodeSendSuccess(response)) {
      final exhausted =
          (retryableFailure || sessionInvalid) &&
          !manualSendOnly &&
          attempt >= maxAttempts;
      response['mfaSendFailedAfterRetries'] = exhausted;
      response['allowManualMfaRetry'] =
          (exhausted || sessionInvalid) &&
          ((service != null && service.isNotEmpty) ||
              (reauthEntryUrl != null && reauthEntryUrl.isNotEmpty));
      if (manualSendOnly || sessionInvalid) {
        response['mfaSendRetryFailed'] = true;
      }
    }
    return response;
  }

  static Map<String, dynamic> _buildMfaSendFailureResult(
    Map<String, dynamic> dynamicCodeInfo, {
    required bool manualSendOnly,
    String? reauthEntryUrl,
    String? service,
  }) {
    final tip = _extractDynamicCodeTip(dynamicCodeInfo);
    final mobileHint = _extractDynamicCodeMobileHint(dynamicCodeInfo);
    final sessionInvalid = dynamicCodeInfo['mfaSessionInvalid'] == true;
    final showRetryDialog =
        sessionInvalid ||
        (dynamicCodeInfo['mfaSendFailedAfterRetries'] == true &&
            !manualSendOnly);
    final message = sessionInvalid
        ? (tip?.isNotEmpty == true
              ? '短信验证码会话未就绪或已失效：$tip'
              : '短信验证码会话未就绪或已失效，请重新建立短信验证会话后重试')
        : (tip?.isNotEmpty == true ? tip! : '短信验证码发送失败，请稍后重试');

    final sessionInvalidDetail =
        tip != null &&
            tip.trim().isNotEmpty &&
            (tip.contains('请求') ||
                tip.contains('重定向') ||
                tip.contains('登录') ||
                tip.contains('会话'))
        ? '：${tip.trim()}'
        : '';
    final normalizedMessage = sessionInvalid
        ? '短信验证会话未就绪或已失效$sessionInvalidDetail'
        : (tip?.isNotEmpty == true
              ? tip
              : (message.toString().trim().isNotEmpty
                    ? message.toString().trim()
                    : '短信验证码发送失败，请稍后重试'));

    return {
      'ok': false,
      'message': normalizedMessage,
      'debug': lastLoginTrace,
      'showMfaSendFailureDialog': showRetryDialog,
      'mfaSendFailedAfterRetries':
          dynamicCodeInfo['mfaSendFailedAfterRetries'] == true,
      'mfaSendRetryFailed':
          manualSendOnly || dynamicCodeInfo['mfaSendRetryFailed'] == true,
      'allowManualMfaRetry':
          dynamicCodeInfo['allowManualMfaRetry'] == true || showRetryDialog,
      'requireInAppMfa': false,
      'reauthEntryUrl': reauthEntryUrl,
      'service': service,
      'tip': tip,
      'mobileHint': mobileHint,
      'mfaSessionInvalid': sessionInvalid,
      'mfaContextReady': dynamicCodeInfo['mfaContextReady'] == true,
      'verificationStage': tronclassVerificationStageMfa,
    };
  }

  static Future<Map<String, dynamic>> _sendDynamicCodeWithContext(
    String username, {
    String? reauthEntryUrl,
    String? service,
    LoginContext? loginContext,
    int maxAttempts = _dynamicCodeAutoRetryAttempts,
    bool manualSendOnly = false,
  }) async {
    _trace(
      '[TC][dynamicCode] prepare send username=$username manual=$manualSendOnly',
    );

    final primeResult = await _primeReauthSession(
      reauthEntryUrl: reauthEntryUrl,
      service: service,
      loginContext: loginContext,
    );
    final effectiveReauthEntryUrl =
        primeResult['reauthEntryUrl']?.toString() ?? reauthEntryUrl;
    final mfaContextReady = primeResult['mfaContextReady'] == true;
    final attemptLimit = maxAttempts < 1 ? 1 : maxAttempts;
    if (!mfaContextReady) {
      final message =
          primeResult['message']?.toString() ??
          '短信验证会话未就绪或已失效，请重新进入短信验证页面后再发送验证码';
      _trace(
        '[TC][dynamicCode] abort send: reauth context not ready message=$message',
      );
      return _finalizeDynamicCodeResult(
        {
          'res': 'fail',
          'returnMessage': message,
          'mobile': '',
          'mfaSessionInvalid': true,
        },
        attempt: 1,
        maxAttempts: attemptLimit,
        manualSendOnly: manualSendOnly,
        retryableFailure: false,
        reauthEntryUrl: effectiveReauthEntryUrl,
        service: service,
        mfaContextReady: false,
      );
    }
    final url = TronclassGuetConstants.dynamicCodeUrl;
    final headers = <String, String>{
      'content-type': 'application/x-www-form-urlencoded',
      'accept': 'application/json, text/javascript, */*; q=0.01',
      'x-requested-with': 'XMLHttpRequest',
      if (effectiveReauthEntryUrl != null && effectiveReauthEntryUrl.isNotEmpty)
        'referer': effectiveReauthEntryUrl,
    };
    for (var attempt = 1; attempt <= attemptLimit; attempt++) {
      try {
        final resp = await ApiService.sendRequest(
          url,
          method: 'POST',
          headers: headers,
          loginContext: loginContext,
          body: {
            'userName': username,
            'authCodeTypeName': 'reAuthDynamicCodeType',
          },
          responseType: ResponseType.plain,
          allowRedirects: false,
        );

        _trace(
          '[TC][dynamicCode] attempt=$attempt/$attemptLimit status=${resp.statusCode} data=${resp.data}',
        );

        final parsed = _tryParseJsonMap(resp.data);
        if (parsed != null) {
          final parsedTip = _extractDynamicCodeTip(parsed);
          final parsedRetryable = _isRetryableDynamicCodeTip(parsedTip);
          final sessionInvalid = isTronclassMfaSessionInvalidResponse(parsed);
          _trace(
            '[TC][dynamicCode] parsed code=${parsed['code']} errCode=${parsed['errCode']} res=${parsed['res']} retryable=$parsedRetryable sessionInvalid=$sessionInvalid msg=${parsedTip ?? ''}',
          );
          if (sessionInvalid) {
            parsed['mfaSessionInvalid'] = true;
            parsed['returnMessage'] = parsedTip?.isNotEmpty == true
                ? parsedTip
                : '短信验证码会话未就绪或已失效';
            return _finalizeDynamicCodeResult(
              parsed,
              attempt: attempt,
              maxAttempts: attemptLimit,
              manualSendOnly: manualSendOnly,
              retryableFailure: false,
              reauthEntryUrl: effectiveReauthEntryUrl,
              service: service,
              mfaContextReady: false,
            );
          }
          if (!_isDynamicCodeSendSuccess(parsed) &&
              parsedRetryable &&
              attempt < attemptLimit) {
            _trace(
              '[TC][dynamicCode] wait ${_dynamicCodeRetryInterval.inSeconds}s before retry',
            );
            await Future.delayed(_dynamicCodeRetryInterval);
            continue;
          }
          return _finalizeDynamicCodeResult(
            parsed,
            attempt: attempt,
            maxAttempts: attemptLimit,
            manualSendOnly: manualSendOnly,
            retryableFailure: parsedRetryable,
            reauthEntryUrl: effectiveReauthEntryUrl,
            service: service,
          );
        }

        final body = resp.data?.toString() ?? '';
        final bodySnippet = _shortText(body);
        final retryableFailure = _isRetryableDynamicCodeTip(body);
        final sessionInvalid = isTronclassMfaSessionInvalidResponse({
          'message': body,
        });
        _trace(
          '[TC][dynamicCode] non-json attempt=$attempt/$attemptLimit retryable=$retryableFailure sessionInvalid=$sessionInvalid body=$bodySnippet',
        );

        if (sessionInvalid) {
          return _finalizeDynamicCodeResult(
            {
              'res': 'fail',
              'returnMessage': '短信验证码会话未就绪或已失效，请重新建立短信验证会话后重试',
              'mobile': '',
              'mfaSessionInvalid': true,
            },
            attempt: attempt,
            maxAttempts: attemptLimit,
            manualSendOnly: manualSendOnly,
            retryableFailure: false,
            reauthEntryUrl: effectiveReauthEntryUrl,
            service: service,
            mfaContextReady: false,
          );
        }

        if (retryableFailure && attempt < attemptLimit) {
          _trace(
            '[TC][dynamicCode] wait ${_dynamicCodeRetryInterval.inSeconds}s before retry',
          );
          await Future.delayed(_dynamicCodeRetryInterval);
          continue;
        }

        final tip = retryableFailure
            ? '璇锋眰瓒呮椂閲嶅畾鍚?'
            : (body.trim().isNotEmpty
                  ? body.trim()
                  : '鍔ㄦ€佺爜鏈嶅姟杩斿洖寮傚父锛岃绋嶅悗閲嶈瘯');
        return _finalizeDynamicCodeResult(
          {'res': 'fail', 'returnMessage': tip, 'mobile': ''},
          attempt: attempt,
          maxAttempts: attemptLimit,
          manualSendOnly: manualSendOnly,
          retryableFailure: retryableFailure,
          reauthEntryUrl: effectiveReauthEntryUrl,
          service: service,
        );
      } catch (e) {
        _trace('[TC][dynamicCode] attempt=$attempt/$attemptLimit exception=$e');
        if (attempt < attemptLimit) {
          _trace(
            '[TC][dynamicCode] wait ${_dynamicCodeRetryInterval.inSeconds}s before retry',
          );
          await Future.delayed(_dynamicCodeRetryInterval);
          continue;
        }
        return _finalizeDynamicCodeResult(
          {'res': 'fail', 'returnMessage': '缃戠粶璇锋眰澶辫触: $e', 'mobile': ''},
          attempt: attempt,
          maxAttempts: attemptLimit,
          manualSendOnly: manualSendOnly,
          retryableFailure: true,
          reauthEntryUrl: effectiveReauthEntryUrl,
          service: service,
        );
      }
    }

    return _finalizeDynamicCodeResult(
      {'res': 'fail', 'returnMessage': '璇锋眰瓒呮椂锛岃绋嶅悗閲嶈瘯', 'mobile': ''},
      attempt: attemptLimit,
      maxAttempts: attemptLimit,
      manualSendOnly: manualSendOnly,
      retryableFailure: true,
      reauthEntryUrl: effectiveReauthEntryUrl,
      service: service,
    );
  }

  static Future<Map<String, dynamic>> _reAuthCheck(
    String code, {
    String? service,
    LoginContext? loginContext,
  }) async {
    final resp = await ApiService.sendRequest(
      TronclassGuetConstants.reauthSubmitUrl,
      method: 'POST',
      loginContext: loginContext,
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        'accept': 'application/json, text/javascript, */*; q=0.01',
        'x-requested-with': 'XMLHttpRequest',
        if (service != null && service.isNotEmpty)
          'referer':
              '${TronclassGuetConstants.reauthLoginViewUrl}?isMultifactor=true&service=${Uri.encodeQueryComponent(service)}',
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
      final redirectUrl = _resolveUrlWithBase(
        resp.requestOptions.uri,
        resp.headers.value('location'),
      );
      final authCode =
          _extractAuthCodeFromAny(resp) ??
          (redirectUrl != null && redirectUrl.isNotEmpty
              ? Uri.tryParse(redirectUrl)?.queryParameters['code']
              : null);
      if (authCode != null && authCode.isNotEmpty) {
        parsed['authCode'] = authCode;
      }
      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        parsed['redirectUrl'] = redirectUrl;
      }
      parsed['responseUri'] = resp.requestOptions.uri.toString();
      _trace(
        '[TC][reAuthCheck] status=${resp.statusCode} uri=${resp.requestOptions.uri} realUri=${resp.realUri} location=${resp.headers.value('location') ?? ''} body=${_shortText(resp.data)} parsed=ok code=${parsed['code']} authCode=${parsed['authCode'] ?? ''} redirectUrl=${parsed['redirectUrl'] ?? ''}',
      );
      return parsed;
    }
    _trace(
      '[TC][reAuthCheck] invalid response status=${resp.statusCode} uri=${resp.requestOptions.uri} realUri=${resp.realUri} location=${resp.headers.value('location') ?? ''} body=${_shortText(resp.data)}',
    );
    return {'code': 'reAuth_failed', 'msg': '动态码验证服务返回异常'};
  }

  // ignore: unused_element
  static Future<Map<String, dynamic>> _handleMfaChallengeLegacy(
    String username, {
    Future<String?> Function(String? mobileHint, String? tip)? mfaCodeProvider,
    String? reauthEntryUrl,
    String? service,
  }) async {
    if (mfaCodeProvider == null) {
      return {
        'ok': false,
        'requireMfa': true,
        'reauthEntryUrl': reauthEntryUrl,
        'service': service,
        'mfaContextReady':
            (reauthEntryUrl?.isNotEmpty == true) ||
            (service?.isNotEmpty == true),
        'verificationStage': tronclassVerificationStageMfa,
        'message': '当前账号需要多因子短信验证码，请输入短信动态码后重试。',
      };
    }

    _trace('[TC][MFA] continue within current session');
    _trace('[TC][MFA] wait 3.6s before sending sms code');
    await Future.delayed(const Duration(milliseconds: 3600));

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
      final message = (tip?.isNotEmpty == true ? tip : '动态码服务返回异常，请稍后重试')!;
      final rateLimited =
          dynamicCodeInfo['retryLimitReached'] == true ||
          _isRetryableDynamicCodeTip(tip);
      if (rateLimited) {
        _trace('[TC][MFA] retry limit reached, abort login');
        return {
          'ok': false,
          'message': '验证码服务繁忙，请稍后重试',
          'debug': lastLoginTrace,
          'rateLimited': true,
          'service': service,
        };
      }
      return {
        'ok': false,
        'message': message,
        'debug': lastLoginTrace,
        'rateLimited': rateLimited,
        'requireInAppMfa': false,
        'reauthEntryUrl': reauthEntryUrl,
        'service': service,
      };
    }

    final mfaCode = await mfaCodeProvider(mobileHint, tip);
    if (mfaCode == null || mfaCode.trim().isEmpty) {
      _trace('[TC][MFA] sms code input cancelled');
      return {
        'ok': false,
        'cancelledMfa': true,
        'message': '短信动态码已发送，但你取消了输入；请重新发起畅课登录后再验证',
        'debug': lastLoginTrace,
      };
    }

    final mfaResult = await _reAuthCheck(mfaCode.trim(), service: service);
    if (mfaResult['code']?.toString() != 'reAuth_success') {
      _trace(
        '[TC][MFA] sms code verification failed code=${mfaResult['code']} msg=${mfaResult['msg'] ?? ''}',
      );
      return {
        'ok': false,
        'message': (mfaResult['msg'] ?? '动态码验证失败').toString(),
        'debug': lastLoginTrace,
      };
    }

    _trace('[TC][MFA] sms code verification success');

    final authCodeFromMfa =
        mfaResult['authCode']?.toString() ??
        _extractAuthCodeFromAny(
          Response(
            requestOptions: RequestOptions(
              path: mfaResult['responseUri']?.toString() ?? '',
            ),
            data: mfaResult['redirectUrl']?.toString(),
            headers: Headers.fromMap({
              'location': [mfaResult['redirectUrl']?.toString() ?? ''],
            }),
            statusCode: 200,
          ),
        );
    if (authCodeFromMfa != null && authCodeFromMfa.isNotEmpty) {
      return completeWithAuthCode(authCodeFromMfa);
    }

    final authAfterMfaProbeResp = await ApiService.sendRequest(
      _identityAuthUrl,
      params: _authQueryParams(),
      responseType: ResponseType.plain,
      allowRedirects: false,
    );
    _trace(
      '[TC][postMfa][probe] status=${authAfterMfaProbeResp.statusCode} uri=${authAfterMfaProbeResp.requestOptions.uri} realUri=${authAfterMfaProbeResp.realUri} location=${authAfterMfaProbeResp.headers.value('location') ?? ''} body=${_shortText(authAfterMfaProbeResp.data)}',
    );

    final authAfterMfaResp = await ApiService.sendRequest(
      _identityAuthUrl,
      params: _authQueryParams(),
      responseType: ResponseType.plain,
      allowRedirects: true,
    );
    _trace(
      '[TC][postMfa][follow] status=${authAfterMfaResp.statusCode} uri=${authAfterMfaResp.requestOptions.uri} realUri=${authAfterMfaResp.realUri} location=${authAfterMfaResp.headers.value('location') ?? ''} body=${_shortText(authAfterMfaResp.data)}',
    );

    final codeAfterMfa = await _crawlAuthCodeFromResponses([
      authAfterMfaProbeResp,
      authAfterMfaResp,
    ]);
    if (codeAfterMfa == null || codeAfterMfa.isEmpty) {
      return {
        'ok': false,
        'requireWebReauth': true,
        'authUrl': buildAuthUri().toString(),
        'message': '动态码验证成功，但未获取到畅课授权码，请在内置页面继续完成授权',
        'debug': lastLoginTrace,
        'service': service,
      };
    }

    return completeWithAuthCode(codeAfterMfa);
  }

  static Future<Map<String, dynamic>> continueMfaChallenge(
    String username, {
    required String password,
    Future<String?> Function(Uint8List imageBytes)? captchaProvider,
    Future<String?> Function(String? mobileHint, String? tip)? mfaCodeProvider,
    String? reauthEntryUrl,
    String? service,
    LoginContext? loginContext,
  }) {
    return _handleMfaChallenge(
      username,
      password: password,
      captchaProvider: captchaProvider,
      mfaCodeProvider: mfaCodeProvider,
      reauthEntryUrl: reauthEntryUrl,
      service: service,
      loginContext: loginContext,
      manualSendOnly: true,
    );
  }

  static Future<Map<String, dynamic>> _reestablishMfaContext(
    String username, {
    required String password,
    Future<String?> Function(Uint8List imageBytes)? captchaProvider,
    LoginContext? loginContext,
  }) async {
    _trace('[TC][MFA] rebuilding current SMS verification context');
    final result = await _loginForAuthCode(
      username,
      password,
      captchaProvider: captchaProvider,
      loginContext: loginContext,
      allowMfaChallenge: true,
      stopAfterMfaDetection: true,
    );
    _trace(
      '[TC][MFA] rebuild result ok=${result['ok']} requireMfa=${result['requireMfa']} stage=${result['verificationStage'] ?? ''} service=${result['service'] ?? ''}',
    );
    return result;
  }

  static Future<Map<String, dynamic>> _handleMfaChallenge(
    String username, {
    required String password,
    Future<String?> Function(Uint8List imageBytes)? captchaProvider,
    Future<String?> Function(String? mobileHint, String? tip)? mfaCodeProvider,
    String? reauthEntryUrl,
    String? service,
    LoginContext? loginContext,
    bool manualSendOnly = false,
  }) async {
    if (mfaCodeProvider == null) {
      return {
        'ok': false,
        'requireMfa': true,
        'message': '褰撳墠璐﹀彿闇€瑕佸鍥犲瓙鐭俊楠岃瘉鐮侊紝璇疯緭鍏ョ煭淇″姩鎬佺爜鍚庨噸璇曘€?',
      };
    }

    _trace('[TC][MFA] continue within current session manual=$manualSendOnly');
    if (!manualSendOnly) {
      _trace(
        '[TC][MFA] wait ${_mfaInitialSendDelay.inMilliseconds}ms before sending sms code',
      );
      await Future.delayed(_mfaInitialSendDelay);
    }

    String? effectiveReauthEntryUrl = reauthEntryUrl;
    String? effectiveService = service;

    var dynamicCodeInfo = await _sendDynamicCodeWithContext(
      username,
      reauthEntryUrl: effectiveReauthEntryUrl,
      service: effectiveService,
      loginContext: loginContext,
      maxAttempts: manualSendOnly ? 1 : _dynamicCodeAutoRetryAttempts,
      manualSendOnly: manualSendOnly,
    );

    if (dynamicCodeInfo['mfaSessionInvalid'] == true) {
      _trace('[TC][MFA] sms verification session invalid, trying to rebuild');
      final rebuiltContext = await _reestablishMfaContext(
        username,
        password: password,
        captchaProvider: captchaProvider,
        loginContext: loginContext,
      );

      if (rebuiltContext['ok'] == true) {
        final rebuiltCode = (rebuiltContext['code'] ?? '').toString().trim();
        if (rebuiltCode.isNotEmpty) {
          return completeWithAuthCode(rebuiltCode, loginContext: loginContext);
        }
      }

      final rebuiltReady = rebuiltContext['mfaContextReady'] == true;
      if (rebuiltContext['verificationStage'] ==
              tronclassVerificationStageMfa ||
          rebuiltContext['requireMfa'] == true) {
        effectiveReauthEntryUrl =
            rebuiltContext['reauthEntryUrl']?.toString() ??
            effectiveReauthEntryUrl;
        effectiveService =
            rebuiltContext['service']?.toString() ?? effectiveService;
        if (!rebuiltReady) {
          return _buildMfaSendFailureResult(
            {
              'mfaSessionInvalid': true,
              'mfaContextReady': false,
              'returnMessage':
                  (rebuiltContext['message'] ?? '短信验证会话未就绪或已失效，请重新进入短信验证页面后重试')
                      .toString(),
            },
            manualSendOnly: manualSendOnly,
            reauthEntryUrl: effectiveReauthEntryUrl,
            service: effectiveService,
          );
        }
        dynamicCodeInfo = await _sendDynamicCodeWithContext(
          username,
          reauthEntryUrl: effectiveReauthEntryUrl,
          service: effectiveService,
          loginContext: loginContext,
          maxAttempts: manualSendOnly ? 1 : _dynamicCodeAutoRetryAttempts,
          manualSendOnly: manualSendOnly,
        );
      } else if (rebuiltContext['ok'] != true) {
        return rebuiltContext;
      }
    }

    final mobileHint = _extractDynamicCodeMobileHint(dynamicCodeInfo);
    final tip = _extractDynamicCodeTip(dynamicCodeInfo);
    final sendOk = _isDynamicCodeSendSuccess(dynamicCodeInfo);

    _trace(
      '[TC][dynamicCode] decision sendOk=$sendOk manual=$manualSendOnly tip=${tip ?? ''}',
    );

    if (!sendOk) {
      return _buildMfaSendFailureResult(
        dynamicCodeInfo,
        manualSendOnly: manualSendOnly,
        reauthEntryUrl: effectiveReauthEntryUrl,
        service: effectiveService,
      );
    }

    final mfaCode = await mfaCodeProvider(mobileHint, tip);
    if (mfaCode == null || mfaCode.trim().isEmpty) {
      _trace('[TC][MFA] sms code input cancelled');
      return {
        'ok': false,
        'cancelledMfa': true,
        'message': '鐭俊鍔ㄦ€佺爜宸插彂閫侊紝浣嗕綘鍙栨秷浜嗚緭鍏ワ紱璇烽噸鏂板彂璧风晠璇剧櫥褰曞悗鍐嶉獙璇?',
        'debug': lastLoginTrace,
      };
    }

    final mfaResult = await _reAuthCheck(
      mfaCode.trim(),
      service: effectiveService,
      loginContext: loginContext,
    );
    if (mfaResult['code']?.toString() != 'reAuth_success') {
      _trace(
        '[TC][MFA] sms code verification failed code=${mfaResult['code']} msg=${mfaResult['msg'] ?? ''}',
      );
      return {
        'ok': false,
        'message': (mfaResult['msg'] ?? '鍔ㄦ€佺爜楠岃瘉澶辫触').toString(),
        'debug': lastLoginTrace,
      };
    }

    _trace('[TC][MFA] sms code verification success');

    _trace('[TC][MFA] restart auth-code flow within verified session');
    final authCodeResult = await _loginForAuthCode(
      username,
      password,
      captchaProvider: captchaProvider,
      mfaCodeProvider: mfaCodeProvider,
      loginContext: loginContext,
      resumeAfterMfa: true,
      allowMfaChallenge: false,
    );
    if (authCodeResult['ok'] != true) {
      return authCodeResult;
    }

    final codeAfterMfa = (authCodeResult['code'] ?? '').toString().trim();
    if (codeAfterMfa.isEmpty) {
      return {
        'ok': false,
        'message': '短信验证码验证成功，但未获取到畅课授权码',
        'debug': lastLoginTrace,
      };
    }

    return completeWithAuthCode(codeAfterMfa, loginContext: loginContext);
  }

  static Future<Map<String, dynamic>> completeWithAuthCode(
    String code, {
    LoginContext? loginContext,
  }) async {
    try {
      CookieManager.isLoggingIn = true;

      final tokenResp = await ApiService.sendRequest(
        _tokenUrl,
        method: 'POST',
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        loginContext: loginContext,
        body: {
          'client_id': TronclassGuetConstants.clientId,
          'redirect_uri': TronclassGuetConstants.redirectUri,
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
        TronclassGuetConstants.portalAccessTokenLoginUrl,
        method: 'POST',
        loginContext: loginContext,
        body: {'access_token': accessToken, 'org_id': 1},
      );
      final hasCookieBackedSession = isSuccessfulTronclassDesktopLoginResponse(
        loginDesktopResp,
      );
      final sessionId = loginDesktopResp.headers.value('x-session-id');
      final trimmedSessionId = sessionId?.trim();
      if (trimmedSessionId != null && trimmedSessionId.isNotEmpty) {
        return {
          'ok': true,
          'sessionId': trimmedSessionId,
          'cookieBacked': false,
        };
      }
      if (hasCookieBackedSession) {
        return {'ok': true, 'sessionId': null, 'cookieBacked': true};
      }
      if (sessionId == null || sessionId.isEmpty) {
        return {'ok': false, 'message': '未获取到畅课会话 ID'};
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
    debugPrint(
      '[TC][bootstrapPortalSession] 开始初始化会话 sessionId=${sessionId?.substring(0, sessionId.length > 20 ? 20 : sessionId.length)}...',
    );
    try {
      final sid = sessionId?.trim();
      if (sid == null || sid.isEmpty) {
        debugPrint('[TC][bootstrapPortalSession] sessionId 为空，跳过');
        return false;
      }

      final probes = <Map<String, dynamic>>[
        {
          'url': TronclassGuetConstants.portalSessionLoginUrl,
          'method': 'POST',
          'body': {'session_id': sid, 'org_id': 1},
        },
        {
          'url': TronclassGuetConstants.portalSessionLoginUrl,
          'method': 'POST',
          'body': {'org_id': 1},
        },
        {
          'url': '${TronclassGuetConstants.portalBaseUrl}/api/users/me',
          'method': 'GET',
          'body': null,
        },
      ];

      for (var i = 0; i < probes.length; i++) {
        final probe = probes[i];
        try {
          debugPrint('[TC][bootstrapPortalSession] 尝试探测 $i: ${probe['url']}');
          final response = await ApiService.sendRequest(
            probe['url'].toString(),
            method: probe['method'].toString(),
            body: probe['body'],
            skipCredentialValidation: true,
          );

          final setCookie = response.headers['set-cookie'];
          if (setCookie != null && setCookie.isNotEmpty) {
            debugPrint('[TC][bootstrapPortalSession] 探测 $i 成功 (set-cookie)');
            return true;
          }

          final data = response.data;
          if (response.statusCode != null &&
              response.statusCode! >= 200 &&
              response.statusCode! < 400) {
            if (data is! Map<String, dynamic>) {
              debugPrint('[TC][bootstrapPortalSession] 探测 $i 成功 (非 JSON 响应)');
              return true;
            }
            final ok =
                data['success'] == true ||
                data['ok'] == true ||
                data['result'] == true ||
                data['code'] == 0 ||
                data['code'] == '0';
            if (ok) {
              debugPrint('[TC][bootstrapPortalSession] 探测 $i 成功 (响应 ok)');
              return true;
            }
          }
          debugPrint('[TC][bootstrapPortalSession] 探测 $i 未成功，继续下一项');
        } catch (e) {
          debugPrint('[TC][bootstrapPortalSession] 探测 $i 异常: $e');
          // continue probing
        }
      }
      debugPrint('[TC][bootstrapPortalSession] 所有探测均未成功');
    } catch (e) {
      debugPrint('[TC][bootstrapPortalSession] 异常: $e');
      // ignore bootstrap errors
    }

    return false;
  }

  static Future<User?> getUserInfo({
    String? fallbackUid,
    String? sessionId,
    LoginContext? loginContext,
  }) async {
    Object? lastError;
    final headers = (sessionId != null && sessionId.trim().isNotEmpty)
        ? <String, String>{'x-session-id': sessionId.trim()}
        : null;

    for (final endpoint in const ['/api/profile', '/api/users/profile']) {
      try {
        final response = await ApiService.sendRequest(
          endpoint,
          headers: headers,
          loginContext: loginContext,
        );
        final user = parseTronclassUserFromPayload(
          response.data,
          fallbackUid: fallbackUid,
        );
        if (user != null) {
          return user;
        }
      } catch (e) {
        lastError = e;
      }
    }

    debugPrint('TCLoginApi.getUserInfo error: $lastError');
    return null;
  }

  static User? parseTronclassUserFromPayload(
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
    final avatar =
        (data['avatar_big_url'] ??
                data['avatar_small_url'] ??
                data['avatar'] ??
                data['avatar_url'] ??
                '')
            .toString();
    final phone =
        (data['mobile_phone'] ??
                data['mobile'] ??
                data['phone'] ??
                data['phone_number'] ??
                '未知手机号')
            .toString();
    final orgName = data['org'] is Map<String, dynamic>
        ? (data['org'] as Map<String, dynamic>)['name']?.toString()
        : null;
    final school = (orgName ?? data['school'] ?? data['org_name'] ?? '桂林电子科技大学')
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

  static String? _extractAuthCodeFromAny(Response response) {
    final direct = _extractAuthCode(response);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final htmlRedirect = _resolveUrlWithBase(
      response.requestOptions.uri,
      _extractRedirectUrlFromHtml(response.data),
    );
    if (htmlRedirect != null && htmlRedirect.isNotEmpty) {
      try {
        final parsed = Uri.parse(htmlRedirect);
        final code = parsed.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return code;
        }
      } catch (_) {
        // ignore parse error
      }
    }

    final raw = response.data?.toString() ?? '';
    final codeRegex = RegExp(
      r'''[?&]code=([^&\s'"<>]+)''',
      caseSensitive: false,
    );
    final codeMatch = codeRegex.firstMatch(raw);
    final encoded = codeMatch?.group(1);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return Uri.decodeQueryComponent(encoded);
      } catch (_) {
        return encoded;
      }
    }

    return null;
  }

  static String _shortText(dynamic value, {int maxLen = 220}) {
    final text = (value?.toString() ?? '').replaceAll('\n', ' ').trim();
    if (text.isEmpty) {
      return '';
    }
    if (text.length <= maxLen) {
      return text;
    }
    return '${text.substring(0, maxLen)}...(len=${text.length})';
  }

  static List<Map<String, dynamic>> _extractBrokerFormSubmissions(
    dynamic htmlContent, {
    Uri? baseUri,
  }) {
    final html = htmlContent?.toString() ?? '';
    if (html.isEmpty) {
      return const [];
    }

    final submissions = <Map<String, dynamic>>[];
    try {
      final doc = html_parser.parse(html);
      for (final form in doc.querySelectorAll('form')) {
        final action = form.attributes['action'];
        if (action == null || action.isEmpty) {
          continue;
        }

        final htmlLower = html.toLowerCase();
        final text = form.text.toLowerCase();
        final fields = <String, String>{};
        for (final input in form.querySelectorAll('input')) {
          final name = input.attributes['name'];
          if (name == null || name.isEmpty) {
            continue;
          }
          final type = (input.attributes['type'] ?? '').toLowerCase();
          final value = input.attributes['value'] ?? '';
          if (type == 'hidden' ||
              value.isNotEmpty ||
              name == 'session_code' ||
              name == 'tab_id' ||
              name == 'client_id' ||
              name == 'execution' ||
              name == 'code') {
            fields[name] = value;
          }
        }

        final hasBrokerFields =
            fields.containsKey('session_code') ||
            fields.containsKey('tab_id') ||
            fields.containsKey('client_id') ||
            fields.containsKey('execution') ||
            fields.containsKey('code');
        final looksBroker =
            hasBrokerFields ||
            text.contains('验证码') ||
            text.contains('session_code') ||
            text.contains('tab_id') ||
            htmlLower.contains('login-pf') ||
            htmlLower.contains('broker/cas-client/login');
        if (!looksBroker) {
          continue;
        }

        final method = (form.attributes['method'] ?? 'GET').toUpperCase();
        final resolvedAction = baseUri != null
            ? _resolveUrlWithBase(baseUri, action)
            : action;
        if (resolvedAction == null || resolvedAction.isEmpty) {
          continue;
        }

        submissions.add({
          'action': resolvedAction,
          'method': method,
          'fields': fields,
        });
      }
    } catch (_) {
      // ignore parse error
    }
    return submissions;
  }

  static Future<String?> _crawlAuthCodeFromResponses(
    List<Response> seeds, {
    int maxHops = 5,
    Duration hopDelay = const Duration(milliseconds: 450),
  }) async {
    final visited = <String>{};
    final queue = List<Response>.from(seeds);
    var hops = 0;

    while (queue.isNotEmpty && hops < maxHops) {
      final current = queue.removeAt(0);
      hops += 1;

      _trace(
        '[TC][authCrawl] hop=$hops uri=${current.requestOptions.uri} realUri=${current.realUri} status=${current.statusCode} location=${current.headers.value('location') ?? ''} body=${_shortText(current.data)}',
      );

      final direct = _extractAuthCodeFromAny(current);
      if (direct != null && direct.isNotEmpty) {
        _trace('[TC][authCrawl] hop=$hops extracted authCode=$direct');
        return direct;
      }

      final candidates = <String?>[
        _resolveUrlWithBase(
          current.requestOptions.uri,
          current.headers.value('location'),
        ),
        _resolveUrlWithBase(
          current.requestOptions.uri,
          _extractRedirectUrlFromHtml(current.data),
        ),
      ];

      for (final candidate in candidates) {
        if (candidate == null || candidate.isEmpty) {
          continue;
        }
        if (!visited.add(candidate)) {
          continue;
        }
        if (!(candidate.contains('authserver') ||
            candidate.contains('code='))) {
          continue;
        }

        try {
          _trace('[TC][authCrawl] hop=$hops follow candidate=$candidate');
          await Future<void>.delayed(hopDelay);
          final nextResp = await ApiService.sendRequest(
            candidate,
            responseType: ResponseType.plain,
            allowRedirects: true,
          );
          _trace(
            '[TC][authCrawl] candidate resp status=${nextResp.statusCode} uri=${nextResp.requestOptions.uri} realUri=${nextResp.realUri} location=${nextResp.headers.value('location') ?? ''} body=${_shortText(nextResp.data)}',
          );
          queue.add(nextResp);
        } catch (e) {
          debugPrint('tronclass auth crawl failed: $e');
        }
      }

      final formSubmissions = _extractBrokerFormSubmissions(
        current.data,
        baseUri: current.requestOptions.uri,
      );
      for (final submission in formSubmissions) {
        final action = submission['action']?.toString() ?? '';
        final method = submission['method']?.toString().toUpperCase() ?? 'GET';
        final fields = Map<String, String>.from(
          submission['fields'] as Map<String, String>? ?? const {},
        );
        final visitKey = '$method $action ${fields.keys.join(',')}';
        if (!visited.add(visitKey)) {
          continue;
        }

        try {
          _trace(
            '[TC][authCrawl] hop=$hops submit form method=$method action=$action fields=${fields.keys.join(',')} body=${_shortText(fields)}',
          );
          await Future<void>.delayed(hopDelay);
          final formResp = await ApiService.sendRequest(
            action,
            method: method,
            body: method == 'POST' ? fields : null,
            params: method == 'GET' ? fields : null,
            responseType: ResponseType.plain,
            allowRedirects: true,
          );
          _trace(
            '[TC][authCrawl] form resp status=${formResp.statusCode} uri=${formResp.requestOptions.uri} realUri=${formResp.realUri} location=${formResp.headers.value('location') ?? ''} body=${_shortText(formResp.data)}',
          );
          queue.add(formResp);
        } catch (e) {
          debugPrint('tronclass auth form submit failed: $e');
        }
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

      // 常见场景 1：隐藏字段中直接带 service
      final input = doc.querySelector('input[name="service"]');
      final value = input?.attributes['value'];
      if (value != null && value.isNotEmpty) {
        return value;
      }

      // 常见场景 2：登录表单 action 上带 service 参数
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

      // 常见场景 3：页面脚本里存在 var service = ["..."]
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
          r'''(?:var\s+)?FIELD\s*=\s*['"]([^'"]+)['"]'''.replaceAll(
            'FIELD',
            RegExp.escape(fieldName),
          ),
          caseSensitive: false,
        ),
        RegExp(
          r'''name=['"]FIELD['"][^>]*value=['"]([^'"]+)['"]'''.replaceAll(
            'FIELD',
            RegExp.escape(fieldName),
          ),
          caseSensitive: false,
        ),
        RegExp(
          r'''['"]FIELD['"]\s*:\s*['"]([^'"]+)['"]'''.replaceAll(
            'FIELD',
            RegExp.escape(fieldName),
          ),
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
    return encryptTronclassCasPasswordWithKey(password, key);
  }

  static Future<String> _getOrCreateCasBfp(String username) async {
    final normalizedUsername = username.trim();
    final prefs = await SharedPreferences.getInstance();
    final key = '$_tronclassCasBfpPrefix$normalizedUsername';
    final existing = prefs.getString(key);
    if (existing != null && RegExp(r'^[0-9A-F]{32}$').hasMatch(existing)) {
      return existing;
    }

    final bfp = List.generate(
      16,
      (_) => _tronclassCasCryptoRandom
          .nextInt(256)
          .toRadixString(16)
          .padLeft(2, '0'),
    ).join().toUpperCase();
    await prefs.setString(key, bfp);
    return bfp;
  }

  static Future<void> _reportCasBrowserFingerprint(
    String username, {
    required String service,
    LoginContext? loginContext,
  }) async {
    final bfp = await _getOrCreateCasBfp(username);
    await ApiService.sendRequest(
      '${TronclassGuetConstants.casBaseUrl}/authserver/bfp/info',
      params: {
        'bfp': bfp,
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      headers: TronclassLoginHeaders.build(
        stage: TronclassLoginRequestStage.casFingerprintReport,
        service: service,
      ),
      responseType: ResponseType.plain,
      allowRedirects: false,
      loginContext: loginContext,
    );
  }

  static Future<void> _clearStaleCasSessionCookies(
    LoginContext? loginContext,
  ) async {
    if (loginContext == null) {
      return;
    }
    try {
      final removed = await TronclassCasLoginHttp(
        loginContext: loginContext,
      ).clearStaleCasSessionCookies();
      if (removed > 0) {
        _trace('[TC][CAS] cleared stale session cookies count=$removed');
      }
    } catch (e) {
      _trace('[TC][CAS] clear stale session cookies failed=$e');
    }
  }

  static Future<Map<String, dynamic>> _loginForAuthCode(
    String username,
    String password, {
    Future<String?> Function(Uint8List imageBytes)? captchaProvider,
    Future<String?> Function(String? mobileHint, String? tip)? mfaCodeProvider,
    LoginContext? loginContext,
    bool resumeAfterMfa = false,
    bool allowMfaChallenge = true,
    bool stopAfterMfaDetection = false,
  }) async {
    _trace(
      resumeAfterMfa
          ? '[TC] restart auth-code flow after MFA'
          : '[TC] 使用 tronclass_plus 登录链路',
    );

    _trace('[TC] 步骤1: 探测 identity auth');
    final authProbe = await ApiService.sendRequest(
      _identityAuthUrl,
      params: _authQueryParams(),
      headers: TronclassLoginHeaders.build(
        stage: TronclassLoginRequestStage.identityAuth,
      ),
      responseType: ResponseType.plain,
      allowRedirects: true,
      loginContext: loginContext,
    );
    _trace('[TC] 步骤1完成: ${authProbe.statusCode}');

    final directCode =
        _extractAuthCodeFromAny(authProbe) ??
        authProbe.requestOptions.uri.queryParameters['code'];
    if (directCode != null && directCode.isNotEmpty) {
      _trace('[TC] auth probe direct code hit');
      return {'ok': true, 'code': directCode};
    }

    String? service =
        _extractService(authProbe) ??
        _extractServiceFromHtml(authProbe.data) ??
        _extractServiceFromRawUrl(authProbe.headers.value('location')) ??
        _extractServiceFromRawUrl(authProbe.requestOptions.uri.toString());

    if (service == null || service.isEmpty) {
      _trace('[TC] 步骤2: 尝试不跟随重定向探测');
      final authProbeNoFollow = await ApiService.sendRequest(
        _identityAuthUrl,
        params: _authQueryParams(),
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.identityAuth,
        ),
        responseType: ResponseType.plain,
        allowRedirects: false,
        loginContext: loginContext,
      );
      _trace('[TC] 步骤2完成: ${authProbeNoFollow.statusCode}');

      service =
          _extractService(authProbeNoFollow) ??
          _extractServiceFromHtml(authProbeNoFollow.data) ??
          _extractServiceFromRawUrl(
            authProbeNoFollow.headers.value('location'),
          ) ??
          _extractServiceFromRawUrl(
            authProbeNoFollow.requestOptions.uri.toString(),
          );

      var codeFromProbe =
          _extractAuthCodeFromAny(authProbeNoFollow) ??
          authProbeNoFollow.requestOptions.uri.queryParameters['code'];
      if (codeFromProbe != null && codeFromProbe.isNotEmpty) {
        _trace('[TC] auth no-follow direct code hit');
        return {'ok': true, 'code': codeFromProbe};
      }

      if (service == null || service.isEmpty) {
        final visited = <String>{};
        final queue = <Response>[authProbe, authProbeNoFollow];
        var hop = 0;
        while (queue.isNotEmpty &&
            hop < 4 &&
            (service == null || service.isEmpty)) {
          final current = queue.removeAt(0);
          hop += 1;

          service =
              _extractService(current) ??
              _extractServiceFromHtml(current.data) ??
              _extractServiceFromRawUrl(current.headers.value('location')) ??
              _extractServiceFromRawUrl(current.requestOptions.uri.toString());
          if (service != null && service.isNotEmpty) {
            break;
          }

          codeFromProbe =
              _extractAuthCodeFromAny(current) ??
              current.requestOptions.uri.queryParameters['code'];
          if (codeFromProbe != null && codeFromProbe.isNotEmpty) {
            _trace('[TC] auth crawl direct code hit hop=$hop');
            return {'ok': true, 'code': codeFromProbe};
          }

          final candidates = <String?>[
            _resolveUrlWithBase(
              current.requestOptions.uri,
              current.headers.value('location'),
            ),
            _resolveUrlWithBase(
              current.requestOptions.uri,
              _extractRedirectUrlFromHtml(current.data),
            ),
          ];

          for (final candidate in candidates) {
            if (candidate == null || candidate.isEmpty) {
              continue;
            }
            if (!visited.add(candidate)) {
              continue;
            }
            try {
              final chaseResp = await ApiService.sendRequest(
                candidate,
                headers: TronclassLoginHeaders.build(
                  stage: TronclassLoginHeaders.stageForUrl(candidate),
                  service: service,
                ),
                responseType: ResponseType.plain,
                allowRedirects: true,
                loginContext: loginContext,
              );
              queue.add(chaseResp);
            } catch (_) {
              // ignore single hop failures and continue probing
            }
          }
        }
      }
    }

    if (service == null || service.isEmpty) {
      return {
        'ok': false,
        'message': '未获取到 CAS service 参数',
        'debug': lastLoginTrace,
      };
    }

    _trace('[TC] 步骤3: 获取 CAS 登录页面');
    final loginPageResp = await ApiService.sendRequest(
      TronclassGuetConstants.casLoginUrl,
      params: {'service': service},
      headers: TronclassLoginHeaders.build(
        stage: TronclassLoginRequestStage.casLoginPage,
        service: service,
      ),
      responseType: ResponseType.plain,
      allowRedirects: false,
      loginContext: loginContext,
    );
    _trace('[TC] 步骤3完成: ${loginPageResp.statusCode}');

    final parsed = _parseLoginHtml(loginPageResp.data.toString());
    final aesKey = parsed['aesKey'];
    final execution = parsed['execution'];
    if (aesKey == null || execution == null) {
      return {'ok': false, 'message': 'CAS 页面参数解析失败', 'debug': lastLoginTrace};
    }

    try {
      _trace('[TC][bfp] report browser fingerprint');
      await _reportCasBrowserFingerprint(
        username,
        service: service,
        loginContext: loginContext,
      );
      _trace('[TC][bfp] report complete');
    } catch (e) {
      _trace('[TC][bfp] report failed=$e');
    }

    String captcha = '';
    _trace('[TC] 步骤4: 检查账号密码页是否需要图形验证码');
    final checkNeedCaptchaResp = await ApiService.sendRequest(
      TronclassGuetConstants.casCheckNeedCaptchaUrl,
      params: {
        'username': username,
        '_': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      headers: TronclassLoginHeaders.build(
        stage: TronclassLoginRequestStage.casCaptchaCheck,
        service: service,
      ),
      responseType: ResponseType.plain,
      allowRedirects: false,
      loginContext: loginContext,
    );
    _trace('[TC] 步骤4完成: ${checkNeedCaptchaResp.statusCode}');
    final checkNeedCaptcha =
        _tryParseJsonMap(checkNeedCaptchaResp.data) ?? const {};
    final needCaptcha =
        checkNeedCaptcha['isNeed'] == true ||
        checkNeedCaptcha['isNeed']?.toString().toLowerCase() == 'true';
    _trace('[TC][captcha] probe=${_loginPayloadSummary(checkNeedCaptcha)}');
    if (needCaptcha) {
      _trace('[TC][captcha] 检测到需要图形验证码');
      _trace('[TC] 需要图形验证码');
      if (captchaProvider == null) {
        return {'ok': false, 'message': '当前账号需要图形验证码'};
      }
      final captchaImageResp = await ApiService.sendRequest(
        '${TronclassGuetConstants.casCaptchaUrl}?${DateTime.now().millisecondsSinceEpoch}',
        headers: TronclassLoginHeaders.build(
          stage: TronclassLoginRequestStage.casCaptchaImage,
          service: service,
        ),
        responseType: ResponseType.bytes,
        allowRedirects: false,
        loginContext: loginContext,
      );
      final rawData = captchaImageResp.data;
      final Uint8List? imageBytes = switch (rawData) {
        Uint8List data => data,
        List<int> data => Uint8List.fromList(data),
        _ => null,
      };
      if (imageBytes == null) {
        return {'ok': false, 'message': '获取图形验证码失败'};
      }
      final input = await captchaProvider(imageBytes);
      if (input == null || input.trim().isEmpty) {
        return {'ok': false, 'message': '已取消图形验证码输入'};
      }
      captcha = input.trim();
      _trace('[TC] 验证码已输入');
    } else {
      _trace('[TC] 无需图形验证码');
    }

    _trace('[TC] 步骤5: 提交登录表单');
    if (!needCaptcha) {
      _trace('[TC][captcha] 无需图形验证码');
    }
    _trace(
      '[TC][login] password accepted path may still enter sms verification',
    );
    final loginResp = await ApiService.sendRequest(
      TronclassGuetConstants.casLoginUrl,
      method: 'POST',
      params: {'service': service},
      headers: TronclassLoginHeaders.build(
        stage: TronclassLoginRequestStage.casLoginSubmit,
        service: service,
      ),
      loginContext: loginContext,
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
    _trace('[TC] 步骤5完成: ${loginResp.statusCode}');

    final code =
        _extractAuthCodeFromAny(loginResp) ??
        loginResp.requestOptions.uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      _trace('[TC] login form direct code hit');
      return {'ok': true, 'code': code};
    }

    if (_isReAuthResponse(loginResp)) {
      final reauthEntryUrl = _extractReauthEntryUrl(
        loginResp,
        service: service,
      );
      final reauthReady = _isReAuthContextReady(
        loginResp,
        resolvedLocation: _resolveUrlWithBase(
          loginResp.requestOptions.uri,
          loginResp.headers.value('location'),
        ),
      );
      _trace(
        '[TC][MFA] detected sms secondary verification ready=$reauthReady reauthEntryUrl=${reauthEntryUrl ?? ''}',
      );
      if (!allowMfaChallenge) {
        return {
          'ok': false,
          'message': '短信验证成功后重新进入授权流程时仍被要求二次验证，请稍后重试',
          'debug': lastLoginTrace,
          'requireMfa': true,
          'reauthEntryUrl': reauthEntryUrl,
          'service': service,
          'mfaContextReady': reauthReady,
          'verificationStage': tronclassVerificationStageMfa,
        };
      }
      if (stopAfterMfaDetection) {
        return {
          'ok': false,
          'requireMfa': true,
          'message': reauthReady ? '检测到短信二次验证' : '检测到短信二次验证，但短信验证会话尚未就绪',
          'debug': lastLoginTrace,
          'reauthEntryUrl': reauthEntryUrl,
          'service': service,
          'mfaContextReady': reauthReady,
          'verificationStage': tronclassVerificationStageMfa,
        };
      }
      return _handleMfaChallenge(
        username,
        password: password,
        captchaProvider: captchaProvider,
        mfaCodeProvider: mfaCodeProvider,
        reauthEntryUrl: reauthEntryUrl,
        service: service,
        loginContext: loginContext,
      );
    }

    final loginErrorTip = _extractLoginErrorTip(loginResp.data);
    final normalizedLoginFailureMessage = loginErrorTip ?? '未获取到畅课授权码';
    _trace(
      '[TC] login POST result=credential_failure tip=${loginErrorTip ?? ''}',
    );
    return {
      'ok': false,
      'message': normalizedLoginFailureMessage,
      'debug': lastLoginTrace,
    };
  }

  /*
    final loginFailureMessage = loginErrorTip ?? '未获取到畅课授权码';
    _trace('[TC] login POST result=credential_failure tip=${loginErrorTip ?? ''}');
    return {
      'ok': false,
      'message': loginErrorTip ?? '未获取到畅课授权码',
      'debug': lastLoginTrace,
    };
  }

*/
  static Future<Map<String, dynamic>> login(
    String username,
    String password, {
    Future<String?> Function(Uint8List imageBytes)? captchaProvider,
    Future<String?> Function(String? mobileHint, String? tip)? mfaCodeProvider,
    Future<String?> Function(TronclassMfaPromptContext context)?
    mfaPromptProvider,
    LoginContext? loginContext,
  }) async {
    try {
      _resetTrace();
      CookieManager.isLoggingIn = true;
      await _clearStaleCasSessionCookies(loginContext);
      final effectiveMfaCodeProvider =
          mfaCodeProvider ??
          (mfaPromptProvider == null
              ? null
              : (String? mobileHint, String? tip) {
                  return mfaPromptProvider(
                    TronclassMfaPromptContext(
                      mobileHint: mobileHint,
                      tip: tip,
                      codeTimeSeconds: 120,
                      resendCode: () => _sendDynamicCodeWithContext(
                        username,
                        manualSendOnly: true,
                      ),
                    ),
                  );
                });

      final authCodeResult = await _loginForAuthCode(
        username,
        password,
        captchaProvider: captchaProvider,
        mfaCodeProvider: effectiveMfaCodeProvider,
        loginContext: loginContext,
      );
      if (authCodeResult['ok'] != true) {
        return authCodeResult;
      }

      final code = (authCodeResult['code'] ?? '').toString().trim();
      if (code.isEmpty) {
        return {'ok': false, 'message': '未获取到畅课授权码', 'debug': lastLoginTrace};
      }

      return completeWithAuthCode(code, loginContext: loginContext);
    } catch (e) {
      _trace('[TC] login exception=$e');
      return {'ok': false, 'message': '畅课登录失败：$e', 'debug': lastLoginTrace};
    } finally {
      CookieManager.isLoggingIn = false;
    }
  }
}
