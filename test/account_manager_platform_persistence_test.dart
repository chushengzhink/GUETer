import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/account_events.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:course_helper/session/credential_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _bootstrap({String platform = 'ketangpai'}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'current_platform': platform,
  });
  CookieManager.resetForTests();
  await PlatformManager().initialize();
  await AccountManager.initialize();
  await CookieManager.initialize();
}

User _tronclassUser({
  String uid = '121518',
  String name = 'QQ User',
  String avatar = 'avatar.png',
  String password = '',
  int? credentialExpiry,
}) {
  return User(
    uid: uid,
    name: name,
    avatar: avatar,
    phone: '138****0000',
    school: 'GUET',
    platform: 'tronclass',
    password: password,
    credentialExpiry: credentialExpiry,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('explicit Tronclass save does not depend on current platform', () async {
    await _bootstrap(platform: 'ketangpai');

    final user = _tronclassUser(password: 'secret');
    await AccountManager.addAccountForPlatformName(
      'tronclass',
      user,
      notify: false,
      migrateTempCookies: false,
    );
    await AccountManager.setCurrentSessionForPlatformName(
      'tronclass',
      user.uid,
      notify: false,
    );

    final tronclassAccounts =
        await AccountManager.refreshAccountsForPlatformName('tronclass');
    final ketangpaiAccounts =
        await AccountManager.refreshAccountsForPlatformName('ketangpai');

    expect(tronclassAccounts.map((account) => account.uid), contains(user.uid));
    expect(ketangpaiAccounts, isEmpty);
  });

  test(
    'credential expiry update preserves latest stored account fields',
    () async {
      await _bootstrap(platform: 'tronclass');

      final fresh = _tronclassUser(
        name: 'Fresh QQ User',
        avatar: 'fresh.png',
        password: '',
      );
      await AccountManager.addAccountForPlatformName(
        'tronclass',
        fresh,
        notify: false,
        migrateTempCookies: false,
      );

      final stale = _tronclassUser(
        name: 'Stale User',
        avatar: '',
        password: 'old-password',
      );
      final updated = await CredentialManager.updateCredentialExpiry(
        stale,
        expiryTimestamp: 2000000000,
        notify: false,
      );

      expect(updated.name, 'Fresh QQ User');
      expect(updated.avatar, 'fresh.png');
      expect(updated.password, '');
      expect(updated.credentialExpiry, 2000000000);

      final stored = AccountManager.getAccountsForPlatformName(
        'tronclass',
      ).single;
      expect(stored.name, 'Fresh QQ User');
      expect(stored.avatar, 'fresh.png');
      expect(stored.password, '');
      expect(stored.credentialExpiry, 2000000000);
    },
  );

  test(
    'platform state notification contains Tronclass account snapshot',
    () async {
      await _bootstrap(platform: 'tronclass');

      final user = _tronclassUser();
      await AccountManager.addAccountForPlatformName(
        'tronclass',
        user,
        notify: false,
        migrateTempCookies: false,
      );
      await AccountManager.setCurrentSessionForPlatformName(
        'tronclass',
        user.uid,
        notify: false,
      );

      final snapshotFuture = AccountChangeNotifier().accountStateChanges
          .firstWhere(
            (snapshot) => snapshot.platform == PlatformType.tronclass,
          );

      AccountManager.notifyStateChangedForPlatform(PlatformType.tronclass);

      final snapshot = await snapshotFuture;
      expect(snapshot.currentAccountId, user.uid);
      expect(
        snapshot.accounts.map((account) => account.uid),
        contains(user.uid),
      );
    },
  );

  test(
    'login completion can activate Tronclass from another platform',
    () async {
      await _bootstrap(platform: 'ketangpai');

      final user = _tronclassUser();
      await AccountManager.addAccountForPlatformName(
        'tronclass',
        user,
        notify: false,
        migrateTempCookies: false,
      );
      await AccountManager.setCurrentSessionForPlatformName(
        'tronclass',
        user.uid,
        notify: false,
      );

      await PlatformManager().activatePlatformForLoginCompletion(
        PlatformType.tronclass,
      );

      expect(PlatformManager().currentPlatform, PlatformType.tronclass);
      expect(AccountManager.currentSessionId, user.uid);
      expect(
        AccountManager.getCurrentPlatformAccounts().map(
          (account) => account.uid,
        ),
        contains(user.uid),
      );
    },
  );
}
