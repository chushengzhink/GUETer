import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'platform_request_context.dart';
import '../session/account.dart';
import '../platform.dart';

/// 简单的畅课（Tronclass）任务抓取与缓存客户端
class TronclassFetchClient {
  static const String _cacheKey = 'tronclass_todos_cache_v1';

  /// 拉取当前会话下的 todos（作业/考试列表）
  ///
  /// 使用独立 Dio 实例，从 AccountManager 加载 Cookie
  static Future<List<Map<String, dynamic>>> fetchTodos() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('畅课', '未登录，无法获取待办');
      return <Map<String, dynamic>>[];
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.tronclass,
      userId: userId,
    );

    final cookieStr = await AccountManager.getCookieForPlatform(
      PlatformType.tronclass,
      userId,
    );
    ApiService.appendExternalConsoleLog(
      '畅课',
      '已注入 Cookie 总长度: ${cookieStr?.length ?? 0}',
    );

    final resp = await context.sendRequest(
      '/api/todos',
      method: 'GET',
    );

    if (resp.statusCode == 200) {
      final data = resp.data;
      if (data is Map && data.containsKey('todo_list')) {
        final list = (data['todo_list'] as List).map((e) {
          try {
            return Map<String, dynamic>.from(e as Map);
          } catch (_) {
            return <String, dynamic>{};
          }
        }).toList();
        ApiService.appendExternalConsoleLog(
          '畅课',
          '获取待办成功，共 ${list.length} 项',
        );
        return list;
      }
      return <Map<String, dynamic>>[];
    }
    throw Exception('Tronclass fetch failed: ${resp.statusCode}');
  }

  /// 获取考试列表
  static Future<List<Map<String, dynamic>>> fetchExams() async {
    final userId = AccountManager.currentSessionId;
    if (userId == null || userId.isEmpty) {
      ApiService.appendExternalConsoleLog('畅课', '未登录，无法获取考试');
      return <Map<String, dynamic>>[];
    }

    final context = await PlatformRequestContext.create(
      platform: PlatformType.tronclass,
      userId: userId,
    );

    final cookieStr = await AccountManager.getCookieForPlatform(
      PlatformType.tronclass,
      userId,
    );
    ApiService.appendExternalConsoleLog(
      '畅课',
      '已注入 Cookie 总长度: ${cookieStr?.length ?? 0}',
    );

    final resp = await context.sendRequest(
      '/api/exams',
      method: 'GET',
    );

    if (resp.statusCode == 200) {
      final data = resp.data;
      if (data is Map && data.containsKey('exam_list')) {
        final list = (data['exam_list'] as List).map((e) {
          try {
            return Map<String, dynamic>.from(e as Map);
          } catch (_) {
            return <String, dynamic>{};
          }
        }).toList();
        ApiService.appendExternalConsoleLog(
          '畅课',
          '获取考试成功，共 ${list.length} 项',
        );
        return list;
      }
      return <Map<String, dynamic>>[];
    }
    throw Exception('Tronclass fetch exams failed: ${resp.statusCode}');
  }

  /// 缓存 todos 到 SharedPreferences（以 JSON 字符串形式）
  static Future<void> cacheTodos(List<Map<String, dynamic>> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(todos);
    await prefs.setString(_cacheKey, encoded);
  }

  /// 读取缓存的 todos
  static Future<List<Map<String, dynamic>>> loadCachedTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// 将 todos 导出为 CSV 字符串（第一行为表头）
  static String exportToCsvString(List<Map<String, dynamic>> todos) {
    final headers = ['course_id', 'course_code', 'course_name', 'task_id', 'title', 'type', 'end_time', 'is_locked', 'is_student'];
    final sb = StringBuffer();
    sb.writeln(headers.join(','));
    for (final t in todos) {
      final row = <String>[];
      row.add(_safe(t['course_id']));
      row.add(_safe(t['course_code']));
      row.add(_quoteIfNeeded(_safe(t['course_name'])));
      row.add(_safe(t['id'] ?? t['task_id'] ?? t['homework_id']));
      row.add(_quoteIfNeeded(_safe(t['title'])));
      row.add(_safe(t['type']));
      row.add(_safe(t['end_time']));
      row.add(_safe(t['is_locked']));
      row.add(_safe(t['is_student']));
      sb.writeln(row.join(','));
    }
    return sb.toString();
  }

  static String _safe(Object? v) {
    if (v == null) return '';
    return v.toString().replaceAll('\n', ' ').replaceAll('\r', ' ');
  }

  static String _quoteIfNeeded(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      final escaped = s.replaceAll('"', '""');
      return '"$escaped"';
    }
    return s;
  }

  /// 简易的周期性拉取（仅在 App 前台/正在运行时有效）
  /// 返回 Timer 对象以便取消：timer.cancel();
  static Timer schedulePeriodicFetch(Duration interval, void Function(List<Map<String, dynamic>>) onUpdate) {
    // 立即执行一次
    unawaited(_periodicFetchAndCache(onUpdate));
    return Timer.periodic(interval, (_) async {
      await _periodicFetchAndCache(onUpdate);
    });
  }

  static Future<void> _periodicFetchAndCache(void Function(List<Map<String, dynamic>>) onUpdate) async {
    try {
      final todos = await fetchTodos();
      await cacheTodos(todos);
      onUpdate(todos);
    } catch (e) {
      ApiService.appendExternalConsoleLog('TronclassFetch', 'fetch error: $e');
    }
  }
}

// Helper to avoid analyzer unused import warning when unawaited is used
void unawaited(Future<void> f) {}
