import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import 'sign_preflight_cache.dart';
import 'sign_request_profile.dart';
import '../platform.dart';
import '../session/account.dart';
import '../utils/encrypt.dart';

/// Chaoxing sign-in API adapted to this project's multi-account session model.
class ChaoxingSignApi {
  static const String _signUrl =
      'https://mobilelearn.chaoxing.com/pptSign/stuSignajax';
  static final SignPreflightCache _preflightCache = SignPreflightCache();

  static String get _deviceCode => EncryptionUtil.getDeviceCode();

  static String _currentUserIdOrThrow(String action) {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('Not logged in, cannot $action');
    }
    return userId;
  }

  static Future<Response> _sendForCurrentUser(
    String url, {
    String method = 'GET',
    Map<String, String>? params,
    Map<String, String>? headers,
    Map<String, String>? legacyHeaders,
    dynamic body,
    ResponseType responseType = ResponseType.json,
    bool allowRedirects = true,
    String action = 'send Chaoxing request',
    SignRequestProfile? signProfile,
  }) async {
    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: _currentUserIdOrThrow(action),
    );
    try {
      return await context.sendRequest(
        url,
        method: method,
        params: params,
        headers: headers,
        legacyHeaders: legacyHeaders,
        body: body,
        responseType: responseType,
        allowRedirects: allowRedirects,
        signProfile: signProfile,
      );
    } finally {
      context.dispose();
    }
  }

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static SignRequestProfile _profileForActive(String activeId) {
    final userId = AccountManager.currentSessionId ?? '';
    final cached = userId.isEmpty
        ? null
        : _preflightCache.read(
            platform: 'chaoxing',
            userId: userId,
            activityId: activeId,
          );
    return SignRequestProfiles.chaoxingMobileLearn(
      referer: cached?.referer ?? 'https://mobilelearn.chaoxing.com/',
    );
  }

  static void _rememberPreflight({
    required String activeId,
    required String detailUrl,
    required Response response,
    String? referer,
  }) {
    final userId = AccountManager.currentSessionId ?? '';
    if (userId.isEmpty || activeId.isEmpty) return;
    _preflightCache.write(
      SignPreflightContext(
        platform: 'chaoxing',
        userId: userId,
        activityId: activeId,
        createdAt: DateTime.now(),
        detailUrl: detailUrl,
        resolvedUrl: response.requestOptions.uri.toString(),
        referer: referer ?? detailUrl,
      ),
    );
  }

  static String _signDetailUrl(String activeId) {
    return 'https://mobilelearn.chaoxing.com/newsign/signDetail?activePrimaryId=$activeId&type=1';
  }

  static Future<Response> getActiveList({
    required String courseId,
    required String classId,
  }) {
    return _sendForCurrentUser(
      'https://mobilelearn.chaoxing.com/ppt/activeAPI/taskactivelist',
      params: {
        'courseId': courseId,
        'classId': classId,
        'showNotStartedActive': '0',
      },
      action: 'get active list',
    );
  }

  static Future<Response> signNormal({
    required String activeId,
    required String courseId,
    required String uid,
    required String name,
    String? objectId,
    String? validate,
    String? clientip,
  }) {
    final params = <String, String>{
      'activeId': activeId,
      'courseId': courseId,
      'uid': uid,
      'clientip': clientip ?? '',
      'latitude': '-1',
      'longitude': '-1',
      'appType': '15',
      'fid': '0',
      'name': name,
      'deviceCode': _deviceCode,
      if (objectId != null && objectId.isNotEmpty) 'objectId': objectId,
      if (validate != null && validate.isNotEmpty) 'validate': validate,
    };

    return _sendForCurrentUser(
      _signUrl,
      params: params,
      responseType: ResponseType.plain,
      action: 'normal sign',
      signProfile: _profileForActive(activeId),
    );
  }

  static Future<Response> signCode({
    required String activeId,
    required String courseId,
    required String uid,
    required String name,
    required String signCode,
    String? validate,
  }) {
    final params = <String, String>{
      'activeId': activeId,
      'courseId': courseId,
      'uid': uid,
      'clientip': '',
      'latitude': '-1',
      'longitude': '-1',
      'appType': '15',
      'fid': '0',
      'name': name,
      'signCode': signCode,
      'deviceCode': _deviceCode,
      if (validate != null && validate.isNotEmpty) 'validate': validate,
    };

    return _sendForCurrentUser(
      _signUrl,
      params: params,
      responseType: ResponseType.plain,
      action: 'code sign',
      signProfile: _profileForActive(activeId),
    );
  }

  static Future<Response> signLocation({
    required String activeId,
    required String courseId,
    required String uid,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? validate,
    String? currentFaceId,
    String? faceEnc,
    int vpProbability = -1,
    String vpStrategy = '',
  }) {
    final params = <String, String>{
      'name': name,
      'address': address,
      'activeId': activeId,
      'courseId': courseId,
      'uid': uid,
      'clientip': '',
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'fid': '0',
      'appType': '15',
      'ifTiJiao': '1',
      'deviceCode': _deviceCode,
      'vpProbability': vpProbability.toString(),
      'vpStrategy': vpStrategy,
      'ifCFP': currentFaceId == null ? '0' : '1',
      if (validate != null && validate.isNotEmpty) 'validate': validate,
      if (currentFaceId != null && currentFaceId.isNotEmpty)
        'currentFaceId': currentFaceId,
      if (faceEnc != null && faceEnc.isNotEmpty) 'faceEnc': faceEnc,
    };

    return _sendForCurrentUser(
      _signUrl,
      params: params,
      responseType: ResponseType.plain,
      action: 'location sign',
      signProfile: _profileForActive(activeId),
    );
  }

  static Future<Response> signQrcode({
    required String enc,
    required String activeId,
    required String courseId,
    required String uid,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    String? enc2,
    String? validate,
    String? currentFaceId,
    String? faceEnc,
  }) {
    final params = <String, String>{
      'enc': enc,
      'name': name,
      'activeId': activeId,
      'uid': uid,
      'clientip': '',
      'location': '',
      'latitude': '-1',
      'longitude': '-1',
      'fid': '0',
      'appType': '15',
      'deviceCode': _deviceCode,
      'vpProbability': '',
      'vpStrategy': '',
      'ifCFP': currentFaceId == null ? '0' : '1',
      'courseId': courseId,
      if (enc2 != null && enc2.isNotEmpty) 'enc2': enc2,
      if (validate != null && validate.isNotEmpty) 'validate': validate,
      if (currentFaceId != null && currentFaceId.isNotEmpty)
        'currentFaceId': currentFaceId,
      if (faceEnc != null && faceEnc.isNotEmpty) 'faceEnc': faceEnc,
    };

    if (address != null && latitude != null && longitude != null) {
      params['location'] = jsonEncode({
        'result': 1,
        'latitude': latitude,
        'longitude': longitude,
        'mockData': {'strategy': 0, 'probability': -1},
        'address': address,
      });
    }

    return _sendForCurrentUser(
      _signUrl,
      params: params,
      responseType: ResponseType.plain,
      action: 'qr code sign',
      signProfile: _profileForActive(activeId),
    );
  }

  static Future<bool> checkSignCode({
    required String activeId,
    required String signCode,
  }) async {
    try {
      final response = await _sendForCurrentUser(
        'https://mobilelearn.chaoxing.com/widget/sign/pcStuSignController/checkSignCode',
        params: {'activeId': activeId, 'signCode': signCode},
        action: 'check sign code',
      );
      final data = _asStringMap(response.data);
      return data?['result'] == 1 || data?['result']?.toString() == '1';
    } catch (e) {
      debugPrint('[ChaoxingSignApi] checkSignCode error: $e');
      return false;
    }
  }

  static Future<String?> getFaceId(String uid) async {
    try {
      final enc = EncryptionUtil.md5Hash(uid + Constant.getFaceSalt);
      final response = await _sendForCurrentUser(
        'https://passport2-api.chaoxing.com/api/getUserFaceid?enc=$enc',
        action: 'get face id',
      );
      final data = _asStringMap(response.data);
      final faceData = _asStringMap(data?['data']);
      final objectId = faceData?['objectid']?.toString();
      return objectId == null || objectId.isEmpty ? null : objectId;
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getFaceId error: $e');
      return null;
    }
  }

  static Future<String?> getFaceEnc({
    required String activeId,
    required String faceId,
    required String uid,
    required Map<String, dynamic> deviceInfo,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final faceResult = <String, dynamic>{
        'currentFaceId': faceId,
        'LiveDetectionStatus': '1',
        'collectStatus': '1',
        'cxcid': deviceInfo['cid'],
        'cxtime': timestamp,
      };
      final sortedKeys = faceResult.keys.toList()..sort();
      final buffer = StringBuffer();
      for (final key in sortedKeys) {
        buffer.write('$key${faceResult[key] ?? ''}');
      }
      buffer.write(deviceInfo['sc'] ?? '');
      faceResult['signToken'] = EncryptionUtil.md5Hash(buffer.toString());

      final response = await _sendForCurrentUser(
        'https://mobilelearn.chaoxing.com/pptSign/check-face-result',
        params: {
          'DB_STRATEGY': 'PRIMARY_KEY',
          'STRATEGY_PARA': 'activeId',
          'activeId': activeId,
          'faceResult': jsonEncode(faceResult),
        },
        action: 'get face enc',
      );
      final data = _asStringMap(response.data);
      if (data == null) return null;
      final ok = data['status'] == 1 || data['status']?.toString() == '1';
      return ok ? data['enc']?.toString() : null;
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getFaceEnc error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSignDetail({
    required String activeId,
    String? code,
  }) async {
    try {
      var url = _signDetailUrl(activeId);
      if (code != null && code.isNotEmpty) {
        url += '&msg=${Uri.encodeQueryComponent(code)}';
      }
      final response = await _sendForCurrentUser(
        url,
        action: 'get sign detail',
      );
      _rememberPreflight(
        activeId: activeId,
        detailUrl: url,
        response: response,
        referer: url,
      );
      return _asStringMap(response.data);
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getSignDetail error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getActiveInfoWeb(String activeId) async {
    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/active/getPPTActiveInfo?activeId=$activeId';
      final response = await _sendForCurrentUser(
        url,
        action: 'get active info',
      );
      _rememberPreflight(
        activeId: activeId,
        detailUrl: url,
        response: response,
        referer: _signDetailUrl(activeId),
      );
      final data = _asStringMap(response.data);
      return data?['result'] == 1 || data?['result']?.toString() == '1'
          ? _asStringMap(data?['data'])
          : null;
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getActiveInfoWeb error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getAttendInfoWeb(String activeId) async {
    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/sign/getAttendInfo?activeId=$activeId&moreClassAttendEnc=';
      final response = await _sendForCurrentUser(
        url,
        action: 'get attend info',
      );
      _rememberPreflight(
        activeId: activeId,
        detailUrl: url,
        response: response,
        referer: _signDetailUrl(activeId),
      );
      final data = _asStringMap(response.data);
      return data?['result'] == 1 || data?['result']?.toString() == '1'
          ? _asStringMap(data?['data'])
          : null;
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getAttendInfoWeb error: $e');
      return null;
    }
  }

  static Future<String?> groupSign(
    String activeId, {
    String? objectId,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final uid = AccountManager.currentSessionId ?? '';
    final params = <String, String>{
      'activeId': activeId,
      'uid': uid,
      'clientip': '',
      if (objectId != null && objectId.isNotEmpty) 'objectId': objectId,
    };
    if (address != null && latitude != null && longitude != null) {
      params.addAll({
        'address': address,
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
        'fid': '',
        'ifTiJiao': '1',
      });
    }
    final response = await _sendForCurrentUser(
      'https://mobilelearn.chaoxing.com/sign/stuSignajax',
      params: params,
      responseType: ResponseType.plain,
      action: 'group sign',
      signProfile: _profileForActive(activeId),
    );
    return response.data?.toString();
  }

  static Future<Map<String, dynamic>?> getSignReceipt(String activeId) async {
    try {
      final response = await _sendForCurrentUser(
        'https://mobilelearn.chaoxing.com/sign/signReceipt2?activeId=$activeId',
        action: 'get sign receipt',
      );
      return _asStringMap(response.data);
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getSignReceipt error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getGroupSignDetail(
    String activeId,
  ) async {
    try {
      final response = await _sendForCurrentUser(
        'https://mobilelearn.chaoxing.com/sign/getSignDetail?id=$activeId',
        action: 'get group sign detail',
      );
      return _asStringMap(response.data);
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getGroupSignDetail error: $e');
      return null;
    }
  }

  static Future<String?> uploadImage(File imageFile, String uid) async {
    try {
      final tokenResponse = await _sendForCurrentUser(
        'https://pan-yz.chaoxing.com/api/token/uservalid',
        action: 'get upload token',
      );
      final token = _asStringMap(tokenResponse.data)?['_token']?.toString();
      if (token == null || token.isEmpty) {
        return null;
      }

      final crc = await EncryptionUtil.getCRC(imageFile);
      await _sendForCurrentUser(
        'https://pan-yz.chaoxing.com/api/crcStorageStatus',
        params: {'puid': uid, 'crc': crc, '_token': token},
        action: 'check image crc',
      );

      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: '$timestamp.jpg',
        ),
        'puid': uid,
      });

      final uploadResponse = await _sendForCurrentUser(
        'https://pan-yz.chaoxing.com/upload?_from=mobilelearn&_token=$token',
        method: 'POST',
        body: formData,
        action: 'upload image',
      );
      return _asStringMap(
        _asStringMap(uploadResponse.data)?['data'],
      )?['objectId']?.toString();
    } catch (e) {
      debugPrint('[ChaoxingSignApi] uploadImage error: $e');
      return null;
    }
  }

  static bool isSignSuccess(String? responseText) {
    if (responseText == null) return false;
    return responseText.contains('success');
  }

  static bool needsValidate(String? responseText) {
    if (responseText == null) return false;
    return responseText.startsWith('validate_');
  }

  static String? extractEnc2(String? responseText) {
    if (!needsValidate(responseText)) return null;
    return responseText!.substring('validate_'.length);
  }

  static String getSignMessage(String? responseText, {bool success = false}) {
    if (success || responseText?.contains('success') == true) {
      return '签到成功';
    }
    if (responseText == null || responseText.isEmpty) {
      return '签到失败，请稍后再试';
    }
    if (responseText.startsWith('validate_')) {
      return '需要验证码';
    }
    return responseText;
  }
}
