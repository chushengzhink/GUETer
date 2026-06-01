import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:course_helper/modules/zerotier/controller/zerotier_controller.dart';
import 'package:course_helper/modules/zerotier/models/zerotier_snapshot.dart';
import 'package:course_helper/modules/zerotier/services/zerotier_storage_service.dart';
import 'package:course_helper/modules/zerotier/ui/zerotier_page.dart';

import 'zerotier_controller_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders unsupported page when Android support is disabled', (
    tester,
  ) async {
    final controller = ZeroTierController(
      supportedOverride: false,
      clientFactory: FakeZeroTierClient.new,
    );

    await tester.pumpWidget(
      MaterialApp(home: ZeroTierPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前平台暂不支持 ZeroTier 虚拟局域网'), findsOneWidget);
  });

  testWidgets('renders joined state and virtual ip after connect', (
    tester,
  ) async {
    const networkId = '8056c2e21c000001';
    SharedPreferences.setMockInitialValues(<String, Object>{
      ZeroTierStorageService.networkIdPreferenceKey: networkId,
    });
    final fakeClient = FakeZeroTierClient(
      snapshot: ZeroTierSnapshot(
        connectionState: ZeroTierConnectionState.joined,
        networkId: networkId,
        virtualIp: '10.147.17.23',
        errorMessage: null,
        isBusy: false,
        updatedAt: DateTime(2026, 5, 22, 12),
        networkName: 'gueter',
        networkStatus: 'ok',
      ),
    );
    final controller = ZeroTierController(
      supportedOverride: true,
      clientFactory: () => fakeClient,
    );
    await controller.connect(networkId);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        home: ZeroTierPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.text('10.147.17.23'), findsOneWidget);
    expect(find.text(networkId), findsWidgets);
  });
}
