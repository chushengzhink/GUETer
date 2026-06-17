import 'dart:io';

import 'package:course_helper/platform.dart';
import 'package:course_helper/services/platform_network_warmup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'diagnoseEndpoint records DNS and TCP latency without rewriting URL',
    () async {
      final service = PlatformNetworkWarmupService(
        lookup: (_) async => <InternetAddress>[InternetAddress('127.0.0.1')],
        socketConnect: (_, _, {timeout}) async => _FakeSocket(),
      );

      final result = await service.diagnoseEndpoint(
        platform: PlatformType.tronclass,
        url: 'https://courses.guet.edu.cn/api/todos',
      );

      expect(result.host, 'courses.guet.edu.cn');
      expect(result.addresses, <String>['127.0.0.1']);
      expect(result.ok, isTrue);

      final saved = await service.loadLastDiagnostics();
      expect(saved.single.host, 'courses.guet.edu.cn');
    },
  );

  test('invalid URL is saved as diagnostic error', () async {
    final service = PlatformNetworkWarmupService();

    final result = await service.diagnoseEndpoint(
      platform: PlatformType.chaoxing,
      url: 'not a url',
    );

    expect(result.ok, isFalse);
    expect(result.error, 'invalid url');
  });
}

class _FakeSocket implements Socket {
  @override
  void destroy() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
