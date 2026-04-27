import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

class KTSignApi {
  static Map<String, String> extractScanParams(String rawUrl) {
    final raw = rawUrl.trim();
    if (raw.isEmpty) {
      return const <String, String>{};
    }

    final normalized = raw.replaceAll('&amp;', '&');
    final uri = Uri.tryParse(normalized);
    String pick(String key) {
      if (uri != null) {
        final fromQuery = uri.queryParameters[key];
        if (fromQuery != null && fromQuery.trim().isNotEmpty) {
          return Uri.decodeComponent(fromQuery).trim();
        }
      }
      return _extractParamFromText(normalized, key);
    }

    return <String, String>{
      'ticketid': pick('ticketid'),
      'expire': pick('expire'),
      'sign': pick('sign'),
    };
  }

  static String _extractParamFromText(String text, String key) {
    final match = RegExp(
      '(?:^|[?&#])$key=([^&#]*)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null || match.groupCount < 1) {
      return '';
    }
    final value = match.group(1) ?? '';
    if (value.isEmpty) {
      return '';
    }
    return Uri.decodeComponent(value).trim();
  }

  static Future<bool> scanToSign(String params, String token) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('课堂派', '未登录，无法签到');
      return false;
    }

    final reqtimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final parsed = extractScanParams(params);
    final ticketid = parsed['ticketid'] ?? '';
    final expire = parsed['expire'] ?? '';
    final sign = parsed['sign'] ?? '';

    if (ticketid.isEmpty || expire.isEmpty || sign.isEmpty) {
      debugPrint(
        'KTSignApi.scanToSign invalid params: ticketid=$ticketid expire=$expire sign=${sign.isNotEmpty}',
      );
      ApiService.appendExternalConsoleLog(
        '课堂派',
        '二维码签到参数无效: ticketid=${ticketid.isEmpty ? "空" : "有"} expire=${expire.isEmpty ? "空" : "有"} sign=${sign.isEmpty ? "空" : "有"}',
      );
      return false;
    }

    ApiService.appendExternalConsoleLog(
      '课堂派',
      '二维码签到: ticketid=${ticketid.substring(0, ticketid.length > 8 ? 8 : ticketid.length)}...',
    );

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.ketangpai,
        userId: userId,
      );

      final response = await context.sendRequest(
        '/AttenceApi/AttenceResult',
        method: 'POST',
        headers: {'token': token},
        body: {
          'ticketid': ticketid,
          'expire': expire,
          'sign': sign,
          'reqtimestamp': reqtimestamp,
        },
      );
      final data = response.data;
      final info = data['data']?['info']?.toString() ?? data['message']?.toString() ?? '';
      final success = data['data']?['state'] == 8;

      ApiService.appendExternalConsoleLog(
        '课堂派',
        '二维码签到结果: ${success ? "成功" : "失败"} $info',
      );

      if (info.isNotEmpty) {
        debugPrint(info);
      }
      return success;
    } catch (e) {
      debugPrint('KTSignApi.scanToSign error: $e');
      ApiService.appendExternalConsoleLog('课堂派', '二维码签到异常: $e');
      return false;
    }
  }

  /// Fetch the number code for a sign-in task
  static Future<String?> getNumberCode({
    required String token,
    required String signId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final reqtimestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.ketangpai,
        userId: userId,
      );

      final response = await context.sendRequest(
        '/AttenceApi/getDigitAttence',
        method: 'POST',
        headers: {'token': token},
        body: {
          'id': signId,
          'reqtimestamp': reqtimestamp,
        },
      );
      final code = response.data['data']?['data']?['code']?.toString();
      if (code != null && code.isNotEmpty) {
        ApiService.appendExternalConsoleLog('课堂派', '获取数字签到码: $code');
        return code;
      }
      return null;
    } catch (e) {
      debugPrint('KTSignApi.getNumberCode error: $e');
      ApiService.appendExternalConsoleLog('课堂派', '获取数字签到码失败: $e');
      return null;
    }
  }

  /// Check-in/check-out sign-in (type 4)
  static Future<bool> checkInOutSign({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final reqtimestamp = DateTime.now().millisecondsSinceEpoch;

    ApiService.appendExternalConsoleLog(
      '课堂派',
      '签入签出: signId=$signId lat=${latitude ?? "默认"} lng=${longitude ?? "默认"}',
    );

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.ketangpai,
        userId: userId,
      );

      final response = await context.sendRequest(
        '/AttenceApi/checkin',
        method: 'POST',
        headers: {'token': token},
        body: {
          'reqtimestamp': reqtimestamp,
          'id': signId,
          'code': '',
          'unusual': '',
          'latitude': latitude ?? '',
          'longitude': longitude ?? '',
          'accuracy': accuracy ?? '',
          'clienttype': 1,
        },
      );

      final success = response.data['code'] == 10000;
      final message = response.data['message']?.toString() ?? '';

      ApiService.appendExternalConsoleLog(
        '课堂派',
        '签入签出结果: ${success ? "成功" : "失败"} $message',
      );

      return success;
    } catch (e) {
      debugPrint('KTSignApi.checkInOutSign error: $e');
      ApiService.appendExternalConsoleLog('课堂派', '签入签出异常: $e');
      return false;
    }
  }

  static Future<bool> numberSign({
    required String code,
    required String token,
    required String signId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final reqtimestamp = DateTime.now().millisecondsSinceEpoch;

    ApiService.appendExternalConsoleLog(
      '课堂派',
      '数字签到: signId=$signId code=$code',
    );

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.ketangpai,
        userId: userId,
      );

      final response = await context.sendRequest(
        '/AttenceApi/checkin',
        method: 'POST',
        headers: {'token': token},
        body: {
          'reqtimestamp': reqtimestamp,
          'id': signId,
          'code': code,
        },
      );

      final success = response.data['code'] == 10000;
      final message = response.data['message']?.toString() ?? '';

      ApiService.appendExternalConsoleLog(
        '课堂派',
        '数字签到结果: ${success ? "成功" : "失败"} $message',
      );

      return success;
    } catch (e) {
      debugPrint('KTSignApi.numberSign error: $e');
      ApiService.appendExternalConsoleLog('课堂派', '数字签到异常: $e');
      return false;
    }
  }

  static Future<bool> gpsSign({
    required String token,
    required String signId,
    String? latitude,
    String? longitude,
    String? accuracy,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return false;
    }

    final reqtimestamp = DateTime.now().millisecondsSinceEpoch;

    ApiService.appendExternalConsoleLog(
      '课堂派',
      'GPS签到: signId=$signId lat=${latitude ?? "默认"} lng=${longitude ?? "默认"}',
    );

    try {
      final context = await PlatformRequestContext.create(
        platform: PlatformType.ketangpai,
        userId: userId,
      );

      final response = await context.sendRequest(
        '/AttenceApi/checkin',
        method: 'POST',
        headers: {'token': token},
        body: {
          'reqtimestamp': reqtimestamp,
          'id': signId,
          'code': '',
          'unusual': '',
          'latitude': latitude ?? '',
          'longitude': longitude ?? '',
          'accuracy': accuracy ?? '',
          'clienttype': 1,
        },
      );

      final success = response.data['code'] == 10000;
      final message = response.data['message']?.toString() ?? '';

      ApiService.appendExternalConsoleLog(
        '课堂派',
        'GPS签到结果: ${success ? "成功" : "失败"} $message',
      );

      return success;
    } catch (e) {
      debugPrint('KTSignApi.gpsSign error: $e');
      ApiService.appendExternalConsoleLog('课堂派', 'GPS签到异常: $e');
      return false;
    }
  }
}
