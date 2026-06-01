import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:course_helper/modules/local_transfer/controller/local_transfer_controller.dart';
import 'package:course_helper/modules/local_transfer/model/transfer_device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = LocalTransferController.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await controller.loadLocalDeviceName();
    controller.clearDevices();
  });

  test('loads saved local device name from shared preferences', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalTransferController.localDeviceNamePreferenceKey: 'Dorm Phone',
    });

    await controller.loadLocalDeviceName();

    expect(controller.localDeviceName, 'Dorm Phone');
    expect(controller.hasConfiguredLocalDeviceName, isTrue);
  });

  test('saves trimmed local device name', () async {
    await controller.saveLocalDeviceName('  Lab Tablet  ');
    await controller.loadLocalDeviceName();

    expect(controller.localDeviceName, 'Lab Tablet');
  });

  test('rejects blank local device name', () async {
    expect(() => controller.saveLocalDeviceName('   '), throwsArgumentError);
  });

  test('device display name prefers alias then model then ip', () {
    final withAlias = TransferDevice(
      ip: '192.168.1.2',
      port: 53317,
      alias: 'Alice Phone',
      version: '2.0',
      deviceModel: 'Pixel 8',
      deviceType: 'mobile',
      fingerprint: 'a',
      protocol: 'https',
      download: false,
      discoveryMethod: 'udp',
      lastSeen: DateTime(2026),
    );
    final withModelOnly = TransferDevice(
      ip: '192.168.1.3',
      port: 53317,
      alias: ' ',
      version: '2.0',
      deviceModel: 'Galaxy Tab',
      deviceType: 'mobile',
      fingerprint: 'b',
      protocol: 'https',
      download: false,
      discoveryMethod: 'udp',
      lastSeen: DateTime(2026),
    );
    final withIpOnly = TransferDevice(
      ip: '192.168.1.4',
      port: 53317,
      alias: '',
      version: '2.0',
      deviceModel: '',
      deviceType: 'mobile',
      fingerprint: 'c',
      protocol: 'https',
      download: false,
      discoveryMethod: 'udp',
      lastSeen: DateTime(2026),
    );

    expect(withAlias.displayName, 'Alice Phone');
    expect(withModelOnly.displayName, 'Galaxy Tab');
    expect(withIpOnly.displayName, '192.168.1.4');
  });

  test('buildSuggestedLocalDeviceName prefers brand and model', () {
    expect(
      buildSuggestedLocalDeviceName(
        fallbackAlias: 'GUETer',
        brand: 'Xiaomi',
        model: '15 Pro',
      ),
      'Xiaomi 15 Pro',
    );
    expect(
      buildSuggestedLocalDeviceName(
        fallbackAlias: 'GUETer',
        brand: 'Xiaomi',
        model: 'Xiaomi 15 Pro',
      ),
      'Xiaomi 15 Pro',
    );
    expect(
      buildSuggestedLocalDeviceName(
        fallbackAlias: 'GUETer',
        brand: 'Android',
        model: 'Android',
      ),
      'GUETer',
    );
  });

  test('inferLocalUnicastCidr prefers GUET campus /22 subnets', () {
    expect(inferLocalUnicastCidr('10.33.1.25'), '10.33.0.0/22');
    expect(inferLocalUnicastCidr('10.38.2.88'), '10.38.0.0/22');
    expect(inferLocalUnicastCidr('192.168.31.18'), '192.168.31.0/24');
  });

  test('expandCidrHosts skips network, broadcast, and excluded IPs', () {
    expect(
      expandCidrHosts('10.33.0.0/30', excludedIps: <String>{'10.33.0.1'}),
      <String>['10.33.0.2'],
    );
  });

  test('buildUnicastCandidateIps deduplicates and excludes local IPs', () {
    final candidates = buildUnicastCandidateIps(
      localIps: <String>['10.33.0.10'],
      staticCidrs: const <String>['10.33.0.0/30', '10.33.0.0/30'],
    );

    expect(candidates.toSet().length, candidates.length);
    expect(candidates.contains('10.33.0.1'), isTrue);
    expect(candidates.contains('10.33.0.2'), isTrue);
    expect(candidates.contains('10.33.0.10'), isFalse);
  });

  test('clearDevices keeps device list empty', () {
    controller.clearDevices(reason: 'test');

    expect(controller.devices, isEmpty);
  });
}
