import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../platform.dart';
import 'api_service.dart';
import 'platform_dio_manager.dart';

/// 独立的平台请求上下文，使用每用户独立的 Dio 实例
class PlatformRequestContext {
  final PlatformType platform;
  final String userId;
  final Dio _dio;

  PlatformRequestContext._({
    required this.platform,
    required this.userId,
    required Dio dio,
  }) : _dio = dio;

  static Future<PlatformRequestContext> create({
    required PlatformType platform,
    required String userId,
  }) async {
    final dio = await PlatformDioManager.getDioForUser(
      platform: platform,
      userId: userId,
    );

    final platformName = _getPlatformName(platform);
    debugPrint('[PlatformRequestContext] Using isolated Dio: platform=$platformName userId=$userId');

    return PlatformRequestContext._(
      platform: platform,
      userId: userId,
      dio: dio,
    );
  }

  Future<Response> sendRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? params,
    Map<String, String>? headers,
    dynamic body,
    ResponseType responseType = ResponseType.json,
    bool allowRedirects = true,
  }) async {
    final options = Options(
      method: method,
      headers: headers,
      responseType: responseType,
    );

    final isAbsoluteUrl = url.startsWith('http://') || url.startsWith('https://');
    final fullUrl = isAbsoluteUrl ? url : '${_dio.options.baseUrl}$url';

    ApiService.appendExternalConsoleLog(
      'PlatformRequestContext',
      '${_getPlatformName(platform)}: $method $fullUrl',
    );

    var response = await _dio.request(
      url,
      queryParameters: params,
      data: body,
      options: options,
    );

    if (allowRedirects) {
      int redirectCount = 0;
      const maxRedirects = 10;
      final visitedUrls = <String>{response.requestOptions.uri.toString()};

      while (redirectCount < maxRedirects) {
        final locationHeader = response.headers.value('location');
        if (locationHeader == null || locationHeader.isEmpty) {
          break;
        }

        final currentUri = response.requestOptions.uri;
        final locationUri = Uri.tryParse(locationHeader);
        if (locationUri == null) {
          break;
        }

        final resolvedUri = locationUri.hasScheme
            ? locationUri
            : currentUri.resolveUri(locationUri);
        final locationUrl = resolvedUri.toString();

        if (visitedUrls.contains(locationUrl)) {
          break;
        }
        visitedUrls.add(locationUrl);

        response = await _dio.request(
          locationUrl,
          options: Options(
            method: 'GET',
            headers: options.headers,
            responseType: options.responseType,
          ),
        );
        redirectCount++;
      }
    }

    if (options.responseType == ResponseType.json) {
      if (response.data is String) {
        response.data = jsonDecode(response.data);
      }
    }

    return response;
  }

  static String _getPlatformName(PlatformType platform) {
    switch (platform) {
      case PlatformType.chaoxing:
        return 'chaoxing';
      case PlatformType.rainClassroom:
        return 'rainclassroom';
      case PlatformType.tronclass:
        return 'tronclass';
      case PlatformType.ketangpai:
        return 'ketangpai';
      case PlatformType.weizhuojiao:
        return 'weizhuojiao';
    }
  }

  void dispose() {
    // Dio 实例由 PlatformDioManager 管理，不需要手动关闭
  }
}
