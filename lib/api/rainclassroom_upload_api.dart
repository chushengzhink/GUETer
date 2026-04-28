import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

class RainClassroomUploadApi {
  static Future<String?> uploadImage(File imageFile) async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      throw Exception('未登录，无法上传图片');
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.rainClassroom,
      userId: userId,
    );

    try {
      final tokenUrl = '/pc/generate_qiniu_token';
      final jsonData = {
        'bucket_name': 'cms-attachment',
        'expired_time': 3600,
      };
      final tokenResponse = await context.sendRequest(
        tokenUrl,
        method: 'POST',
        body: jsonData,
      );

      if (tokenResponse.data == null ||
          tokenResponse.data['success'] != true ||
          tokenResponse.data['data'] == null) {
        debugPrint('Failed to get qiniu token');
        return null;
      }

      final token = tokenResponse.data['data']['token'];

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final originalFileName = imageFile.path.split('/').last;
      final fileName = '$timestamp$originalFileName';

      final uploadUrl = 'https://upload.qiniup.com/';
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        'token': token,
        'key': fileName,
        'fname': originalFileName,
      });

      final uploadResponse = await context.sendRequest(
        uploadUrl,
        method: 'POST',
        body: formData,
      );

      if (uploadResponse.data == null ||
          uploadResponse.data['success'] != true) {
        debugPrint('Failed to upload to qiniu');
        return null;
      }

      final key = uploadResponse.data['key'];
      final imageUrl = 'https://qn-scd1.yuketang.cn/$key';
      return imageUrl;
    } catch (e) {
      debugPrint('uploadImageToQiniu error: $e');
    }
    return null;
  }
}
