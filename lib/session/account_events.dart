import 'dart:async';

import '../models/user.dart';
import '../platform.dart';

class AccountStateSnapshot {
  AccountStateSnapshot({
    required this.platform,
    required List<User> accounts,
    this.currentAccountId,
  }) : accounts = List.unmodifiable(accounts);

  final PlatformType platform;
  final List<User> accounts;
  final String? currentAccountId;

  User? get currentAccount {
    final accountId = currentAccountId;
    if (accountId == null || accountId.isEmpty) {
      return null;
    }

    for (final account in accounts) {
      if (account.uid == accountId) {
        return account;
      }
    }
    return null;
  }
}

class AccountChangeNotifier {
  static final AccountChangeNotifier _instance =
      AccountChangeNotifier._internal();

  factory AccountChangeNotifier() => _instance;

  AccountChangeNotifier._internal();

  final StreamController<AccountStateSnapshot> _controller =
      StreamController<AccountStateSnapshot>.broadcast();

  AccountStateSnapshot? _lastSnapshot;

  Stream<AccountStateSnapshot> get accountStateChanges => _controller.stream;

  Stream<String?> get accountChanges =>
      _controller.stream.map((snapshot) => snapshot.currentAccountId);

  AccountStateSnapshot? get currentSnapshot => _lastSnapshot;

  void notifySnapshot(AccountStateSnapshot snapshot) {
    _lastSnapshot = snapshot;
    _controller.add(snapshot);
  }

  void notifyAccountChanged(
    String? accountId, {
    PlatformType? platform,
    List<User>? accounts,
  }) {
    notifySnapshot(
      AccountStateSnapshot(
        platform:
            platform ??
            _lastSnapshot?.platform ??
            PlatformManager().currentPlatform,
        accounts: accounts ?? _lastSnapshot?.accounts ?? const [],
        currentAccountId: accountId,
      ),
    );
  }

  void dispose() {
    _controller.close();
  }
}
