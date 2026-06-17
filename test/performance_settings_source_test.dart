import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String settingsSource;
  late String diagnosticsSource;

  setUpAll(() {
    settingsSource = File('lib/pages/settings.dart').readAsStringSync();
    diagnosticsSource = File('lib/services/diagnostics_service.dart').existsSync()
        ? File('lib/services/diagnostics_service.dart').readAsStringSync()
        : '';
  });

  test('settings page exposes low power performance switch and report entry', () {
    expect(settingsSource, contains('lowPowerPerformanceSwitch'));
    expect(settingsSource, contains('低算力流畅模式'));
    expect(settingsSource, contains('performanceDiagnosticsSwitch'));
    expect(settingsSource, contains('最近采样帧数'));
    expect(settingsSource, contains('performanceReportTile'));
    expect(settingsSource, contains('流畅度报告'));
  });

  test('diagnostics service remains available for repair suggestions', () {
    expect(diagnosticsSource, contains('class DiagnosticsService'));
  });
}
