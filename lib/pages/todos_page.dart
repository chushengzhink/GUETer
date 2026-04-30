import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/course.dart';
import '../api/api_service.dart';
import '../api/platform_request_context.dart';
import '../api/chaoxing_chapter_api.dart';
import '../api/chaoxing_homework_api.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../platform.dart';
import '../utils/user_agent.dart';
import '../utils/global_palette.dart';
import '../theme/design_tokens.dart';
import '../theme/animations.dart';
import '../theme/components/app_badge.dart';
import '../services/notification_service.dart';
import 'tronclass_todo_detail_page.dart';

/// 单个平台的待办数据容器
class TodoPlatformData {
  List<Map<String, dynamic>> pendingTodos;
  List<Map<String, dynamic>> completedTodos;
  DateTime? lastRefreshTime;
  bool isLoading;
  bool requestLock;

  TodoPlatformData({
    List<Map<String, dynamic>>? pendingTodos,
    List<Map<String, dynamic>>? completedTodos,
    this.lastRefreshTime,
    this.isLoading = false,
    this.requestLock = false,
  }) : pendingTodos = pendingTodos ?? [],
       completedTodos = completedTodos ?? [];
}

class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> with WidgetsBindingObserver {
  // 按平台隔离的持久化数据容器，生命周期内不允许整体重建
  final Map<PlatformType, TodoPlatformData> _platformData = {
    PlatformType.chaoxing: TodoPlatformData(),
    PlatformType.tronclass: TodoPlatformData(),
    PlatformType.rainClassroom: TodoPlatformData(),
    PlatformType.ketangpai: TodoPlatformData(),
  };

  final Map<PlatformType, bool> _platformExpanded = {
    PlatformType.chaoxing: true,
    PlatformType.tronclass: true,
    PlatformType.rainClassroom: true,
    PlatformType.ketangpai: true,
  };

  bool _isInitializing = true;
  StreamSubscription<String?>? _accountChangeSubscription;
  Timer? _countdownTimer;
  String? _selectedDateFilter;

  /// 获取所有已登录平台的账号信息（不读取全局 currentPlatform）
  Map<PlatformType, String> _getAllPlatformAccounts() {
    final accounts = <PlatformType, String>{};

    for (final platform in [
      PlatformType.tronclass,
      PlatformType.chaoxing,
      PlatformType.rainClassroom,
      PlatformType.ketangpai,
    ]) {
      final platformAccounts = AccountManager.getAccountsForPlatform(platform);
      if (platformAccounts.isNotEmpty) {
        accounts[platform] = platformAccounts.first.uid;
      }
    }

    return accounts;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService.appendExternalConsoleLog('TodosPage', 'initState called');
    _autoRefreshOnOpen();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    // 优化：仅在有紧急待办时才启动倒计时
    _countdownTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted && _hasUrgentTodos()) {
        setState(() {});
      }
    });
  }

  bool _hasUrgentTodos() {
    final now = DateTime.now();
    for (final data in _platformData.values) {
      for (final todo in data.pendingTodos) {
        final deadline = _extractDeadlineFromTodo(todo, PlatformType.tronclass);
        if (deadline != null && deadline.difference(now).inHours < 24) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _autoRefreshOnOpen() async {
    setState(() => _isInitializing = true);
    await NotificationService().initialize();
    await _checkAndRequestNotificationPermission();

    // 先加载本地持久化数据
    await _loadPersistedTodos();

    if (mounted) {
      setState(() => _isInitializing = false);
    }

    // 后台静默刷新
    _loadAllTodos().catchError((e) {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Background refresh failed: $e',
      );
    });
  }

  Future<void> _loadPersistedTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final platform in [
        PlatformType.tronclass,
        PlatformType.chaoxing,
        PlatformType.rainClassroom,
        PlatformType.ketangpai,
      ]) {
        final key = 'todos_${platform.name}';
        final jsonStr = prefs.getString(key);

        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          final data = _platformData[platform]!;

          data.pendingTodos =
              (decoded['pending'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          data.completedTodos =
              (decoded['completed'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

          if (decoded['lastRefreshTime'] != null) {
            data.lastRefreshTime = DateTime.parse(
              decoded['lastRefreshTime'] as String,
            );
          }

          ApiService.appendExternalConsoleLog(
            'TodosPage',
            '${platform.name}: loaded ${data.pendingTodos.length} pending todos from cache',
          );
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Failed to load persisted todos: $e',
      );
    }
  }

  Future<void> _persistTodos() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      for (final entry in _platformData.entries) {
        final platform = entry.key;
        final data = entry.value;
        final key = 'todos_${platform.name}';

        final json = jsonEncode({
          'pending': data.pendingTodos,
          'completed': data.completedTodos,
          'lastRefreshTime': data.lastRefreshTime?.toIso8601String(),
        });

        await prefs.setString(key, json);
      }

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Todos persisted to local storage',
      );
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Failed to persist todos: $e',
      );
    }
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    // 每次进入待办页都检查通知权限状态
    final hasPermission = await NotificationService().checkPermissionStatus();

    if (!hasPermission && mounted) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('开启通知权限'),
          content: const Text('开启通知权限后，待办截止前我们会及时提醒你'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去开启'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        // 跳转到系统通知权限设置页面
        try {
          await NotificationService().requestPermissions();
        } catch (e) {
          ApiService.appendExternalConsoleLog(
            'TodosPage',
            'Failed to open notification settings: $e',
          );
        }
      }
    }
  }

  Future<void> _scheduleNotificationsForAllPlatforms() async {
    final platformNames = {
      PlatformType.tronclass: '畅课',
      PlatformType.chaoxing: '学习通',
      PlatformType.rainClassroom: '雨课堂',
      PlatformType.ketangpai: '课堂派',
    };

    final allPendingTodos = <Map<String, dynamic>>[];

    for (var entry in _platformData.entries) {
      final platform = entry.key;
      final data = entry.value;
      final platformName = platformNames[platform] ?? platform.name;

      if (data.pendingTodos.isNotEmpty) {
        await NotificationService().scheduleNotificationsForTodos(
          data.pendingTodos,
          platformName,
        );
        allPendingTodos.addAll(data.pendingTodos);
      }
    }

    await NotificationService().updateOngoingNotification(allPendingTodos);
  }

  @override
  void dispose() {
    _accountChangeSubscription?.cancel();
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 移除自动刷新逻辑，避免频繁请求
  }

  /// 直接从全局账户管理器检查平台登录状态（不切换平台）
  Map<PlatformType, bool> _getPlatformLoginStates() {
    final states = <PlatformType, bool>{};

    for (final platform in [
      PlatformType.tronclass,
      PlatformType.chaoxing,
      PlatformType.rainClassroom,
      PlatformType.ketangpai,
    ]) {
      final accounts = AccountManager.getAccountsForPlatform(platform);
      states[platform] = accounts.isNotEmpty;
    }

    return states;
  }

  /// 刷新所有已登录平台的待办
  Future<void> _refreshAllPlatformAccounts() async {
    ApiService.appendExternalConsoleLog(
      'TodosPage',
      'Manual refresh all platforms triggered',
    );
    await _loadAllTodos();
    await _scheduleNotificationsForAllPlatforms();
  }

  /// 刷新单个平台的待办
  Future<void> _refreshSinglePlatform(PlatformType platform) async {
    ApiService.appendExternalConsoleLog(
      'TodosPage',
      'Manual refresh platform ${platform.name} triggered',
    );

    final platformAccounts = _getAllPlatformAccounts();
    final userId = platformAccounts[platform];

    if (userId == null) {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'No account found for platform ${platform.name}',
      );
      return;
    }

    switch (platform) {
      case PlatformType.tronclass:
        await _loadTronclassTodos(userId);
        break;
      case PlatformType.chaoxing:
        await _loadChaoxingTodos(userId);
        break;
      case PlatformType.rainClassroom:
        await _loadRainClassroomTodos(userId);
        break;
      case PlatformType.ketangpai:
        await _loadKetangpaiTodos(userId);
        break;
      default:
        break;
    }

    await _scheduleNotificationsForAllPlatforms();
  }

  Future<void> _loadAllTodos() async {
    final platformAccounts = _getAllPlatformAccounts();

    ApiService.appendExternalConsoleLog(
      'TodosPage',
      '开始加载所有平台待办（使用隔离请求上下文，不修改全局状态）',
    );

    // 并发执行，使用独立的请求上下文
    await Future.wait([
      if (platformAccounts.containsKey(PlatformType.tronclass))
        _loadTronclassTodos(platformAccounts[PlatformType.tronclass]!),
      if (platformAccounts.containsKey(PlatformType.chaoxing))
        _loadChaoxingTodos(platformAccounts[PlatformType.chaoxing]!),
      if (platformAccounts.containsKey(PlatformType.rainClassroom))
        _loadRainClassroomTodos(platformAccounts[PlatformType.rainClassroom]!),
      if (platformAccounts.containsKey(PlatformType.ketangpai))
        _loadKetangpaiTodos(platformAccounts[PlatformType.ketangpai]!),
    ]);

    await _scheduleNotificationsForAllPlatforms();
  }

  Future<void> _loadTronclassTodos(String userId) async {
    final data = _platformData[PlatformType.tronclass]!;

    if (data.requestLock) {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Tronclass: request already in progress, skipping',
      );
      return;
    }

    setState(() {
      data.isLoading = true;
      data.requestLock = true;
    });

    PlatformRequestContext? context;
    try {
      context = await PlatformRequestContext.create(
        platform: PlatformType.tronclass,
        userId: userId,
      );

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Tronclass: requesting GET /api/todos',
      );
      final response = await context.sendRequest('/api/todos');

      if (!mounted) {
        ApiService.appendExternalConsoleLog(
          'TodosPage',
          'Tronclass: widget unmounted, discarding response',
        );
        return;
      }

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Tronclass: response status=${response.statusCode}',
      );

      final todos = <Map<String, dynamic>>[];
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['todo_list'] is List) {
          todos.addAll(
            (responseData['todo_list'] as List).cast<Map<String, dynamic>>(),
          );
        }
      }

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Tronclass: parsed ${todos.length} todos',
      );

      setState(() {
        data.pendingTodos = todos;
        data.lastRefreshTime = DateTime.now();
      });

      await _persistTodos();

      // 新增：获取课程内的作业、测试、互动
      await _loadTronclassCourseItems(userId, context, data);
    } catch (e) {
      ApiService.appendExternalConsoleLog('TodosPage', 'Tronclass: error = $e');
    } finally {
      if (mounted) {
        setState(() {
          data.isLoading = false;
          data.requestLock = false;
        });
      }
      context?.dispose();
    }
  }

  /// 获取畅课课程内的作业、测试、互动
  Future<void> _loadTronclassCourseItems(
    String userId,
    PlatformRequestContext context,
    TodoPlatformData data,
  ) async {
    try {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Tronclass: fetching course items (exams, homeworks, interactions)',
      );

      // 获取课程列表
      final coursesResponse = await context.sendRequest(
        '/api/users/$userId/courses',
        params: {'page': '1', 'per_page': '50'},
      );

      if (!mounted) return;

      if (coursesResponse.data is! Map<String, dynamic>) return;
      final coursesData = coursesResponse.data['data'];
      if (coursesData is! List) return;

      final courseItems = <Map<String, dynamic>>[];
      final existingIds = data.pendingTodos
          .map((t) => t['id']?.toString() ?? '')
          .toSet();

      for (final course in coursesData) {
        if (course is! Map<String, dynamic>) continue;
        final courseId = course['id']?.toString() ?? '';
        final courseName = course['name']?.toString() ?? '';
        if (courseId.isEmpty) continue;

        // 获取测试列表
        try {
          final examResponse = await context.sendRequest(
            '/api/courses/$courseId/exam-list',
            params: {
              'page': '1',
              'page_size': '10',
              'conditions':
                  '{"itemsSortBy":{"predicate":"created_at","reverse":true}}',
            },
          );

          if (examResponse.data is Map<String, dynamic>) {
            final exams = examResponse.data['exams'];
            if (exams is List) {
              for (final exam in exams) {
                if (exam is! Map<String, dynamic>) continue;
                final isClosed = exam['is_closed'] == true;
                if (isClosed) continue;

                final id = exam['id']?.toString() ?? '';
                if (id.isEmpty || existingIds.contains(id)) continue;

                existingIds.add(id);
                courseItems.add({
                  'id': id,
                  'title': exam['title']?.toString() ?? '',
                  'type': 'exam',
                  'course_name': courseName,
                  'end_time': exam['end_time']?.toString() ?? '',
                  'is_locked': exam['is_started'] != true,
                });
              }
            }
          }
        } catch (e) {
          ApiService.appendExternalConsoleLog(
            'TodosPage',
            'Tronclass: fetch exams for course $courseId error: $e',
          );
        }

        // 获取作业列表
        try {
          final homeworkResponse = await context.sendRequest(
            '/api/courses/$courseId/homework-activities',
            params: {
              'page': '1',
              'page_size': '10',
              'conditions':
                  '{"itemsSortBy":{"predicate":"created_at","reverse":true}}',
            },
          );

          if (homeworkResponse.data is Map<String, dynamic>) {
            final homeworks = homeworkResponse.data['homework_activities'];
            if (homeworks is List) {
              for (final homework in homeworks) {
                if (homework is! Map<String, dynamic>) continue;
                final isClosed = homework['is_closed'] == true;
                final submitted = homework['submitted'] == true;
                if (isClosed || submitted) continue;

                final id = homework['id']?.toString() ?? '';
                if (id.isEmpty || existingIds.contains(id)) continue;

                existingIds.add(id);
                courseItems.add({
                  'id': id,
                  'title': homework['title']?.toString() ?? '',
                  'type': 'homework',
                  'course_name': courseName,
                  'end_time': homework['end_time']?.toString() ?? '',
                  'is_locked': homework['is_in_progress'] != true,
                });
              }
            }
          }
        } catch (e) {
          ApiService.appendExternalConsoleLog(
            'TodosPage',
            'Tronclass: fetch homeworks for course $courseId error: $e',
          );
        }

        // 获取互动列表
        try {
          final interactionResponse = await context.sendRequest(
            '/api/courses/$courseId/interactions',
          );

          if (interactionResponse.data is Map<String, dynamic>) {
            final interactions = interactionResponse.data['interactions'];
            if (interactions is List) {
              for (final interaction in interactions) {
                if (interaction is! Map<String, dynamic>) continue;
                final isFinished = interaction['is_finished'] == true;
                if (isFinished) continue;

                final id = interaction['id']?.toString() ?? '';
                if (id.isEmpty || existingIds.contains(id)) continue;

                existingIds.add(id);
                courseItems.add({
                  'id': id,
                  'title': interaction['title']?.toString() ?? '',
                  'type': 'questionnaire',
                  'course_name': courseName,
                  'end_time': interaction['end_time']?.toString() ?? '',
                  'is_locked': false,
                });
              }
            }
          }
        } catch (e) {
          ApiService.appendExternalConsoleLog(
            'TodosPage',
            'Tronclass: fetch interactions for course $courseId error: $e',
          );
        }
      }

      if (!mounted) return;

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Tronclass: found ${courseItems.length} course items',
      );

      // 合并原有待办和课程待办
      final allTodos = [...data.pendingTodos, ...courseItems];

      // 按截止时间排序
      allTodos.sort((a, b) {
        final aTime = a['end_time']?.toString() ?? '';
        final bTime = b['end_time']?.toString() ?? '';
        if (aTime.isEmpty) return 1;
        if (bTime.isEmpty) return -1;
        return aTime.compareTo(bTime);
      });

      setState(() {
        data.pendingTodos = allTodos;
      });

      await _persistTodos();
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Tronclass: load course items error: $e',
      );
    }
  }

  Future<void> _loadChaoxingTodos(String userId) async {
    final data = _platformData[PlatformType.chaoxing]!;

    if (data.requestLock) {
      return;
    }

    setState(() {
      data.isLoading = true;
      data.requestLock = true;
    });

    PlatformRequestContext? context;
    try {
      context = await PlatformRequestContext.create(
        platform: PlatformType.chaoxing,
        userId: userId,
      );

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Chaoxing: fetching courses and todos',
      );

      final coursesData = await CXCourseApi.getCourses();
      if (!mounted) return;

      final allTodos = <Map<String, dynamic>>[];

      if (coursesData != null && coursesData['result'] == 1) {
        final channelList = coursesData['channelList'] as List<dynamic>? ?? [];

        for (final channel in channelList) {
          if (channel['content']?['course'] == null) continue;

          final courseData = channel['content']['course'];
          final courseId = courseData['data']?[0]?['id']?.toString() ?? '';
          final clazzId = channel['content']['id']?.toString() ?? '';
          final cpi = channel['cpi']?.toString() ?? '';
          final courseName = courseData['data']?[0]?['name']?.toString() ?? '';

          if (courseId.isEmpty || clazzId.isEmpty) continue;

          try {
            final homeworks = await ChaoxingHomeworkApi.getHomeworkList(
              courseId,
              clazzId,
            );
            for (final homework in homeworks) {
              final status = homework['status']?.toString() ?? '';
              if (status == '1' || status == 'completed') continue;

              allTodos.add({
                'id':
                    homework['workId']?.toString() ??
                    homework['id']?.toString() ??
                    '',
                'title': homework['title']?.toString() ?? '作业',
                'platform': '学习通',
                'course_name': courseName,
                'end_time': homework['endTime']?.toString() ?? '',
                'type': 'homework',
                'account': userId,
              });
            }

            final unfinishedTasks = await ChaoxingChapterApi.getUnfinishedTasks(
              courseId,
              clazzId,
              cpi,
            );
            for (final task in unfinishedTasks) {
              allTodos.add({
                'id':
                    task['objectId']?.toString() ??
                    task['jobId']?.toString() ??
                    '',
                'title': task['title']?.toString() ?? '学习任务',
                'platform': '学习通',
                'course_name': courseName,
                'chapter_name': task['chapterName']?.toString() ?? '',
                'type': task['type']?.toString() ?? 'task',
                'account': userId,
              });
            }
          } catch (e) {
            ApiService.appendExternalConsoleLog(
              'TodosPage',
              'Chaoxing: error fetching todos for course $courseId: $e',
            );
          }
        }
      }

      if (!mounted) return;

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Chaoxing: found ${allTodos.length} todos',
      );

      setState(() {
        data.pendingTodos = allTodos;
        data.lastRefreshTime = DateTime.now();
        data.isLoading = false;
        data.requestLock = false;
      });

      await _persistTodos();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        data.isLoading = false;
        data.requestLock = false;
      });
    } finally {
      context?.dispose();
    }
  }

  Future<void> _loadRainClassroomTodos(String userId) async {
    final data = _platformData[PlatformType.rainClassroom]!;

    if (data.requestLock) {
      return;
    }

    setState(() {
      data.isLoading = true;
      data.requestLock = true;
    });

    PlatformRequestContext? context;
    try {
      context = await PlatformRequestContext.create(
        platform: PlatformType.rainClassroom,
        userId: userId,
      );

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'RainClassroom: requesting GET /api/v3/classroom/on-lesson-upcoming-exam',
      );
      final response = await context.sendRequest(
        '/api/v3/classroom/on-lesson-upcoming-exam',
      );

      if (!mounted) return;

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'RainClassroom: response status=${response.statusCode}',
      );

      // 打印完整响应体用于调试
      if (response.data != null) {
        ApiService.appendExternalConsoleLog(
          'TodosPage',
          'RainClassroom: full response body = ${response.data.toString()}',
        );
      }

      List<Map<String, dynamic>> todos = [];

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        final code = responseData['code'];
        final msg = responseData['msg']?.toString() ?? '';

        if (code == 50000 || msg.toUpperCase().contains('UNAUTHENTICATED')) {
          ApiService.appendExternalConsoleLog(
            'TodosPage',
            'RainClassroom: auth expired',
          );
        } else if (code == 0 && responseData['data'] != null) {
          final dataMap = responseData['data'] as Map<String, dynamic>;

          // 打印 data 字段的所有 key
          ApiService.appendExternalConsoleLog(
            'TodosPage',
            'RainClassroom: data keys = ${dataMap.keys.join(", ")}',
          );

          final upcomingExam = dataMap['upcomingExam'];

          if (upcomingExam is List) {
            ApiService.appendExternalConsoleLog(
              'TodosPage',
              'RainClassroom: upcomingExam list length = ${upcomingExam.length}',
            );

            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

            for (var exam in upcomingExam) {
              if (exam is Map) {
                final examId = exam['id']?.toString() ?? '';
                final title = exam['title']?.toString() ?? '未知考试';
                final classroomName = exam['classroom_name']?.toString() ?? '';
                final classroomId = exam['classroom_id']?.toString() ?? '';
                final startTime = exam['start_time'];
                final endTime = exam['end_time'];

                ApiService.appendExternalConsoleLog(
                  'TodosPage',
                  'RainClassroom: exam item - id=$examId, title=$title, start=$startTime, end=$endTime',
                );

                if (startTime != null && endTime != null) {
                  // end_time <= 0 表示老师没设截止时间，判定为进行中
                  final bool isInProgress;
                  if (endTime <= 0) {
                    isInProgress = startTime <= now;
                    ApiService.appendExternalConsoleLog(
                      'TodosPage',
                      'RainClassroom: exam "$title" end_time=$endTime (无截止时间), 判定为进行中',
                    );
                  } else {
                    isInProgress = startTime <= now && now <= endTime;
                    final status = isInProgress ? '进行中' : '已结束';
                    ApiService.appendExternalConsoleLog(
                      'TodosPage',
                      'RainClassroom: exam "$title" end_time=$endTime, 状态=$status',
                    );
                  }

                  if (isInProgress) {
                    todos.add({
                      'id': examId,
                      'title': title,
                      'type': 'exam',
                      'classroom_id': classroomId,
                      'classroom_name': classroomName,
                      'start_time': startTime,
                      'end_time': endTime,
                      'platform': '雨课堂',
                      'account': userId,
                    });
                  }
                }
              }
            }
          } else {
            ApiService.appendExternalConsoleLog(
              'TodosPage',
              'RainClassroom: upcomingExam is not a List, type = ${upcomingExam.runtimeType}',
            );
          }
        }
      }

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'RainClassroom: parsed ${todos.length} todos',
      );

      setState(() {
        data.pendingTodos = todos;
        data.lastRefreshTime = DateTime.now();
        data.isLoading = false;
        data.requestLock = false;
      });

      await _persistTodos();
    } catch (e) {
      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'RainClassroom: error = $e',
      );
      if (!mounted) return;
      setState(() {
        data.isLoading = false;
        data.requestLock = false;
      });
    } finally {
      context?.dispose();
    }
  }

  Future<void> _loadKetangpaiTodos(String userId) async {
    final data = _platformData[PlatformType.ketangpai]!;

    if (data.requestLock) {
      return;
    }

    setState(() {
      data.isLoading = true;
      data.requestLock = true;
    });

    PlatformRequestContext? context;
    try {
      context = await PlatformRequestContext.create(
        platform: PlatformType.ketangpai,
        userId: userId,
      );

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Ketangpai: requesting POST /Futurev2/Todo/getTodoList',
      );
      final response = await context.sendRequest(
        '/Futurev2/Todo/getTodoList',
        method: 'POST',
      );

      if (!mounted) return;

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Ketangpai: response status=${response.statusCode}',
      );

      final todos = <Map<String, dynamic>>[];
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        if (responseData['status'] == 1 && responseData['data'] is List) {
          todos.addAll(
            (responseData['data'] as List).cast<Map<String, dynamic>>(),
          );
        } else if (responseData['data'] is List) {
          todos.addAll(
            (responseData['data'] as List).cast<Map<String, dynamic>>(),
          );
        }
      }

      ApiService.appendExternalConsoleLog(
        'TodosPage',
        'Ketangpai: loaded ${todos.length} todos',
      );

      setState(() {
        data.pendingTodos = todos;
        data.lastRefreshTime = DateTime.now();
        data.isLoading = false;
        data.requestLock = false;
      });

      await _persistTodos();
    } catch (e) {
      ApiService.appendExternalConsoleLog('TodosPage', 'Ketangpai: error = $e');
      if (!mounted) return;
      setState(() {
        data.isLoading = false;
        data.requestLock = false;
      });
    } finally {
      context?.dispose();
    }
  }

  bool _hasPlatformAccount(PlatformType platform) {
    final loginStates = _getPlatformLoginStates();
    return loginStates[platform] ?? false;
  }

  int _getTotalTodos() {
    return _platformData.values.fold(
      0,
      (sum, data) => sum + data.pendingTodos.length,
    );
  }

  int _getCompletedTodos() {
    return _platformData.values.fold(
      0,
      (sum, data) => sum + data.completedTodos.length,
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupTodosByDate() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final entry in _platformData.entries) {
      final platform = entry.key;
      final data = entry.value;

      for (final todo in data.pendingTodos) {
        final deadline = _extractDeadlineFromTodo(todo, platform);
        if (deadline == null) continue;

        final deadlineDate = DateTime(
          deadline.year,
          deadline.month,
          deadline.day,
        );
        final diffDays = deadlineDate.difference(today).inDays;

        if (diffDays < 0 || diffDays > 6) continue;

        final dateKey = DateFormat('yyyy-MM-dd').format(deadlineDate);
        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add({...todo, '_platform': platform});
      }
    }

    return grouped;
  }

  DateTime? _extractDeadlineFromTodo(
    Map<String, dynamic> todo,
    PlatformType platform,
  ) {
    if (platform == PlatformType.tronclass) {
      final endTimeStr = todo['end_time']?.toString() ?? '';
      if (endTimeStr.isNotEmpty) {
        try {
          return DateTime.parse(endTimeStr);
        } catch (_) {}
      }
    } else if (platform == PlatformType.rainClassroom) {
      final endTime = todo['end_time'];
      if (endTime != null) {
        try {
          return DateTime.fromMillisecondsSinceEpoch(endTime * 1000);
        } catch (_) {}
      }
    } else if (platform == PlatformType.ketangpai) {
      final endTimeStr = todo['endtime']?.toString() ?? '';
      if (endTimeStr.isNotEmpty && endTimeStr != '0') {
        try {
          final timestamp = int.tryParse(endTimeStr);
          if (timestamp != null) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        } catch (_) {}
      }
    } else if (platform == PlatformType.chaoxing) {
      final endTimeStr = todo['end_time']?.toString() ?? '';
      if (endTimeStr.isNotEmpty) {
        try {
          return DateTime.parse(endTimeStr);
        } catch (_) {}
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _getFilteredTodos(PlatformType platform) {
    final data = _platformData[platform]!;
    List<Map<String, dynamic>> todos;

    if (_selectedDateFilter == null) {
      todos = List.from(data.pendingTodos);
    } else {
      todos = data.pendingTodos.where((todo) {
        final deadline = _extractDeadlineFromTodo(todo, platform);
        if (deadline == null) return false;
        final dateKey = DateFormat('yyyy-MM-dd').format(deadline);
        return dateKey == _selectedDateFilter;
      }).toList();
    }

    // 按剩余时间升序排序（越紧急越靠前）
    final now = DateTime.now();
    todos.sort((a, b) {
      final deadlineA = _extractDeadlineFromTodo(a, platform);
      final deadlineB = _extractDeadlineFromTodo(b, platform);

      // 无截止时间的排在最后
      if (deadlineA == null && deadlineB == null) return 0;
      if (deadlineA == null) return 1;
      if (deadlineB == null) return -1;

      final remainingA = deadlineA.difference(now).inSeconds;
      final remainingB = deadlineB.difference(now).inSeconds;

      // 已过期的排在最后，其他按截止时间升序
      final isExpiredA = remainingA < 0;
      final isExpiredB = remainingB < 0;

      if (isExpiredA && !isExpiredB) return 1;
      if (!isExpiredA && isExpiredB) return -1;

      // 都已过期或都未过期，按截止时间升序
      return deadlineA.compareTo(deadlineB);
    });

    return todos;
  }

  @override
  Widget build(BuildContext context) {
    final totalTodos = _getTotalTodos();
    final completedTodos = _getCompletedTodos();
    final palette = resolveGlobalPalette(
      AppSettings.globalColorSchemeNotifier.value,
    );
    final groupedByDate = _groupTodosByDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办事项'),
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshAllPlatformAccounts,
            tooltip: '刷新全部',
          ),
          if (_selectedDateFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _selectedDateFilter = null;
                });
              },
              tooltip: '清除筛选',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _buildCompactStatBadge(
                  context,
                  '待完成',
                  totalTodos,
                  Icons.pending_actions_outlined,
                  palette.primary,
                ),
                SizedBox(width: AppSpacing.md),
                _buildCompactStatBadge(
                  context,
                  '已完成',
                  completedTodos,
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在加载待办事项...'),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildTimelineSection(context, groupedByDate, palette),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      _buildPlatformSection(
                        platform: PlatformType.chaoxing,
                        title: '学习通',
                        icon: Icons.school,
                        color: const Color(0xFFFF6B35),
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildPlatformSection(
                        platform: PlatformType.tronclass,
                        title: '畅课',
                        icon: Icons.class_,
                        color: const Color(0xFF1DB6C2),
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildPlatformSection(
                        platform: PlatformType.rainClassroom,
                        title: '雨课堂',
                        icon: Icons.cloud,
                        color: const Color(0xFF4A90E2),
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildPlatformSection(
                        platform: PlatformType.ketangpai,
                        title: '课堂派',
                        icon: Icons.groups,
                        color: const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatRefreshTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }

  Widget _buildCompactStatBadge(
    BuildContext context,
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> groupedByDate,
    dynamic palette,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(7, (index) => today.add(Duration(days: index)));

    return Container(
      margin: EdgeInsets.all(AppSpacing.lg),
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 20, color: palette.primary),
              SizedBox(width: AppSpacing.sm),
              Text(
                '未来7天',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_selectedDateFilter != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Text(
                    '已筛选',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final dateKey = DateFormat('yyyy-MM-dd').format(date);
                final todosForDate = groupedByDate[dateKey] ?? [];
                final isSelected = _selectedDateFilter == dateKey;
                final isToday = index == 0;

                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.md),
                  child: _buildTimelineNode(
                    context,
                    date,
                    todosForDate.length,
                    isSelected,
                    isToday,
                    palette,
                    () {
                      setState(() {
                        _selectedDateFilter = isSelected ? null : dateKey;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(
    BuildContext context,
    DateTime date,
    int count,
    bool isSelected,
    bool isToday,
    dynamic palette,
    VoidCallback onTap,
  ) {
    final hasDeadline = count > 0;
    final bgColor = isSelected
        ? palette.primary
        : hasDeadline
        ? palette.primary.withValues(alpha: 0.1)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isSelected
        ? Colors.white
        : hasDeadline
        ? palette.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: hasDeadline ? onTap : null,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 70,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: isSelected
                ? palette.primary
                : hasDeadline
                ? palette.primary.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('EEE', 'zh_CN').format(date),
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppSpacing.xs / 2),
            Text(
              DateFormat('d').format(date),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (isToday) ...[
              SizedBox(height: AppSpacing.xs / 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : palette.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  '今天',
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white : palette.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else if (hasDeadline) ...[
              SizedBox(height: AppSpacing.xs / 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : palette.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : palette.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatRemaining(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);

    if (diff.isNegative) {
      final absDiff = diff.abs();
      final hours = absDiff.inHours;
      final minutes = absDiff.inMinutes % 60;
      return '已截止 $hours时 $minutes分';
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    if (days > 0) {
      return '剩余 $days天 $hours时 $minutes分';
    } else if (hours > 0) {
      return '剩余 $hours时 $minutes分';
    } else {
      return '剩余 $minutes分';
    }
  }

  Widget _buildPlatformSection({
    required PlatformType platform,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final data = _platformData[platform]!;
    final allTodos = data.pendingTodos;
    final filteredTodos = _getFilteredTodos(platform);
    final loading = data.isLoading;
    final expanded = _platformExpanded[platform] ?? false;
    final hasAccount = _hasPlatformAccount(platform);
    final lastRefresh = data.lastRefreshTime;

    final displayTodos = filteredTodos;
    final isFiltered = _selectedDateFilter != null;

    return AppAnimations.fadeSlideIn(
      child: Card(
        elevation: AppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                hasAccount
                    ? loading
                          ? '加载中...'
                          : lastRefresh == null
                          ? '点击刷新按钮加载待办'
                          : isFiltered
                          ? displayTodos.isEmpty
                                ? '筛选日期无待办'
                                : '${displayTodos.length} 个待办（已筛选）'
                          : allTodos.isEmpty
                          ? '暂无待办 · 上次刷新: ${_formatRefreshTime(lastRefresh)}'
                          : '${allTodos.length} 个待办 · 上次刷新: ${_formatRefreshTime(lastRefresh)}'
                    : '未登录账号',
                style: TextStyle(
                  color: hasAccount
                      ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasAccount)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: loading
                          ? null
                          : () => _refreshSinglePlatform(platform),
                      tooltip: '刷新此平台',
                    ),
                  if (hasAccount)
                    Icon(expanded ? Icons.expand_less : Icons.expand_more)
                  else
                    const Icon(Icons.lock_outline, color: Colors.grey),
                ],
              ),
              onTap: hasAccount
                  ? () {
                      setState(() {
                        _platformExpanded[platform] = !expanded;
                      });
                    }
                  : null,
            ),
            if (expanded && hasAccount) ...[
              const Divider(height: 1),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (displayTodos.isEmpty && lastRefresh == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.refresh, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        '点击右侧刷新按钮加载待办',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else if (displayTodos.isEmpty && isFiltered)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.filter_alt_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '筛选日期无待办',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else if (displayTodos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.task_alt, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('暂无待办事项', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              else
                ...displayTodos.map(
                  (todo) => _buildTodoItem(todo, platform, color),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodoItem(
    Map<String, dynamic> todo,
    PlatformType platform,
    Color color,
  ) {
    if (platform == PlatformType.tronclass) {
      return _buildTronclassTodoItem(todo);
    }
    if (platform == PlatformType.rainClassroom) {
      return _buildRainClassroomTodoItem(todo);
    }
    if (platform == PlatformType.ketangpai) {
      return _buildKetangpaiTodoItem(todo);
    }

    final title = todo['title']?.toString() ?? '未知任务';
    final type = todo['type']?.toString() ?? '';

    return ListTile(
      leading: Icon(_getTypeIcon(type), color: color),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }

  Widget _buildTronclassTodoItem(Map<String, dynamic> todo) {
    final type = todo['type']?.toString() ?? '';
    final title = todo['title']?.toString() ?? '未知任务';
    final courseName = todo['course_name']?.toString() ?? '';
    final endTimeStr = todo['end_time']?.toString() ?? '';
    final isLocked = todo['is_locked'] == true;

    DateTime? endTime;
    if (endTimeStr.isNotEmpty) {
      try {
        endTime = DateTime.parse(endTimeStr);
      } catch (_) {}
    }

    final now = DateTime.now();
    final isOverdue = endTime != null && endTime.isBefore(now);
    final isUrgent = endTime != null && endTime.difference(now).inHours < 24;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs / 2,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(_getTypeIcon(type), color: const Color(0xFF1DB6C2)),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courseName,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (endTime != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 12,
                    color: isOverdue
                        ? Theme.of(context).colorScheme.error
                        : isUrgent
                        ? Colors.orange
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    DateFormat('MM-dd HH:mm').format(endTime.toLocal()),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? Theme.of(context).colorScheme.error
                          : isUrgent
                          ? Colors.orange
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (isOverdue) ...[
                    SizedBox(width: AppSpacing.xs),
                    AppBadge(
                      label: '逾期',
                      type: AppBadgeType.error,
                      isSmall: true,
                    ),
                  ] else if (isUrgent) ...[
                    SizedBox(width: AppSpacing.xs),
                    AppBadge(
                      label: '紧急',
                      type: AppBadgeType.warning,
                      isSmall: true,
                    ),
                  ],
                ],
              ),
              SizedBox(height: AppSpacing.xs / 2),
              Text(
                _formatRemaining(endTime.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOverdue
                      ? Theme.of(context).colorScheme.error
                      : isUrgent
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        trailing: isLocked
            ? Icon(
                Icons.lock_outline,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              )
            : Icon(
                Icons.chevron_right,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
        onTap: isLocked
            ? null
            : () {
                // 检查当前平台是否为畅课
                if (PlatformManager().currentPlatform != PlatformType.tronclass) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('提示'),
                      content: const Text('请先在账号页切换到畅课平台，再打开畅课待办'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TronclassTodoDetailPage(todo: todo),
                  ),
                );
              },
      ),
    );
  }

  Widget _buildRainClassroomTodoItem(Map<String, dynamic> todo) {
    final title = todo['title']?.toString() ?? '未知考试';
    final classroomName = todo['classroom_name']?.toString() ?? '';
    final endTime = todo['end_time'];

    DateTime? endDateTime;
    bool isOverdue = false;
    bool isUrgent = false;

    // end_time <= 0 表示老师没设截止时间，判定为进行中（未过期）
    if (endTime != null && endTime > 0) {
      try {
        endDateTime = DateTime.fromMillisecondsSinceEpoch(endTime * 1000);
        final now = DateTime.now();
        isOverdue = endDateTime.isBefore(now);
        isUrgent = !isOverdue && endDateTime.difference(now).inHours < 24;

        debugPrint('[TodosPage] 雨课堂考试 "$title" end_time=$endTime 状态=${isOverdue ? "已过期" : "进行中"}');
      } catch (_) {}
    } else {
      debugPrint('[TodosPage] 雨课堂考试 "$title" end_time=$endTime (无截止时间)，判定为进行中');
    }

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs / 2,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.quiz_outlined, color: Color(0xFF4A90E2)),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (classroomName.isNotEmpty)
              Text(
                classroomName,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            if (endDateTime != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 12,
                    color: isOverdue
                        ? Theme.of(context).colorScheme.error
                        : isUrgent
                        ? Colors.orange
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    DateFormat('MM-dd HH:mm').format(endDateTime.toLocal()),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? Theme.of(context).colorScheme.error
                          : isUrgent
                          ? Colors.orange
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (isOverdue) ...[
                    SizedBox(width: AppSpacing.xs),
                    AppBadge(
                      label: '逾期',
                      type: AppBadgeType.error,
                      isSmall: true,
                    ),
                  ] else if (isUrgent) ...[
                    SizedBox(width: AppSpacing.xs),
                    AppBadge(
                      label: '紧急',
                      type: AppBadgeType.warning,
                      isSmall: true,
                    ),
                  ],
                ],
              ),
              SizedBox(height: AppSpacing.xs / 2),
              Text(
                _formatRemaining(endDateTime.toLocal()),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOverdue
                      ? Theme.of(context).colorScheme.error
                      : isUrgent
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onTap: () async {
          final examId = todo['id']?.toString() ?? '';
          final classroomId = todo['classroom_id']?.toString() ?? '';

          if (examId.isEmpty || classroomId.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('考试信息不完整')));
            return;
          }

          try {
            final userAgent = await UserAgentHelper.getRainClassroomUA();
            final headers = UserAgentHelper.getRainClassroomHeaders(userAgent);

            final tokenResponse = await ApiService.sendRequest(
              '/v/exam/gen_token',
              method: 'POST',
              headers: headers,
              body: {'exam_id': examId, 'classroom_id': classroomId},
            );

            if (tokenResponse.data == null ||
                tokenResponse.data['status'] != 200) {
              throw Exception('生成考试token失败');
            }

            final tokenData = tokenResponse.data['data'];
            if (tokenData == null) {
              throw Exception('考试token数据为空');
            }

            final token = tokenData['token'];
            final examHost =
                tokenData['exam_host'] ?? 'https://examination.xuetangx.com';
            final userId = tokenData['user_id']?.toString() ?? '';

            final nextUrl = Uri.encodeComponent(
              '$examHost/exam/$examId?isFrom=2&platform=mobile',
            );
            final examUrl =
                '$examHost/login?exam_id=$examId&user_id=$userId&crypt=${Uri.encodeComponent(token)}&next=$nextUrl&language=zh&platform=mobile';

            final uri = Uri.parse(examUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              throw Exception('无法打开考试链接');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('打开考试失败: $e')));
            }
          }
        },
      ),
    );
  }

  Widget _buildKetangpaiTodoItem(Map<String, dynamic> todo) {
    final contentType = todo['contenttype'] ?? 0;
    final title = todo['title']?.toString() ?? '未知任务';
    final courseName = todo['course_name']?.toString() ?? '';
    final endTimeStr = todo['endtime']?.toString() ?? '';

    String typeLabel;
    IconData typeIcon;
    switch (contentType) {
      case 4:
        typeLabel = '作业';
        typeIcon = Icons.assignment_outlined;
        break;
      case 5:
        typeLabel = '话题';
        typeIcon = Icons.forum_outlined;
        break;
      case 6:
        typeLabel = '测试';
        typeIcon = Icons.quiz_outlined;
        break;
      default:
        typeLabel = '任务';
        typeIcon = Icons.task_outlined;
    }

    DateTime? endTime;
    if (endTimeStr.isNotEmpty && endTimeStr != '0') {
      try {
        final timestamp = int.tryParse(endTimeStr);
        if (timestamp != null) {
          endTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    final isOverdue = endTime != null && endTime.isBefore(now);
    final isUrgent = endTime != null && endTime.difference(now).inHours < 24;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs / 2,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(typeIcon, color: const Color(0xFF9C27B0)),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppBadge(
                  label: typeLabel,
                  type: AppBadgeType.neutral,
                  isSmall: true,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    courseName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (endTime != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 12,
                    color: isOverdue
                        ? Theme.of(context).colorScheme.error
                        : isUrgent
                        ? Colors.orange
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(endTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue
                          ? Theme.of(context).colorScheme.error
                          : isUrgent
                          ? Colors.orange
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (isOverdue) ...[
                    SizedBox(width: AppSpacing.xs),
                    AppBadge(
                      label: '已逾期',
                      type: AppBadgeType.error,
                      isSmall: true,
                    ),
                  ] else if (isUrgent) ...[
                    SizedBox(width: AppSpacing.xs),
                    AppBadge(
                      label: '即将截止',
                      type: AppBadgeType.warning,
                      isSmall: true,
                    ),
                  ],
                ],
              ),
              SizedBox(height: AppSpacing.xs / 2),
              Text(
                _formatRemaining(endTime),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOverdue
                      ? Theme.of(context).colorScheme.error
                      : isUrgent
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('课堂派详情页功能开发中')));
        },
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'homework':
        return Icons.assignment;
      case 'exam':
        return Icons.quiz;
      case 'questionnaire':
        return Icons.poll;
      default:
        return Icons.task;
    }
  }
}
