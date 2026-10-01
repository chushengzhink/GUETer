import 'dart:convert';

import 'package:dio/dio.dart';

enum PlatformReadFailure { auth, network, server, format, business }

/// Safe user-facing read failures; raw responses belong in the request console.
class PlatformReadException implements Exception {
  const PlatformReadException(this.kind);
  final PlatformReadFailure kind;

  String message({bool english = false}) => switch (kind) {
    PlatformReadFailure.auth =>
      english ? 'Your session expired. Please sign in again.' : '登录状态已失效，请重新登录',
    PlatformReadFailure.network =>
      english
          ? 'Unable to connect. Check your network and retry.'
          : '网络连接失败，请检查网络后重试',
    PlatformReadFailure.server =>
      english
          ? 'The service is unavailable. Please retry later.'
          : '平台服务暂不可用，请稍后重试',
    PlatformReadFailure.format =>
      english
          ? 'The response format was unexpected. Please retry.'
          : '平台返回的数据格式异常，请重试',
    PlatformReadFailure.business =>
      english
          ? 'The platform could not complete this request. Please retry.'
          : '平台未能完成请求，请重试',
  };

  static PlatformReadException from(Object error) {
    if (error is PlatformReadException) return error;
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        return const PlatformReadException(PlatformReadFailure.auth);
      }
      if (status != null && status >= 400) {
        return const PlatformReadException(PlatformReadFailure.server);
      }
      if (error.error is FormatException) {
        return const PlatformReadException(PlatformReadFailure.format);
      }
      return const PlatformReadException(PlatformReadFailure.network);
    }
    return const PlatformReadException(PlatformReadFailure.format);
  }

  @override
  String toString() => message();
}

Map<String, dynamic> readPlatformObject(Response response) {
  final status = response.statusCode ?? 0;
  if (status == 401 ||
      status == 403 ||
      (status >= 300 &&
          status < 400 &&
          RegExp(
            r'login|auth|cas',
            caseSensitive: false,
          ).hasMatch(response.headers.value('location') ?? ''))) {
    throw const PlatformReadException(PlatformReadFailure.auth);
  }
  if (status < 200 || status >= 300) {
    throw const PlatformReadException(PlatformReadFailure.server);
  }
  dynamic data = response.data;
  if (data is String) {
    try {
      data = jsonDecode(data.trim());
    } on FormatException {
      throw const PlatformReadException(PlatformReadFailure.format);
    }
  }
  if (data is! Map) {
    throw const PlatformReadException(PlatformReadFailure.format);
  }
  return data.map((key, value) => MapEntry(key.toString(), value));
}
