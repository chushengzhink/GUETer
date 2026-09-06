import 'dart:async';
import 'package:course_helper/controllers/account_context_controller.dart';
import 'package:course_helper/controllers/sign_task_controller.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/sign_execution_context.dart';
import 'package:course_helper/api/sign_request_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

User user(String id) => User(name: id, avatar: '', phone: '', uid: id, school: '', platform: 'rainclassroom');
SignExecutionContext identity(String id, {RainClassroomServerType server = RainClassroomServerType.pro}) => SignExecutionContext(
  platform: PlatformType.rainClassroom, account: user(id), server: server,
  tronclassBaseUrl: 'https://school.test', ketangpaiBaseUrl: 'https://kt.test');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rapid selection coalesces intermediate destinations and commits last intent', () async {
    AccountTarget current = (platform: PlatformType.chaoxing, accountId: 'A');
    final first = Completer<void>();
    final applied = <AccountTarget>[];
    final controller = AccountContextController(read: () => current, apply: (target) async {
      applied.add(target);
      if (applied.length == 1) await first.future;
      current = target;
    });
    final start = controller.select(PlatformType.rainClassroom, accountId: 'B');
    controller.select(PlatformType.tronclass, accountId: 'C');
    final finish = controller.select(PlatformType.chaoxing, accountId: 'A');
    expect(controller.switching, isTrue);
    expect(controller.target?.accountId, 'A');
    first.complete(); await start; await finish;
    expect(applied.map((e) => e.accountId), ['B', 'A']);
    expect(current.accountId, 'A'); expect(controller.switching, isFalse);
    controller.dispose();
  });
  test('failed selection leaves a recoverable error and next selection works', () async {
    var fail = true;
    final controller = AccountContextController(read: () => (platform: PlatformType.chaoxing, accountId: 'A'),
      apply: (_) async { if (fail) throw StateError('storage'); });
    await controller.select(PlatformType.tronclass);
    expect(controller.error, isNotNull);
    fail = false; await controller.select(PlatformType.chaoxing);
    expect(controller.error, isNull); controller.dispose();
  });
  test('concurrent tasks retain account and endpoint across awaits without changing UI', () async {
    PlatformManager().setPlatformSync(PlatformType.chaoxing);
    AccountManager.setCurrentSessionTemp('ui');
    final gates = [Completer<void>(), Completer<void>()];
    final observed = <String>[];
    Future<void> run(int i, SignExecutionContext ctx) => ctx.run(() async {
      await gates[i].future;
      observed.add('${AccountManager.currentSessionId}|${PlatformManager().serverName}');
      expect(PlatformManager().currentPlatform, PlatformType.rainClassroom);
    });
    final a = run(0, identity('A'));
    final b = run(1, identity('B', server: RainClassroomServerType.huanghe));
    AccountManager.setCurrentSessionTemp('new-ui');
    gates[1].complete(); await b; gates[0].complete(); await a;
    expect(observed, ['B|huanghe', 'A|pro']);
    expect(AccountManager.currentSessionId, 'new-ui');
    expect(PlatformManager().currentPlatform, PlatformType.chaoxing);
  });
  test('duplicate check-in joins one task; changing accounts creates separate task', () async {
    final controller = SignTaskController();
    final gate = Completer<int>(); var calls = 0;
    Future<int> action() { calls++; return gate.future; }
    final a = controller.run(identity: identity('A'), operation: 'qr:123', label: 'Check in', action: action);
    final duplicate = controller.run(identity: identity('A'), operation: 'qr:123', label: 'Check in', action: action);
    final b = controller.run(identity: identity('B'), operation: 'qr:123', label: 'Check in', action: action);
    expect(calls, 2);
    gate.complete(42); expect(await a, 42); expect(await duplicate, 42); await b;
    expect(controller.hasRunning, isFalse);
    expect(controller.tasks, hasLength(2)); controller.dispose();
  });
  test('waiting task resumes once without restarting the action', () async {
    final controller = SignTaskController(); var submissions = 0;
    final future = controller.run(identity: identity('A'), operation: '123', label: 'Check in', action: () async {
      final proceed = await SignTaskController.currentTask!.ask('Network required');
      if (proceed) submissions++;
    });
    final task = controller.tasks.single;
    expect(task.waiting, isTrue); expect(submissions, 0);
    task.respond(true); task.respond(true); await future;
    expect(submissions, 1); controller.dispose();
  });
  test('unknown write outcome never retries with fallback headers', () async {
    var calls = 0;
    await expectLater(SignRequestExecutor.run(
      profile: const SignRequestProfile(kind: SignRequestProfileKind.tronclassRollcall,
        platformLabel: 'TronClass', profileName: 'test', headers: {}),
      headers: {}, legacyHeaders: {}, operation: 'POST /api/rollcall/1',
      context: const SignRequestContext(platform: PlatformType.tronclass,
        url: 'https://school.test/api/rollcall/1', method: 'POST', contentKind: SignRequestContentKind.json),
      send: (_) async { calls++; throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.receiveTimeout); },
    ), throwsA(isA<DioException>()));
    expect(calls, 1);
  });
}
