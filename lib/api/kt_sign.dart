import 'package:flutter/foundation.dart';

import 'api_service.dart';

class KTSignApi {
  static Future<bool> scanToSign(String params, String token) async {
    final reqtimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ticketid = RegExp(r'ticketid=([^&]*)').firstMatch(params)?.group(1) ?? '';
    final expire = RegExp(r'expire=([^&]*)').firstMatch(params)?.group(1) ?? '';
    final sign = RegExp(r'sign=([^&]*)').firstMatch(params)?.group(1) ?? '';

    try {
      final response = await ApiService.sendRequest(
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
      if (info.isNotEmpty) {
        debugPrint(info);
      }
      return data['data']?['state'] == 8;
    } catch (e) {
      debugPrint('KTSignApi.scanToSign error: $e');
      return false;
    }
  }

  static Future<bool> numberSign({
    required String code,
    required String token,
    required String signId,
  }) async {
    final reqtimestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await ApiService.sendRequest(
        '/AttenceApi/checkin',
        method: 'POST',
        headers: {'token': token},
        body: {
          'reqtimestamp': reqtimestamp,
          'id': signId,
          'code': code,
        },
      );
      return response.data['code'] == 10000;
    } catch (e) {
      debugPrint('KTSignApi.numberSign error: $e');
      return false;
    }
  }

  static Future<bool> gpsSign({
    required String token,
    required String signId,
  }) async {
    final reqtimestamp = DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await ApiService.sendRequest(
        '/AttenceApi/checkin',
        method: 'POST',
        headers: {'token': token},
        body: {
          'reqtimestamp': reqtimestamp,
          'id': signId,
          'code': '',
          'unusual': 0,
          'latitude': '25.3',
          'longitude': '110.4',
          'accuracy': '100',
          'clienttype': 1,
        },
      );
      return response.data['code'] == 10000;
    } catch (e) {
      debugPrint('KTSignApi.gpsSign error: $e');
      return false;
    }
  }
}
