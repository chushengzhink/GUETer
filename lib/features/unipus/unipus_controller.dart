import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'unipus_models.dart';
import 'unipus_service.dart';

@pragma('vm:entry-point')
void unipusForegroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(_UnipusForegroundTaskHandler());
}

class _UnipusForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class UnipusController extends ChangeNotifier {
  UnipusController({UnipusService? service})
    : _service = service ?? UnipusService();

  static const _configKey = 'unipus_assist_config';
  static const _logsKey = 'unipus_assist_logs';
  static const _lastIndexKey = 'unipus_assist_current_index';

  final UnipusService _service;

  UnipusAssistConfig _config = UnipusAssistConfig.empty;
  bool _busy = false;
  bool _loggedIn = false;
  bool _foregroundRunning = false;
  int _currentIndex = 0;
  String? _error;
  List<UnipusCourseBlock> _courseBlocks = const <UnipusCourseBlock>[];
  List<UnipusQueueItem> _queue = const <UnipusQueueItem>[];
  final List<UnipusAssistLog> _logs = <UnipusAssistLog>[];

  UnipusAssistConfig get config => _config;
  bool get busy => _busy;
  bool get loggedIn => _loggedIn;
  bool get foregroundRunning => _foregroundRunning;
  int get currentIndex => _currentIndex;
  String? get error => _error;
  List<UnipusCourseBlock> get courseBlocks => List.unmodifiable(_courseBlocks);
  List<UnipusQueueItem> get queue => List.unmodifiable(_queue);
  List<UnipusAssistLog> get logs => List.unmodifiable(_logs);
  UnipusQueueItem? get currentItem =>
      _currentIndex >= 0 && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;
  int get confirmedCount => _queue.where((item) => item.confirmed).length;
  int get pendingCount => _queue.length - confirmedCount;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final rawConfig = prefs.getString(_configKey);
    if (rawConfig != null && rawConfig.isNotEmpty) {
      try {
        _config = UnipusAssistConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawConfig) as Map),
        );
      } catch (_) {
        _config = UnipusAssistConfig.empty;
      }
    }
    final rawLogs = prefs.getStringList(_logsKey) ?? const <String>[];
    _logs
      ..clear()
      ..addAll(
        rawLogs.map((line) {
          try {
            return UnipusAssistLog.fromJson(
              Map<String, dynamic>.from(jsonDecode(line) as Map),
            );
          } catch (_) {
            return UnipusAssistLog(
              timestamp: DateTime.now(),
              message: line,
              level: UnipusLogLevel.info,
            );
          }
        }),
      );
    _currentIndex = prefs.getInt(_lastIndexKey) ?? 0;
    _foregroundRunning = await FlutterForegroundTask.isRunningService;
    notifyListeners();
  }

  Future<void> saveConfig(UnipusAssistConfig config) async {
    _config = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _configKey,
      jsonEncode(config.toJson(includePassword: config.rememberPassword)),
    );
    _log('配置已保存', level: UnipusLogLevel.success);
    notifyListeners();
  }

  Future<void> loginAndScan({
    required UnipusCaptchaResolver captchaResolver,
  }) async {
    await _runGuarded(() async {
      if (_config.username.trim().isEmpty) {
        throw ArgumentError('请先填写 U 校园账号');
      }
      await _service.prepare(
        _config.username,
        userAgent: _config.userAgent.trim().isEmpty ? null : _config.userAgent,
      );
      var loggedIn = await _service.checkLoginAndSetupSession();
      if (!loggedIn) {
        if (_config.password.trim().isEmpty) {
          throw ArgumentError('登录状态失效，请填写密码后重试');
        }
        _log('Cookie 失效，开始登录 U 校园');
        await _service.login(
          username: _config.username,
          password: _config.password,
          userAgent: _config.userAgent.trim().isEmpty
              ? null
              : _config.userAgent,
          captchaResolver: captchaResolver,
        );
        loggedIn = true;
      } else {
        _log('已通过 Cookie 恢复 U 校园登录');
      }
      _loggedIn = loggedIn;
      await scanCourses();
    });
  }

  Future<void> scanCourses() async {
    await _runGuarded(() async {
      _log('开始扫描 U 校园课程');
      final blocks = await _service.fetchCourses();
      _courseBlocks = blocks;
      final queue = <UnipusQueueItem>[];
      for (final block in blocks) {
        for (final course in block.courses) {
          final tutorialId = _config.tutorialId.trim().isNotEmpty
              ? _config.tutorialId.trim()
              : course.tutorialId;
          if (tutorialId.isEmpty) continue;
          if (_config.tutorialId.trim().isNotEmpty &&
              course.tutorialId.isNotEmpty &&
              course.tutorialId != _config.tutorialId.trim()) {
            continue;
          }
          _log('读取课程树：${course.courseName}');
          final roots = await _service.fetchCourseNodes(tutorialId);
          final flattened = roots
              .expand((node) => node.flatten())
              .where((node) => node.isLeaf)
              .where(_shouldQueueNode)
              .toList();
          for (final node in flattened) {
            queue.add(
              UnipusQueueItem(
                id: '${tutorialId}_${node.leaf}_${node.path.join('_')}',
                courseName: course.courseName.isEmpty
                    ? block.className
                    : course.courseName,
                node: node,
              ),
            );
          }
        }
      }
      if (_config.unfinishedFirst) {
        queue.sort((a, b) {
          final aRank = a.node.passed ? 1 : 0;
          final bRank = b.node.passed ? 1 : 0;
          if (aRank != bRank) return aRank.compareTo(bRank);
          return a.node.pathLabel.compareTo(b.node.pathLabel);
        });
      }
      _queue = queue;
      _currentIndex = queue.isEmpty ? 0 : _currentIndex.clamp(0, queue.length - 1);
      await _persistCurrentIndex();
      _log('已生成 ${queue.length} 个辅助队列项', level: UnipusLogLevel.success);
    });
  }

  Future<void> startAssist() async {
    await _runGuarded(() async {
      await _startForegroundService();
      if (_config.autoOpenNext && currentItem != null) {
        await openCurrentItem();
      }
      _log('已启动连续辅助模式');
    });
  }

  Future<void> stopAssist() async {
    await _runGuarded(() async {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      _foregroundRunning = false;
      _log('已停止后台辅助');
    });
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    await _runGuarded(() async {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        _log('已发起忽略电池优化请求');
      } else {
        _log('系统已允许忽略电池优化');
      }
    });
  }

  Future<void> openCurrentItem() async {
    final item = currentItem;
    if (item == null) {
      _log('没有可打开的当前任务', level: UnipusLogLevel.warning);
      return;
    }
    final opened = await _service.openTaskPage(item);
    if (opened) {
      _queue = List<UnipusQueueItem>.from(_queue)
        ..[_currentIndex] = item.copyWith(openedAt: DateTime.now());
      _log('已打开：${item.courseName} / ${item.node.displayTitle}');
      notifyListeners();
    } else {
      _log('打开任务页面失败：${item.node.displayTitle}', level: UnipusLogLevel.error);
    }
  }

  Future<void> confirmCurrentAndAdvance() async {
    final item = currentItem;
    if (item == null) return;
    final updated = item.copyWith(
      confirmed: true,
      confirmedAt: DateTime.now(),
    );
    _queue = List<UnipusQueueItem>.from(_queue)..[_currentIndex] = updated;
    _log('用户确认已处理：${item.courseName} / ${item.node.displayTitle}');
    if (_currentIndex < _queue.length - 1) {
      _currentIndex += 1;
      await _persistCurrentIndex();
      if (_config.autoOpenNext) {
        await openCurrentItem();
      }
    } else {
      _log('队列已到末尾', level: UnipusLogLevel.success);
    }
    notifyListeners();
  }

  void moveToQueueIndex(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    unawaited(_persistCurrentIndex());
    _log('已切换到队列第 ${index + 1} 项');
    notifyListeners();
  }

  String exportQueueMarkdown() => _service.exportQueueMarkdown(_queue);

  String exportLogsText() {
    final buffer = StringBuffer();
    for (final log in _logs) {
      buffer.writeln('[${log.timestamp.toIso8601String()}] ${log.message}');
    }
    return buffer.toString();
  }

  bool _shouldQueueNode(UnipusTaskNode node) {
    if (_config.reviewMode) return true;
    if (node.passed) return false;
    return node.required || !node.passed;
  }

  Future<void> _startForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'unipus_assist_service',
        channelName: 'U 校园辅助',
        channelDescription: '保持 U 校园辅助队列和确认流程可见运行',
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        allowWifiLock: true,
      ),
    );

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        notificationTitle: 'GUETer - U 校园辅助',
        notificationText: currentItem == null
            ? '辅助队列待命'
            : '当前：${currentItem!.node.displayTitle}',
        callback: unipusForegroundStartCallback,
      );
    }
    _foregroundRunning = true;
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error, stackTrace) {
      _error = _formatError(error);
      _log(_error!, level: UnipusLogLevel.error);
      debugPrint('Unipus assist error: $error\n$stackTrace');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _persistCurrentIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastIndexKey, _currentIndex);
  }

  Future<void> _persistLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = _logs.length > 120
        ? _logs.sublist(_logs.length - 120)
        : _logs;
    await prefs.setStringList(
      _logsKey,
      recent.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  void _log(String message, {UnipusLogLevel level = UnipusLogLevel.info}) {
    _logs.add(
      UnipusAssistLog(
        timestamp: DateTime.now(),
        message: message,
        level: level,
      ),
    );
    if (_logs.length > 160) {
      _logs.removeRange(0, _logs.length - 160);
    }
    unawaited(_persistLogs());
  }

  String _formatError(Object error) {
    final text = error.toString();
    final separator = text.indexOf(': ');
    if (separator != -1) {
      return text.substring(separator + 2).trim();
    }
    return text;
  }
}
