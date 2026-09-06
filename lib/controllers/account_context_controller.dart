import 'dart:async';
import 'package:flutter/foundation.dart';

import '../platform.dart';
import '../session/account.dart';
import '../session/sign_execution_context.dart';

typedef AccountTarget = ({
  PlatformType platform,
  String? accountId,
  RainClassroomServerType server,
  String tronclassBaseUrl,
  String ketangpaiBaseUrl,
});

/// Serializes local session changes while coalescing rapid selections. Network
/// refreshes are owned by the destination and never block selecting another one.
class AccountContextController extends ChangeNotifier {
  AccountContextController({
    required Future<void> Function(AccountTarget) apply,
    required AccountTarget Function() read,
  }) : _apply = apply,
       _read = read;

  static final instance = AccountContextController(
    apply: (target) async {
      final manager = PlatformManager();
      final previous = SignExecutionContext.capture();
      if (target.accountId != null &&
          !AccountManager.getAccountsForPlatform(
            target.platform,
          ).any((u) => u.uid == target.accountId)) {
        throw StateError('账号不可用 / Account unavailable');
      }
      try {
        await manager.applySiteSelection(
          server: target.server,
          tronclassBaseUrl: target.tronclassBaseUrl,
          ketangpaiBaseUrl: target.ketangpaiBaseUrl,
        );
        await manager.applyPlatformSelection(target.platform, notify: false);
        if (target.accountId != null &&
            !await AccountManager.applyAccountSelection(target.accountId!)) {
          throw StateError('账号不可用 / Account unavailable');
        }
        manager.notifyContextChanged();
      } catch (_) {
        await manager.applySiteSelection(
          server: previous.server,
          tronclassBaseUrl: previous.tronclassBaseUrl,
          ketangpaiBaseUrl: previous.ketangpaiBaseUrl,
        );
        await manager.applyPlatformSelection(previous.platform, notify: false);
        if (previous.account != null) {
          await AccountManager.applyAccountSelection(previous.account!.uid);
        }
        manager.notifyContextChanged();
        rethrow;
      }
    },
    read: () => (
      platform: PlatformManager().currentPlatform,
      accountId: AccountManager.currentSessionId,
      server: PlatformManager().currentServer,
      tronclassBaseUrl: PlatformManager().tronclassBaseUrl,
      ketangpaiBaseUrl: PlatformManager().ketangpaiBaseUrl,
    ),
  );

  final Future<void> Function(AccountTarget) _apply;
  final AccountTarget Function() _read;
  AccountTarget? _pending;
  Future<void>? _draining;
  AccountTarget? target;
  Object? error;
  bool _disposed = false;
  bool get switching => _draining != null;
  AccountTarget get current => _read();

  Future<void> select(
    PlatformType platform, {
    String? accountId,
    RainClassroomServerType? server,
    String? tronclassBaseUrl,
    String? ketangpaiBaseUrl,
  }) {
    final source = target ?? current;
    final next = (
      platform: platform,
      accountId: accountId,
      server: server ?? source.server,
      tronclassBaseUrl: tronclassBaseUrl ?? source.tronclassBaseUrl,
      ketangpaiBaseUrl: ketangpaiBaseUrl ?? source.ketangpaiBaseUrl,
    );
    if (next == target && switching) return _draining!;
    target = next;
    _pending = next;
    error = null;
    if (_draining != null) {
      _notify();
      return _draining!;
    }
    final done = Completer<void>();
    _draining = done.future;
    _notify();
    _drain(done);
    return done.future;
  }

  Future<void> _drain(Completer<void> done) async {
    while (_pending != null) {
      final next = _pending!;
      _pending = null;
      try {
        await _apply(next);
        if (_pending == null) error = null;
      } catch (failure) {
        if (_pending == null) error = failure;
      }
    }
    target = null;
    _draining = null;
    _notify();
    done.complete();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
