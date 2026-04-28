import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationsEnabled = true;

  static const String _notificationEnabledKey = 'notifications_enabled';
  static const int _ongoingNotificationId = 999999;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    _initialized = true;
    ApiService.appendExternalConsoleLog('NotificationService', 'Initialized successfully');
  }

  Future<bool> checkPermissionStatus() async {
    if (!_initialized) await initialize();

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled();
      ApiService.appendExternalConsoleLog('NotificationService', 'Android permission status: $granted');
      return granted ?? false;
    }

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: false,
        badge: false,
        sound: false,
      );
      ApiService.appendExternalConsoleLog('NotificationService', 'iOS permission status: $granted');
      return granted ?? false;
    }

    return true;
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      ApiService.appendExternalConsoleLog('NotificationService', 'Android permission granted: $granted');
      return granted ?? false;
    }

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      ApiService.appendExternalConsoleLog('NotificationService', 'iOS permission granted: $granted');
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

  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> scheduleNotificationsForTodos(List<Map<String, dynamic>> todos, String platformName) async {
    if (!_initialized || !_notificationsEnabled) return;

    for (var todo in todos) {
      await _scheduleNotificationForTodo(todo, platformName);
    }
  }

  Future<void> updateOngoingNotification(List<Map<String, dynamic>> allPendingTodos) async {
    if (!_initialized || !_notificationsEnabled) return;

    if (allPendingTodos.isEmpty) {
      await _showOngoingNotification(
        title: '所有待办已完成',
        body: '暂无未完成的待办事项',
        bigText: null,
      );
    } else {
      final count = allPendingTodos.length;
      final nearestTodo = allPendingTodos.first;
      final todoTitle = nearestTodo['title']?.toString() ?? '未知任务';
      final platform = nearestTodo['platform']?.toString() ?? '';

      DateTime? deadline;
      if (nearestTodo['end_time'] != null) {
        try {
          final endTimeStr = nearestTodo['end_time'].toString();
          if (endTimeStr.contains('-')) {
            final parsed = DateTime.parse(endTimeStr);
            deadline = parsed.isUtc ? parsed.toLocal() : parsed;
          } else {
            final timestamp = int.tryParse(endTimeStr);
            if (timestamp != null) {
              final utcDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
              deadline = utcDate.add(const Duration(hours: 8));
            }
          }
        } catch (_) {}
      } else if (nearestTodo['endtime'] != null) {
        try {
          final timestamp = int.tryParse(nearestTodo['endtime'].toString());
          if (timestamp != null && timestamp > 0) {
            final parsed = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            deadline = parsed.isUtc ? parsed.add(const Duration(hours: 8)) : parsed;
          }
        } catch (_) {}
      }

      final deadlineStr = deadline != null ? _formatDeadline(deadline) : '未知';
      final remainingStr = deadline != null ? _formatRemaining(deadline) : '';
      final bigText = '[$platform] $todoTitle${remainingStr.isNotEmpty ? ' 剩余 $remainingStr' : ''} (截止 $deadlineStr)';

      await _showOngoingNotification(
        title: '您有 $count 项待办未完成',
        body: '最近一项：$todoTitle',
        bigText: bigText,
      );
    }
  }

  Future<void> _showOngoingNotification({
    required String title,
    required String body,
    String? bigText,
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
      styleInformation: bigText != null
          ? BigTextStyleInformation(
              bigText,
              contentTitle: title,
              summaryText: '待办提醒',
            )
          : null,
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
      await _notifications.show(
        _ongoingNotificationId,
        title,
        body,
        details,
      );
      ApiService.appendExternalConsoleLog('NotificationService', 'Updated ongoing notification: $title');
    } catch (e) {
      ApiService.appendExternalConsoleLog('NotificationService', 'Failed to show ongoing notification: $e');
    }
  }

  Future<void> _scheduleNotificationForTodo(Map<String, dynamic> todo, String platformName) async {
    final todoId = todo['id']?.toString() ?? '';
    if (todoId.isEmpty) return;

    DateTime? deadline;
    String title = todo['title']?.toString() ?? '未知任务';
    String courseName = todo['course_name']?.toString() ?? todo['classroom_name']?.toString() ?? '';

    if (todo['end_time'] != null) {
      final endTimeStr = todo['end_time'].toString();
      try {
        if (endTimeStr.contains('-')) {
          final parsed = DateTime.parse(endTimeStr);
          deadline = parsed.isUtc ? parsed.toLocal() : parsed;
        } else {
          final timestamp = int.tryParse(endTimeStr);
          if (timestamp != null) {
            final utcDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
            deadline = utcDate.add(const Duration(hours: 8));
            ApiService.appendExternalConsoleLog('NotificationService', '原始截止时间(UTC): ${utcDate.toIso8601String()}, 北京时间: ${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}');
          }
        }
      } catch (e) {
        ApiService.appendExternalConsoleLog('NotificationService', 'Failed to parse end_time: $e');
      }
    } else if (todo['endtime'] != null) {
      final endTimeStr = todo['endtime'].toString();
      try {
        final timestamp = int.tryParse(endTimeStr);
        if (timestamp != null && timestamp > 0) {
          final parsed = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          deadline = parsed.isUtc ? parsed.add(const Duration(hours: 8)) : parsed;
          ApiService.appendExternalConsoleLog('NotificationService', '原始截止时间: ${parsed.toIso8601String()}, 北京时间: ${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}');
        }
      } catch (e) {
        ApiService.appendExternalConsoleLog('NotificationService', 'Failed to parse endtime: $e');
      }
    }

    if (deadline == null) return;

    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      await cancelNotificationForTodo(todoId);
      return;
    }

    final notificationIdBase = todoId.hashCode.abs() % 100000;
    final oneHourBefore = deadline.subtract(const Duration(hours: 1));
    final oneDayBefore = deadline.subtract(const Duration(hours: 24));

    final body = '$platformName · $courseName · 截止 ${_formatDeadline(deadline)}';

    ApiService.appendExternalConsoleLog('NotificationService', '调度通知: $title 截止时间(北京时间) ${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}');

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
        title: '⚠️ 即将截止：$title',
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
      visibility: NotificationVisibility.public,
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      ApiService.appendExternalConsoleLog('NotificationService', 'Scheduled notification $id for $scheduledDate');
    } catch (e) {
      ApiService.appendExternalConsoleLog('NotificationService', 'Failed to schedule notification: $e');
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
    ApiService.appendExternalConsoleLog('NotificationService', 'Cancelled all notifications');
  }

  Future<void> cancelOngoingNotification() async {
    if (!_initialized) return;
    await _notifications.cancel(_ongoingNotificationId);
    ApiService.appendExternalConsoleLog('NotificationService', 'Cancelled ongoing notification');
  }

  String _formatDeadline(DateTime deadline) {
    return '${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);

    if (diff.isNegative) {
      final absDiff = diff.abs();
      final hours = absDiff.inHours;
      final minutes = absDiff.inMinutes % 60;
      return '已截止 ${hours}时 ${minutes}分';
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days > 0) {
      return '${days}天 ${hours}时 ${minutes}分';
    } else if (hours > 0) {
      return '${hours}时 ${minutes}分';
    } else {
      return '${minutes}分';
    }
  }
}
