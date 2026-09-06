import 'dart:async';
import 'package:flutter/foundation.dart';
import '../session/sign_execution_context.dart';

class SignTask extends ChangeNotifier {
  SignTask(this.key, this.identity, this.label);
  final String key;
  final SignExecutionContext identity;
  final String label;
  final List<String> messages = [];
  bool running = true;
  Object? error;
  bool waiting = false;
  Completer<bool>? _decision;
  void Function()? openSettings;

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
    identity.run(() => runZoned(() async {
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
    }, zoneValues: {_taskKey: task}));
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
