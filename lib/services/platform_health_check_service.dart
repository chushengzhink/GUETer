import 'package:dio/dio.dart';

import '../platform.dart';

enum PlatformHealthStatus { normal, reachableAnonymousDenied, abnormal }

class PlatformHealthCheckTarget {
  const PlatformHealthCheckTarget({
    required this.name,
    required this.url,
    required this.platform,
  });

  final String name;
  final String url;
  final PlatformType platform;
}

class PlatformHealthCheckResult {
  const PlatformHealthCheckResult({
    required this.name,
    required this.url,
    required this.platform,
    required this.status,
    required this.elapsed,
    this.statusCode,
    this.error,
  });

  final String name;
  final String url;
  final PlatformType platform;
  final PlatformHealthStatus status;
  final Duration elapsed;
  final int? statusCode;
  final String? error;

  bool get isOk => status != PlatformHealthStatus.abnormal;

  String get statusLabel {
    switch (status) {
      case PlatformHealthStatus.normal:
        return '正常';
      case PlatformHealthStatus.reachableAnonymousDenied:
        return '连通，匿名访问被拒绝';
      case PlatformHealthStatus.abnormal:
        return '异常';
    }
  }

  String get detail {
    final codeText = statusCode == null ? '连接失败' : 'HTTP $statusCode';
    return '$codeText · ${elapsed.inMilliseconds} ms';
  }
}

class PlatformHealthCheckReport {
  const PlatformHealthCheckReport({
    required this.results,
    required this.totalElapsed,
    required this.checkedAt,
    required this.tronclassBaseUrl,
    required this.ketangpaiBaseUrl,
  });

  final List<PlatformHealthCheckResult> results;
  final Duration totalElapsed;
  final DateTime checkedAt;
  final String tronclassBaseUrl;
  final String ketangpaiBaseUrl;

  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln('GUETer 四平台健康检查报告')
      ..writeln('时间: ${checkedAt.toLocal()}')
      ..writeln('并发总耗时: ${totalElapsed.inMilliseconds} ms')
      ..writeln('畅课地址: $tronclassBaseUrl')
      ..writeln('课堂派地址: $ketangpaiBaseUrl')
      ..writeln('')
      ..writeln('检查结果:');

    for (final item in results) {
      buffer.writeln('- ${item.name}: ${item.statusLabel} (${item.detail})');
      buffer.writeln('  ${item.url}');
      if (item.error != null && item.error!.isNotEmpty) {
        buffer.writeln('  ${item.error}');
      }
    }

    return buffer.toString().trim();
  }
}

typedef PlatformHealthProbe =
    Future<Response<dynamic>> Function(
      Dio dio,
      PlatformHealthCheckTarget target,
    );

class PlatformHealthCheckService {
  PlatformHealthCheckService({
    Dio? dio,
    PlatformHealthProbe? probe,
    Duration timeout = const Duration(seconds: 2),
  }) : _probe = probe,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: timeout,
               receiveTimeout: timeout,
               followRedirects: false,
               validateStatus: (_) => true,
             ),
           );

  final Dio _dio;
  final PlatformHealthProbe? _probe;

  List<PlatformHealthCheckTarget> defaultTargets({
    required String tronclassBaseUrl,
    required String ketangpaiBaseUrl,
  }) {
    return <PlatformHealthCheckTarget>[
      const PlatformHealthCheckTarget(
        name: '学习通',
        url: 'https://passport2.chaoxing.com',
        platform: PlatformType.chaoxing,
      ),
      const PlatformHealthCheckTarget(
        name: '雨课堂',
        url: 'https://www.yuketang.cn',
        platform: PlatformType.rainClassroom,
      ),
      PlatformHealthCheckTarget(
        name: '畅课',
        url: tronclassBaseUrl,
        platform: PlatformType.tronclass,
      ),
      PlatformHealthCheckTarget(
        name: '课堂派',
        url: ketangpaiBaseUrl,
        platform: PlatformType.ketangpai,
      ),
    ];
  }

  Future<PlatformHealthCheckReport> checkDefaultTargets({
    required String tronclassBaseUrl,
    required String ketangpaiBaseUrl,
  }) {
    return checkTargets(
      defaultTargets(
        tronclassBaseUrl: tronclassBaseUrl,
        ketangpaiBaseUrl: ketangpaiBaseUrl,
      ),
      tronclassBaseUrl: tronclassBaseUrl,
      ketangpaiBaseUrl: ketangpaiBaseUrl,
    );
  }

  Future<PlatformHealthCheckReport> checkTargets(
    List<PlatformHealthCheckTarget> targets, {
    required String tronclassBaseUrl,
    required String ketangpaiBaseUrl,
  }) async {
    final stopwatch = Stopwatch()..start();
    final results = await Future.wait(targets.map(_checkTarget));
    stopwatch.stop();
    return PlatformHealthCheckReport(
      results: results,
      totalElapsed: stopwatch.elapsed,
      checkedAt: DateTime.now(),
      tronclassBaseUrl: tronclassBaseUrl,
      ketangpaiBaseUrl: ketangpaiBaseUrl,
    );
  }

  Future<PlatformHealthCheckResult> _checkTarget(
    PlatformHealthCheckTarget target,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = _probe == null
          ? await _dio.get<dynamic>(target.url)
          : await _probe(_dio, target);
      stopwatch.stop();
      final code = response.statusCode ?? 0;
      return PlatformHealthCheckResult(
        name: target.name,
        url: target.url,
        platform: target.platform,
        statusCode: response.statusCode,
        elapsed: stopwatch.elapsed,
        status: classifyStatus(target.platform, code),
      );
    } catch (error) {
      stopwatch.stop();
      return PlatformHealthCheckResult(
        name: target.name,
        url: target.url,
        platform: target.platform,
        status: PlatformHealthStatus.abnormal,
        elapsed: stopwatch.elapsed,
        error: error.toString(),
      );
    }
  }

  static PlatformHealthStatus classifyStatus(
    PlatformType platform,
    int statusCode,
  ) {
    if (statusCode <= 0) {
      return PlatformHealthStatus.abnormal;
    }
    if (platform == PlatformType.ketangpai && statusCode == 403) {
      return PlatformHealthStatus.reachableAnonymousDenied;
    }
    if (statusCode < 500) {
      return PlatformHealthStatus.normal;
    }
    return PlatformHealthStatus.abnormal;
  }
}
