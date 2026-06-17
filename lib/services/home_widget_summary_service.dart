import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../study/study_card_store.dart';
import 'notification_service.dart';

class HomeWidgetSummary {
  const HomeWidgetSummary({
    required this.todoCount,
    required this.reviewDueCount,
    required this.nearestTodoTitle,
    required this.notificationEnabled,
    required this.updatedAt,
  });

  final int todoCount;
  final int reviewDueCount;
  final String nearestTodoTitle;
  final bool notificationEnabled;
  final DateTime updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'todoCount': todoCount,
      'reviewDueCount': reviewDueCount,
      'nearestTodoTitle': nearestTodoTitle,
      'notificationEnabled': notificationEnabled,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class HomeWidgetSummaryService {
  HomeWidgetSummaryService({
    StudyCardStore? studyCardStore,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _studyCardStore = studyCardStore ?? StudyCardStore(),
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String androidWidgetName = 'GueterTodayWidget';
  static const MethodChannel _channel = MethodChannel(
    'com.gueter.cszm/home_widget_summary',
  );
  static const String todoCountKey = 'gueter_widget_todo_count';
  static const String reviewDueCountKey = 'gueter_widget_review_due_count';
  static const String nearestTodoTitleKey = 'gueter_widget_nearest_todo_title';
  static const String notificationEnabledKey =
      'gueter_widget_notification_enabled';
  static const String updatedAtKey = 'gueter_widget_updated_at';

  final StudyCardStore _studyCardStore;
  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<HomeWidgetSummary> buildSummary() async {
    final studySummary = await _studyCardStore.summary();
    final prefs = await _preferencesLoader();
    final todoCount = _readTodoCount(prefs);
    final nearestTodoTitle = _readNearestTodoTitle(prefs);
    bool notificationEnabled = true;
    try {
      notificationEnabled = await NotificationService().checkPermissionStatus();
    } catch (_) {
      notificationEnabled = false;
    }
    return HomeWidgetSummary(
      todoCount: todoCount,
      reviewDueCount: studySummary.dueCards,
      nearestTodoTitle: nearestTodoTitle,
      notificationEnabled: notificationEnabled,
      updatedAt: DateTime.now(),
    );
  }

  Future<HomeWidgetSummary> updateWidget() async {
    final summary = await buildSummary();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return summary;
    }
    await _channel.invokeMethod<void>('update', <String, Object?>{
      todoCountKey: summary.todoCount,
      reviewDueCountKey: summary.reviewDueCount,
      nearestTodoTitleKey: summary.nearestTodoTitle,
      notificationEnabledKey: summary.notificationEnabled,
      updatedAtKey: _formatClock(summary.updatedAt),
    });
    return summary;
  }

  int _readTodoCount(SharedPreferences prefs) {
    const candidateKeys = <String>[
      'todo_today_count',
      'todos_today_count',
      'app_widget_todo_count',
      'ongoing_todo_count',
    ];
    for (final key in candidateKeys) {
      final value = prefs.getInt(key);
      if (value != null) return value;
    }
    return 0;
  }

  String _readNearestTodoTitle(SharedPreferences prefs) {
    const candidateKeys = <String>[
      'todo_nearest_title',
      'nearest_todo_title',
      'app_widget_nearest_todo',
    ];
    for (final key in candidateKeys) {
      final value = prefs.getString(key);
      if (value != null && value.trim().isNotEmpty) {
        return _sanitizeSummaryText(value);
      }
    }
    return '暂无待办';
  }

  String _sanitizeSummaryText(String value) {
    var text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceAll(RegExp(r'\b\d{8,12}\b'), '<id>');
    if (text.length > 40) {
      text = '${text.substring(0, 40)}...';
    }
    return text;
  }

  String _formatClock(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
