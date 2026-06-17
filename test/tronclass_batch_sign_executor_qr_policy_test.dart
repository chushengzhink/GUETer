import 'package:course_helper/api/tronclass_batch_sign_executor.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/services/mobile_data_reconnect_service.dart';
import 'package:course_helper/services/sign_run_console.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

User _user(String uid) {
  return User(
    name: 'user-$uid',
    avatar: '',
    phone: '',
    uid: uid,
    school: '',
    platform: 'tronclass',
  );
}

Response<dynamic> _response(Map<String, dynamic> data) {
  return Response<dynamic>(
    data: data,
    statusCode: 200,
    requestOptions: RequestOptions(path: '/sign'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    MobileDataReconnectService.debugRestartOverride = null;
  });

  testWidgets('strict policy runs network gate for every selected account', (
    tester,
  ) async {
    var networkCalls = 0;
    var actionCalls = 0;
    MobileDataReconnectService.debugRestartOverride = () async {
      networkCalls += 1;
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
    final users = [_user('1'), _user('2')];
    TronclassBatchSignResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await TronclassBatchSignExecutor(
                sessionHealthChecker: (_) async => true,
              ).sign(
                context: context,
                courseName: 'qr',
                console: console,
                users: users,
                action: (_, _) async {
                  actionCalls += 1;
                  return _response({'status': 'on_call'});
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

    expect(networkCalls, 2);
    expect(actionCalls, 2);
    expect(result?.successCount, 2);
  });

  testWidgets('qr fast policy skips network gate only for first account', (
    tester,
  ) async {
    var networkCalls = 0;
    var actionCalls = 0;
    MobileDataReconnectService.debugRestartOverride = () async {
      networkCalls += 1;
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
    final users = [_user('1'), _user('2'), _user('3')];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await TronclassBatchSignExecutor(
                sessionHealthChecker: (_) async => true,
              ).sign(
                context: context,
                courseName: 'qr',
                console: console,
                users: users,
                networkPolicy: TronclassBatchNetworkPolicy.qrFastFirst,
                action: (_, _) async {
                  actionCalls += 1;
                  return _response({'status': 'on_call'});
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

    expect(networkCalls, 2);
    expect(actionCalls, 3);
    expect(
      console.events.map((event) => event.message),
      contains('极速防过期：首账号跳过换网直接提交'),
    );
  });

  testWidgets('qr expired response skips remaining accounts without network', (
    tester,
  ) async {
    var networkCalls = 0;
    var actionCalls = 0;
    MobileDataReconnectService.debugRestartOverride = () async {
      networkCalls += 1;
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
    final users = [_user('1'), _user('2'), _user('3')];
    TronclassBatchSignResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await TronclassBatchSignExecutor(
                sessionHealthChecker: (_) async => true,
              ).sign(
                context: context,
                courseName: 'qr',
                console: console,
                users: users,
                networkPolicy: TronclassBatchNetworkPolicy.qrFastFirst,
                action: (_, _) async {
                  actionCalls += 1;
                  return _response({'message': 'QR_code_expired'});
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

    expect(networkCalls, 0);
    expect(actionCalls, 1);
    expect(result?.failedCount, 1);
    expect(result?.skippedCount, 2);
    expect(
      result?.items.skip(1).map((item) => item.message).toSet(),
      {'签到二维码已过期，请重新扫码'},
    );
  });
}
