import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../api/api_service.dart';

class _OngoingTodoEntry {
  const _OngoingTodoEntry({
    required this.title,
    required this.platform,
    required this.deadline,
  });

  final String title;
  final String platform;
  final DateTime deadline;
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationsEnabled = true;
  bool _showTodosOnLockScreen = true;

  static const String _notificationEnabledKey = 'notifications_enabled';
  static const String _showTodosOnLockScreenKey =
      'todo_notifications_show_on_lock_screen';
  static const int _ongoingNotificationId = 999999;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_notificationEnabledKey) ?? true;
    _showTodosOnLockScreen = prefs.getBool(_showTodosOnLockScreenKey) ?? true;

    _initialized = true;
    ApiService.appendExternalConsoleLog(
      'NotificationService',
      'Initialized successfully',
    );
  }

  Future<bool> checkPermissionStatus() async {
    if (!_initialized) await initialize();

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'Android permission status: $granted',
      );
      return granted ?? false;
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: false,
        badge: false,
        sound: false,
      );
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'iOS permission status: $granted',
      );
      return granted ?? false;
    }

    return true;
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'Android permission granted: $granted',
      );
      return granted ?? false;
    }

    final iosPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'iOS permission granted: $granted',
      );
      return granted ?? false;
    }

    return true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationEnabledKey, enabled);

    if (!enabled) {
      await cancelAllNotifications();
      await cancelOngoingNotification();
    }
  }

  Future<void> setShowTodosOnLockScreen(bool enabled) async {
    if (!_initialized) await initialize();

    _showTodosOnLockScreen = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTodosOnLockScreenKey, enabled);
  }

  bool get notificationsEnabled => _notificationsEnabled;

  bool get showTodosOnLockScreen => _showTodosOnLockScreen;

  Future<void> scheduleNotificationsForTodos(
    List<Map<String, dynamic>> todos,
    String platformName,
  ) async {
    if (!_initialized || !_notificationsEnabled) return;

    for (final todo in todos) {
      await _scheduleNotificationForTodo(todo, platformName);
    }
  }

  Future<void> updateOngoingNotification(
    List<Map<String, dynamic>> allPendingTodos,
  ) async {
    if (!_initialized || !_notificationsEnabled) return;

    if (allPendingTodos.isEmpty) {
      await _showOngoingNotification(title: '所有待办已完成', body: '暂无未完成的待办事项');
      return;
    }

    final visibleTodos = _buildVisibleOngoingTodos(allPendingTodos);
    if (visibleTodos.isEmpty) {
      await _showOngoingNotification(title: '暂无未截止的待办', body: '已截止的待办不会显示在通知栏');
      return;
    }

    final nearestTodo = visibleTodos.first;
    await _showOngoingNotification(
      title: '您有 ${visibleTodos.length} 项待办未完成',
      body: '最近一项：${nearestTodo.title}',
      expandedTodos: visibleTodos,
    );
  }

  Future<void> _showOngoingNotification({
    required String title,
    required String body,
    List<_OngoingTodoEntry>? expandedTodos,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'ongoing_todos',
      '待办汇总',
      channelDescription: '常驻通知栏显示待办汇总',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      visibility: _androidVisibility,
      styleInformation: _buildOngoingStyleInformation(title, expandedTodos),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(_ongoingNotificationId, title, body, details);
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'Updated ongoing notification: $title',
      );
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'Failed to show ongoing notification: $e',
      );
    }
  }

  StyleInformation? _buildOngoingStyleInformation(
    String title,
    List<_OngoingTodoEntry>? expandedTodos,
  ) {
    if (expandedTodos == null || expandedTodos.isEmpty) {
      return null;
    }

    if (expandedTodos.length == 1) {
      final todo = expandedTodos.first;
      return BigTextStyleInformation(
        '${todo.title}\n平台：${todo.platform}\n截止：${_formatDeadline(todo.deadline)}（北京时间）',
        contentTitle: title,
        summaryText: '截止时间按北京时间显示',
      );
    }

    final lines = expandedTodos
        .map(
          (todo) =>
              '${todo.title} · ${todo.platform} · 截止 ${_formatDeadline(todo.deadline)}',
        )
        .toList();

    return InboxStyleInformation(
      lines,
      contentTitle: title,
      summaryText: '截止时间按北京时间显示',
    );
  }

  List<_OngoingTodoEntry> _buildVisibleOngoingTodos(
    List<Map<String, dynamic>> allPendingTodos,
  ) {
    final now = DateTime.now();
    final todos = <_OngoingTodoEntry>[];

    for (final todo in allPendingTodos) {
      final deadline = _extractDeadline(todo);
      if (deadline == null || deadline.isBefore(now)) {
        continue;
      }

      final title = todo['title']?.toString().trim();
      if (title == null || title.isEmpty) {
        continue;
      }

      todos.add(
        _OngoingTodoEntry(
          title: title,
          platform: _extractPlatformName(todo),
          deadline: deadline,
        ),
      );
    }

    todos.sort((a, b) => a.deadline.compareTo(b.deadline));
    return todos;
  }

  String _extractPlatformName(Map<String, dynamic> todo) {
    final platform =
        todo['platform_name']?.toString().trim() ??
        todo['platform']?.toString().trim() ??
        '';
    return platform.isEmpty ? '未知平台' : platform;
  }

  Future<void> _scheduleNotificationForTodo(
    Map<String, dynamic> todo,
    String platformName,
  ) async {
    final todoId = todo['id']?.toString() ?? '';
    if (todoId.isEmpty) return;

    final deadline = _extractDeadline(todo);
    final title = todo['title']?.toString() ?? '未知任务';
    final courseName =
        todo['course_name']?.toString() ??
        todo['classroom_name']?.toString() ??
        '';

    if (deadline == null) return;

    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      await cancelNotificationForTodo(todoId);
      return;
    }

    final notificationIdBase = todoId.hashCode.abs() % 100000;
    final oneHourBefore = deadline.subtract(const Duration(hours: 1));
    final oneDayBefore = deadline.subtract(const Duration(hours: 24));

    final body =
        '$platformName · $courseName · 截止 ${_formatDeadline(deadline)}';

    ApiService.appendExternalConsoleLog(
      'NotificationService',
      '调度通知: $title 截止时间(北京时间) ${_formatLogTime(deadline)}',
    );

    if (oneDayBefore.isAfter(now)) {
      await _scheduleNotification(
        id: notificationIdBase * 10 + 1,
        title: title,
        body: body,
        scheduledDate: oneDayBefore,
        priority: Priority.defaultPriority,
      );
    }

    if (oneHourBefore.isAfter(now)) {
      await _scheduleNotification(
        id: notificationIdBase * 10 + 2,
        title: '⏰ 即将截止：$title',
        body: body,
        scheduledDate: oneHourBefore,
        priority: Priority.high,
      );
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required Priority priority,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'todo_reminders',
      '待办提醒',
      channelDescription: '待办事项截止时间提醒',
      importance: priority == Priority.high ? Importance.max : Importance.high,
      priority: priority,
      fullScreenIntent: priority == Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: _androidVisibility,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'Scheduled notification $id for $scheduledDate',
      );
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        'NotificationService',
        'Failed to schedule notification: $e',
      );
    }
  }

  Future<void> cancelNotificationForTodo(String todoId) async {
    if (!_initialized) return;

    final notificationIdBase = todoId.hashCode.abs() % 100000;
    await _notifications.cancel(notificationIdBase * 10 + 1);
    await _notifications.cancel(notificationIdBase * 10 + 2);
  }

  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    await _notifications.cancelAll();
    ApiService.appendExternalConsoleLog(
      'NotificationService',
      'Cancelled all notifications',
    );
  }

  Future<void> cancelOngoingNotification() async {
    if (!_initialized) return;
    await _notifications.cancel(_ongoingNotificationId);
    ApiService.appendExternalConsoleLog(
      'NotificationService',
      'Cancelled ongoing notification',
    );
  }

  DateTime? _extractDeadline(Map<String, dynamic> todo) {
    if (todo['end_time'] != null) {
      final endTimeStr = todo['end_time'].toString();
      try {
        if (endTimeStr.contains('-')) {
          final parsed = DateTime.parse(endTimeStr);
          return parsed.isUtc ? parsed.toLocal() : parsed;
        }

        final timestamp = int.tryParse(endTimeStr);
        if (timestamp != null) {
          final utcDate = DateTime.fromMillisecondsSinceEpoch(
            timestamp * 1000,
            isUtc: true,
          );
          final deadline = utcDate.add(const Duration(hours: 8));
          ApiService.appendExternalConsoleLog(
            'NotificationService',
            '原始截止时间(UTC): ${utcDate.toIso8601String()}, 北京时间: ${_formatLogTime(deadline)}',
          );
          return deadline;
        }
      } catch (e) {
        ApiService.appendExternalConsoleLog(
          'NotificationService',
          'Failed to parse end_time: $e',
        );
      }
    }

    if (todo['endtime'] != null) {
      final endTimeStr = todo['endtime'].toString();
      try {
        final timestamp = int.tryParse(endTimeStr);
        if (timestamp != null && timestamp > 0) {
          final parsed = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          final deadline = parsed.isUtc
              ? parsed.add(const Duration(hours: 8))
              : parsed;
          ApiService.appendExternalConsoleLog(
            'NotificationService',
            '原始截止时间: ${parsed.toIso8601String()}, 北京时间: ${_formatLogTime(deadline)}',
          );
          return deadline;
        }
      } catch (e) {
        ApiService.appendExternalConsoleLog(
          'NotificationService',
          'Failed to parse endtime: $e',
        );
      }
    }

    return null;
  }

  NotificationVisibility get _androidVisibility => _showTodosOnLockScreen
      ? NotificationVisibility.public
      : NotificationVisibility.secret;

  String _formatDeadline(DateTime deadline) {
    return '${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
  }

  String _formatLogTime(DateTime deadline) {
    return '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
  }
}
