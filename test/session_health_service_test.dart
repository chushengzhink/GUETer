import 'dart:async';

import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/services/session_health_service.dart';
import 'package:flutter_test/flutter_test.dart';

User _tronclassUser({int? expiry}) {
  return User(
    name: 'Alice',
    avatar: '',
    phone: '',
    uid: 'tc-1',
    school: '',
    platform: 'tronclass',
    credentialExpiry: expiry,
  );
}

void main() {
  tearDown(() {
    SessionHealthService.debugTronclassProbeOverride = null;
    SessionHealthService.debugRefreshOverride = null;
    SessionHealthService.debugCurrentPlatformIssuesOverride = null;
  });

  test('healthy tronclass account returns no issue', () async {
    SessionHealthService.debugTronclassProbeOverride = (_) async => true;

    final result = await SessionHealthService().checkUser(
      _tronclassUser(),
      platform: PlatformType.tronclass,
    );

    expect(result.healthy, isTrue);
    expect(result.issue, isNull);
  });

  test('failed probe refresh success suppresses issue', () async {
    var probeCount = 0;
    SessionHealthService.debugTronclassProbeOverride = (_) async {
      probeCount += 1;
      return probeCount > 1;
    };
    SessionHealthService.debugRefreshOverride = (_) async => true;

    final result = await SessionHealthService().checkUser(
      _tronclassUser(),
      platform: PlatformType.tronclass,
    );

    expect(result.healthy, isTrue);
    expect(probeCount, 2);
  });

  test('failed probe and failed refresh emits issue', () async {
    SessionHealthService.debugTronclassProbeOverride = (_) async => false;
    SessionHealthService.debugRefreshOverride = (_) async => false;

    final result = await SessionHealthService().checkUser(
      _tronclassUser(),
      platform: PlatformType.tronclass,
    );

    expect(result.healthy, isFalse);
    expect(result.issue?.platform, PlatformType.tronclass);
    expect(result.issue?.accountId, 'tc-1');
    expect(result.issue?.reason, contains('会话已过期'));
    expect(result.issue?.refreshAttempted, isTrue);
  });

  test('controller ignores stale platform check results', () async {
    final controller = SessionHealthController();
    addTearDown(controller.dispose);
    final releaseChaoxing = Completer<List<SessionHealthIssue>>();

    SessionHealthService.debugCurrentPlatformIssuesOverride = (platform) {
      if (platform == PlatformType.chaoxing) {
        return releaseChaoxing.future;
      }
      return Future.value([
        SessionHealthIssue(
          platform: PlatformType.tronclass,
          accountId: 'tc-1',
          accountName: 'Tron',
          reason: '畅课会话已过期，请重新登录',
          detectedAt: DateTime(2026),
          refreshAttempted: true,
          canReLogin: true,
        ),
      ]);
    };

    final first = controller.checkCurrentPlatform(
      platform: PlatformType.chaoxing,
    );
    final second = controller.checkCurrentPlatform(
      platform: PlatformType.tronclass,
    );

    await second;
    releaseChaoxing.complete([
      SessionHealthIssue(
        platform: PlatformType.chaoxing,
        accountId: 'cx-1',
        accountName: 'Cx',
        reason: '学习通登录态失效，请重新登录',
        detectedAt: DateTime(2026),
        refreshAttempted: true,
        canReLogin: true,
      ),
    ]);
    await first;

    expect(controller.issues.map((issue) => issue.platform), [
      PlatformType.tronclass,
    ]);
  });
}
