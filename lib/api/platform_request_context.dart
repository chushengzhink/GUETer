import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../platform.dart';
import 'api_service.dart';
import 'platform_functional_request_profile.dart';
import 'platform_dio_manager.dart';
import 'sign_request_profile.dart';
import 'platform_request_stability.dart';

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
    debugPrint(
      '[PlatformRequestContext] Using isolated Dio: platform=$platformName userId=$userId',
    );

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
    Map<String, String>? legacyHeaders,
    dynamic body,
    ResponseType responseType = ResponseType.json,
    bool allowRedirects = true,
    SignRequestProfile? signProfile,
    PlatformRequestOptions? platformOptions,
  }) async {
    final isAbsoluteUrl =
        url.startsWith('http://') || url.startsWith('https://');
    final fullUrl = isAbsoluteUrl ? url : '${_dio.options.baseUrl}$url';

    ApiService.appendExternalConsoleLog(
      'PlatformRequestContext',
      '${_getPlatformName(platform)}: $method $fullUrl',
    );

    final shouldUseStableRequest = PlatformRequestStability.shouldHandle(
      method: method,
      options: platformOptions,
    );
    var stableFromCache = false;
    var stableDedupeHit = false;
    String? stableStaleReason;
    var functionalProfileName = '';
    var functionalHeaderCount = 0;
    final signContext = signProfile == null
        ? null
        : SignRequestContext(
            platform: platform,
            url: fullUrl,
            method: method,
            baseUrl: _dio.options.baseUrl.isEmpty ? null : _dio.options.baseUrl,
            referer: _headerValue(headers, 'Referer'),
            contentKind: SignRequestContext.inferContentKind(
              method: method,
              body: body,
              headers: headers,
            ),
            csrfTokenHint:
                _headerValue(headers, 'X-CSRFToken') ??
                _headerValue(headers, 'x-csrftoken'),
          );
    final functionalContext = PlatformFunctionalRequestContext(
      platform: platform,
      url: fullUrl,
      method: method,
      baseUrl: _dio.options.baseUrl.isEmpty ? null : _dio.options.baseUrl,
      referer: _headerValue(headers, 'Referer'),
      contentKind: PlatformFunctionalRequestContext.inferContentKind(
        method: method,
        body: body,
        headers: headers,
      ),
    );

    var response = await SignRequestExecutor.run(
      profile: signProfile,
      headers: _mergeFunctionalHeaders(
        headers: headers,
        signProfile: signProfile,
        platformOptions: platformOptions,
        context: functionalContext,
        onApplied: (profileName, headerCount) {
          functionalProfileName = profileName;
          functionalHeaderCount = headerCount;
        },
      ),
      legacyHeaders: legacyHeaders,
      operation: '$method $fullUrl',
      context: signContext,
      logSink: ApiService.appendExternalConsoleLog,
      send: (effectiveHeaders) async {
        Future<Response<dynamic>> network(CancelToken? cancelToken) {
          return _dio.request(
            url,
            queryParameters: params,
            data: body,
            options: Options(
              method: method,
              headers: effectiveHeaders,
              responseType: responseType,
            ),
            cancelToken: cancelToken,
          );
        }

        if (shouldUseStableRequest) {
          final stableResult = await PlatformRequestStability.execute(
            platform: _getPlatformName(platform),
            userId: userId,
            url: fullUrl,
            method: method,
            params: params,
            options: platformOptions!,
            network: network,
          );
          stableFromCache = stableResult.fromCache;
          stableDedupeHit = stableResult.dedupeHit;
          stableStaleReason = stableResult.staleReason;
          return stableResult.response;
        }

        return network(null);
      },
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

        final redirectHeaders = response.requestOptions.headers.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
        response = await _dio.request(
          locationUrl,
          options: Options(
            method: 'GET',
            headers: redirectHeaders,
            responseType: responseType,
          ),
        );
        redirectCount++;
      }
    }

    if (responseType == ResponseType.json) {
      if (response.data is String) {
        response.data = jsonDecode(response.data);
      }
    }

    if (platformOptions != null) {
      final throttleState = PlatformRequestStability.throttle.stateFor(
        platform: _getPlatformName(platform),
        userId: userId,
      );
      ApiService.appendExternalConsoleLog(
        _getPlatformName(platform),
        'operationId=${platformOptions.operationId} '
        'cachePolicy=${platformOptions.cachePolicy.name} '
        'fromCache=$stableFromCache dedupeHit=$stableDedupeHit '
        'queueWaitMs=${throttleState.lastQueueWaitMs} '
        '${functionalProfileName.isEmpty ? '' : 'functionalProfile=$functionalProfileName profileHeaders=$functionalHeaderCount '}'
        '${stableStaleReason == null ? '' : 'staleReason=$stableStaleReason failureCategory=$stableStaleReason '}'
        '${throttleState.isDegraded ? 'throttle=serial degradeReason=${throttleState.lastDegradeReason ?? ''} ' : ''}'
        'status=${response.statusCode} uri=${response.requestOptions.uri}',
      );
    }

    return response;
  }

  Map<String, String>? _mergeFunctionalHeaders({
    required Map<String, String>? headers,
    required SignRequestProfile? signProfile,
    required PlatformRequestOptions? platformOptions,
    required PlatformFunctionalRequestContext context,
    required void Function(String profileName, int headerCount) onApplied,
  }) {
    if (!_shouldApplyFunctionalProfile(
      method: context.method,
      signProfile: signProfile,
      options: platformOptions,
    )) {
      return headers;
    }
    final profile = PlatformFunctionalRequestProfiles.forPlatform(platform);
    final merged = profile.mergeHeaders(headers, context: context);
    onApplied(profile.profileName, merged.length);
    return merged;
  }

  bool _shouldApplyFunctionalProfile({
    required String method,
    required SignRequestProfile? signProfile,
    required PlatformRequestOptions? options,
  }) {
    if (signProfile != null || options == null) return false;
    if (!options.functionalProfileEnabled) return false;
    if (!_isFunctionalProfilePlatform(platform)) return false;
    if (options.requestKind == PlatformRequestKind.read) return true;
    return method.toUpperCase() == 'GET' &&
        options.cachePolicy != PlatformRequestCachePolicy.networkOnly &&
        options.requestKind == null;
  }

  bool _isFunctionalProfilePlatform(PlatformType platform) {
    return platform == PlatformType.chaoxing ||
        platform == PlatformType.rainClassroom ||
        platform == PlatformType.tronclass ||
        platform == PlatformType.ketangpai;
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

  static String? _headerValue(Map<String, String>? headers, String key) {
    if (headers == null) return null;
    final lowerKey = key.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }
    return null;
  }

  void dispose() {
    // Dio 实例由 PlatformDioManager 管理，不需要手动关闭
  }
}
