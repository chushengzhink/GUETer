import 'package:course_helper/platform.dart';
import 'package:course_helper/services/platform_health_check_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Response<dynamic> _healthResponse({
  required PlatformHealthCheckTarget target,
  required int statusCode,
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: target.url),
    statusCode: statusCode,
  );
}

void main() {
  test('checks targets concurrently', () async {
    final service = PlatformHealthCheckService(
      probe: (_, target) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return _healthResponse(target: target, statusCode: 200);
      },
    );

    final report = await service.checkTargets(
      const <PlatformHealthCheckTarget>[
        PlatformHealthCheckTarget(
          name: 'A',
          url: 'https://a.example',
          platform: PlatformType.chaoxing,
        ),
        PlatformHealthCheckTarget(
          name: 'B',
          url: 'https://b.example',
          platform: PlatformType.rainClassroom,
        ),
        PlatformHealthCheckTarget(
          name: 'C',
          url: 'https://c.example',
          platform: PlatformType.tronclass,
        ),
      ],
      tronclassBaseUrl: 'https://courses.guet.edu.cn',
      ketangpaiBaseUrl: 'https://openapiv5.ketangpai.com',
    );

    expect(report.results, hasLength(3));
    expect(
      report.results,
      everyElement((PlatformHealthCheckResult r) => r.isOk),
    );
    expect(report.totalElapsed, lessThan(const Duration(milliseconds: 180)));
  });

  test('classifies ketangpai 403 as reachable anonymous denied', () {
    expect(
      PlatformHealthCheckService.classifyStatus(PlatformType.ketangpai, 403),
      PlatformHealthStatus.reachableAnonymousDenied,
    );
    expect(
      PlatformHealthCheckService.classifyStatus(PlatformType.chaoxing, 403),
      PlatformHealthStatus.normal,
    );
    expect(
      PlatformHealthCheckService.classifyStatus(PlatformType.tronclass, 503),
      PlatformHealthStatus.abnormal,
    );
  });

  test('report includes total elapsed and platform labels', () async {
    final service = PlatformHealthCheckService(
      probe: (_, target) async {
        return _healthResponse(
          target: target,
          statusCode: target.platform == PlatformType.ketangpai ? 403 : 200,
        );
      },
    );

    final report = await service.checkDefaultTargets(
      tronclassBaseUrl: 'https://courses.guet.edu.cn',
      ketangpaiBaseUrl: 'https://openapiv5.ketangpai.com',
    );
    final text = report.toPlainText();

    expect(text, contains('GUETer 四平台健康检查报告'));
    expect(text, contains('并发总耗时'));
    expect(text, contains('学习通'));
    expect(text, contains('课堂派'));
    expect(text, contains('连通，匿名访问被拒绝'));
  });
}
