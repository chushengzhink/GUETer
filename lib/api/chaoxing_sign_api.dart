import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';
import '../utils/encrypt.dart';

/// 学习通/雨课堂签到 API（完整实现，参考 yuketang 项目）
///
/// 支持 5 种签到类型：
/// 1. 普通签到（可带照片）
/// 2. 二维码签到
/// 3. 手势签到
/// 4. 位置签到
/// 5. 签到码签到
class ChaoxingSignApi {
  static const String _signUrl =
      'https://mobilelearn.chaoxing.com/pptSign/stuSignajax';

  /// 获取设备指纹
  static String get _deviceCode => EncryptionUtil.getDeviceCode();

  /// 获取课程活动列表
  static Future<Response> getActiveList({
    required String courseId,
    required String classId,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取活动列表');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    final url = '/ppt/activeAPI/taskactivelist';
    final params = {
      'courseId': courseId,
      'classId': classId,
      'showNotStartedActive': '0',
    };

    return await context.sendRequest(url, method: 'GET', params: params);
  }

  /// 普通签到（可带照片）
  static Future<Response> signNormal({
    required String activeId,
    required String courseId,
    required String uid,
    required String name,
    String? objectId,
    String? validate,
    String? clientip,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    final params = <String, String>{
      'activeId': activeId,
      'courseId': courseId,
      'uid': uid,
      'name': name,
      'clientip': clientip ?? '',
      'latitude': '-1',
      'longitude': '-1',
      'appType': '15',
      'fid': '0',
      'deviceCode': _deviceCode,
    };

    if (objectId != null) {
      params['objectId'] = objectId;
    }

    if (validate != null) {
      params['validate'] = validate;
    }

    return await context.sendRequest(
      _signUrl,
      method: 'GET',
      params: params,
      responseType: ResponseType.plain,
    );
  }

  /// 二维码签到（可带定位）
  /// 需要验证码时第一次发送会返回 validate_${enc2}
  /// enc2 用于固定 enc
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
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

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
      'ifCFP': '0',
      'courseId': courseId,
    };

    // 添加位置信息
    if (address != null && latitude != null && longitude != null) {
      final locationJson =
          '{"result":1,"latitude":$latitude,"longitude":$longitude,"mockData":{"strategy":0,"probability":-1},"address":"$address"}';
      params['location'] = locationJson;
    }

    // 添加验证码相关参数
    if (enc2 != null && validate != null) {
      params['enc2'] = enc2;
      params['validate'] = validate;
    }

    // 添加人脸 ID
    if (currentFaceId != null) {
      params['currentFaceId'] = currentFaceId;
    }

    return await context.sendRequest(
      _signUrl,
      method: 'GET',
      params: params,
      responseType: ResponseType.plain,
    );
  }

  /// 位置签到
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
    int vpProbability = -1,
    String vpStrategy = '',
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

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
      'ifCFP': '0',
    };

    if (validate != null) {
      params['validate'] = validate;
    }

    if (currentFaceId != null) {
      params['currentFaceId'] = currentFaceId;
    }

    return await context.sendRequest(
      _signUrl,
      method: 'GET',
      params: params,
      responseType: ResponseType.plain,
    );
  }

  /// 手势签到 / 签到码签到
  static Future<Response> signCode({
    required String activeId,
    required String courseId,
    required String uid,
    required String name,
    required String signCode,
    String? validate,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法签到');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    final params = <String, String>{
      'activeId': activeId,
      'courseId': courseId,
      'uid': uid,
      'name': name,
      'clientip': '',
      'latitude': '-1',
      'longitude': '-1',
      'appType': '15',
      'fid': '0',
      'signCode': signCode,
      'deviceCode': _deviceCode,
    };

    if (validate != null) {
      params['validate'] = validate;
    }

    return await context.sendRequest(
      _signUrl,
      method: 'GET',
      params: params,
      responseType: ResponseType.plain,
    );
  }

  /// 检查手势/签到码是否正确
  static Future<bool> checkSignCode({
    required String activeId,
    required String signCode,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法验证签到码');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    final url =
        'https://mobilelearn.chaoxing.com/widget/sign/pcStuSignController/checkSignCode';
    final params = {'activeId': activeId, 'signCode': signCode};

    try {
      final response = await context.sendRequest(
        url,
        method: 'GET',
        params: params,
      );

      final data = response.data;
      return data['result'] == 1;
      // {"result":1,"msg":"验证成功","data":null,"errorMsg":null}
      // {"result":0,"msg":null,"data":null,"errorMsg":"手势不正确"}
    } catch (e) {
      debugPrint('[ChaoxingSignApi] checkSignCode error: $e');
      return false;
    }
  }

  /// 获取首次采集的人脸图片 ID
  static Future<String?> getFaceId(String uid) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取人脸 ID');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final enc = EncryptionUtil.md5Hash(uid + Constant.getFaceSalt);
      final url =
          'https://passport2-api.chaoxing.com/api/getUserFaceid?enc=$enc';

      final response = await context.sendRequest(url, method: 'GET');
      final data = response.data;

      // {"result":1,"msg":"获取成功","data":{"http":"http://p.ananas.chaoxing.com/star3/origin/$objectid.jpg","objectid":objectid},"errorMsg":""}
      // 如果没有采集过人脸则为空字符串
      if (data['result'] == 1) {
        return data['data']['objectid'];
      }
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getFaceId error: $e');
    }

    return null;
  }

  /// 获取签到详情
  /// 所有签到类型可用
  static Future<Map<String, dynamic>?> getSignDetail({
    required String activeId,
    String? code,
  }) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取签到详情');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      var url =
          'https://mobilelearn.chaoxing.com/newsign/signDetail?activePrimaryId=$activeId&type=1';
      if (code != null) {
        url += '&msg=$code';
      }

      final response = await context.sendRequest(url, method: 'GET');
      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getSignDetail error: $e');
      return null;
    }
  }

  /// 获取活动详情
  static Future<Map<String, dynamic>?> getActiveInfoWeb(String activeId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取活动详情');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/active/getPPTActiveInfo?activeId=$activeId';

      final response = await context.sendRequest(url, method: 'GET');
      final data = response.data;

      if (data['result'] == 1) {
        return data['data'];
      }
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getActiveInfoWeb error: $e');
    }

    return null;
  }

  /// 获取参与详情
  static Future<Map<String, dynamic>?> getAttendInfoWeb(String activeId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取参与详情');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/v2/apis/sign/getAttendInfo?activeId=$activeId&moreClassAttendEnc=';

      final response = await context.sendRequest(url, method: 'GET');
      final data = response.data;

      if (data['result'] == 1) {
        return data['data'];
      }
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getAttendInfoWeb error: $e');
    }

    return null;
  }

  /// 签到回执
  static Future<Map<String, dynamic>?> getSignReceipt(String activeId) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法获取签到回执');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      final url =
          'https://mobilelearn.chaoxing.com/sign/signReceipt2?activeId=$activeId';

      final response = await context.sendRequest(url, method: 'GET');
      return response.data;
    } catch (e) {
      debugPrint('[ChaoxingSignApi] getSignReceipt error: $e');
      return null;
    }
  }

  /// 上传图片到学习通
  static Future<String?> uploadImage(File imageFile, String uid) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法上传图片');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.chaoxing,
      userId: userId,
    );

    try {
      // 1. 获取 token
      final tokenUrl = 'https://pan-yz.chaoxing.com/api/token/uservalid';
      final tokenResponse = await context.sendRequest(tokenUrl, method: 'GET');

      if (tokenResponse.data == null) {
        debugPrint('[ChaoxingSignApi] Failed to get token');
        return null;
      }

      final token = tokenResponse.data['_token'];

      // 2. 上传 CRC 状态
      final crcUrl = 'https://pan-yz.chaoxing.com/api/crcStorageStatus';
      final crc = await EncryptionUtil.getCRC(imageFile);
      final crcParams = <String, String>{
        'puid': uid,
        'crc': crc,
        '_token': token.toString(),
      };

      await context.sendRequest(crcUrl, method: 'GET', params: crcParams);

      // 3. 生成文件名
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final milliseconds = now.millisecond.toString().padLeft(3, '0');
      final fileName = '$timestamp$milliseconds.jpg';

      // 4. 上传文件
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path, filename: fileName),
        'puid': uid,
      });

      final uploadUrl =
          'https://pan-yz.chaoxing.com/upload?_from=mobilelearn&_token=$token';

      final uploadResponse = await context.sendRequest(
        uploadUrl,
        method: 'POST',
        body: formData,
      );

      final responseData = uploadResponse.data;
      final objectId = responseData['data']?['objectId'];

      return objectId;
    } catch (e) {
      debugPrint('[ChaoxingSignApi] uploadImage error: $e');
      return null;
    }
  }

  /// 检查签到状态是否成功
  static bool isSignSuccess(String? responseText) {
    if (responseText == null) return false;

    // 成功响应: "success" 或 "success2"（已过截止时间）
    return responseText.contains('success');
  }

  /// 检查是否需要验证码
  static bool needsValidate(String? responseText) {
    if (responseText == null) return false;

    // 需要验证码响应: "validate_${enc2}"
    return responseText.startsWith('validate_');
  }

  /// 从响应中提取 enc2（用于验证码场景）
  static String? extractEnc2(String? responseText) {
    if (responseText == null || !responseText.startsWith('validate_')) {
      return null;
    }

    return responseText.substring('validate_'.length);
  }

  /// 获取签到结果消息
  static String getSignMessage(String? responseText, {bool success = false}) {
    if (success) {
      return '签到成功';
    }

    if (responseText == null) {
      return '签到失败，请稍后再试';
    }

    if (responseText.contains('success')) {
      return '签到成功';
    }

    if (responseText.startsWith('validate_')) {
      return '需要验证码';
    }

    // 返回原始错误信息
    return responseText;
  }
}
