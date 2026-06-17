import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';

import '../core/async/app_async_view.dart';
import '../features/courses/chaoxing/chaoxing_course_detail_controller.dart';
import '../platform.dart';
import '../api/course.dart';
import '../api/api_service.dart';
import '../api/kt_sign.dart';
import '../session/account.dart';
import '../session/account_events.dart';
import '../session/app_settings.dart';
import '../session/sign_record_store.dart';
import '../models/course.dart';
import '../models/active.dart';
import '../services/platform_network_warmup_service.dart';
import '../services/platform_page_snapshot_store.dart';
import '../services/sign_network_gate.dart';
import '../services/sign_platform_context.dart';
import '../services/sign_run_console.dart';
import '../materials/material_search_context.dart';
import '../utils/global_palette.dart';
import '../utils/rainclassroom_scan_parser.dart';
import '../utils/tronclass_qr_parser.dart';
import '../theme/design_tokens.dart';
import '../theme/animations.dart';
import '../theme/components/app_badge.dart';
import '../theme/components/dashboard_components.dart';
import '../smart/smart_models.dart';
import '../widgets/context_help.dart';
import '../widgets/material_context_search.dart';
import '../widgets/platform_sign_log_card.dart';
import '../widgets/sign_run_console_panel.dart';
import '../widgets/smart_inline_panel.dart';
import 'widget/scan.dart';
import 'widget/avatar.dart';
import 'widget/ketangpai_course_showcase.dart';
import 'widget/ketangpai_course_tokens.dart';
import 'actives/sign_in/sign_in.dart';
import 'actives/topic_discuss.dart';
import 'actives/quiz.dart';
import 'actives/evaluate.dart';
import 'actives/vote.dart';
import 'actives/questionnaire.dart';
import 'chaoxing_course_detail_page.dart';
import 'rainclassroom_course_detail.dart';
import 'tronclass_dashboard_page.dart';
import 'tronclass_qr_sign_page.dart';
import 'ketangpai_course_struct.dart';
import 'ketangpai_profile_page.dart';
import 'ketangpai_shared_room_page.dart';
import 'ketangpai_private_sign_page.dart';
import 'ketangpai_room_list_page.dart';
import 'ketangpai_suggestions_page.dart';

class CourseContentPage extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String classId;
  final String cpi;

  const CourseContentPage({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.classId,
    required this.cpi,
  });

  @override
  State<CourseContentPage> createState() => _CourseContentPageState();
}

class _CourseContentPageState extends State<CourseContentPage> {
  late final ChaoxingCourseActivitiesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChaoxingCourseActivitiesController(
      courseId: widget.courseId,
      classId: widget.classId,
      cpi: widget.cpi,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openActive(Active active) {
    if (!active.status) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该活动已结束')));
      return;
    }

    switch (active.activeType) {
      case ActiveType.signIn:
      case ActiveType.signOut:
      case ActiveType.scheduledSignIn:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SignInPage(
              active: active,
              courseId: widget.courseId,
              classId: widget.classId,
              cpi: widget.cpi,
            ),
          ),
        );
        return;
      case ActiveType.topicDiscuss:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TopicDiscussPage(active: active),
          ),
        );
        return;
      case ActiveType.quiz:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizPage(
              active: active,
              courseId: widget.courseId,
              classId: widget.classId,
            ),
          ),
        );
        return;
      case ActiveType.evaluation:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EvaluatePage(
              active: active,
              courseId: widget.courseId,
              classId: widget.classId,
            ),
          ),
        );
        return;
      case ActiveType.vote:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VotePage(
              active: active,
              courseId: widget.courseId,
              classId: widget.classId,
            ),
          ),
        );
        return;
      case ActiveType.questionnaire:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuestionnairePage(
              active: active,
              courseId: widget.courseId,
              classId: widget.classId,
            ),
          ),
        );
        return;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该活动类型暂不支持')));
    }
  }

  Widget _buildActiveCard(Active active) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            active.getIcon(),
            color: active.status
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            size: 35,
          ),
        ),
        title: Text(
          active.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          active.description,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openActive(active),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return AppAsyncView<List<Active>>(
            state: _controller.state,
            emptyTitle: '暂无内容',
            errorTitle: '获取内容列表失败',
            onRetry: _controller.load,
            onRefresh: _controller.refresh,
            dataBuilder: (context, activities, isRefreshing) {
              return Stack(
                children: [
                  ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) =>
                        _buildActiveCard(activities[index]),
                  ),
                  if (isRefreshing)
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: LinearProgressIndicator(),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

final GlobalKey coursesPageKey = GlobalKey();

enum _RainClassroomScanRouteChoice { auto, lessonPage, miniProgram, dynamicQr }

class _RainClassroomScanExecution {
  const _RainClassroomScanExecution({
    required this.kind,
    required this.url,
    this.lessonId,
  });

  final RainClassroomScanKind kind;
  final String url;
  final String? lessonId;
}

class _CoursesPageState extends State<CoursesPage> with WidgetsBindingObserver {
  List<Course> _courses = [];
  List<Course> _onlineCourses = [];
  List<Course> _offlineCourses = [];
  bool _isLoading = true;
  bool _showOnlineOnly = true;
  String? _emptyHint;
  Map<String, dynamic>? _rainCourseDebugSummary;
  StreamSubscription? _accountChangeSubscription;
  StreamSubscription? _platformChangeSubscription;
  Timer? _refreshTimer;
  bool _isLoadingCourses = false;
  bool _isShowingCachedCourses = false;
  bool _isRefreshingCoursesInBackground = false;
  Color _globalPrimary = const Color(0xFF1F9EA8);
  Color _globalSecondary = const Color(0xFF157B88);
  DateTime? _lastRefreshAt;
  String? _lastRefreshMessage;
  DateTime? _snapshotUpdatedAt;
  bool _snapshotRefreshFailed = false;
  String? _pendingAccountReloadUserId;
  bool _runningPendingAccountReload = false;

  final Map<PlatformType, List<Course>> _coursesCache = {};
  final Map<PlatformType, List<Course>> _onlineCoursesCache = {};
  final Map<PlatformType, List<Course>> _offlineCoursesCache = {};
  final Map<PlatformType, DateTime> _cacheTimestamps = {};
  final PlatformPageSnapshotStore _snapshotStore = PlatformPageSnapshotStore();
  final SignRunConsoleController _scanConsoleController =
      SignRunConsoleController();
  _RainClassroomScanExecution? _pendingRainScanExecution;

  Future<void> refreshCourses() {
    return _refreshCourses();
  }

  Future<void> _switchPlatform(PlatformType platform) async {
    if (PlatformManager().currentPlatform == platform) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前已经在该平台')));
      return;
    }

    // 用户主动切换平台，保持平台状态和课程数据同步。
    await PlatformManager().setPlatform(platform, userInitiated: true);
    if (!mounted) return;

    final platformName = switch (platform) {
      PlatformType.chaoxing => '学习通',
      PlatformType.rainClassroom => '雨课堂',
      PlatformType.tronclass => '畅课',
      PlatformType.ketangpai => '课堂派',
      PlatformType.weizhuojiao => '微助教',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已切换到$platformName')));
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Future<void> _refreshCourses({bool showFeedback = false}) async {
    await _loadCourses(forceNetwork: true);
    if (mounted) {
      _lastRefreshAt = DateTime.now();
      _lastRefreshMessage = _courses.isEmpty
          ? '未获取到课程数据'
          : '已加载 ${_courses.length} 门课程';
      setState(() {});
    }
    if (!mounted || !showFeedback) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('课程已刷新：${_formatClock(DateTime.now())}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ignore: unused_element
  Widget _buildRefreshStatusBar(BuildContext context) {
    final lastRefreshText = _lastRefreshAt == null
        ? '尚未手动刷新'
        : '最近刷新：${_formatClock(_lastRefreshAt!)}';
    final statusText = _lastRefreshMessage ?? '等待刷新课程数据，可下拉或点击刷新按钮。';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSpacing.lg - 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _globalPrimary.withValues(alpha: 0.95),
              _globalSecondary.withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.large + 2),
          boxShadow: [
            BoxShadow(
              color: _globalPrimary.withValues(alpha: 0.16),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: const Icon(Icons.sync_rounded, color: Colors.white),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    lastRefreshText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_courses.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '门课程',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseListBody({required bool isTronclass}) {
    if (PlatformManager().isKetangpai) {
      return _buildKetangpaiCourseListBody();
    }

    return RefreshIndicator(
      onRefresh: _refreshCourses,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _buildPlatformDashboardHeader(),
          const SizedBox(height: AppSpacing.md),
          const SmartInlinePanel(
            title: '课程智能建议',
            types: {
              SmartInsightType.accountNetwork,
              SmartInsightType.today,
              SmartInsightType.todoRisk,
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          const ContextHelpHint(
            title: '课程页帮助',
            tips: [
              '课程为空时先确认当前平台和账号，再刷新课程。',
              '扫码、签到和课程活动会继续走原平台链路，不会被智能建议自动提交。',
              '看到缓存提示时可以先查看旧课程，后台刷新成功后会更新。',
              '平台请求失败时到设置里的诊断区查看健康检查和请求日志。',
            ],
          ),
          if (_courses.isNotEmpty)
            MaterialRelatedPanel(
              title: '课程相关资料',
              contextData: MaterialSearchContext.course(
                courseName: _courses.first.name,
                teacher: _courses.first.teacher,
                limit: 3,
              ),
              maxItems: 3,
            ),
          if (_isShowingCachedCourses || _isRefreshingCoursesInBackground)
            _buildCourseRefreshStatusBanner(),
          const SizedBox(height: AppSpacing.md),
          _buildCourseStatsGrid(),
          const SizedBox(height: AppSpacing.md),
          _buildCourseQuickActions(),
          if (!PlatformManager().isTronclass &&
              !PlatformManager().isWeizhuojiao)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: PlatformSignLogCard(
                platform: _currentSignLogPlatformLabel(),
                platformType: PlatformManager().currentPlatform,
                title: '${_currentSignLogPlatformLabel()}签到日志',
                subtitle: '查看本平台账号签到结果和失败原因',
              ),
            ),
          if (PlatformManager().isRainClassroom ||
              PlatformManager().isKetangpai)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SignRunConsolePanel(controller: _scanConsoleController),
            ),
          if (PlatformManager().isRainClassroom) _buildRainClassroomToggle(),
          if (PlatformManager().isRainClassroom) _buildRainCourseDebugPanel(),
          if (PlatformManager().isKetangpai) _buildKetangpaiFunctionCards(),
          if (_courses.isEmpty)
            _buildPlatformEmptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _courses.length,
              itemBuilder: (context, index) =>
                  _buildPlatformCourseCard(_courses[index]),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCourseRefreshStatusBanner() {
    final isStale =
        _snapshotUpdatedAt != null &&
        DateTime.now().difference(_snapshotUpdatedAt!) >
            const Duration(minutes: 30);
    final message = _snapshotRefreshFailed
        ? '显示缓存课程，后台刷新失败'
        : _isRefreshingCoursesInBackground
        ? (isStale ? '显示较旧缓存课程，后台刷新中' : '显示缓存课程，后台刷新中')
        : (isStale ? '当前显示较旧缓存课程' : '当前显示缓存课程');
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Semantics(
        label: message,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            children: [
              Icon(
                _isRefreshingCoursesInBackground
                    ? Icons.sync_rounded
                    : Icons.offline_pin_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _currentSignLogPlatformLabel() {
    if (PlatformManager().isChaoxing) return '学习通';
    if (PlatformManager().isRainClassroom) return '雨课堂';
    if (PlatformManager().isKetangpai) return '课堂派';
    if (PlatformManager().isTronclass) return '畅课';
    if (PlatformManager().isWeizhuojiao) return '微助教';
    return '全部';
  }

  Widget _buildPlatformDashboardHeader() {
    final currentPlatform = PlatformManager().currentPlatform;
    final title = switch (currentPlatform) {
      PlatformType.chaoxing => '学习通课程工作台',
      PlatformType.rainClassroom => '雨课堂课程工作台',
      PlatformType.tronclass => 'TronClass',
      PlatformType.ketangpai => '课堂派课程工作台',
      PlatformType.weizhuojiao => '微助教课程工作台',
    };
    final subtitle = switch (currentPlatform) {
      PlatformType.chaoxing => '同步课程、查看活动，并从扫码入口处理签到流程。',
      PlatformType.rainClassroom => '管理在线课堂和离线课程，按需同步课程列表。',
      PlatformType.tronclass => '课程、待办和签到入口集中管理。',
      PlatformType.ketangpai => '课程资料、共享房间和签到工具集中在工作台。',
      PlatformType.weizhuojiao => '入口正在完善中。',
    };
    final icon = switch (currentPlatform) {
      PlatformType.chaoxing => Icons.local_fire_department_outlined,
      PlatformType.rainClassroom => Icons.water_drop_outlined,
      PlatformType.tronclass => Icons.dashboard_customize_outlined,
      PlatformType.ketangpai => Icons.widgets_outlined,
      PlatformType.weizhuojiao => Icons.construction_outlined,
    };
    final refreshText = _lastRefreshAt == null
        ? '尚未手动刷新'
        : '最近刷新：${_formatClock(_lastRefreshAt!)}';

    return DashboardHeader(
      eyebrow: 'COURSE WORKSPACE',
      title: title,
      subtitle: subtitle,
      icon: icon,
      primary: _globalPrimary,
      secondary: _globalSecondary,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: '扫码',
            onPressed: _openScanPage,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton.filledTonal(
            tooltip: '刷新课程',
            onPressed: _isLoading
                ? null
                : () => _refreshCourses(showFeedback: true),
            icon: const Icon(Icons.refresh_rounded),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildHeaderPill(Icons.schedule_rounded, refreshText),
            _buildHeaderPill(
              Icons.layers_outlined,
              _courses.isEmpty ? '等待课程数据' : '已加载 ${_courses.length} 门课',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 15),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        final tiles = [
          DashboardStatTile(
            label: '全部课程',
            value: '${_courses.length}',
            icon: Icons.menu_book_outlined,
            color: _globalPrimary,
          ),
          DashboardStatTile(
            label: '在线课程',
            value: '${_onlineCourses.length}',
            icon: Icons.online_prediction_rounded,
            color: const Color(0xFF0EA5E9),
          ),
          DashboardStatTile(
            label: '离线课程',
            value: '${_offlineCourses.length}',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFFF97316),
          ),
        ];

        if (isWide) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: tiles[1]),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            tiles[2],
          ],
        );
      },
    );
  }

  Widget _buildCourseQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = [
          DashboardActionCard(
            title: '同步课程',
            subtitle: _lastRefreshMessage ?? '刷新课程列表并更新当前平台数据。',
            icon: Icons.cloud_sync_outlined,
            color: _globalPrimary,
            onTap: _isLoading
                ? null
                : () => _refreshCourses(showFeedback: true),
          ),
          DashboardActionCard(
            title: '扫码签到',
            subtitle: '扫描二维码并进入当前平台的签到流程。',
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0xFFF97316),
            onTap: _openScanPage,
          ),
          DashboardActionCard(
            title: '账号管理',
            subtitle: '查看和切换账号，保持登录状态可用。',
            icon: Icons.manage_accounts_outlined,
            color: const Color(0xFF6366F1),
            onTap: _openAccountsPage,
          ),
        ];

        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: actions[i]),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              actions[i],
            ],
          ],
        );
      },
    );
  }

  Widget _buildKetangpaiCourseListBody() {
    return KetangpaiShowcaseBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshCourses,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  KetangpaiCourseTokens.pageInset,
                  18,
                  KetangpaiCourseTokens.pageInset,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildKetangpaiWorkspaceHero(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  KetangpaiCourseTokens.pageInset,
                  12,
                  KetangpaiCourseTokens.pageInset,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildKetangpaiSummaryStrip(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  KetangpaiCourseTokens.pageInset,
                  KetangpaiCourseTokens.sectionGap,
                  KetangpaiCourseTokens.pageInset,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildKetangpaiFunctionCards(),
                ),
              ),
              if (_courses.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KetangpaiCourseTokens.pageInset,
                      KetangpaiCourseTokens.sectionGap,
                      KetangpaiCourseTokens.pageInset,
                      24,
                    ),
                    child: _buildKetangpaiEmptyState(),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KetangpaiCourseTokens.pageInset,
                    KetangpaiCourseTokens.sectionGap,
                    KetangpaiCourseTokens.pageInset,
                    12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildKetangpaiSectionHeader(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KetangpaiCourseTokens.pageInset,
                    0,
                    KetangpaiCourseTokens.pageInset,
                    28,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _courses.length - 1 ? 0 : 14,
                        ),
                        child: _buildKetangpaiCoursePanel(_courses[index]),
                      );
                    }, childCount: _courses.length),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKetangpaiWorkspaceHero() {
    final refreshText = _lastRefreshAt == null
        ? '尚未手动刷新'
        : '最近刷新：${_formatClock(_lastRefreshAt!)}';
    final statusText = _courses.isEmpty ? '暂无课程' : '已加载';

    return KetangpaiHeroPanel(
      eyebrow: 'KETANGPAI COURSE WORKSPACE',
      title: '课堂派课程工作台',
      subtitle: '保留原有同步、扫码和跳转流程，集中展示课程、共享房间和签到工具。',
      trailing: Wrap(
        spacing: 8,
        children: [
          KetangpaiGhostIconButton(
            icon: Icons.qr_code_scanner_rounded,
            onTap: _openScanPage,
            tooltip: '扫码',
          ),
          KetangpaiGhostIconButton(
            icon: Icons.refresh_rounded,
            onTap: () => _refreshCourses(showFeedback: true),
            tooltip: '刷新课程',
          ),
        ],
      ),
      badges: [
        _buildKetangpaiHeroTag('Editorial Dashboard'),
        _buildKetangpaiHeroTag('Course Flow'),
        _buildKetangpaiHeroTag('Quick Tools'),
      ],
      stats: [
        KetangpaiStatBadge(
          label: 'COURSES',
          value: '${_courses.length}',
          icon: Icons.menu_book_outlined,
          highlight: true,
        ),
        KetangpaiStatBadge(
          label: 'STATUS',
          value: statusText,
          icon: Icons.wifi_tethering_rounded,
        ),
        KetangpaiStatBadge(
          label: 'UPDATED',
          value: refreshText,
          icon: Icons.schedule_rounded,
        ),
      ],
      primaryAction: KetangpaiActionButton(
        label: '立即刷新',
        icon: Icons.sync_rounded,
        onTap: () => _refreshCourses(showFeedback: true),
      ),
      secondaryAction: KetangpaiActionButton(
        label: '账号管理',
        icon: Icons.manage_accounts_outlined,
        filled: false,
        onTap: _openAccountsPage,
      ),
    );
  }

  Widget _buildKetangpaiHeroTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildKetangpaiSectionHeader() {
    final palette = KetangpaiCoursePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '课程数据为空',
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '保留课堂派课程同步逻辑，可通过刷新重新拉取课程、共享房间和签到入口。',
          style: TextStyle(
            color: palette.textMuted,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildKetangpaiSummaryStrip() {
    final palette = KetangpaiCoursePalette.of(context);
    final summaryItems = <({String label, String value, IconData icon})>[
      (label: '课程数据', value: '${_courses.length}', icon: Icons.layers_outlined),
      (
        label: '刷新状态',
        value: _lastRefreshAt == null ? '尚未刷新' : '已刷新',
        icon: Icons.sync_outlined,
      ),
      (
        label: '最近刷新时间',
        value: _lastRefreshAt == null
            ? '--:--:--'
            : _formatClock(_lastRefreshAt!),
        icon: Icons.schedule_outlined,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surfaceStrong.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.stroke),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        children: [
          for (final item in summaryItems)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 18, color: palette.accent),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildKetangpaiCoursePanel(Course course) {
    final meta = <String>[
      if ((course.note ?? '').trim().isNotEmpty) course.note!.trim(),
      if ((course.schools ?? '').trim().isNotEmpty) course.schools!.trim(),
      if ((course.beginDate ?? '').trim().isNotEmpty &&
          (course.endDate ?? '').trim().isNotEmpty)
        '${course.beginDate} - ${course.endDate}',
    ];

    return KetangpaiCoursePanel(
      title: course.name,
      teacher: course.teacher,
      subtitle: meta.isEmpty ? '暂无课程信息' : meta.first,
      meta: meta.length > 1 ? meta.sublist(1) : const <String>[],
      imageUrl: course.image,
      badge: '课堂派课程',
      stateLabel: course.state ? '正在上课' : '未开始',
      onTap: () => _openCourseForCurrentPlatform(course),
    );
  }

  Widget _buildKetangpaiEmptyState() {
    return KetangpaiEmptyStage(
      title: '课程详情和签到入口',
      description: _emptyHint ?? '保留原有课堂派接口和跳转逻辑，可进入课程资料、共享房间和签到工具。',
      actionLabel: '进入课程',
      onAction: _loadCourses,
      icon: Icons.auto_stories_outlined,
    );
  }

  Widget _buildPlatformEmptyState() {
    IconData icon = Icons.menu_book_outlined;
    String title = '当前暂无课程数据';
    String desc = _emptyHint ?? '请下拉刷新后重试';

    if (PlatformManager().isChaoxing) {
      icon = Icons.local_fire_department_outlined;
      title = '学习通课程暂不可用';
      desc = _emptyHint ?? '请确认学习通账号已登录，并检查网络后重新刷新课程。';
    } else if (PlatformManager().isRainClassroom) {
      icon = Icons.water_drop_outlined;
      title = '雨课堂课程暂不可用';
      desc = _emptyHint ?? '请确认雨课堂账号已登录，并检查服务器和课程列表后重试。';
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: DashboardEmptyState(
        title: title,
        subtitle: desc,
        icon: icon,
        color: _globalPrimary,
        action: FilledButton.icon(
          onPressed: _loadCourses,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('进入课程'),
          style: FilledButton.styleFrom(
            backgroundColor: _globalPrimary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  String _currentPageTitle({required bool isTronclass}) {
    if (PlatformManager().isChaoxing) {
      return '学习通课程';
    }
    if (PlatformManager().isRainClassroom) {
      return '雨课堂课程';
    }
    if (PlatformManager().isKetangpai) {
      return '课堂派课程';
    }
    return '课程';
  }

  void _openCourseForCurrentPlatform(Course course) {
    if (PlatformManager().isChaoxing) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChaoxingCourseDetailPage(course: course),
        ),
      );
      return;
    }

    if (PlatformManager().isRainClassroom) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RainClassroomCourseDetailPage(course: course),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KetangpaiCourseStructPage(course: course),
      ),
    );
  }

  Widget _buildCourseAvatar(Course course) {
    final title = course.name.trim();
    final firstChar = title.isEmpty ? '课' : title.substring(0, 1);
    if (course.image.isNotEmpty) {
      return AvatarWidget(
        imageUrl: course.image,
        size: 50,
        borderRadius: 8,
        iconSize: 25,
      );
    }

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_globalPrimary, _globalSecondary.withValues(alpha: 0.92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          firstChar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformCourseCard(Course course) {
    if (PlatformManager().isChaoxing) {
      return _buildChaoxingCourseCard(course);
    }
    if (PlatformManager().isRainClassroom) {
      return _buildRainCourseCard(course);
    }
    return _buildDefaultCourseCard(course);
  }

  Widget _buildChaoxingCourseCard(Course course) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.large),
        onTap: () => _openCourseForCurrentPlatform(course),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCourseAvatar(course),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                course.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            AppBadge(
                              label: '学习通',
                              type: AppBadgeType.error,
                              icon: Icons.school,
                              isSmall: true,
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          course.teacher,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRainCourseCard(Course course) {
    final palette = resolvePlatformPalette(
      PlatformType.rainClassroom,
      fallback: resolveGlobalPalette(
        AppSettings.globalColorSchemeNotifier.value,
      ),
    );

    return AppAnimations.fadeSlideIn(
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        elevation: AppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.large),
          onTap: () => _openCourseForCurrentPlatform(course),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              gradient: LinearGradient(
                colors: [
                  palette.primary.withValues(alpha: 0.08),
                  Theme.of(context).colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 76,
                  decoration: BoxDecoration(
                    color: palette.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                _buildCourseAvatar(course),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              course.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AppBadge(
                            label: '雨课堂',
                            type: AppBadgeType.info,
                            icon: Icons.water_drop,
                            isSmall: true,
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        course.teacher,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (course.beginDate != null &&
                          course.endDate != null) ...[
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          '上课时间：${course.beginDate} - ${course.endDate}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultCourseCard(Course course) {
    final palette = resolveGlobalPalette(
      AppSettings.globalColorSchemeNotifier.value,
    );

    return AppAnimations.fadeSlideIn(
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        elevation: AppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.large),
          onTap: () => _openCourseForCurrentPlatform(course),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.large),
              gradient: LinearGradient(
                colors: [
                  palette.primary.withValues(alpha: 0.05),
                  Theme.of(context).colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                _buildCourseAvatar(course),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        course.teacher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildPlatformWorkspaceHeader() {
    String title = '平台课程工作台';
    String subtitle = '在这里查看课程、同步数据并进入签到工具。';
    IconData icon = Icons.grid_view_outlined;

    if (PlatformManager().isChaoxing) {
      title = '学习通课程工作台';
      subtitle = '管理学习通课程、章节、作业和课堂活动入口。';
      icon = Icons.local_fire_department_outlined;
    } else if (PlatformManager().isRainClassroom) {
      title = '雨课堂课程工作台';
      subtitle = '同步雨课堂在线与离线课程，并保留扫码签到流程。';
      icon = Icons.water_drop_outlined;
    } else if (PlatformManager().isKetangpai) {
      title = '课堂派课程工作台';
      subtitle = '集中管理课堂派课程、共享房间和签到入口。';
      icon = Icons.dashboard_outlined;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                _globalPrimary.withValues(alpha: 0.12),
                _globalSecondary.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _globalPrimary.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _globalPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _globalPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _globalPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRainClassroomToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _globalPrimary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showOnlineOnly = true;
                    _courses = _onlineCourses;
                  });
                },
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _showOnlineOnly
                        ? _globalPrimary
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.online_prediction,
                        size: 18,
                        color: _showOnlineOnly ? Colors.white : _globalPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '在线课程 (${_onlineCourses.length})',
                        style: TextStyle(
                          color: _showOnlineOnly
                              ? Colors.white
                              : _globalPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showOnlineOnly = false;
                    _courses = _offlineCourses;
                  });
                },
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_showOnlineOnly
                        ? _globalPrimary
                        : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 18,
                        color: !_showOnlineOnly ? Colors.white : _globalPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '离线课程 (${_offlineCourses.length})',
                        style: TextStyle(
                          color: !_showOnlineOnly
                              ? Colors.white
                              : _globalPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRainCourseDebugPanel() {
    final debug = _rainCourseDebugSummary;
    if (debug == null || debug.isEmpty) {
      return const SizedBox.shrink();
    }

    final ok = debug['ok'] == true;
    final courseItems = debug['courseItems']?.toString() ?? '-';
    final onLessonItems = debug['onLessonItems']?.toString() ?? '-';
    final mergedResult = debug['mergedResult']?.toString() ?? '-';
    final lessonByCourseId = debug['lessonByCourseId']?.toString() ?? '-';
    final lessonByCourseAndClassId =
        debug['lessonByCourseAndClassId']?.toString() ?? '-';
    final courseCode = debug['courseCode']?.toString() ?? '-';
    final onLessonCode = debug['onLessonCode']?.toString() ?? '-';
    final authExpired = debug['authExpired'] == true;
    final reason = debug['reason']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card(
        elevation: 0,
        color: ok ? const Color(0xFFEFF5FF) : const Color(0xFFFFF4E8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: ok
                          ? const Color(0xFF2F73E0).withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      ok
                          ? Icons.analytics_outlined
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: ok
                          ? const Color(0xFF2F73E0)
                          : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: ok
                        ? const Color(0xFF2F73E0)
                        : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '雨课堂课程匹配结果',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ok
                          ? const Color(0xFF2F73E0)
                          : Colors.orange.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _debugChip('娑撴槒顕崇粙?', courseItems),
                  _debugChip('在线课程', onLessonItems),
                  _debugChip('合并结果', mergedResult),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'lesson 匹配：byCourseId=$lessonByCourseId, byCourseAndClassId=$lessonByCourseAndClassId',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                '课程匹配：course=$courseCode, onLesson=$onLessonCode',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (authExpired) ...[
                const SizedBox(height: 4),
                const Text(
                  '未找到匹配的雨课堂课程，请检查课程编号、班级编号和 lesson 信息。',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
              if (!ok && reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '跳过课程：$reason',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _debugChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8E6FF)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF2F73E0),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildKetangpaiFunctionCards() {
    if (PlatformManager().isKetangpai) {
      final palette = KetangpaiCoursePalette.of(context);
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          final tileWidth = isWide
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '雨课堂课程入口',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '保留原有课程同步和扫码逻辑，可查看在线课程、离线课程和签到入口。',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: tileWidth,
                    height: 148,
                    child: KetangpaiToolTile(
                      title: '在线课程',
                      subtitle: '正在上课或即将开始的课程会显示在这里。',
                      icon: Icons.meeting_room_outlined,
                      kicker: 'ROOM',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const KetangpaiSharedRoomPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    height: 148,
                    child: KetangpaiToolTile(
                      title: '本地签到',
                      subtitle: '使用当前课程信息进入签到工具，保留原有提交流程。',
                      icon: Icons.location_on_outlined,
                      kicker: 'SIGN',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const KetangpaiPrivateSignPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Card(
        elevation: 0,
        color: Colors.lightBlue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.apps_rounded,
                      size: 20,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '课堂派课程同步结果',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFunctionButton(
                    icon: Icons.person_outlined,
                    label: '课堂派个人信息',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KetangpaiProfilePage(),
                        ),
                      );
                    },
                  ),
                  _buildFunctionButton(
                    icon: Icons.meeting_room_outlined,
                    label: '在线课程',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KetangpaiSharedRoomPage(),
                        ),
                      );
                    },
                  ),
                  _buildFunctionButton(
                    icon: Icons.location_on_outlined,
                    label: '本地签到',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const KetangpaiPrivateSignPage(),
                        ),
                      );
                    },
                  ),
                  _buildFunctionButton(
                    icon: Icons.class_outlined,
                    label: '课程资料',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const KetangpaiRoomListPage(),
                        ),
                      );
                    },
                  ),
                  _buildFunctionButton(
                    icon: Icons.feedback_outlined,
                    label: '刷新列表',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const KetangpaiSuggestionsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void onVisibilityChanged(bool visible) {
    debugPrint('[YKT] onVisibilityChanged: visible=$visible');
    // 课堂派保留原有课程接口和跳转逻辑。
    _refreshTimer?.cancel();
  }

  /// 同步课堂派课程列表并更新缓存。
  void updateWithOnLessonCourses(Map<String, dynamic> onLessonCourses) {
    _loadCourses(onLessonCourses: onLessonCourses);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.globalColorSchemeNotifier.addListener(_onGlobalSchemeChanged);
    _loadGlobalPalette();

    final currentPlatform = PlatformManager().currentPlatform;
    final cachedCourses = _coursesCache[currentPlatform];

    if (cachedCourses != null && cachedCourses.isNotEmpty) {
      _courses = cachedCourses;
      _onlineCourses = _onlineCoursesCache[currentPlatform] ?? [];
      _offlineCourses = _offlineCoursesCache[currentPlatform] ?? [];
      _isLoading = false;
    } else {
      _loadCourseSnapshotThenRefresh(currentPlatform);
      if (PlatformManager().isRainClassroom) {
        _isLoading = false;
      }
    }

    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      unawaited(
        PlatformNetworkWarmupService().warmupDio(
          platform: currentPlatform,
          userId: currentUserId,
        ),
      );
    }

    // 刷新课程前先设置加载状态。
    _accountChangeSubscription = AccountChangeNotifier().accountStateChanges.listen((
      snapshot,
    ) {
      if (snapshot.platform != PlatformManager().currentPlatform) {
        return;
      }
      final changedAccountId = snapshot.currentAccountId ?? '';
      if (mounted &&
          changedAccountId.isNotEmpty &&
          PlatformManager().isTronclass) {
        _coursesCache.remove(PlatformType.tronclass);
        _onlineCoursesCache.remove(PlatformType.tronclass);
        _offlineCoursesCache.remove(PlatformType.tronclass);
        setState(() {
          _emptyHint = null;
          _snapshotRefreshFailed = false;
        });
      }
      // Prevent reload loop: only reload if not currently loading courses
      // 雨课堂不自动加载，由用户或扫码流程触发。
      if (mounted &&
          changedAccountId.isNotEmpty &&
          !_isLoading &&
          !_isLoadingCourses &&
          !PlatformManager().isRainClassroom) {
        debugPrint(
          '[Courses] Account changed to $changedAccountId, reloading courses',
        );
        _loadCourses(forceNetwork: true);
      } else {
        if (mounted &&
            changedAccountId.isNotEmpty &&
            !PlatformManager().isRainClassroom) {
          _queuePendingAccountReload(changedAccountId);
        }
        debugPrint(
          '[Courses] Account changed queued reload: mounted=$mounted isLoading=$_isLoading isLoadingCourses=$_isLoadingCourses pendingUser=$_pendingAccountReloadUserId',
        );
      }
    });

    // 切换平台后清理旧平台课程状态。
    _platformChangeSubscription = PlatformManager().platformChanges.listen((
      newPlatform,
    ) async {
      if (mounted) {
        debugPrint(
          '[Courses] Platform changed to $newPlatform, loading from cache',
        );

        var waitCount = 0;
        while (_isLoadingCourses && waitCount < 160) {
          await Future.delayed(const Duration(milliseconds: 50));
          waitCount++;
        }

        if (!mounted) return;

        if (_isLoadingCourses) {
          debugPrint('[Courses] Timed out waiting for previous load');
          _isLoadingCourses = false;
          setState(() {
            _isLoading = false;
          });
        }

        _loadGlobalPalette();
        final cachedCourses = _coursesCache[newPlatform];
        final cachedOnline = _onlineCoursesCache[newPlatform];
        final cachedOffline = _offlineCoursesCache[newPlatform];

        if (cachedCourses != null && cachedCourses.isNotEmpty) {
          setState(() {
            _courses = cachedCourses;
            _onlineCourses = cachedOnline ?? [];
            _offlineCourses = cachedOffline ?? [];
            _isLoading = false;
            _emptyHint = null;
          });
        } else {
          setState(() {
            _courses = [];
            _onlineCourses = [];
            _offlineCourses = [];
            _isLoading = PlatformManager().isRainClassroom ? false : true;
          });

          _loadCourseSnapshotThenRefresh(newPlatform);
        }
      }
    });

    // initState 时不启动自动刷新，避免误触发平台请求。
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[YKT] didChangeAppLifecycleState: state=$state');
    // 关闭定时刷新，保持用户主动刷新模式。
  }

  void _loadGlobalPalette() {
    final scheme = AppSettings.globalColorSchemeNotifier.value;
    final palette = resolveGlobalPalette(scheme);
    final platformPalette = resolvePlatformPalette(
      PlatformManager().currentPlatform,
      fallback: palette,
    );

    if (!mounted) return;
    setState(() {
      _globalPrimary = platformPalette.primary;
      _globalSecondary = platformPalette.secondary;
    });
  }

  void _onGlobalSchemeChanged() {
    _loadGlobalPalette();
  }

  Future<void> _loadCourseSnapshotThenRefresh(PlatformType platform) async {
    final userId = AccountManager.currentSessionId ?? '';
    if (userId.isNotEmpty) {
      unawaited(
        PlatformNetworkWarmupService().warmupDio(
          platform: platform,
          userId: userId,
        ),
      );
      final snapshot = await _snapshotStore.readList(
        platform: platform,
        userId: userId,
        page: 'courses',
      );
      if (mounted &&
          PlatformManager().currentPlatform == platform &&
          snapshot != null &&
          snapshot.data.isNotEmpty) {
        final courses = snapshot.data.map(Course.fromJson).toList();
        setState(() {
          _courses = courses;
          _coursesCache[platform] = courses;
          _cacheTimestamps[platform] = snapshot.updatedAt;
          _snapshotUpdatedAt = snapshot.updatedAt;
          _isLoading = false;
          _isShowingCachedCourses = true;
          _isRefreshingCoursesInBackground = true;
          _snapshotRefreshFailed = false;
          _emptyHint = null;
        });
      }
    }

    if (!mounted || PlatformManager().currentPlatform != platform) return;
    if (!PlatformManager().isRainClassroom) {
      unawaited(_loadCourses());
    }
  }

  void _queuePendingAccountReload(String accountId) {
    if (!mounted || PlatformManager().isRainClassroom) {
      return;
    }
    _pendingAccountReloadUserId = accountId;
    debugPrint('[Courses] queued pending account reload userId=$accountId');
  }

  void _runPendingAccountReloadIfNeeded(PlatformType completedPlatform) {
    if (_runningPendingAccountReload || !mounted) {
      return;
    }
    final pendingUserId = _pendingAccountReloadUserId;
    if (pendingUserId == null || pendingUserId.isEmpty) {
      return;
    }
    if (PlatformManager().currentPlatform != completedPlatform ||
        PlatformManager().isRainClassroom ||
        AccountManager.currentSessionId != pendingUserId) {
      debugPrint(
        '[Courses] drop pending account reload userId=$pendingUserId current=${AccountManager.currentSessionId ?? ''} platform=${PlatformManager().currentPlatform}',
      );
      _pendingAccountReloadUserId = null;
      return;
    }
    _pendingAccountReloadUserId = null;
    _runningPendingAccountReload = true;
    debugPrint(
      '[Courses] running pending account reload userId=$pendingUserId',
    );
    unawaited(
      _loadCourses(forceNetwork: true).whenComplete(() {
        _runningPendingAccountReload = false;
      }),
    );
  }

  Future<void> _loadCourses({
    Map<String, dynamic>? onLessonCourses,
    bool forceNetwork = false,
  }) async {
    // Prevent concurrent loads that cause infinite refresh loop
    if (_isLoadingCourses) {
      debugPrint('[Courses] Already loading courses, skipping duplicate call');
      return;
    }

    _isLoadingCourses = true;
    final requestPlatform = PlatformManager().currentPlatform;
    final requestUserId = AccountManager.currentSessionId ?? '';
    final cachedCourses = _coursesCache[requestPlatform];
    final hasCachedCourses = cachedCourses != null && cachedCourses.isNotEmpty;

    setState(() {
      _isLoading = !hasCachedCourses;
      _isShowingCachedCourses = hasCachedCourses;
      _isRefreshingCoursesInBackground = hasCachedCourses;
      _snapshotRefreshFailed = false;
      if (hasCachedCourses) {
        _courses = cachedCourses;
        _onlineCourses = _onlineCoursesCache[requestPlatform] ?? [];
        _offlineCourses = _offlineCoursesCache[requestPlatform] ?? [];
      } else {
        _courses = [];
        _onlineCourses = [];
        _offlineCourses = [];
      }
      _emptyHint = null;
      _rainCourseDebugSummary = null;
    });

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      if (AccountManager.currentSessionId != requestUserId) {
        _isLoadingCourses = false;
        _runPendingAccountReloadIfNeeded(requestPlatform);
        return;
      }
      setState(() {
        _isLoading = false;
        _isShowingCachedCourses = false;
        _isRefreshingCoursesInBackground = false;
        _emptyHint = '当前未登录，请先到账号页登录。';
      });
      _isLoadingCourses = false;
      _runPendingAccountReloadIfNeeded(requestPlatform);
      return;
    }

    try {
      List<Course>? coursesData;
      List<Course>? onlineData;
      List<Course>? offlineData;

      if (PlatformManager().isChaoxing) {
        coursesData = await CXCourseApi.getCoursesList().timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            ApiService.appendExternalConsoleLog('学习通', '课程列表加载超时，结束加载状态');
            return null;
          },
        );
      } else if (PlatformManager().isRainClassroom) {
        // 雨课堂课程分在线和离线两路拉取。
        final results = await Future.wait([
          RCCourseApi.getOnlineCoursesList(),
          RCCourseApi.getOfflineCoursesList(),
        ]);
        onlineData = results[0];
        offlineData = results[1];
        coursesData = _showOnlineOnly ? onlineData : offlineData;
      } else if (PlatformManager().isTronclass) {
        coursesData = await TCCourseApi.getCoursesList();
      } else if (PlatformManager().isKetangpai) {
        coursesData = await KTCourseApi.getCoursesList();
      }

      if (!mounted ||
          PlatformManager().currentPlatform != requestPlatform ||
          AccountManager.currentSessionId != requestUserId) {
        debugPrint(
          '[Courses] Platform/account changed during load, discarding stale data',
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      if (coursesData != null && coursesData.isNotEmpty) {
        debugPrint('[Courses] 雨课堂课程请求完成');

        _coursesCache[requestPlatform] = coursesData;
        _cacheTimestamps[requestPlatform] = DateTime.now();
        _snapshotUpdatedAt = _cacheTimestamps[requestPlatform];
        final userId = AccountManager.currentSessionId ?? '';
        if (userId.isNotEmpty) {
          await _snapshotStore.writeList(
            platform: requestPlatform,
            userId: userId,
            page: 'courses',
            data: coursesData.map((course) => course.toJson()).toList(),
            updatedAt: _snapshotUpdatedAt,
          );
        }
        if (PlatformManager().isRainClassroom) {
          _onlineCoursesCache[requestPlatform] = onlineData ?? [];
          _offlineCoursesCache[requestPlatform] = offlineData ?? [];
        }

        setState(() {
          _courses = coursesData!;
          if (PlatformManager().isRainClassroom) {
            _onlineCourses = onlineData ?? [];
            _offlineCourses = offlineData ?? [];
          }
          _isLoading = false;
          _isShowingCachedCourses = false;
          _isRefreshingCoursesInBackground = false;
          _snapshotRefreshFailed = false;
          _emptyHint = null;
          _rainCourseDebugSummary = PlatformManager().isRainClassroom
              ? RCCourseApi.getLastCourseDebugSummary()
              : null;
        });
        debugPrint('[Courses] 课程列表更新完成，_courses.length=${_courses.length}');
      } else {
        final rainDebug = PlatformManager().isRainClassroom
            ? RCCourseApi.getLastCourseDebugSummary()
            : null;
        setState(() {
          if (!hasCachedCourses) {
            _courses = [];
          }
          if (PlatformManager().isRainClassroom && !hasCachedCourses) {
            _onlineCourses = onlineData ?? [];
            _offlineCourses = offlineData ?? [];
          }
          _isLoading = false;
          _isRefreshingCoursesInBackground = false;
          _snapshotRefreshFailed = hasCachedCourses;
          _emptyHint = hasCachedCourses
              ? '正在显示缓存课程，后台刷新未获得新数据'
              : PlatformManager().isRainClassroom
              ? '课程加载失败，请检查账号和服务器后重试'
              : PlatformManager().isChaoxing
              ? '未获取到学习通课程数据'
              : '课程加载失败，请稍后重试';
          _rainCourseDebugSummary = PlatformManager().isRainClassroom
              ? rainDebug
              : null;
        });
      }
    } catch (e) {
      debugPrint('[Courses] load failed: $e');
      if (!mounted) return;
      setState(() {
        if (!hasCachedCourses) {
          _courses = [];
          _onlineCourses = [];
          _offlineCourses = [];
        }
        _isLoading = false;
        _isRefreshingCoursesInBackground = false;
        _snapshotRefreshFailed = hasCachedCourses;
        _emptyHint = hasCachedCourses
            ? '正在显示缓存课程，后台刷新失败'
            : PlatformManager().isRainClassroom
            ? '课程加载失败，请检查账号和服务器后重试'
            : PlatformManager().isChaoxing
            ? '未获取到学习通课程数据'
            : '课程加载失败，请稍后重试';
        _rainCourseDebugSummary = PlatformManager().isRainClassroom
            ? RCCourseApi.getLastCourseDebugSummary()
            : null;
      });
    } finally {
      _isLoadingCourses = false;
      if (mounted) {
        setState(() {
          _isRefreshingCoursesInBackground = false;
        });
      }
      _runPendingAccountReloadIfNeeded(requestPlatform);
    }
  }

  // ignore: unused_element
  Widget _buildTronclassPlatformSwitcherPanel() {
    final currentPlatform = PlatformManager().currentPlatform;
    final currentPlatformName = switch (currentPlatform) {
      PlatformType.chaoxing => '学习通',
      PlatformType.rainClassroom => '雨课堂',
      PlatformType.tronclass => '畅课',
      PlatformType.ketangpai => '课堂派',
      PlatformType.weizhuojiao => '微助教',
    };

    final entries = <Map<String, Object>>[
      {
        'platform': PlatformType.chaoxing,
        'label': '学习通',
        'subtitle': '课程与活动入口',
        'icon': Icons.school_outlined,
        'color': const Color(0xFF1F9EA8),
      },
      {
        'platform': PlatformType.rainClassroom,
        'label': '雨课堂',
        'subtitle': '在线课程和离线课程',
        'icon': Icons.cloud_outlined,
        'color': const Color(0xFF5B90EF),
      },
      {
        'platform': PlatformType.tronclass,
        'label': '畅课',
        'subtitle': '仪表盘与签到入口',
        'icon': Icons.dashboard_customize_outlined,
        'color': const Color(0xFF1DB6C2),
      },
      {
        'platform': PlatformType.ketangpai,
        'label': '课堂派',
        'subtitle': '课程、共享房间和签到',
        'icon': Icons.quiz_outlined,
        'color': const Color(0xFFF6A23A),
      },
      {
        'platform': PlatformType.weizhuojiao,
        'label': '微助教',
        'subtitle': '功能入口正在完善',
        'icon': Icons.construction_outlined,
        'color': const Color(0xFF8A8F98),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _globalPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.swap_horiz, color: _globalPrimary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择平台后会切换当前课程工作台。',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '请确认账号已登录，切换后可刷新对应平台课程。',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _globalPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '当前：$currentPlatformName',
                      style: TextStyle(
                        color: _globalPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: entries.map((entry) {
                  final platform = entry['platform'] as PlatformType;
                  final label = entry['label'] as String;
                  final subtitle = entry['subtitle'] as String;
                  final icon = entry['icon'] as IconData;
                  final color = entry['color'] as Color;
                  final selected = currentPlatform == platform;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _switchPlatform(platform),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 108,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? LinearGradient(
                                colors: [color, color.withValues(alpha: 0.82)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: selected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? color
                              : Colors.grey.withValues(alpha: 0.20),
                        ),
                        boxShadow: [
                          if (selected)
                            BoxShadow(
                              color: color.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            icon,
                            color: selected ? Colors.white : color,
                            size: 20,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> handleScanContent(String result) async {
    if (!AccountManager.hasActiveSession()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('需要切换平台'),
              content: SelectableText(result),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      });
      return;
    }

    try {
      final uri = Uri.tryParse(result);
      final detectedPlatform = _detectScanPlatform(result, uri);

      if (detectedPlatform == PlatformType.chaoxing) {
        await _handleChaoxingScan(result, uri);
        return;
      }

      if (detectedPlatform == PlatformType.rainClassroom) {
        await _handleRainClassroomScan(result, uri);
        return;
      }

      if (detectedPlatform == PlatformType.tronclass) {
        await _handleTronclassScan(result, uri);
        return;
      }

      if (detectedPlatform == PlatformType.ketangpai) {
        await _handleKetangpaiScan(result, uri);
        return;
      }

      if (!result.startsWith('http')) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('扫码结果无法识别：$result')));
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('打开链接？'),
              content: SelectableText(result),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('URL 解析失败：$e')));
    }
  }

  PlatformType? _detectScanPlatform(String raw, Uri? uri) {
    if (_isChaoxingScanCandidate(raw, uri)) {
      return PlatformType.chaoxing;
    }
    if (_isRainClassroomScanCandidate(raw, uri)) {
      return PlatformType.rainClassroom;
    }
    if (_isTronclassScanCandidate(raw, uri)) {
      return PlatformType.tronclass;
    }
    if (_isKetangpaiScanCandidate(raw, uri)) {
      return PlatformType.ketangpai;
    }
    return null;
  }

  bool _isChaoxingScanCandidate(String raw, Uri? uri) {
    final lowerRaw = raw.toLowerCase();
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    final query = uri?.queryParameters ?? const <String, String>{};

    if (host.contains('chaoxing.com') || lowerRaw.contains('chaoxing.com')) {
      return path.contains('/widget/sign/') ||
          path.contains('/newsign/') ||
          path.contains('/pptsign/') ||
          lowerRaw.contains('activeid=') ||
          lowerRaw.contains('activeprimaryid=') ||
          lowerRaw.contains('rcode=') ||
          lowerRaw.contains('enc=') ||
          query.containsKey('id') ||
          query.containsKey('activeId') ||
          query.containsKey('activePrimaryId') ||
          query.containsKey('rcode') ||
          query.containsKey('enc');
    }

    return lowerRaw.contains('mobilelearn.chaoxing.com') ||
        lowerRaw.contains('passport2.chaoxing.com');
  }

  bool _isRainClassroomScanCandidate(String raw, Uri? uri) {
    return RainClassroomScanParser.isCandidate(raw, uri);
  }

  bool _isKetangpaiScanCandidate(String raw, Uri? uri) {
    final lowerRaw = raw.toLowerCase();
    final host = uri?.host.toLowerCase() ?? '';
    final query = uri?.queryParameters ?? const <String, String>{};

    if (host.contains('ketangpai') || lowerRaw.contains('ketangpai')) {
      return true;
    }

    return lowerRaw.contains('ticketid=') &&
            lowerRaw.contains('expire=') &&
            lowerRaw.contains('sign=') ||
        query.containsKey('ticketid') &&
            query.containsKey('expire') &&
            query.containsKey('sign');
  }

  bool _isTronclassScanCandidate(String raw, Uri? uri) {
    final lowerRaw = raw.toLowerCase();
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    final query = uri?.queryParameters ?? const <String, String>{};

    if (host.contains('courses.guet.edu.cn') ||
        lowerRaw.contains('courses.guet.edu.cn')) {
      if (path == '/j' || path == '/scanner-jumper') {
        return true;
      }
      if (path.contains('/rollcall/')) {
        return true;
      }
      if (query.containsKey('p') ||
          query.containsKey('_p') ||
          query.containsKey('rollcallId') ||
          query.containsKey('rollcall_id') ||
          query.containsKey('rcode') ||
          query.containsKey('data')) {
        return true;
      }
    }

    return lowerRaw.contains('/j?p=') ||
        lowerRaw.contains('/j?_p=') ||
        lowerRaw.contains('/scanner-jumper');
  }

  Future<void> _handleTronclassScan(String raw, Uri? uri) async {
    ApiService.appendExternalConsoleLog(
      'tronclass',
      '[CoursesScan] Tronclass scan received rawLength=${raw.length}',
    );
    if (!PlatformManager().isTronclass) {
      await PlatformManager().setPlatform(
        PlatformType.tronclass,
        userInitiated: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已自动切换到畅课')));
    }

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('需要登录'),
            content: const Text('请先登录账号后再使用扫码签到。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      return;
    }

    final parsed = TronclassQrParser.parse(raw);
    if (parsed == null) {
      ApiService.appendExternalConsoleLog(
        'tronclass',
        '[CoursesScan] Tronclass QR parse failed raw=${uri ?? raw}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法识别扫码内容：${uri ?? raw}')));
      throw StateError('不属于畅课签到二维码或二维码格式无法识别');
    }

    final rollcallId = (parsed['rollcallId'] ?? parsed['rollcall_id'] ?? '')
        .toString()
        .trim();
    final qrPayloadRaw = parsed['data']?.toString().trim();
    final qrPayload = (qrPayloadRaw == null || qrPayloadRaw.isEmpty)
        ? null
        : qrPayloadRaw;

    if (rollcallId.isEmpty || qrPayload == null) {
      ApiService.appendExternalConsoleLog(
        'tronclass',
        '[CoursesScan] Tronclass QR invalid parsedKeys=${parsed.keys.join(",")}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('畅课二维码缺少签到参数，请确认二维码是否有效')));
      throw StateError('畅课二维码缺少 rollcallId 或 data');
    }

    if (!mounted) return;
    ApiService.appendExternalConsoleLog(
      'tronclass',
      '[CoursesScan] entering Tronclass QR confirm rollcallId=$rollcallId',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TronclassQrSignConfirmPage(rollcallId: rollcallId, data: qrPayload),
      ),
    );
    ApiService.appendExternalConsoleLog(
      'tronclass',
      '[CoursesScan] Tronclass QR confirm closed rollcallId=$rollcallId',
    );
  }

  Future<void> _handleChaoxingScan(String raw, Uri? uri) async {
    if (!PlatformManager().isChaoxing) {
      await PlatformManager().setPlatform(PlatformType.chaoxing);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录雨课堂账号')));
    }

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('需要登录'),
            content: const Text('请先登录账号后再使用扫码签到。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      return;
    }

    final scanUri = uri ?? Uri.tryParse(raw);
    if (scanUri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法识别学习通扫码内容：$raw')));
      return;
    }

    final requestUrl = raw.startsWith('http') ? raw : scanUri.toString();
    final response = await ApiService.sendRequest(
      requestUrl,
      responseType: ResponseType.plain,
      allowRedirects: false,
    );
    if (!mounted) return;

    final locationUrl = response.headers.value('location');
    final targetUri = Uri.tryParse(locationUrl ?? '') ?? scanUri;
    final params = targetUri.queryParameters;
    final activeId =
        params['id'] ?? params['activeId'] ?? params['activePrimaryId'];

    if (activeId == null || activeId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法解析课程签到参数，请重新扫码')));
      return;
    }

    final classId = params['classId'] ?? '';
    var enc = params['enc'] ?? '';
    final decodedRcode = params['rcode'] == null
        ? ''
        : Uri.decodeComponent(params['rcode']!);
    if (enc.isEmpty && decodedRcode.isNotEmpty) {
      final match = RegExp(r'enc=([^&\s]+)').firstMatch(decodedRcode);
      enc = match?.group(1) ?? '';
    }

    if (enc.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法解析 enc 参数')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignInPage(
          active: Active(
            type: 2,
            id: activeId,
            name: '扫码签到课程',
            description: '',
            startTime: 0,
            url: '',
            status: true,
            extras: {},
            signType: SignType.qrCode,
          ),
          courseId: '',
          classId: classId,
          cpi: '',
          enc: enc,
        ),
      ),
    );
  }

  Future<void> _handleRainClassroomScan(String raw, Uri? uri) async {
    if (!PlatformManager().isRainClassroom) {
      await PlatformManager().setPlatform(PlatformType.rainClassroom);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已自动切换到雨课堂')));
    }

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: const Text('请先登录账号后再使用扫码签到。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      return;
    }

    Uri? resolvedUri = uri;
    if (resolvedUri == null && raw.startsWith('http')) {
      resolvedUri = Uri.tryParse(raw);
    }

    if (resolvedUri != null &&
        resolvedUri.host.contains('weixin.qq.com') &&
        resolvedUri.path.startsWith('/q/')) {
      resolvedUri = await _resolveScannedUri(resolvedUri, raw);
    }

    final extractedUri =
        resolvedUri ?? RainClassroomScanParser.extractTargetUriFromText(raw);
    final target = extractedUri == null
        ? null
        : RainClassroomScanParser.classifyUri(extractedUri);

    if (target == null) {
      final unresolvedWeixinShortLink =
          extractedUri != null &&
          extractedUri.host.contains('weixin.qq.com') &&
          extractedUri.path.startsWith('/q/');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unresolvedWeixinShortLink
                ? '微信短链接暂时无法解析，请复制完整雨课堂链接后重试'
                : '无法识别雨课堂扫码内容：${uri ?? raw}',
          ),
        ),
      );
      return;
    }

    final execution = await _showRainClassroomScanRoutePicker(
      raw: raw,
      resolvedUri: extractedUri,
      target: target,
    );
    if (execution == null) {
      return;
    }

    _pendingRainScanExecution = execution;
    await _multiScan(execution.url);
  }

  Future<void> _handleKetangpaiScan(String raw, Uri? uri) async {
    if (!PlatformManager().isKetangpai) {
      await PlatformManager().setPlatform(PlatformType.ketangpai);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已自动切换到课堂派')));
    }

    final target = uri?.toString() ?? raw;
    await _multiScan(target);
  }

  Future<_RainClassroomScanExecution?> _showRainClassroomScanRoutePicker({
    required String raw,
    required Uri? resolvedUri,
    required RainClassroomScanTarget target,
  }) async {
    final autoLabel = target.kind == RainClassroomScanKind.lessonPage
        ? '检测到课程页链接，可按课程页流程处理。'
        : '检测到动态二维码链接，可直接按扫码流程处理。';
    final lessonId = target.lessonId;
    final dynamicUrl = raw.startsWith('http')
        ? raw
        : (resolvedUri?.toString() ?? target.uri.toString());
    final initialChoice = target.kind == RainClassroomScanKind.lessonPage
        ? _RainClassroomScanRouteChoice.lessonPage
        : _RainClassroomScanRouteChoice.dynamicQr;

    final choice = await showDialog<_RainClassroomScanRouteChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('选择雨课堂扫码方式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(autoLabel),
              const SizedBox(height: 12),
              const Text('请确认扫码来源，系统会按所选方式继续处理。'),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_mode),
                title: const Text('自动选择'),
                subtitle: Text(autoLabel),
                onTap: () => Navigator.pop(
                  dialogContext,
                  _RainClassroomScanRouteChoice.auto,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: lessonId != null && lessonId.isNotEmpty,
                leading: const Icon(Icons.school_outlined),
                title: const Text('课程页方式'),
                subtitle: Text(
                  lessonId == null || lessonId.isEmpty
                      ? '当前链接缺少 lessonId，无法使用课程页方式'
                      : '使用 lessonId 和 source=12 进入课程页流程',
                ),
                onTap: lessonId == null || lessonId.isEmpty
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _RainClassroomScanRouteChoice.lessonPage,
                      ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: lessonId != null && lessonId.isNotEmpty,
                leading: const Icon(Icons.open_in_full),
                title: const Text('小程序方式'),
                subtitle: Text(
                  lessonId == null || lessonId.isEmpty
                      ? '当前链接缺少 lessonId，无法使用小程序方式'
                      : '使用 lessonId 和 source=11 进入小程序流程',
                ),
                onTap: lessonId == null || lessonId.isEmpty
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _RainClassroomScanRouteChoice.miniProgram,
                      ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code_2),
                title: const Text('动态二维码方式'),
                subtitle: const Text('使用原始链接调用 /api/v3/app/scan 接口'),
                onTap: () => Navigator.pop(
                  dialogContext,
                  _RainClassroomScanRouteChoice.dynamicQr,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, initialChoice),
              child: const Text('使用推荐方式'),
            ),
          ],
        );
      },
    );

    if (choice == null) {
      return null;
    }

    switch (choice) {
      case _RainClassroomScanRouteChoice.auto:
        return _RainClassroomScanExecution(
          kind: target.kind,
          url: target.uri.toString(),
          lessonId: target.lessonId,
        );
      case _RainClassroomScanRouteChoice.lessonPage:
        if (lessonId == null || lessonId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('缺少 lessonId，无法使用课程页方式')),
            );
          }
          return null;
        }
        return _RainClassroomScanExecution(
          kind: RainClassroomScanKind.lessonPage,
          url: target.uri.toString(),
          lessonId: lessonId,
        );
      case _RainClassroomScanRouteChoice.miniProgram:
        if (lessonId == null || lessonId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('缺少 lessonId，无法使用小程序方式')),
            );
          }
          return null;
        }
        return _RainClassroomScanExecution(
          kind: RainClassroomScanKind.miniProgram,
          url: target.uri.toString(),
          lessonId: lessonId,
        );
      case _RainClassroomScanRouteChoice.dynamicQr:
        return _RainClassroomScanExecution(
          kind: RainClassroomScanKind.dynamicQr,
          url: dynamicUrl,
        );
    }
  }

  // ignore: unused_element
  bool _looksLikeRainClassroomQrCandidate(String raw, Uri uri) {
    final lowerRaw = raw.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (_isRainQrUri(uri)) {
      return true;
    }

    // WeChat short-link codes are common for RainClassroom dynamic sign-in.
    if (host.contains('weixin.qq.com') && path.startsWith('/q/')) {
      return true;
    }

    if (host.endsWith('yuketang.cn') &&
        ((path.contains('/lesson/check-in/dynamic-qr-code') ||
                lowerRaw.contains('dynamic-qr-code')) ||
            path.contains('/lesson/student/v3/'))) {
      return true;
    }

    final qp = uri.queryParameters;
    if (qp.containsKey('c') && qp.containsKey('t') && qp.containsKey('s')) {
      return true;
    }

    return false;
  }

  // ignore: unused_element
  Future<Uri> _resolveScannedUri(Uri uri, String rawUrl) async {
    if (!(uri.host.contains('weixin.qq.com') && uri.path.startsWith('/q/'))) {
      return uri;
    }

    // 1) Try existing request chain first.
    try {
      final resolvedResp = await ApiService.sendRequest(
        rawUrl,
        responseType: ResponseType.plain,
        allowRedirects: true,
      );
      final resolved = resolvedResp.requestOptions.uri;
      final fromBody = _extractRainQrUriFromCandidates(
        resolved,
        rawCandidates: <String>[resolvedResp.data?.toString() ?? ''],
      );
      if (fromBody != null) {
        return fromBody;
      }
      if (!(resolved.host.contains('weixin.qq.com') &&
          resolved.path.startsWith('/q/'))) {
        return resolved;
      }
    } catch (_) {
      // continue with raw resolver fallback
    }

    // 2) Fallback: resolve redirects without platform interceptors/cookies.
    try {
      return await _resolveRedirectWithRawDio(rawUrl);
    } catch (_) {
      return uri;
    }
  }

  Future<Uri> _resolveRedirectWithRawDio(String url) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    var current = url;
    for (int i = 0; i < 8; i++) {
      final resp = await dio.get(
        current,
        options: Options(
          responseType: ResponseType.plain,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36',
          },
        ),
      );

      final location = resp.headers.value('location');
      if (location == null || location.isEmpty) {
        final bodyUri = _extractRainQrUriFromCandidates(
          resp.requestOptions.uri,
          rawCandidates: <String>[resp.data?.toString() ?? ''],
        );
        return bodyUri ?? resp.requestOptions.uri;
      }

      final currentUri = Uri.parse(current);
      final locationUri = Uri.parse(location);
      current = locationUri.hasScheme
          ? locationUri.toString()
          : currentUri.resolveUri(locationUri).toString();

      final nestedUri = _extractRainQrUriFromCandidates(
        Uri.parse(current),
        rawCandidates: <String>[current, location],
      );
      if (nestedUri != null) {
        return nestedUri;
      }
    }

    return Uri.parse(current);
  }

  Uri? _extractRainQrUriFromCandidates(
    Uri baseUri, {
    required List<String> rawCandidates,
  }) {
    if (RainClassroomScanParser.classifyUri(baseUri) != null) {
      return baseUri;
    }

    for (final raw in rawCandidates) {
      final fromText = RainClassroomScanParser.extractTargetUriFromText(raw);
      if (fromText != null) {
        return fromText;
      }
    }

    for (final value in baseUri.queryParameters.values) {
      final fromQuery = RainClassroomScanParser.extractTargetUriFromText(value);
      if (fromQuery != null) {
        return fromQuery;
      }
      try {
        final decoded = Uri.decodeComponent(value);
        final fromDecoded = RainClassroomScanParser.extractTargetUriFromText(
          decoded,
        );
        if (fromDecoded != null) {
          return fromDecoded;
        }
      } catch (_) {
        // skip malformed query component
      }
    }
    return null;
  }

  bool _isRainQrUri(Uri uri) {
    return RainClassroomScanParser.isDynamicQrUri(uri);
  }

  /// 使用选中账号批量执行扫码签到。
  Future<void> _multiScan(String qrCodeUrl) async {
    final isRainClassroom = PlatformManager().isRainClassroom;
    final isKetangpai = PlatformManager().isKetangpai;
    final signLogStore = SignRecordStore();
    final signContext = isRainClassroom
        ? SignPlatformContext.rainClassroom
        : isKetangpai
        ? SignPlatformContext.ketangpai
        : null;

    if (signContext == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前平台不支持批量扫码签到')));
      return;
    }

    _scanConsoleController.resetForPlatform(signContext);
    final targetAccounts = AccountManager.getAccountsForPlatform(
      signContext.platformType,
    );

    if (targetAccounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可用账号，请先登录或选择账号')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    int successCount = 0;
    final List<String> failedAccounts = [];

    final currentUserId = AccountManager.currentSessionId;
    for (final user in targetAccounts) {
      try {
        if (isRainClassroom) {
          AccountManager.setCurrentSessionTemp(user.uid);
          _scanConsoleController.add(
            platform: '雨课堂',
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.sessionCheck,
            message: '检查雨课堂会话',
          );
          final rainExecution = _pendingRainScanExecution;
          final gateResult = await SignNetworkGate().run<int?>(
            context: context,
            platformLabel: '雨课堂',
            user: user,
            console: _scanConsoleController,
            action: () => _signRainClassroomTarget(qrCodeUrl, rainExecution),
          );
          if (gateResult.skipped) {
            final reason = gateResult.reason ?? '用户跳过';
            failedAccounts.add('${user.name} ($reason)');
            await signLogStore.append(
              platform: '雨课堂',
              platformType: PlatformType.rainClassroom,
              courseName: '扫码签到课程',
              account: user.name,
              status: '失败',
              detail: reason,
            );
            continue;
          }
          final status = gateResult.value;
          ApiService.appendExternalConsoleLog(
            'rainclassroom',
            'rain scan mode=${rainExecution?.kind.name ?? 'dynamicQr'}',
          );
          if (status == 0) {
            successCount++;
            _scanConsoleController.add(
              platform: '雨课堂',
              accountName: user.name,
              accountId: user.uid,
              stage: SignRunStage.signSuccess,
              message: '扫码签到成功',
            );
            await signLogStore.append(
              platform: '雨课堂',
              platformType: PlatformType.rainClassroom,
              courseName: '扫码签到课程',
              account: user.name,
              status: '成功',
            );
          } else if (status == 51203) {
            failedAccounts.add('${user.name} (缺少有效的雨课堂会话)');
            _scanConsoleController.add(
              platform: '雨课堂',
              accountName: user.name,
              accountId: user.uid,
              stage: SignRunStage.signFailure,
              message: '缺少有效的雨课堂会话',
            );
            await signLogStore.append(
              platform: '雨课堂',
              platformType: PlatformType.rainClassroom,
              courseName: '扫码签到课程',
              account: user.name,
              status: '失败',
              detail: '缺少有效的雨课堂会话',
            );
          } else {
            failedAccounts.add('${user.name} (签到失败)');
            _scanConsoleController.add(
              platform: '雨课堂',
              accountName: user.name,
              accountId: user.uid,
              stage: SignRunStage.signFailure,
              message: '签到失败',
              detail: 'status=$status',
            );
            await signLogStore.append(
              platform: '雨课堂',
              platformType: PlatformType.rainClassroom,
              courseName: '扫码签到课程',
              account: user.name,
              status: '失败',
              detail: '签到失败',
            );
          }
        } else if (isKetangpai) {
          _scanConsoleController.add(
            platform: '课堂派',
            accountName: user.name,
            accountId: user.uid,
            stage: SignRunStage.sessionCheck,
            message: '检查课堂派 token',
          );
          if (user.token.isEmpty) {
            failedAccounts.add('${user.name} (token 无效或已过期)');
            _scanConsoleController.add(
              platform: '课堂派',
              accountName: user.name,
              accountId: user.uid,
              stage: SignRunStage.signFailure,
              message: 'token 无效或已过期',
            );
            await signLogStore.append(
              platform: '课堂派',
              platformType: PlatformType.ketangpai,
              courseName: '扫码签到课程',
              account: user.name,
              status: '失败',
              detail: 'token 无效或已过期',
            );
            continue;
          }

          final gateResult = await SignNetworkGate().run<bool>(
            context: context,
            platformLabel: '课堂派',
            user: user,
            console: _scanConsoleController,
            action: () => KTSignApi.scanToSign(qrCodeUrl, user.token),
          );
          if (gateResult.skipped) {
            final reason = gateResult.reason ?? '用户跳过';
            failedAccounts.add('${user.name} ($reason)');
            await signLogStore.append(
              platform: '课堂派',
              platformType: PlatformType.ketangpai,
              courseName: '扫码签到课程',
              account: user.name,
              status: '失败',
              detail: reason,
            );
            continue;
          }
          final ok = gateResult.value == true;
          if (ok) {
            successCount++;
            _scanConsoleController.add(
              platform: '课堂派',
              accountName: user.name,
              accountId: user.uid,
              stage: SignRunStage.signSuccess,
              message: '扫码签到成功',
            );
            await signLogStore.append(
              platform: '课堂派',
              platformType: PlatformType.ketangpai,
              courseName: '扫码签到课程',
              account: user.name,
              status: '成功',
            );
          } else {
            failedAccounts.add('${user.name} (签到失败)');
            _scanConsoleController.add(
              platform: '课堂派',
              accountName: user.name,
              accountId: user.uid,
              stage: SignRunStage.signFailure,
              message: '签到失败',
            );
            await signLogStore.append(
              platform: '课堂派',
              platformType: PlatformType.ketangpai,
              courseName: '扫码签到课程',
              account: user.name,
              status: '失败',
              detail: '签到失败',
            );
          }
        } else {
          failedAccounts.add('${user.name} (当前账号未登录或会话失效)');
        }
      } catch (e) {
        failedAccounts.add('${user.name} (异常：$e)');
        _scanConsoleController.add(
          platform: isRainClassroom ? '雨课堂' : '课堂派',
          accountName: user.name,
          accountId: user.uid,
          stage: SignRunStage.aborted,
          message: '签到异常',
          detail: e.toString(),
        );
        if (isRainClassroom || isKetangpai) {
          await signLogStore.append(
            platform: isRainClassroom ? '雨课堂' : '课堂派',
            platformType: signContext.platformType,
            courseName: '扫码签到课程',
            account: user.name,
            status: '失败',
            detail: '异常',
          );
        }
      }
    }
    if (currentUserId != null && currentUserId.isNotEmpty) {
      AccountManager.setCurrentSessionTemp(currentUserId);
    }
    _pendingRainScanExecution = null;

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    _showMultiScanResult(successCount, targetAccounts.length, failedAccounts);
  }

  /// 显示批量扫码签到结果。
  void _showMultiScanResult(
    int successCount,
    int totalCount,
    List<String> failedAccounts,
  ) {
    var message = '签到完成：\n成功: $successCount/$totalCount';
    if (failedAccounts.isNotEmpty) {
      message += '\n\n失败账号:\n${failedAccounts.join('\n')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          successCount == totalCount ? '全部签到成功' : '部分失败',
          style: TextStyle(
            color: successCount == totalCount ? Colors.green : Colors.orange,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<int?> _signRainClassroomTarget(
    String qrCodeUrl,
    _RainClassroomScanExecution? rainExecution,
  ) async {
    if (rainExecution?.kind == RainClassroomScanKind.miniProgram) {
      final lessonId = rainExecution?.lessonId;
      if (lessonId == null || lessonId.isEmpty) {
        return null;
      }
      return RCCourseApi.checkInFromMiniProgram(lessonId);
    }

    if (rainExecution?.kind == RainClassroomScanKind.lessonPage) {
      final lessonId = rainExecution?.lessonId;
      if (lessonId == null || lessonId.isEmpty) {
        return null;
      }
      return RCCourseApi.checkInFromLessonPage(lessonId);
    }

    return RCCourseApi.scanDynamicQr(rainExecution?.url ?? qrCodeUrl);
  }

  void _openScanPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanPage(onScanResult: handleScanContent),
      ),
    );
  }

  void _openAccountsPage() {
    Navigator.pushNamed(context, '/accounts');
  }

  List<Widget> _buildPlatformAppBarActions({required bool isTronclass}) {
    final actions = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: AppSettings.strictSecurityModeNotifier,
            builder: (context, strictMode, _) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      strictMode ? Icons.shield : Icons.shield_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      strictMode ? '严格模式' : '普通模式',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ];

    if (PlatformManager().isChaoxing) {
      actions.add(
        IconButton(
          tooltip: '账号管理',
          icon: const Icon(Icons.manage_accounts_outlined),
          onPressed: _openAccountsPage,
        ),
      );
      actions.add(
        IconButton(
          tooltip: '扫码签到',
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _openScanPage,
        ),
      );
      return actions;
    }

    if (PlatformManager().isRainClassroom) {
      actions.add(
        IconButton(
          tooltip: '同步课程',
          icon: const Icon(Icons.cloud_sync_outlined),
          onPressed: _isLoading
              ? null
              : () => _refreshCourses(showFeedback: true),
        ),
      );
      actions.add(
        IconButton(
          tooltip: '扫码签到',
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _openScanPage,
        ),
      );
      return actions;
    }

    actions.add(
      IconButton(
        tooltip: '扫码',
        icon: const Icon(Icons.qr_code_scanner),
        onPressed: _openScanPage,
      ),
    );
    return actions;
  }

  IconData _floatingActionIcon({required bool isTronclass}) {
    if (PlatformManager().isRainClassroom) return Icons.cloud_sync_outlined;
    if (PlatformManager().isChaoxing) return Icons.auto_awesome_motion_outlined;
    return Icons.refresh;
  }

  String _floatingActionLabel({required bool isTronclass}) {
    if (PlatformManager().isRainClassroom) return '同步课程';
    if (PlatformManager().isChaoxing) return '刷新课程活动';
    return '刷新课程';
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformManager().isTronclass) {
      return TronclassDashboardPage(onScanResult: handleScanContent);
    }

    if (PlatformManager().isWeizhuojiao) {
      return Scaffold(
        appBar: AppBar(title: const Text('微助教课程')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 52,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  '微助教功能正在完善，请稍后再试。',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '课程数据会在支持的平台中展示，当前平台暂未接入完整课程能力。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isTronclass = PlatformManager().isTronclass;
    final isKetangpai = PlatformManager().isKetangpai;

    return Scaffold(
      appBar: isKetangpai
          ? null
          : AppBar(
              title: Text(_currentPageTitle(isTronclass: isTronclass)),
              backgroundColor: _globalPrimary,
              foregroundColor: Colors.white,
              actions: _buildPlatformAppBarActions(isTronclass: isTronclass),
            ),
      floatingActionButton: isKetangpai
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLoading
                  ? null
                  : () => _refreshCourses(showFeedback: true),
              backgroundColor: _globalPrimary,
              foregroundColor: Colors.white,
              icon: Icon(_floatingActionIcon(isTronclass: isTronclass)),
              label: Text(_floatingActionLabel(isTronclass: isTronclass)),
            ),
      floatingActionButtonLocation: isKetangpai
          ? null
          : FloatingActionButtonLocation.endFloat,
      body: _isLoading
          ? (isKetangpai
                ? const KetangpaiShowcaseBackground(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const Center(child: CircularProgressIndicator()))
          : _buildCourseListBody(isTronclass: isTronclass),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppSettings.globalColorSchemeNotifier.removeListener(
      _onGlobalSchemeChanged,
    );
    _accountChangeSubscription?.cancel();
    _platformChangeSubscription?.cancel();
    _refreshTimer?.cancel();
    _scanConsoleController.dispose();
    super.dispose();
  }
}
