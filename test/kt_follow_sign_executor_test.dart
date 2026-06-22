import 'package:course_helper/api/kt_follow_sign.dart';
import 'package:course_helper/api/kt_sign.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/services/sign_run_console.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

User _user({String token = 'token'}) {
  return User(
    name: 'kt-user',
    avatar: '',
    phone: '',
    uid: 'kt-user',
    school: '',
    platform: 'ketangpai',
    token: token,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('false token health hint does not skip direct sign action', () async {
    var actionCalls = 0;
    final console = SignRunConsoleController();
    addTearDown(console.dispose);

    final result = await KtFollowSignExecutor.debugExecute(
      users: [_user()],
      courseName: 'course',
      signTypeLabel: '扫码签到',
      tokenHealthHint: const {'kt-user': false},
      console: console,
      reconnectNetwork: false,
      signAction: (_) async {
        actionCalls += 1;
        return const KetangpaiSignResult(success: true, message: 'ok');
      },
    );

    expect(actionCalls, 1);
    expect(result.successCount, 1);
    expect(
      console.events.map((event) => event.message),
      contains('token 探活待确认，继续尝试签到'),
    );
    expect(console.events.map((event) => event.message), contains('平台所选：直接提交'));
  });

  test('auth expired sign response is reported as login expired', () async {
    final result = await KtFollowSignExecutor.debugExecute(
      users: [_user()],
      courseName: 'course',
      signTypeLabel: '扫码签到',
      reconnectNetwork: false,
      signAction: (_) async {
        return KetangpaiSignResult.failure(
          'raw message',
          raw: const {'code': 20003, 'message': 'token expired'},
        );
      },
    );

    expect(result.successCount, 0);
    expect(result.failedAccounts.single, contains('登录态过期，请重新登录'));
  });
}
