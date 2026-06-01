import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NasaApodData {
  const NasaApodData({
    required this.title,
    required this.url,
    required this.explanation,
    required this.date,
    required this.mediaType,
  });

  factory NasaApodData.fromJson(Map<String, dynamic> json) {
    return NasaApodData(
      title: (json['title'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      explanation: (json['explanation'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      mediaType: (json['media_type'] ?? 'image').toString(),
    );
  }

  final String title;
  final String url;
  final String explanation;
  final String date;
  final String mediaType;

  bool get isImage => mediaType == 'image' && url.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'explanation': explanation,
      'date': date,
      'media_type': mediaType,
    };
  }
}

class NasaApiService {
  static const String _apodUrl =
      'https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY';
  static const String _cachedApodKey = 'nasa_apod_cached_json';
  static const String _lastAutoRefreshDateKey = 'nasa_apod_last_auto_refresh';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<NasaApodData?> loadCachedApod() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedApodKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return NasaApodData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<NasaApodData?> fetchApod() async {
    try {
      final response = await _dio.get(_apodUrl);
      if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
        return null;
      }

      final data = NasaApodData.fromJson(response.data as Map<String, dynamic>);
      if (data.title.isEmpty || data.date.isEmpty) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedApodKey, jsonEncode(data.toJson()));
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<bool> shouldAutoRefreshToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_lastAutoRefreshDateKey);
    return lastDate != _todayKey();
  }

  Future<void> markAutoRefreshedToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoRefreshDateKey, _todayKey());
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  void dispose() {
    _dio.close();
  }
}
