import 'dart:async';

import '../api/api_service.dart';
import 'cookie.dart';
import 'credential_manager.dart';

class StartupRecoveryCoordinator {
  StartupRecoveryCoordinator._();

  static const Duration _perAccountTimeout = Duration(seconds: 5);
  static Future<void>? _inFlight;

  static Future<void> runAfterLaunch() {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }

    final future = _run();
    _inFlight = future;
    return future;
  }

  static Future<void> _run() async {
    final startedAt = DateTime.now();
    ApiService.logStartupRecovery(
      '[StartupRecovery] post-launch recovery begin',
    );

    try {
      await CookieManager.restoreCookiesForStartup(
        perAccountTimeout: _perAccountTimeout,
      );
      await CredentialManager.validateAllCredentialsForStartup(
        perUserTimeout: _perAccountTimeout,
      );
      await CookieManager.refreshAccountsInBackground(
        startupMode: true,
        perAccountTimeout: _perAccountTimeout,
      );

      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      await ApiService.finishStartupRecoverySession(
        status: 'completed',
        summary: 'elapsedMs=$elapsedMs',
      );
    } catch (e) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      ApiService.logStartupRecovery(
        '[StartupRecovery] aborted error=$e elapsedMs=$elapsedMs',
      );
      await ApiService.finishStartupRecoverySession(
        status: 'aborted',
        summary: 'error=$e elapsedMs=$elapsedMs',
      );
    } finally {
      _inFlight = null;
    }
  }
}
