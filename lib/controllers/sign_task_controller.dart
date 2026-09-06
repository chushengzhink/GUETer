import 'dart:async';
import 'package:flutter/material.dart';
import '../session/sign_execution_context.dart';

class SignTask extends ChangeNotifier {
  SignTask(this.key, this.identity, this.label);
  final String key;
  final SignExecutionContext identity;
  final String label;
  final List<String> messages = [];
  List<String> accounts = const [];
  List<SignExecutionContext> resultContexts = const [];
  Future<String> Function()? queryResult;
  bool querying = false;
  Future<void> query() async {
    if (querying || queryResult == null) return;
    querying = true;
    SignTaskController.instance.notifyTaskChanged();
    try {
      messages.add(await queryResult!());
    } catch (_) {
      messages.add('查询失败，请检查网络后再次查询 / Unable to query. Check your connection.');
    } finally {
      querying = false;
      SignTaskController.instance.notifyTaskChanged();
    }
  }

  bool running = true;
  Object? error;
  bool waiting = false;
  Completer<bool>? _decision;
  void Function()? openSettings;
  Future<bool> Function(BuildContext)? challenge;

  Future<bool> requestChallenge(Future<bool> Function(BuildContext) resolve) {
    challenge = resolve;
    return ask('需要完成验证 / Verification required');
  }

  Future<void> resolveChallenge(BuildContext context) async {
    final resolve = challenge;
    if (resolve == null) return;
    challenge = null;
    try {
      respond(await identity.run(() => resolve(context)));
    } catch (_) {
      respond(false);
    }
  }

  Future<bool> ask(String message, {void Function()? settings}) {
    messages.add(message);
    waiting = true;
    openSettings = settings;
    _decision = Completer<bool>();
    notifyListeners();
    SignTaskController.instance.notifyTaskChanged();
    return _decision!.future;
  }

  void respond(bool proceed) {
    final decision = _decision;
    _decision = null;
    waiting = false;
    openSettings = null;
    challenge = null;
    if (decision != null && !decision.isCompleted) decision.complete(proceed);
    notifyListeners();
    SignTaskController.instance.notifyTaskChanged();
  }
}

/// Task ownership outlives routes. UI may observe or answer a pending question;
/// navigating away never restarts a submitted operation.
class SignTaskController extends ChangeNotifier {
  static final instance = SignTaskController();
  static final Object _taskKey = Object();
  static SignTask? get currentTask => Zone.current[_taskKey] as SignTask?;
  final List<SignTask> _tasks = [];
  final Map<String, Future<Object?>> _running = {};
  final Map<String, Future<Object?>> _requests = {};

  Future<T> deduplicate<T>({
    required SignExecutionContext identity,
    required String operation,
    required Future<T> Function() action,
  }) {
    final key = '${identity.key}|$operation';
    final existing = _requests[key];
    if (existing != null) return existing.then((value) => value as T);
    final done = Completer<T>();
    _requests[key] = done.future;
    identity.run(() async {
      try {
        done.complete(await action());
      } catch (error, stack) {
        done.completeError(error, stack);
      } finally {
        _requests.remove(key);
      }
    });
    return done.future;
  }

  List<SignTask> get tasks => List.unmodifiable(_tasks);
  bool get hasRunning => _tasks.any((t) => t.running);

  Future<T> run<T>({
    required SignExecutionContext identity,
    required String operation,
    required String label,
    required Future<T> Function() action,
  }) {
    final key = '${identity.key}|$operation';
    final existing = _running[key];
    if (existing != null) return existing.then((value) => value as T);
    final task = SignTask(key, identity, label);
    _tasks.insert(0, task);
    if (_tasks.length > 20) {
      final completed = _tasks.lastWhere((t) => !t.running, orElse: () => task);
      if (completed != task) _tasks.remove(completed);
    }
    final done = Completer<T>();
    _running[key] = done.future;
    notifyListeners();
    identity.run(
      () => runZoned(() async {
        try {
          done.complete(await action());
        } catch (failure, stack) {
          task.error = failure;
          done.completeError(failure, stack);
        } finally {
          task.running = false;
          _running.remove(key);
          task.notifyListeners();
          notifyListeners();
        }
      }, zoneValues: {_taskKey: task}),
    );
    return done.future;
  }

  void record(String message) {
    final task = currentTask;
    if (task == null) return;
    task.messages.add(message);
    task.notifyListeners();
    notifyListeners();
  }

  void notifyTaskChanged() => notifyListeners();
  void dismissCompleted() {
    _tasks.removeWhere((task) => !task.running);
    notifyListeners();
  }
}
