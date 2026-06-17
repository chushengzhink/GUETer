import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/login.dart';
import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/credential_manager.dart';
import '../session/tronclass_auth.dart';

class SessionHealthIssue {
  const SessionHealthIssue({
    required this.platform,
    required this.accountId,
    required this.accountName,
    required this.reason,
    required this.detectedAt,
    required this.refreshAttempted,
    required this.canReLogin,
  });

  final PlatformType platform;
  final String accountId;
  final String accountName;
  final String reason;
  final DateTime detectedAt;
  final bool refreshAttempted;
  final bool canReLogin;

  String get key => '${platform.name}:$accountId';
}

class SessionHealthResult {
  const SessionHealthResult._({this.issue});

  final SessionHealthIssue? issue;

  bool get healthy => issue == null;

  static const healthyResult = SessionHealthResult._();
}

class SessionHealthService {
  SessionHealthService({
    Duration refreshTimeout = const Duration(seconds: 5),
    Duration probeTimeout = const Duration(seconds: 5),
  }) : _refreshTimeout = refreshTimeout,
       _probeTimeout = probeTimeout;

  final Duration _refreshTimeout;
  final Duration _probeTimeout;

  static Future<bool> Function(User user)? debugTronclassProbeOverride;
  static Future<bool> Function(User user)? debugRefreshOverride;
  static Future<List<SessionHealthIssue>> Function(PlatformType platform)?
  debugCurrentPlatformIssuesOverride;

  Future<List<SessionHealthIssue>> checkCurrentPlatformAccounts({
    PlatformType? platform,
  }) async {
    final targetPlatform = platform ?? PlatformManager().currentPlatform;
    final issuesOverride = debugCurrentPlatformIssuesOverride;
    if (issuesOverride != null) {
      return issuesOverride(targetPlatform);
    }
    final accounts = AccountManager.getAccountsForPlatform(targetPlatform);
    final issues = <SessionHealthIssue>[];

    for (final user in accounts) {
      final result = await checkUser(user, platform: targetPlatform);
      final issue = result.issue;
      if (issue != null) {
        issues.add(issue);
      }
    }

    return issues;
  }

  Future<SessionHealthResult> checkUser(
    User user, {
    PlatformType? platform,
  }) async {
    final targetPlatform = platform ?? _platformOf(user);
    if (targetPlatform == null) {
      return SessionHealthResult._(
        issue: _issue(
          user,
          PlatformManager().currentPlatform,
          '无法识别账号所属平台',
          refreshAttempted: false,
        ),
      );
    }

    if (await _isHealthy(user, targetPlatform)) {
      return SessionHealthResult.healthyResult;
    }

    final refreshed = await _refresh(user);
    if (refreshed && await _isHealthy(user, targetPlatform)) {
      return SessionHealthResult.healthyResult;
    }

    return SessionHealthResult._(
      issue: _issue(
        user,
        targetPlatform,
        _defaultReason(targetPlatform),
        refreshAttempted: true,
      ),
    );
  }

  Future<bool> ensureHealthy(User user, {PlatformType? platform}) async {
    return (await checkUser(user, platform: platform)).healthy;
  }

  Future<bool> _refresh(User user) async {
    final override = debugRefreshOverride;
    if (override != null) {
      return override(user);
    }
    try {
      return await CredentialManager.refreshCredentialGuarded(
        user,
        timeout: _refreshTimeout,
      );
    } catch (e) {
      debugPrint('[SessionHealth] refresh failed: $e');
      return false;
    }
  }

  Future<bool> _isHealthy(User user, PlatformType platform) async {
    if (user.isCredentialExpired()) {
      return false;
    }

    if (platform == PlatformType.tronclass) {
      return _isTronclassHealthy(user);
    }

    return true;
  }

  Future<bool> _isTronclassHealthy(User user) async {
    final override = debugTronclassProbeOverride;
    if (override != null) {
      return override(user);
    }

    final sessionId = await TronclassAuthManager.getSessionIdForUser(user.uid);
    if (sessionId == null || sessionId.trim().isEmpty) {
      return false;
    }

    try {
      final bootstrapped = await TCLoginApi.bootstrapPortalSession(
        sessionId: sessionId,
      ).timeout(_probeTimeout, onTimeout: () => false);
      if (!bootstrapped) {
        return false;
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: PlatformManager().tronclassBaseUrl,
          connectTimeout: _probeTimeout,
          receiveTimeout: _probeTimeout,
          sendTimeout: _probeTimeout,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: const {'accept': 'application/json, text/plain, */*'},
        ),
      );

      final response = await dio.get<dynamic>(
        '/api/profile',
        options: Options(headers: {'x-session-id': sessionId}),
      );
      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return false;
      }
      final data = response.data;
      if (data is String) {
        final lower = data.toLowerCase();
        if (lower.contains('<html') || lower.contains('login')) {
          return false;
        }
      }
      return status >= 200 && status < 400;
    } catch (e) {
      debugPrint('[SessionHealth] tronclass probe failed: $e');
      return false;
    }
  }

  SessionHealthIssue _issue(
    User user,
    PlatformType platform,
    String reason, {
    required bool refreshAttempted,
  }) {
    return SessionHealthIssue(
      platform: platform,
      accountId: user.uid,
      accountName: user.name,
      reason: reason,
      detectedAt: DateTime.now(),
      refreshAttempted: refreshAttempted,
      canReLogin: true,
    );
  }

  PlatformType? _platformOf(User user) {
    if (user.isChaoxing) return PlatformType.chaoxing;
    if (user.isRainClassroom) return PlatformType.rainClassroom;
    if (user.isTronclass) return PlatformType.tronclass;
    if (user.isKetangpai) return PlatformType.ketangpai;
    if (user.isWeizhuojiao) return PlatformType.weizhuojiao;
    return null;
  }

  String _defaultReason(PlatformType platform) {
    if (platform == PlatformType.tronclass) {
      return '畅课会话已过期，请重新登录';
    }
    return '${_platformLabel(platform)}登录态失效，请重新登录';
  }

  String _platformLabel(PlatformType platform) {
    return switch (platform) {
      PlatformType.chaoxing => '学习通',
      PlatformType.rainClassroom => '雨课堂',
      PlatformType.tronclass => '畅课',
      PlatformType.ketangpai => '课堂派',
      PlatformType.weizhuojiao => '微助教',
    };
  }
}

class SessionHealthController extends ChangeNotifier {
  SessionHealthController({SessionHealthService? service})
    : _service = service ?? SessionHealthService();

  final SessionHealthService _service;
  final List<SessionHealthIssue> _issues = <SessionHealthIssue>[];
  final Set<String> _dismissedKeys = <String>{};
  final Map<PlatformType, int> _platformGenerations = <PlatformType, int>{};
  final Set<PlatformType> _checkingPlatforms = <PlatformType>{};
  int _globalGeneration = 0;

  List<SessionHealthIssue> get issues => List.unmodifiable(_issues);
  bool get checking => _checkingPlatforms.isNotEmpty;

  SessionHealthIssue? get visibleIssue {
    final currentPlatform = PlatformManager().currentPlatform;
    for (final issue in _issues) {
      if (issue.platform == currentPlatform &&
          !_dismissedKeys.contains(issue.key)) {
        return issue;
      }
    }
    return null;
  }

  int get visibleIssueCount => _issues
      .where(
        (issue) =>
            issue.platform == PlatformManager().currentPlatform &&
            !_dismissedKeys.contains(issue.key),
      )
      .length;

  Future<void> checkCurrentPlatform({
    PlatformType? platform,
    bool resetDismissed = true,
  }) async {
    final targetPlatform = platform ?? PlatformManager().currentPlatform;
    final globalGeneration = ++_globalGeneration;
    final generation = (_platformGenerations[targetPlatform] ?? 0) + 1;
    _platformGenerations[targetPlatform] = generation;
    if (_checkingPlatforms.contains(targetPlatform)) return;
    _checkingPlatforms.add(targetPlatform);
    notifyListeners();

    try {
      final nextIssues = await _service.checkCurrentPlatformAccounts(
        platform: targetPlatform,
      );
      if (_globalGeneration != globalGeneration ||
          _platformGenerations[targetPlatform] != generation) {
        return;
      }
      _issues
        ..removeWhere((issue) => issue.platform == targetPlatform)
        ..addAll(nextIssues);
      if (resetDismissed) {
        _dismissedKeys.removeWhere(
          (key) => _issues.any((issue) => issue.key == key),
        );
      }
    } finally {
      _checkingPlatforms.remove(targetPlatform);
      notifyListeners();
    }
  }

  Future<bool> ensureHealthy(User user, {PlatformType? platform}) async {
    final targetPlatform = platform ?? _platformOfUser(user);
    final result = await _service.checkUser(user, platform: platform);
    final issue = result.issue;
    if (issue == null) {
      if (targetPlatform != null) {
        _issues.removeWhere(
          (item) =>
              item.platform == targetPlatform && item.accountId == user.uid,
        );
      }
      notifyListeners();
      return true;
    }

    _issues.removeWhere((item) => item.key == issue.key);
    _issues.add(issue);
    _dismissedKeys.remove(issue.key);
    notifyListeners();
    return false;
  }

  PlatformType? _platformOfUser(User user) {
    if (user.isChaoxing) return PlatformType.chaoxing;
    if (user.isRainClassroom) return PlatformType.rainClassroom;
    if (user.isTronclass) return PlatformType.tronclass;
    if (user.isKetangpai) return PlatformType.ketangpai;
    if (user.isWeizhuojiao) return PlatformType.weizhuojiao;
    return null;
  }

  void dismiss(SessionHealthIssue issue) {
    _dismissedKeys.add(issue.key);
    notifyListeners();
  }

  void clearForAccount(PlatformType platform, String accountId) {
    _issues.removeWhere(
      (issue) => issue.platform == platform && issue.accountId == accountId,
    );
    _dismissedKeys.remove('${platform.name}:$accountId');
    notifyListeners();
  }
}
