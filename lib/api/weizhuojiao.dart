import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../api/api_service.dart';

class WZJSignData {
  final String openid;
  final String sourceUrl;
  final Map<String, dynamic> fields;
  final bool applyGps;

  const WZJSignData({
    required this.openid,
    required this.sourceUrl,
    required this.fields,
    required this.applyGps,
  });

  String? get signId => fields['signId']?.toString();
  String? get courseId => fields['courseId']?.toString();
}

class WZJApi {
  static const String _baseUrl = 'https://v18.teachermate.cn';
  static const String _signPagePath = '/wechat/wechat/guide/signin';
  static const String _signSubmitPath = '/wechat-api/v1/class-attendance/student-sign-in';

  static final Map<String, String> _headers = {
    'user-agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 8_4 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H143 MicroMessenger/6.2.3 NetType/WIFI Language/zh_CN',
    'accept': 'application/json, text/plain, */*',
    'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
    'host': 'v18.teachermate.cn',
  };

  static String extractOpenid(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(text);
    if (uri != null) {
      final queryOpenid = uri.queryParameters['openid'];
      if (queryOpenid != null && queryOpenid.trim().isNotEmpty) {
        return queryOpenid.trim();
      }
    }

    final match = RegExp(r'openid=([^&?#]+)').firstMatch(text);
    if (match != null) {
      return Uri.decodeComponent(match.group(1) ?? '').trim();
    }

    return text;
  }

  static Future<WZJSignData?> loadSignData(String input) async {
    try {
      final openid = extractOpenid(input);
      if (openid.isEmpty) {
        return null;
      }

      final response = await ApiService.sendRequest(
        '$_baseUrl$_signPagePath?openid=${Uri.encodeComponent(openid)}',
        method: 'GET',
        headers: _headers,
        responseType: ResponseType.plain,
      );

      final html = response.data?.toString() ?? '';
      if (html.isEmpty) {
        return null;
      }

      final document = html_parser.parse(html);
      final fields = <String, dynamic>{};
      bool applyGps = false;

      for (final element in document.querySelectorAll('input[type=hidden]')) {
        final id = element.attributes['id']?.trim();
        final value = element.attributes['value']?.trim() ?? '';
        if (id == null || id.isEmpty) {
          continue;
        }

        switch (id) {
          case 'token-hash':
            fields['wx_csrf_name'] = value;
            break;
          case 'openid':
            fields['openid'] = value.isNotEmpty ? value : openid;
            break;
          case 'sign-id':
            fields['signId'] = value;
            break;
          case 'course-id':
            fields['courseId'] = value;
            break;
          case 'apply-gps':
            applyGps = value == '1';
            break;
          default:
            fields[id] = value;
            break;
        }
      }

      fields.putIfAbsent('openid', () => openid);
      return WZJSignData(
        openid: openid,
        sourceUrl: '$_baseUrl$_signPagePath?openid=${Uri.encodeComponent(openid)}',
        fields: fields,
        applyGps: applyGps,
      );
    } catch (e) {
      debugPrint('WZJApi.loadSignData error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> submitSign(
    WZJSignData signData, {
    double? longitude,
    double? latitude,
  }) async {
    try {
      final body = Map<String, dynamic>.from(signData.fields);
      if (signData.applyGps) {
        body['lon'] = (longitude ?? 0).toStringAsFixed(5);
        body['lat'] = (latitude ?? 0).toStringAsFixed(5);
      } else {
        body['lon'] = '0';
        body['lat'] = '0';
      }

      final response = await ApiService.sendRequest(
        '$_baseUrl$_signSubmitPath',
        method: 'POST',
        headers: _headers,
        body: FormData.fromMap(body),
        responseType: ResponseType.plain,
      );

      final message = response.data?.toString().trim() ?? '';
      return {
        'ok': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': message.isNotEmpty ? message : '提交完成',
        'body': response.data,
      };
    } catch (e) {
      debugPrint('WZJApi.submitSign error: $e');
      return {
        'ok': false,
        'message': '签到失败：$e',
      };
    }
  }
}
