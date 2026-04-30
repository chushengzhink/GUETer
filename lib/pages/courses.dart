import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform.dart';
import '../api/course.dart';
import '../api/api_service.dart';
import '../api/kt_sign.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../session/sign_record_store.dart';
import '../models/course.dart';
import '../models/active.dart';
import '../utils/global_palette.dart';
import '../utils/tronclass_qr_parser.dart';
import '../theme/design_tokens.dart';
import '../theme/animations.dart';
import '../theme/components/app_badge.dart';
import 'widget/scan.dart';
import 'widget/avatar.dart';
import 'actives/sign_in/sign_in.dart';
import 'actives/topic_discuss.dart';
import 'actives/quiz.dart';
import 'actives/evaluate.dart';
import 'actives/vote.dart';
import 'actives/questionnaire.dart';
import 'accounts.dart';
import 'rainclassroom_course_detail.dart';
import 'tronclass_sign_in.dart';
import 'tronclass_web_login.dart';
import 'tronclass_todos_page.dart';
import 'tronclass_sign_in_list_page.dart';
import 'tronclass_sign_page.dart';
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
  List<Active> _activeList = [];
  bool _isContentLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCourseContent();
  }

  Future<void> _loadCourseContent() async {
    setState(() {
      _isContentLoading = true;
    });

    try {
      final List<Active>? contentList = await CXCourseApi.getActiveList(
        widget.courseId,
        widget.classId,
        widget.cpi,
      );

      if (contentList != null) {
        setState(() {
          _activeList = contentList;
          _isContentLoading = false;
        });
      } else {
        setState(() {
          _activeList = [];
          _isContentLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('获取内容列表失败')));
        }
      }
    } catch (e) {
      setState(() {
        _activeList = [];
        _isContentLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('获取内容列表时发生错误：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isContentLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeList.isEmpty
          ? const Center(
              child: Text(
                '暂无内容',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCourseContent,
              child: ListView.builder(
                itemCount: _activeList.length,
                itemBuilder: (context, index) {
                  var active = _activeList[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        active.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (active.status) {
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
                              break;

                            case ActiveType.topicDiscuss:
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TopicDiscussPage(active: active),
                                ),
                              );
                              break;

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
                              break;

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
                              break;

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
                              break;

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
                              break;

                            default:
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('该活动类型暂不支持')),
                              );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('该活动已结束')),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
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
  Map<String, dynamic>? _lastOnLessonCourses;
  bool _isVisible = false;
  bool _isLoadingCourses = false;
  Color _globalPrimary = const Color(0xFF1F9EA8);
  Color _globalSecondary = const Color(0xFF157B88);
  Color _globalAccent = const Color(0xFF59BE30);
  DateTime? _lastRefreshAt;
  String? _lastRefreshMessage;

  final Map<PlatformType, List<Course>> _coursesCache = {};
  final Map<PlatformType, List<Course>> _onlineCoursesCache = {};
  final Map<PlatformType, List<Course>> _offlineCoursesCache = {};
  final Map<PlatformType, DateTime> _cacheTimestamps = {};

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

    // 用户主动点击切换按钮
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
    await _loadCourses();
    if (mounted) {
      _lastRefreshAt = DateTime.now();
      _lastRefreshMessage = _courses.isEmpty
          ? '未获取到课程数据'
          : '已更新 ${_courses.length} 门课程';
      setState(() {});
    }
    if (!mounted || !showFeedback) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('课程已刷新 · ${_formatClock(DateTime.now())}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Widget _buildRefreshStatusBar(BuildContext context) {
    final lastRefreshText = _lastRefreshAt == null
        ? '尚未手动刷新'
        : '最近刷新：${_formatClock(_lastRefreshAt!)}';
    final statusText = _lastRefreshMessage ?? '下拉或点击右下角按钮刷新课程';

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
    if (isTronclass) {
      return RefreshIndicator(
        onRefresh: _refreshCourses,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTronclassGreeting(),
                const SizedBox(height: 16),
                _buildTronclassQuickButtons(),
                const SizedBox(height: 24),
                const Text(
                  "待办事项",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                _buildTronclassLoginPanel(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCourses,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildRefreshStatusBar(context),
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
              itemBuilder: (context, index) => _buildPlatformCourseCard(_courses[index]),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPlatformEmptyState() {
    IconData icon = Icons.menu_book_outlined;
    String title = '当前暂无课程数据';
    String desc = _emptyHint ?? '请下拉刷新后重试';

    if (PlatformManager().isChaoxing) {
      icon = Icons.local_fire_department_outlined;
      title = '学习通课程区暂时为空';
      desc = _emptyHint ?? '可稍后刷新，或检查账号登录状态';
    } else if (PlatformManager().isRainClassroom) {
      icon = Icons.water_drop_outlined;
      title = '雨课堂课程区暂时为空';
      desc = _emptyHint ?? '可先检查登录态和服务器配置，再刷新';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg - 2,
        AppSpacing.lg,
        AppSpacing.xs + 2,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(AppSpacing.lg + 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: _globalPrimary.withValues(alpha: 0.14)),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _globalPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: Icon(icon, color: _globalPrimary, size: 30),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
            SizedBox(height: AppSpacing.lg - 2),
            FilledButton.icon(
              onPressed: _loadCourses,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新加载课程'),
              style: FilledButton.styleFrom(
                backgroundColor: _globalPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _currentPageTitle({required bool isTronclass}) {
    if (isTronclass) {
      return '畅课工作台';
    }
    if (PlatformManager().isChaoxing) {
      return '学习通课程区';
    }
    if (PlatformManager().isRainClassroom) {
      return '雨课堂课程区';
    }
    if (PlatformManager().isKetangpai) {
      return '课堂派课程区';
    }
    return '课程';
  }

  void _openCourseForCurrentPlatform(Course course) {
    if (PlatformManager().isChaoxing) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseContentPage(
            courseId: course.courseId,
            courseName: course.name,
            classId: course.classId,
            cpi: course.cpi!,
          ),
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
                          '开课时间：${course.beginDate} 至 ${course.endDate}',
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
    String title = '平台课程区';
    String subtitle = '按当前平台展示课程与操作入口';
    IconData icon = Icons.grid_view_outlined;

    if (PlatformManager().isChaoxing) {
      title = '学习通课程区';
      subtitle = '红色主题：课程活动、签到任务与课堂入口';
      icon = Icons.local_fire_department_outlined;
    } else if (PlatformManager().isRainClassroom) {
      title = '雨课堂课程区';
      subtitle = '蓝色主题：在线课堂、课程同步与调试摘要';
      icon = Icons.water_drop_outlined;
    } else if (PlatformManager().isKetangpai) {
      title = '课堂派课程区';
      subtitle = '保留当前风格';
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
                        '在线课堂 (${_onlineCourses.length})',
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
                        '离线课堂 (${_offlineCourses.length})',
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
                    '雨课堂抓取摘要',
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
                  _debugChip('主课程', courseItems),
                  _debugChip('在线课堂', onLessonItems),
                  _debugChip('合并后', mergedResult),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'lesson映射: 按课程 $lessonByCourseId · 按课程+课堂 $lessonByCourseAndClassId',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                '业务码: course=$courseCode · onLesson=$onLessonCode',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (authExpired) ...[
                const SizedBox(height: 4),
                const Text(
                  '检测到登录态失效，请到“账号”页重新登录雨课堂账号后再刷新。',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ],
              if (!ok && reason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '异常: $reason',
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
                    '课堂派功能',
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
                    label: '个人信息',
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
                    label: '共享房间',
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
                    label: '课程列表',
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
                    label: '意见反馈',
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
    _isVisible = visible;
    // 完全禁用可见性变化触发的刷新
    _refreshTimer?.cancel();
  }

  /// 使用在线课堂数据更新课程列表
  void updateWithOnLessonCourses(Map<String, dynamic> onLessonCourses) {
    _loadCourses(onLessonCourses);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppSettings.globalColorSchemeNotifier.addListener(_onGlobalSchemeChanged);
    _isVisible = true;
    _loadGlobalPalette();

    final currentPlatform = PlatformManager().currentPlatform;
    final cachedCourses = _coursesCache[currentPlatform];

    if (cachedCourses != null && cachedCourses.isNotEmpty) {
      _courses = cachedCourses;
      _onlineCourses = _onlineCoursesCache[currentPlatform] ?? [];
      _offlineCourses = _offlineCoursesCache[currentPlatform] ?? [];
      _isLoading = false;
    } else if (!PlatformManager().isRainClassroom) {
      _loadCourses();
    } else {
      _isLoading = false;
    }

    // 监听账户变更事件
    _accountChangeSubscription = AccountChangeNotifier().accountChanges.listen((
      accountId,
    ) {
      // Prevent reload loop: only reload if not currently loading courses
      // 雨课堂不自动加载
      if (mounted &&
          !_isLoading &&
          !_isLoadingCourses &&
          !PlatformManager().isRainClassroom) {
        debugPrint(
          '[Courses] Account changed to $accountId, reloading courses',
        );
        _loadCourses();
      } else {
        debugPrint(
          '[Courses] Account changed but skipping reload: mounted=$mounted isLoading=$_isLoading isLoadingCourses=$_isLoadingCourses',
        );
      }
    });

    // 监听平台变化
    _platformChangeSubscription = PlatformManager().platformChanges.listen((
      newPlatform,
    ) async {
      if (mounted) {
        debugPrint('[Courses] Platform changed to $newPlatform, loading from cache');

        while (_isLoadingCourses) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        if (!mounted) return;

        _loadGlobalPalette();
        _lastOnLessonCourses = null;

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

          if (!PlatformManager().isRainClassroom) {
            _loadCourses();
          }
        }
      }
    });

    // initState 时不启动自动刷新
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[YKT] didChangeAppLifecycleState: state=$state');
    // 完全禁用生命周期触发的刷新
    _refreshTimer?.cancel();
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
      _globalAccent = platformPalette.accent;
    });
  }

  void _onGlobalSchemeChanged() {
    _loadGlobalPalette();
  }

  Future<void> _loadCourses([Map<String, dynamic>? onLessonCourses]) async {
    // Prevent concurrent loads that cause infinite refresh loop
    if (_isLoadingCourses) {
      debugPrint('[Courses] Already loading courses, skipping duplicate call');
      return;
    }

    _isLoadingCourses = true;
    final requestPlatform = PlatformManager().currentPlatform;
    final requestPlatformName = PlatformManager().currentPlatformName;

    setState(() {
      _isLoading = true;
      _courses = [];
      _onlineCourses = [];
      _offlineCourses = [];
      _emptyHint = null;
      _rainCourseDebugSummary = null;
    });

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emptyHint = '当前未登录，请先到账号页登录';
      });
      _isLoadingCourses = false;
      return;
    }

    try {
      List<Course>? coursesData;
      List<Course>? onlineData;
      List<Course>? offlineData;

      if (PlatformManager().isChaoxing) {
        coursesData = await CXCourseApi.getCoursesList();
      } else if (PlatformManager().isRainClassroom) {
        // 雨课堂同时获取在线和离线课程
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

      if (!mounted || PlatformManager().currentPlatform != requestPlatform) {
        debugPrint('[Courses] Platform changed during load, discarding stale data');
        _isLoadingCourses = false;
        return;
      }

      if (coursesData != null && coursesData.isNotEmpty) {
        debugPrint('[Courses] 准备更新缓存和状态');

        _coursesCache[requestPlatform] = coursesData;
        _cacheTimestamps[requestPlatform] = DateTime.now();
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
          _emptyHint = null;
          _rainCourseDebugSummary = PlatformManager().isRainClassroom
              ? RCCourseApi.getLastCourseDebugSummary()
              : null;
        });
        debugPrint('[Courses] 缓存和状态更新完成，_courses.length=${_courses.length}');
      } else {
        final rainDebug = PlatformManager().isRainClassroom
            ? RCCourseApi.getLastCourseDebugSummary()
            : null;
        final rcAuthExpired =
            rainDebug != null && rainDebug['authExpired'] == true;
        final rainServerInfo = PlatformManager().isRainClassroom
            ? '服务器：${PlatformManager().serverName}\n'
                  '账号状态：${AccountManager.hasActiveSession() ? '已登录' : '未登录'}\n'
                  '在线课堂：${_lastOnLessonCourses == null ? '未拉取' : '已拉取'}\n'
                  '最近在线课堂 keys：${_lastOnLessonCourses == null ? '无' : _lastOnLessonCourses!.keys.take(6).join(', ')}\n'
                  '请对照控制台里的 [ApiService] / [RC] 日志查看具体请求结果'
            : '';
        setState(() {
          _courses = [];
          if (PlatformManager().isRainClassroom) {
            _onlineCourses = onlineData ?? [];
            _offlineCourses = offlineData ?? [];
          }
          _isLoading = false;
          _emptyHint = PlatformManager().isRainClassroom
              ? (rcAuthExpired
                    ? '雨课堂登录态已失效\n平台：$requestPlatformName\n服务器：${PlatformManager().serverName}\n请前往”账号”页重新登录雨课堂账号后再刷新。'
                    : '未获取到雨课堂课程数据\n平台：$requestPlatformName\n$rainServerInfo')
              : '暂无课程数据';
          _rainCourseDebugSummary = PlatformManager().isRainClassroom
              ? rainDebug
              : null;
        });
      }
    } catch (e) {
      debugPrint('[Courses] load failed: $e');
      setState(() {
        _courses = [];
        _onlineCourses = [];
        _offlineCourses = [];
        _isLoading = false;
        _emptyHint = PlatformManager().isRainClassroom
            ? '课程加载失败\n平台：$requestPlatformName\n服务器：${PlatformManager().serverName}\n登录状态：${AccountManager.hasActiveSession() ? '已登录' : '未登录'}\n请先检查账号和服务器，再看控制台日志'
            : '课程加载失败，请下拉刷新重试';
        _rainCourseDebugSummary = PlatformManager().isRainClassroom
            ? RCCourseApi.getLastCourseDebugSummary()
            : null;
      });
    } finally {
      _isLoadingCourses = false;
    }
  }

  Widget _buildTronclassEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_globalPrimary, _globalSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _globalPrimary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '畅课已接通，但当前暂无课程数据',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              '可以重新加载课程，或直接使用右上角扫码入口进入签到。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadCourses,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重新加载'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TronclassSignPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('扫码签到'),
                ),
                OutlinedButton.icon(
                  onPressed: _openTronclassPortal,
                  icon: const Icon(Icons.language),
                  label: const Text('畅课门户'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTronclassPortal() async {
    if (!PlatformManager().isTronclass) {
      return;
    }

    var mode = await AppSettings.getString(
      AppSettings.tronclassPortalOpenModeKey,
      AppSettings.portalOpenModeExternalPreferred,
    );

    if (mode == AppSettings.portalOpenModeAskEveryTime && mounted) {
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择打开方式'),
          content: const Text('本次如何打开畅课门户？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  AppSettings.portalOpenModeEmbeddedPreferred,
                );
              },
              child: const Text('内置门户'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  AppSettings.portalOpenModeExternalPreferred,
                );
              },
              child: const Text('系统浏览器'),
            ),
          ],
        ),
      );
      mode = selected ?? AppSettings.portalOpenModeExternalPreferred;
    }

    if (defaultTargetPlatform == TargetPlatform.windows &&
        mode == AppSettings.portalOpenModeEmbeddedPreferred) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Windows 下已自动改为系统浏览器打开')));
      }
      mode = AppSettings.portalOpenModeExternalPreferred;
    }

    if (mode == AppSettings.portalOpenModeExternalPreferred) {
      final opened = await launchUrl(
        Uri.parse(PlatformManager().tronclassBaseUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('系统浏览器打开失败')));
      }
      return;
    }

    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录畅课账号')));
      return;
    }

    final currentUser = AccountManager.getAccountById(currentUserId);
    final accountName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : currentUserId;

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassWebLoginPage(
          accountName: accountName,
          accountId: currentUserId,
          initialUrl: Uri.parse(PlatformManager().tronclassBaseUrl),
          initialMessage: '已进入畅课门户，可直接查看课程、公告和作业',
          autoCloseOnAuthSuccess: false,
        ),
      ),
    );
  }

  Widget _buildTronclassGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 6) {
      greeting = '夜深了，注意休息';
    } else if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    return Text(
      greeting,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTronclassQuickButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildGradientButton(
              gradient: const LinearGradient(
                colors: [Color(0xFF00BBBD), Color(0xFF0EB0D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              icon: Icons.qr_code_scanner,
              label: "扫码",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ScanPage(onScanResult: handleScanContent),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildGradientButton(
              gradient: const LinearGradient(
                colors: [Color(0xFF59BE30), Color(0xFF44BE30)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              icon: Icons.edit_note,
              label: "签到",
              onTap: () async {
                // 获取签到列表
                try {
                  final activities = await TCCourseApi.getSignActivities('');
                  if (!mounted) return;

                  // 无论是否有签到活动，都跳转到签到列表页面
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TronclassSignInListPage(activities: activities),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('获取签到列表失败: $e')));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required LinearGradient gradient,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          InkWell(
            onTap: onTap,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          Positioned(
            top: -15,
            left: -15,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.9623],
                ),
              ),
            ),
          ),
          Positioned(
            right: -15,
            bottom: -15,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.9623],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTronclassQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
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

  Widget _buildTronclassLoginPanel() {
    final hasAccount = AccountManager.hasActiveSession();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            hasAccount ? Icons.verified_user : Icons.lock_outline,
            color: hasAccount ? _globalPrimary : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAccount ? '已登录，随时可以签到' : '尚未登录，请先登录再签到',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login').then((_) {
                          if (mounted) {
                            setState(() {});
                            _loadCourses();
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(hasAccount ? '添加账号' : '去登录'),
                    ),
                    if (hasAccount)
                      TextButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('退出登录'),
                              content: const Text('确定要退出当前账号吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('取消'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('确定'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            await AccountManager.setCurrentSession(null);
                            setState(() {});
                            _loadCourses();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已退出登录')),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('退出'),
                      ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/accounts').then((_) {
                          if (mounted) {
                            setState(() {});
                            _loadCourses();
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('切换账号'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        'subtitle': '课程与签到',
        'icon': Icons.school_outlined,
        'color': const Color(0xFF1F9EA8),
      },
      {
        'platform': PlatformType.rainClassroom,
        'label': '雨课堂',
        'subtitle': '在线课堂',
        'icon': Icons.cloud_outlined,
        'color': const Color(0xFF5B90EF),
      },
      {
        'platform': PlatformType.tronclass,
        'label': '畅课',
        'subtitle': '签到工作台',
        'icon': Icons.dashboard_customize_outlined,
        'color': const Color(0xFF1DB6C2),
      },
      {
        'platform': PlatformType.ketangpai,
        'label': '课堂派',
        'subtitle': '答题与考试',
        'icon': Icons.quiz_outlined,
        'color': const Color(0xFFF6A23A),
      },
      {
        'platform': PlatformType.weizhuojiao,
        'label': '微助教',
        'subtitle': '功能待完善',
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
                          '平台快捷切换',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '先切平台，再进入对应工作区。',
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

  Widget _buildTronclassSectionHeader() {
    final currentUser = AccountManager.getAccountById(
      AccountManager.currentSessionId ?? '',
    );
    final accountName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : '当前账号';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '畅课工作台',
                style: TextStyle(
                  color: _globalPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '账号：$accountName · 门户、扫码、签到独立分区',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: _openTronclassPortal,
            icon: const Icon(Icons.language, size: 18),
            label: const Text('门户'),
          ),
        ],
      ),
    );
  }

  Widget _buildTronclassHeaderPanel() {
    final currentUser = AccountManager.getAccountById(
      AccountManager.currentSessionId ?? '',
    );
    final userName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : '当前账号';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_globalPrimary, _globalSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _globalPrimary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '畅课工作台',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '欢迎你，$userName',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildTronclassQuickAction(
            icon: Icons.language,
            title: '畅课门户',
            subtitle: '打开 Web 门户，浏览课程与任务',
            color: _globalPrimary,
            onTap: _openTronclassPortal,
          ),
          const SizedBox(height: 8),
          _buildTronclassQuickAction(
            icon: Icons.assignment_outlined,
            title: '待办事项',
            subtitle: '查看作业、考试、问卷等任务',
            color: const Color(0xFFFF6B6B),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TronclassTodosPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTronclassQuickAction(
                  icon: Icons.qr_code_scanner,
                  title: '扫码',
                  subtitle: '立即签到',
                  color: _globalAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ScanPage(onScanResult: handleScanContent),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTronclassQuickAction(
                  icon: Icons.account_circle_outlined,
                  title: '账号',
                  subtitle: '管理登录状态',
                  color: _globalSecondary,
                  onTap: () {
                    Navigator.pushNamed(context, '/accounts');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTronclassLoginPanel(),
        ],
      ),
    );
  }

  Widget _buildTronclassCourseCard(Course course) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TronclassSignInPage(course: course),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _globalPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.class_outlined, color: _globalPrimary),
                  ),
                  const SizedBox(width: 10),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.teacher.isEmpty ? '未知教师' : course.teacher,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TronclassSignInPage(course: course),
                        ),
                      );
                    },
                    icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                    label: const Text('签到'),
                  ),
                ],
              ),
              if (course.schools != null || course.note != null) ...[
                const SizedBox(height: 10),
                Text(
                  course.schools ?? course.note ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
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
              title: const Text('二维码内容'),
              content: SelectableText(result),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
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
        ).showSnackBar(SnackBar(content: Text('扫描结果：$result')));
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('扫描到链接'),
              content: SelectableText(result),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
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
    final lowerRaw = raw.toLowerCase();
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    final query = uri?.queryParameters ?? const <String, String>{};

    if (host.endsWith('yuketang.cn') || lowerRaw.contains('yuketang.cn')) {
      return path.contains('/api/v3/lesson/check-in/dynamic-qr-code') ||
          path.contains('/lesson/check-in') ||
          lowerRaw.contains('/api/v3/lesson/check-in/dynamic-qr-code') ||
          lowerRaw.contains('dynamic-qr-code');
    }

    if (host.contains('weixin.qq.com') || lowerRaw.contains('weixin.qq.com')) {
      return path.startsWith('/q/') || lowerRaw.contains('/q/');
    }

    return lowerRaw.contains('dynamic-qr-code') ||
        lowerRaw.contains('c=') &&
            lowerRaw.contains('t=') &&
            lowerRaw.contains('s=') ||
        query.containsKey('c') &&
            query.containsKey('t') &&
            query.containsKey('s') &&
            (query.containsKey('v') || lowerRaw.contains('dynamic-qr-code'));
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
    if (!PlatformManager().isTronclass) {
      // 用户扫描畅课二维码，自动切换到畅课平台
      await PlatformManager().setPlatform(
        PlatformType.tronclass,
        userInitiated: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('自动切换平台为畅课')));
    }

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('没有可用账号'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法解析畅课二维码：${uri ?? raw}')));
      return;
    }

    final rollcallId = (parsed['rollcallId'] ?? parsed['rollcall_id'] ?? '')
        .toString()
        .trim();
    final qrPayloadRaw = parsed['data']?.toString().trim();
    final qrPayload = (qrPayloadRaw == null || qrPayloadRaw.isEmpty)
        ? null
        : qrPayloadRaw;

    if (rollcallId.isEmpty || qrPayload == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('二维码缺少签到参数，请在畅课签到页选择会话后扫码')));
      return;
    }

    final account = AccountManager.getAccountById(
      AccountManager.currentSessionId ?? '',
    );
    final accountName =
        account?.name ?? (AccountManager.currentSessionId ?? '未知账号');
    final signResult = await TCCourseApi.sign(
      rollcallId,
      mode: 'qrcode',
      qrPayload: qrPayload,
    );

    final ok = signResult['ok'] == true;
    final message = (signResult['message'] ?? '签到失败').toString();

    await SignRecordStore().append(
      platform: '畅课',
      courseName: '扫码签到任务',
      account: accountName,
      status: ok ? '成功' : '失败',
      detail: 'rollcallId=$rollcallId, result=$message',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '畅课签到成功：$message' : '畅课签到失败：$message')),
    );
  }

  Future<void> _handleChaoxingScan(String raw, Uri? uri) async {
    if (!PlatformManager().isChaoxing) {
      await PlatformManager().setPlatform(PlatformType.chaoxing);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('自动切换平台为学习通')));
    }

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('提示'),
            content: const Text('没有可用账号'),
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
      ).showSnackBar(SnackBar(content: Text('无法解析学习通二维码：$raw')));
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
      ).showSnackBar(const SnackBar(content: Text('未找到学习通活动ID')));
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
      ).showSnackBar(const SnackBar(content: Text('未找到 enc 参数')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignInPage(
          active: Active(
            type: 2,
            id: activeId,
            name: '二维码签到',
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
      ).showSnackBar(const SnackBar(content: Text('自动切换平台为雨课堂')));
    }

    if (!AccountManager.hasActiveSession()) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: const Text('没有可用账号'),
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

    final target = uri?.toString() ?? raw;
    await _multiScan(target);
  }

  Future<void> _handleKetangpaiScan(String raw, Uri? uri) async {
    if (!PlatformManager().isKetangpai) {
      await PlatformManager().setPlatform(PlatformType.ketangpai);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('自动切换平台为课堂派')));
    }

    final target = uri?.toString() ?? raw;
    await _multiScan(target);
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
        (path.contains('/lesson/check-in/dynamic-qr-code') ||
            lowerRaw.contains('dynamic-qr-code'))) {
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
    if (_isRainQrUri(baseUri)) {
      return baseUri;
    }

    for (final raw in rawCandidates) {
      final fromText = _extractRainQrUriFromText(raw);
      if (fromText != null) {
        return fromText;
      }
    }

    for (final value in baseUri.queryParameters.values) {
      final fromQuery = _extractRainQrUriFromText(value);
      if (fromQuery != null) {
        return fromQuery;
      }
      try {
        final decoded = Uri.decodeComponent(value);
        final fromDecoded = _extractRainQrUriFromText(decoded);
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
    return uri.path == '/api/v3/lesson/check-in/dynamic-qr-code' &&
        uri.host.contains('yuketang.cn');
  }

  Uri? _extractRainQrUriFromText(String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final normalized = text.replaceAll('&amp;', '&');
    final regex = RegExp(
      "https?://[^\\s\"']+/api/v3/lesson/check-in/dynamic-qr-code\\?[^\\s\"']+",
      caseSensitive: false,
    );
    final match = regex.firstMatch(normalized);
    if (match != null) {
      final candidate = match.group(0)!;
      try {
        return Uri.parse(candidate);
      } catch (_) {
        // try decoded form below
      }
      try {
        return Uri.parse(Uri.decodeFull(candidate));
      } catch (_) {
        return null;
      }
    }

    try {
      final decoded = Uri.decodeComponent(normalized);
      if (decoded != normalized) {
        return _extractRainQrUriFromText(decoded);
      }
    } catch (_) {
      // keep null
    }
    return null;
  }

  /// 为所有用户扫描
  Future<void> _multiScan(String qrCodeUrl) async {
    final isRainClassroom = PlatformManager().isRainClassroom;
    final isKetangpai = PlatformManager().isKetangpai;
    final signLogStore = SignRecordStore();

    final allAccounts = AccountManager.getAllAccounts();
    final targetAccounts = allAccounts.where((user) {
      if (isRainClassroom) return user.isRainClassroom;
      if (isKetangpai) return user.isKetangpai;
      return true;
    }).toList();

    if (targetAccounts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前平台没有可用账号进行签到')));
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
          final status = await RCCourseApi.scan(qrCodeUrl);
          if (status == 0) {
            successCount++;
            await signLogStore.append(
              platform: '雨课堂',
              courseName: '扫码签到任务',
              account: user.name,
              status: '成功',
            );
          } else if (status == 51203) {
            failedAccounts.add('${user.name} (动态二维码过期)');
            await signLogStore.append(
              platform: '雨课堂',
              courseName: '扫码签到任务',
              account: user.name,
              status: '失败',
              detail: '动态二维码过期',
            );
          } else {
            failedAccounts.add('${user.name} (错误码：$status)');
            await signLogStore.append(
              platform: '雨课堂',
              courseName: '扫码签到任务',
              account: user.name,
              status: '失败',
              detail: '错误码:$status',
            );
          }
        } else if (isKetangpai) {
          if (user.token.isEmpty) {
            failedAccounts.add('${user.name} (token为空，请先登录)');
            await signLogStore.append(
              platform: '课堂派',
              courseName: '扫码签到任务',
              account: user.name,
              status: '失败',
              detail: 'token为空',
            );
            continue;
          }

          final ok = await KTSignApi.scanToSign(qrCodeUrl, user.token);
          if (ok) {
            successCount++;
            await signLogStore.append(
              platform: '课堂派',
              courseName: '扫码签到任务',
              account: user.name,
              status: '成功',
            );
          } else {
            failedAccounts.add('${user.name} (签到失败)');
            await signLogStore.append(
              platform: '课堂派',
              courseName: '扫码签到任务',
              account: user.name,
              status: '失败',
              detail: '签到失败',
            );
          }
        } else {
          failedAccounts.add('${user.name} (当前平台不支持批量扫码)');
        }
      } catch (e) {
        failedAccounts.add('${user.name} (异常：$e)');
        if (isRainClassroom || isKetangpai) {
          await signLogStore.append(
            platform: isRainClassroom ? '雨课堂' : '课堂派',
            courseName: '扫码签到任务',
            account: user.name,
            status: '失败',
            detail: '异常:$e',
          );
        }
      }
    }
    if (currentUserId != null && currentUserId.isNotEmpty) {
      AccountManager.setCurrentSessionTemp(currentUserId);
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    _showMultiScanResult(successCount, targetAccounts.length, failedAccounts);
  }

  /// 显示所有签到结果
  void _showMultiScanResult(
    int successCount,
    int totalCount,
    List<String> failedAccounts,
  ) {
    String message = '签到完成！\n成功: $successCount/$totalCount';
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
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
                      strictMode ? '严格' : '标准',
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

    if (isTronclass) {
      actions.add(
        IconButton(
          tooltip: '畅课门户',
          icon: const Icon(Icons.language),
          onPressed: _openTronclassPortal,
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
    if (isTronclass) return Icons.refresh;
    if (PlatformManager().isRainClassroom) return Icons.cloud_sync_outlined;
    if (PlatformManager().isChaoxing) return Icons.auto_awesome_motion_outlined;
    return Icons.refresh;
  }

  String _floatingActionLabel({required bool isTronclass}) {
    if (isTronclass) return '刷新';
    if (PlatformManager().isRainClassroom) return '同步';
    if (PlatformManager().isChaoxing) return '刷新活动';
    return '刷新';
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformManager().isWeizhuojiao) {
      return Scaffold(
        appBar: AppBar(title: const Text('课程')),
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
                  '微助教功能正在完善中',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('该入口已临时封禁，后续版本开放。', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final isTronclass = PlatformManager().isTronclass;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPageTitle(isTronclass: isTronclass)),
        backgroundColor: _globalPrimary,
        foregroundColor: Colors.white,
        actions: _buildPlatformAppBarActions(isTronclass: isTronclass),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading
            ? null
            : () => _refreshCourses(showFeedback: true),
        backgroundColor: _globalPrimary,
        foregroundColor: Colors.white,
        icon: Icon(_floatingActionIcon(isTronclass: isTronclass)),
        label: Text(_floatingActionLabel(isTronclass: isTronclass)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
    super.dispose();
  }
}
