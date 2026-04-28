import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';
import '../utils/encrypt.dart';

/// 学习通验证码 API（参考 yuketang 项目）
class ChaoxingCaptchaApi {
  late int _timestamp;
  late String _iv;
  static final RegExp _captchaRegExp = RegExp(r'cx_captcha_function\((.+)\)');

  /// 获取验证码图片
  Future<Map<String, dynamic>?> getCaptchaImages(String referer) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取验证码');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    _timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. 获取验证码配置
      final configUrl = 'https://captcha.chaoxing.com/captcha/get/conf';
      final configParams = {
        'callback': 'cx_captcha_function',
        'captchaId': Constant.cxCaptchaId,
        '_': _timestamp.toString(),
      };

      final configResponse = await context.sendRequest(
        configUrl,
        method: 'GET',
        params: configParams,
        responseType: ResponseType.plain,
      );

      // 解析配置响应
      String configResponseText = configResponse.data;
      Match? configMatch = _captchaRegExp.firstMatch(configResponseText);

      if (configMatch == null) {
        debugPrint('[ChaoxingCaptchaApi] Failed to parse captcha config');
        return null;
      }

      String configJsonString = configMatch.group(1)!.trim();
      Map<String, dynamic> config = jsonDecode(configJsonString);

      int serviceTime = config['t'];
      String captchaKey = EncryptionUtil.md5Hash('$serviceTime${_uuid()}');
      String token =
          '${EncryptionUtil.md5Hash('$serviceTime${Constant.cxCaptchaId}slide$captchaKey')}:${serviceTime + 300000}';
      _iv = EncryptionUtil.md5Hash(
        '${Constant.cxCaptchaId}slide$_timestamp${_uuid()}',
      );

      // 2. 获取验证码图片
      final imageUrl =
          'https://captcha.chaoxing.com/captcha/get/verification/image';
      final imageParams = {
        'callback': 'cx_captcha_function',
        'captchaId': Constant.cxCaptchaId,
        'type': 'slide',
        'version': '1.1.20',
        'captchaKey': captchaKey,
        'token': token,
        'referer': referer,
        'iv': _iv,
        '_': (_timestamp + 1).toString(),
      };

      final response = await context.sendRequest(
        imageUrl,
        method: 'GET',
        params: imageParams,
        responseType: ResponseType.plain,
      );

      String responseText = response.data;
      Match? match = _captchaRegExp.firstMatch(responseText);

      if (match != null) {
        String jsonString = match.group(1)!.trim();
        return jsonDecode(jsonString);
      }
    } catch (e) {
      debugPrint('[ChaoxingCaptchaApi] getCaptchaImages error: $e');
    }
    return null;
  }

  /// 提交验证码结果
  Future<String?> submitCaptcha(
    double xValue,
    String token,
    String referer,
  ) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法提交验证码');
    }

    if (_iv.isEmpty || _timestamp <= 0) {
      debugPrint('[ChaoxingCaptchaApi] iv or timestamp not initialized');
      return null;
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://captcha.chaoxing.com/captcha/check/verification/result';
      final params = {
        'callback': 'cx_captcha_function',
        'captchaId': Constant.cxCaptchaId,
        'type': 'slide',
        'token': token,
        'textClickArr': '[{"x":${xValue.round()}}]',
        'coordinate': '[]',
        'runEnv': '10',
        'version': '1.1.20',
        't': 'a',
        'iv': _iv,
        '_': (_timestamp + 2).toString(),
      };

      final headers = {'Referer': referer};

      final response = await context.sendRequest(
        url,
        method: 'GET',
        params: params,
        headers: headers,
        responseType: ResponseType.plain,
      );

      String responseText = response.data;
      Match? match = _captchaRegExp.firstMatch(responseText);

      if (match != null) {
        String jsonString = match.group(1)!.trim();
        Map<String, dynamic> result = jsonDecode(jsonString);

        if (result['error'] == 0 && result['result'] == true) {
          // 解析 extraData 中的 validate
          String extraData = result['extraData'];
          Map<String, dynamic> extraDataMap = jsonDecode(extraData);
          return extraDataMap['validate'];
        }
      }
    } catch (e) {
      debugPrint('[ChaoxingCaptchaApi] submitCaptcha error: $e');
    }
    return null;
  }

  /// 生成 UUID
  static String _uuid() {
    Random random = Random();
    String hexChars = "0123456789abcdef";
    List<String> vA = List.generate(
      36,
      (index) => hexChars[random.nextInt(16)],
    );

    vA[14] = "4";
    String originalChar = vA[19];
    int num = int.tryParse(originalChar, radix: 16) ?? 0;
    int newValue = (num & 3) | 8;
    vA[19] = hexChars[newValue];

    List<int> dashPositions = [8, 13, 18, 23];
    for (int pos in dashPositions) {
      vA[pos] = "-";
    }

    return vA.join('');
  }
}
