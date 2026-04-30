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

      return success;
    } catch (e) {
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
    String? courseId, // 新增：用于从课程设置读取坐标
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      return false;
    }

    // 优先使用传入的坐标，否则尝试从课程设置读取
    String finalLatitude = latitude ?? '';
    String finalLongitude = longitude ?? '';
    String finalAccuracy = accuracy ?? '100';

    if (finalLatitude.isEmpty || finalLongitude.isEmpty) {
      // 尝试从课程设置读取坐标
      if (courseId != null && courseId.isNotEmpty) {
        try {
          // 动态导入避免循环依赖
          final settingModule = await _loadCourseSetting();
          if (settingModule != null) {
            final location = await settingModule.getDefaultLocation(courseId);
            if (location != null) {
              finalLatitude = location.latitude.toString();
              finalLongitude = location.longitude.toString();
              ApiService.appendExternalConsoleLog(
                '课堂派',
                'GPS签到: 使用课程设置坐标 lat=$finalLatitude lng=$finalLongitude',
              );
            }
          }
        } catch (e) {
          ApiService.appendExternalConsoleLog('课堂派', 'GPS签到: 读取课程设置失败: $e');
        }
      }

      // 如果仍然为空，使用默认坐标
      if (finalLatitude.isEmpty || finalLongitude.isEmpty) {
        finalLatitude = '25.3';
        finalLongitude = '110.4';
        ApiService.appendExternalConsoleLog(
          '课堂派',
          'GPS签到: 使用默认坐标 lat=$finalLatitude lng=$finalLongitude',
        );
      }
    }

    final reqtimestamp = DateTime.now().millisecondsSinceEpoch;

    ApiService.appendExternalConsoleLog(
      '课堂派',
      'GPS签到: signId=$signId lat=$finalLatitude lng=$finalLongitude',
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
          'latitude': finalLatitude,
          'longitude': finalLongitude,
          'accuracy': finalAccuracy,
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
      ApiService.appendExternalConsoleLog('课堂派', 'GPS签到异常: $e');
      return false;
    }
  }

  /// 动态加载课程设置模块（避免循环依赖）
  static Future<_CourseSettingModule?> _loadCourseSetting() async {
    try {
      // 这里使用延迟导入避免循环依赖
      // 实际实现时需要根据项目结构调整
      return null; // 暂时返回 null，后续实现
    } catch (e) {
      return null;
    }
  }
}

/// 课程设置模块接口（避免循环依赖）
abstract class _CourseSettingModule {
  Future<_Location?> getDefaultLocation(String courseId);
}

/// 位置信息（避免循环依赖）
class _Location {
  final double latitude;
  final double longitude;
  final String address;

  _Location({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}
