import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:course_helper/modules/zerotier/controller/zerotier_controller.dart';
import 'package:course_helper/modules/zerotier/models/zerotier_snapshot.dart';
import 'package:course_helper/modules/zerotier/services/zerotier_client.dart';
import 'package:course_helper/modules/zerotier/services/zerotier_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('initialize requires prompt when no stored network id exists', () async {
    final controller = ZeroTierController(
      supportedOverride: true,
      clientFactory: FakeZeroTierClient.new,
    );

    await controller.initialize();

    expect(controller.requiresInitialNetworkIdPrompt, isTrue);
    expect(controller.networkId, isEmpty);
  });

  test('connect rejects invalid network id', () async {
    final controller = ZeroTierController(
      supportedOverride: true,
      clientFactory: FakeZeroTierClient.new,
    );

    final result = await controller.connect('invalid');

    expect(result, isFalse);
    expect(controller.snapshot.connectionState, ZeroTierConnectionState.failed);
    expect(controller.snapshot.errorMessage, '网络 ID 必须是 16 位十六进制字符。');
  });

  test('connect maps successful join into joined snapshot', () async {
    const networkId = '8056c2e21c000001';
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

    final result = await controller.connect(networkId);

    expect(result, isTrue);
    expect(fakeClient.startCalls, 1);
    expect(fakeClient.joinCalls, 1);
    expect(fakeClient.lastJoinedNetworkId, networkId);
    expect(controller.snapshot.connectionState, ZeroTierConnectionState.joined);
    expect(controller.snapshot.virtualIp, '10.147.17.23');
    expect(controller.snapshot.networkStatus, 'ok');
  });

  test('connect maps timeout into failed snapshot', () async {
    final fakeClient = FakeZeroTierClient(
      joinError: TimeoutException('等待 ZeroTier 分配虚拟 IP 超时。'),
    );
    final controller = ZeroTierController(
      supportedOverride: true,
      clientFactory: () => fakeClient,
    );

    final result = await controller.connect('8056c2e21c000001');

    expect(result, isFalse);
    expect(controller.snapshot.connectionState, ZeroTierConnectionState.failed);
    expect(
      controller.snapshot.errorMessage,
      contains('等待 ZeroTier 分配虚拟 IP 超时'),
    );
  });

  test('refreshStatus uses saved network id and updates snapshot', () async {
    const networkId = '8056c2e21c000001';
    SharedPreferences.setMockInitialValues(<String, Object>{
      ZeroTierStorageService.networkIdPreferenceKey: networkId,
    });
    final fakeClient = FakeZeroTierClient(
      snapshot: ZeroTierSnapshot(
        connectionState: ZeroTierConnectionState.joined,
        networkId: networkId,
        virtualIp: '10.147.17.99',
        errorMessage: null,
        isBusy: false,
        updatedAt: DateTime(2026, 5, 22, 13),
        networkName: null,
        networkStatus: 'ok',
      ),
    );
    final controller = ZeroTierController(
      supportedOverride: true,
      clientFactory: () => fakeClient,
    );

    await controller.initialize();
    await controller.refreshStatus();

    expect(fakeClient.refreshCalls, 1);
    expect(controller.snapshot.connectionState, ZeroTierConnectionState.joined);
    expect(controller.snapshot.virtualIp, '10.147.17.99');
  });
}

class FakeZeroTierClient implements ZeroTierClient {
  FakeZeroTierClient({
    ZeroTierSnapshot? snapshot,
    this.joinError,
    this.refreshError,
  }) : _snapshot =
           snapshot ?? ZeroTierSnapshot.initial(networkId: '8056c2e21c000001');

  final Object? joinError;
  final Object? refreshError;

  final ZeroTierSnapshot _snapshot;
  int startCalls = 0;
  int joinCalls = 0;
  int refreshCalls = 0;
  String? lastJoinedNetworkId;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> joinNetwork(String networkId) async {
    joinCalls += 1;
    lastJoinedNetworkId = networkId;
    if (joinError != null) {
      throw joinError!;
    }
  }

  @override
  Future<ZeroTierSnapshot> refreshSnapshot() async {
    refreshCalls += 1;
    if (refreshError != null) {
      throw refreshError!;
    }
    return _snapshot;
  }

  @override
  Future<void> startNode() async {
    startCalls += 1;
  }
}
