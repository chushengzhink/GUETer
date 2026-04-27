import 'dart:io';

class UserAgentHelper {
  static String? _cachedUserAgent;
  static bool _initialized = false;

  static const String _fallbackUA =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.43 Mobile Safari/537.36';

  static Future<String> getRainClassroomUA() async {
    if (_initialized && _cachedUserAgent != null) {
      return _cachedUserAgent!;
    }

    _cachedUserAgent = _buildFallbackUA();
    _initialized = true;
    return _cachedUserAgent!;
  }

  static Future<String> getTronclassUA() async {
    if (_initialized && _cachedUserAgent != null) {
      return _cachedUserAgent!;
    }

    _cachedUserAgent = _buildFallbackUA();
    _initialized = true;
    return _cachedUserAgent!;
  }

  static String _buildFallbackUA() {
    if (Platform.isAndroid) {
      final androidVersion = _getAndroidVersion();
      if (androidVersion != null) {
        return 'Mozilla/5.0 (Linux; Android $androidVersion; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.43 Mobile Safari/537.36';
      }
    }
    return _fallbackUA;
  }

  static String? _getAndroidVersion() {
    try {
      final version = Platform.operatingSystemVersion;
      final match = RegExp(r'Android (\d+(?:\.\d+)?)').firstMatch(version);
      return match?.group(1);
    } catch (e) {
      return null;
    }
  }

  static Map<String, String> getRainClassroomHeaders(String userAgent) {
    return {
      'User-Agent': userAgent,
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Referer': 'https://www.yuketang.cn/',
    };
  }

  static Map<String, String> getTronclassHeaders(String userAgent, String baseUrl) {
    return {
      'User-Agent': userAgent,
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Referer': baseUrl,
    };
  }

  static void clearCache() {
    _cachedUserAgent = null;
    _initialized = false;
  }
}
