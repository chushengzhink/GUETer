import 'dart:async';
import 'package:flutter/foundation.dart';

import '../platform.dart';
import '../session/account.dart';

typedef AccountTarget = ({PlatformType platform, String? accountId});

/// Serializes local session changes while coalescing rapid selections. Network
/// refreshes are owned by the destination and never block selecting another one.
class AccountContextController extends ChangeNotifier {
  AccountContextController({
    required Future<void> Function(AccountTarget) apply,
    required AccountTarget Function() read,
  }) : _apply = apply, _read = read;

  static final instance = AccountContextController(
    apply: (target) async {
      await PlatformManager().applyPlatformSelection(target.platform);
      if (target.accountId != null) {
        if (!await AccountManager.applyAccountSelection(target.accountId!)) {
          throw StateError('账号不可用 / Account unavailable');
        }
      }
    },
    read: () => (
      platform: PlatformManager().currentPlatform,
      accountId: AccountManager.currentSessionId,
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

  Future<void> select(PlatformType platform, {String? accountId}) {
    final next = (platform: platform, accountId: accountId);
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

  void _notify() { if (!_disposed) notifyListeners(); }
  @override
  void dispose() { _disposed = true; super.dispose(); }
}
