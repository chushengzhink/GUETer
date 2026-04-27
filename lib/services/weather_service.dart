import 'package:dio/dio.dart';

class WeatherData {
  final double temperature;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final DateTime timestamp;

  const WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.timestamp,
  });

  String get weatherDescription {
    return _getWeatherDescription(weatherCode);
  }

  String get weatherEmoji {
    return _getWeatherEmoji(weatherCode);
  }

  static String _getWeatherDescription(int code) {
    if (code == 0) return '晴天';
    if (code == 1) return '少云';
    if (code == 2) return '多云';
    if (code == 3) return '阴天';
    if (code == 45 || code == 48) return '雾';
    if (code >= 51 && code <= 67) return '雨';
    if (code >= 71 && code <= 77) return '雪';
    if (code >= 80 && code <= 99) return '阵雨';
    return '未知';
  }

  static String _getWeatherEmoji(int code) {
    if (code == 0) return '☀️';
    if (code == 1) return '🌤️';
    if (code == 2) return '⛅';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '❄️';
    if (code >= 80 && code <= 99) return '⛈️';
    return '🌡️';
  }
}

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const double _latitude = 25.3117;
  static const double _longitude = 110.4168;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<WeatherData?> fetchWeather() async {
    try {
      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'latitude': _latitude,
          'longitude': _longitude,
          'current_weather': true,
          'daily': 'temperature_2m_max,temperature_2m_min,weathercode',
          'timezone': 'Asia/Shanghai',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final currentWeather = data['current_weather'] as Map<String, dynamic>;
        final daily = data['daily'] as Map<String, dynamic>;

        return WeatherData(
          temperature: (currentWeather['temperature'] as num).toDouble(),
          weatherCode: currentWeather['weathercode'] as int,
          maxTemp: ((daily['temperature_2m_max'] as List)[0] as num).toDouble(),
          minTemp: ((daily['temperature_2m_min'] as List)[0] as num).toDouble(),
          timestamp: DateTime.now(),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _dio.close();
  }
}
