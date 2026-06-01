import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:course_helper/modules/zerotier/services/zerotier_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads saved network id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ZeroTierStorageService.networkIdPreferenceKey: '8056c2e21c000001',
    });
    final service = ZeroTierStorageService();

    final networkId = await service.loadNetworkId();

    expect(networkId, '8056c2e21c000001');
  });

  test('blank save clears stored network id', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ZeroTierStorageService.networkIdPreferenceKey: '8056c2e21c000001',
    });
    final service = ZeroTierStorageService();

    await service.saveNetworkId('   ');

    expect(await service.loadNetworkId(), isNull);
  });

  test('save trims and lowercases network id', () async {
    final service = ZeroTierStorageService();

    await service.saveNetworkId('  8056C2E21C000001  ');

    expect(await service.loadNetworkId(), '8056c2e21c000001');
  });
}
