import 'package:course_helper/services/sign_run_console.dart';
import 'package:course_helper/services/sign_platform_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracks success, failure, skipped and copy text', () {
    final controller = SignRunConsoleController();
    addTearDown(controller.dispose);

    controller.add(
      platform: '学习通',
      accountName: 'alice',
      accountId: 'u1',
      stage: SignRunStage.queued,
      message: 'queued',
      mirrorToRequestConsole: false,
    );
    controller.add(
      platform: '学习通',
      accountName: 'alice',
      accountId: 'u1',
      stage: SignRunStage.signSuccess,
      message: 'ok',
      mirrorToRequestConsole: false,
    );
    controller.add(
      platform: '学习通',
      accountName: 'bob',
      accountId: 'u2',
      stage: SignRunStage.signFailure,
      message: 'failed',
      detail: 'reason',
      mirrorToRequestConsole: false,
    );
    controller.add(
      platform: '学习通',
      accountName: 'carol',
      accountId: 'u3',
      stage: SignRunStage.userSkipped,
      message: 'skip',
      mirrorToRequestConsole: false,
    );

    expect(controller.events, hasLength(4));
    expect(controller.successCount, 1);
    expect(controller.failureCount, 1);
    expect(controller.skippedCount, 1);
    expect(controller.copyText(), contains('[学习通] [bob/u2]'));
    expect(controller.copyText(), contains('reason'));
  });

  test('rejects events from another bound platform', () {
    final controller = SignRunConsoleController(
      platformContext: SignPlatformContext.chaoxing,
    );
    addTearDown(controller.dispose);

    controller.add(
      platform: '学习通',
      accountName: 'alice',
      accountId: 'u1',
      stage: SignRunStage.signSuccess,
      message: 'ok',
      mirrorToRequestConsole: false,
    );
    controller.add(
      platform: '雨课堂',
      accountName: 'bob',
      accountId: 'u2',
      stage: SignRunStage.signFailure,
      message: 'polluted',
      mirrorToRequestConsole: false,
    );

    expect(controller.events, hasLength(1));
    expect(controller.events.single.platform, '学习通');
  });

  test('resetForPlatform clears previous run and rebinds platform', () {
    final controller = SignRunConsoleController(
      platformContext: SignPlatformContext.chaoxing,
    );
    addTearDown(controller.dispose);

    controller.add(
      platform: '学习通',
      accountName: 'alice',
      accountId: 'u1',
      stage: SignRunStage.signSuccess,
      message: 'ok',
      mirrorToRequestConsole: false,
    );

    controller.resetForPlatform(SignPlatformContext.tronclass);
    controller.add(
      platform: '畅课',
      accountName: 'tc',
      accountId: 'u3',
      stage: SignRunStage.signSuccess,
      message: 'ok',
      mirrorToRequestConsole: false,
    );

    expect(controller.events, hasLength(1));
    expect(controller.events.single.platform, '畅课');
  });
}
