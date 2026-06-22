import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/sign_mode_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

User _user(String uid, String platform) {
  return User(
    uid: uid,
    name: uid,
    avatar: '',
    phone: '',
    school: '',
    platform: platform,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('default mode is manual current for every supported platform', () async {
    expect(
      await SignModeSettings.getMode(PlatformType.chaoxing),
      SignAccountMode.manualCurrent,
    );
    expect(
      await SignModeSettings.getMode(PlatformType.rainClassroom),
      SignAccountMode.manualCurrent,
    );
    expect(
      await SignModeSettings.getMode(PlatformType.tronclass),
      SignAccountMode.manualCurrent,
    );
    expect(
      await SignModeSettings.getMode(PlatformType.ketangpai),
      SignAccountMode.manualCurrent,
    );
  });

  test('modes are stored independently per platform', () async {
    await SignModeSettings.setMode(
      PlatformType.tronclass,
      SignAccountMode.savedPlatformSelection,
    );
    await SignModeSettings.setMode(
      PlatformType.ketangpai,
      SignAccountMode.perRunSelection,
    );

    expect(
      await SignModeSettings.getMode(PlatformType.tronclass),
      SignAccountMode.savedPlatformSelection,
    );
    expect(
      await SignModeSettings.getMode(PlatformType.ketangpai),
      SignAccountMode.perRunSelection,
    );
    expect(
      await SignModeSettings.getMode(PlatformType.chaoxing),
      SignAccountMode.manualCurrent,
    );
  });

  test('manual current resolves only the current account', () {
    final users = [_user('a', 'tronclass'), _user('b', 'tronclass')];

    final resolution = SignModeSettings.resolveUsersFromState(
      platform: PlatformType.tronclass,
      mode: SignAccountMode.manualCurrent,
      platformAccounts: users,
      currentSessionId: 'b',
    );

    expect(resolution.users.map((user) => user.uid), ['b']);
    expect(resolution.networkPolicy, SignSubmitNetworkPolicy.direct);
  });

  test(
    'saved platform selection starts empty and requires explicit accounts',
    () {
      final users = [_user('a', 'ketangpai'), _user('b', 'ketangpai')];

      final empty = SignModeSettings.resolveUsersFromState(
        platform: PlatformType.ketangpai,
        mode: SignAccountMode.savedPlatformSelection,
        platformAccounts: users,
        currentSessionId: 'a',
        savedSelectionIds: const <String>{},
      );

      expect(empty.users, isEmpty);
      expect(empty.message, contains('暂无课堂派签到账号'));
      expect(empty.networkPolicy, SignSubmitNetworkPolicy.direct);

      final selected = SignModeSettings.resolveUsersFromState(
        platform: PlatformType.ketangpai,
        mode: SignAccountMode.savedPlatformSelection,
        platformAccounts: users,
        currentSessionId: 'a',
        savedSelectionIds: {'b', 'other-platform'},
      );

      expect(selected.users.map((user) => user.uid), ['b']);
      expect(selected.networkPolicy, SignSubmitNetworkPolicy.direct);
    },
  );

  test(
    'per run mode uses explicit selection and filters cross platform users',
    () {
      final users = [_user('a', 'rainclassroom'), _user('b', 'rainclassroom')];
      final selected = [_user('b', 'rainclassroom'), _user('x', 'tronclass')];

      final resolution = SignModeSettings.resolveUsersFromState(
        platform: PlatformType.rainClassroom,
        mode: SignAccountMode.perRunSelection,
        platformAccounts: users,
        currentSessionId: 'a',
        perRunSelection: selected,
      );

      expect(resolution.users.map((user) => user.uid), ['b']);
      expect(resolution.networkPolicy, SignSubmitNetworkPolicy.reconnect);
    },
  );

  test('mode labels describe direct and reconnect batch semantics', () {
    expect(
      SignModeSettings.labelOf(SignAccountMode.savedPlatformSelection),
      '平台所选（直接批量）',
    );
    expect(
      SignModeSettings.labelOf(SignAccountMode.perRunSelection),
      '每次选择（换网批量）',
    );
    expect(
      SignModeSettings.descriptionOf(SignAccountMode.savedPlatformSelection),
      contains('直接提交'),
    );
    expect(
      SignModeSettings.descriptionOf(SignAccountMode.perRunSelection),
      contains('换 IP'),
    );
  });
}
