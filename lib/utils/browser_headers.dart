import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class BrowserHeadersManager {
  static String? _cachedUserAgent;
  static const String _fallbackUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.43 Mobile Safari/537.36';

  static Future<String> getUserAgent() async {
    if (_cachedUserAgent != null) {
      return _cachedUserAgent!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('browser_user_agent');
      if (stored != null && stored.isNotEmpty && !stored.contains('Dart')) {
        _cachedUserAgent = stored;
        debugPrint('[BrowserHeaders] Using stored UA: $stored');
        return stored;
      }
    } catch (e) {
      debugPrint('[BrowserHeaders] Failed to get stored UA: $e');
    }

    String platformUA = _fallbackUserAgent;
    if (Platform.isAndroid) {
      platformUA =
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.43 Mobile Safari/537.36';
    } else if (Platform.isIOS) {
      platformUA =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1';
    } else if (Platform.isWindows) {
      platformUA =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    } else if (Platform.isMacOS) {
      platformUA =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    }

    _cachedUserAgent = platformUA;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('browser_user_agent', platformUA);
    } catch (e) {
      debugPrint('[BrowserHeaders] Failed to save UA: $e');
    }

    debugPrint('[BrowserHeaders] Using platform-specific UA: $platformUA');
    return platformUA;
  }

  static Map<String, String> getStandardHeaders({String? referer}) {
    final headers = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9',
    };
    if (referer != null) {
      headers['Referer'] = referer;
    }
    return headers;
  }

  static String getRefererForPlatform(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'tronclass':
        return 'https://courses.guet.edu.cn/';
      case 'chaoxing':
        return 'https://www.chaoxing.com/';
      case 'rainclassroom':
        return 'https://www.yuketang.cn/';
      case 'ketangpai':
        return 'https://www.ketangpai.com/';
      case 'weizhuojiao':
        return 'https://v18.teachermate.cn/';
      default:
        return '';
    }
  }
}
