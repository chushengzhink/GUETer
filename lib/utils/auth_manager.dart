import 'package:dio/dio.dart';

class AuthManager {
  static final Dio dio = Dio(BaseOptions(
    baseUrl: 'https://example.com', // 替换为实际的 API 基础 URL
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  static String? _token;
  static String? _cookie;

  static void setAuth({required String token, required String cookie}) {
    _token = token;
    _cookie = cookie;
    dio.options.headers['Authorization'] = 'Bearer $token';
    dio.options.headers['Cookie'] = cookie;
  }

  static void clearAuth() {
    _token = null;
    _cookie = null;
    dio.options.headers.remove('Authorization');
    dio.options.headers.remove('Cookie');
  }

  static bool get isAuthenticated => _token != null && _cookie != null;
}