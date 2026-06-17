import 'package:course_helper/models/user.dart';
import 'package:course_helper/services/mobile_data_reconnect_service.dart';
import 'package:course_helper/services/sign_network_gate.dart';
import 'package:course_helper/services/sign_run_console.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

User _user() {
  return User(name: 'alice', avatar: '', phone: '', uid: 'u1', school: '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MobileDataReconnectService.debugRestartOverride = null;
    MobileDataReconnectService.debugPublicIpOverride = null;
    MobileDataReconnectService.debugCapabilityOverride = null;
  });

  testWidgets('runs action when mobile data restart succeeds', (tester) async {
    MobileDataReconnectService.debugRestartOverride = () async {
      return const MobileDataReconnectResult(
        success: true,
        mode: MobileDataReconnectMode.privilegedAuto,
        message: 'ok',
        ipBefore: '1.1.1.1',
        ipAfter: '2.2.2.2',
        ipChanged: true,
      );
    };
    final console = SignRunConsoleController();
    addTearDown(console.dispose);
    var actionCalled = false;
    SignNetworkGateResult<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await SignNetworkGate().run<String>(
                context: context,
                platformLabel: '学习通',
                user: _user(),
                console: console,
                action: () async {
                  actionCalled = true;
                  return 'done';
                },
              );
            },
            child: const Text('run'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(actionCalled, isTrue);
    expect(result?.value, 'done');
    expect(
      console.events.map((event) => event.stage),
      containsAll(<SignRunStage>[
        SignRunStage.networkStart,
        SignRunStage.networkSuccess,
        SignRunStage.signStart,
      ]),
    );
  });

  testWidgets('skips account when user rejects manual reconnect', (
    tester,
  ) async {
    MobileDataReconnectService.debugRestartOverride = () async {
      return const MobileDataReconnectResult(
        success: false,
        mode: MobileDataReconnectMode.manualAssist,
        message: 'manual',
        ipBefore: '1.1.1.1',
        requiresManualAction: true,
      );
    };
    final console = SignRunConsoleController();
    addTearDown(console.dispose);
    var actionCalled = false;
    SignNetworkGateResult<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await SignNetworkGate().run<String>(
                context: context,
                platformLabel: '学习通',
                user: _user(),
                console: console,
                action: () async {
                  actionCalled = true;
                  return 'done';
                },
              );
            },
            child: const Text('run'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跳过该账号'));
    await tester.pumpAndSettle();

    expect(actionCalled, isFalse);
    expect(result?.skipped, isTrue);
    expect(console.events.last.stage, SignRunStage.userSkipped);
  });
}
