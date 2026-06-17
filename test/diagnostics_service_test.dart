import 'package:flutter_test/flutter_test.dart';

import 'package:course_helper/services/diagnostics_service.dart';

void main() {
  test('builds repair suggestions from logs and states', () {
    const service = DiagnosticsService();
    final issues = service.buildIssues(
      logs: const <Map<String, String>>[
        <String, String>{
          'level': 'error',
          'retryable': 'true',
          'message': 'HTTP 401 cookie expired',
        },
        <String, String>{
          'level': 'error',
          'retryable': 'true',
          'message': 'OpenList connection timeout',
        },
        <String, String>{
          'level': 'error',
          'retryable': 'true',
          'message': 'request failed',
        },
      ],
      notificationAllowed: false,
      hasNetwork: false,
      hasCurrentAccount: false,
      localTransferRunning: false,
    );

    expect(issues.map((issue) => issue.id), contains('network'));
    expect(issues.map((issue) => issue.id), contains('notification'));
    expect(issues.map((issue) => issue.id), contains('credential'));
    expect(issues.map((issue) => issue.id), contains('openlist'));
    expect(issues.map((issue) => issue.id).toSet().length, issues.length);
  });
}
