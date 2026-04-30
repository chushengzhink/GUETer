import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';
import '../utils/encrypt.dart';

/// 学习通上传 API（参考 yuketang 项目）
class ChaoxingUploadApi {
  /// 上传图片到学习通云盘
  static Future<String?> uploadImage(File imageFile) async {
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
        debugPrint('[ChaoxingUploadApi] Failed to get token');
        return null;
      }
      final String token = tokenResponse.data['_token'];

      // 2. 上传 CRC
      final crcUrl = 'https://pan-yz.chaoxing.com/api/crcStorageStatus';
      final crc = await EncryptionUtil.getCRC(imageFile);
      final crcParams = {'puid': userId, 'crc': crc, '_token': token};
      await context.sendRequest(crcUrl, method: 'GET', params: crcParams);

      // 3. 生成文件名
      DateTime now = DateTime.now();
      final timestamp =
          "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
      final milliseconds = now.millisecond.toString().padLeft(3, '0');
      final formattedTime = '$timestamp$milliseconds';
      final fileName = "$formattedTime.jpg";

      // 4. 上传图片
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
        'puid': userId,
      });

      final uploadUrl =
          'https://pan-yz.chaoxing.com/upload?_from=mobilelearn&_token=$token';

      final uploadResponse = await context.sendRequest(
        uploadUrl,
        method: 'POST',
        body: formData,
      );
      final objectId = uploadResponse.data['data']['objectId'];

      return objectId;
    } catch (e) {
      debugPrint('[ChaoxingUploadApi] uploadImage error: $e');
      return null;
    }
  }

  /// 通过 objectId 获取图片 URL
  static String getImageUrl(String objectId) {
    return 'https://p.ananas.chaoxing.com/star4/$objectId/origin.jpg';
  }

  /// 将学习通的 Star3 图片转换为 Star4（减少一次重定向）
  static String toNewImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 3) {
        final size = pathSegments[1];
        final fileNameWithExt = pathSegments[2];

        final lastDotIndex = fileNameWithExt.lastIndexOf('.');
        if (lastDotIndex != -1) {
          final filename = fileNameWithExt.substring(0, lastDotIndex);
          final extension = fileNameWithExt.substring(lastDotIndex);
          return '${uri.scheme}://${uri.host}/star4/$filename/$size$extension';
        } else {
          return '${uri.scheme}://${uri.host}/star4/$fileNameWithExt/$size.png';
        }
      }
    } catch (e) {
      debugPrint('[ChaoxingUploadApi] URL转换失败: $e');
    }
    return url;
  }
}
