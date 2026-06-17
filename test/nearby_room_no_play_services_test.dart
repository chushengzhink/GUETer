import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nearby room copy advertises BLE hotspot fallback', () {
    final page = File(
      'lib/modules/airchat/ui/nearby_room_page.dart',
    ).readAsStringSync();
    final unsupported = File(
      'lib/modules/airchat/ui/unsupported_page.dart',
    ).readAsStringSync();
    final zhArb = File('lib/l10n/app_zh.arb').readAsStringSync();
    final enArb = File('lib/l10n/app_en.arb').readAsStringSync();

    expect(page, contains('无需 Google Play 服务'));
    expect(page, contains('BLE 发现 + 热点接力'));
    expect(page, contains('手动加入房主热点'));
    expect(unsupported, contains('无需强制安装 Google Play 服务'));
    expect(zhArb, contains('Google Nearby 或 BLE + 热点'));
    expect(enArb, contains('Google Nearby or BLE + Hotspot'));
  });

  test(
    'Android channel routes BLE hotspot discovery advertising and connect',
    () {
      final activity = File(
        'android/app/src/main/kotlin/com/gueter/cszm/MainActivity.kt',
      ).readAsStringSync();

      expect(activity, contains('if (transportMode == "ble_hotspot")'));
      expect(activity, contains('bleHotspotHandler.startDiscovery(result)'));
      expect(
        activity,
        contains('bleHotspotHandler.startAdvertising(endpointInfo, result)'),
      );
      expect(activity, contains('bleHotspotHandler.connectToDevice(userId)'));
      expect(
        activity,
        contains('nearbyHandler.sendControlMessage(userId, action, payload)'),
      );
      expect(
        activity,
        contains('nearbyHandler.sendFile(userId, filePath, fileName)'),
      );
    },
  );
}
