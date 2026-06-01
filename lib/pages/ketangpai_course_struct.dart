import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';
import 'ketangpai_announcement_page.dart';
import 'ketangpai_answer_question_page.dart';
import 'ketangpai_attendance_stats_page.dart';
import 'ketangpai_course_ware_page.dart';
import 'ketangpai_exam_page.dart';
import 'ketangpai_homework_page.dart';
import 'ketangpai_members_page.dart';
import 'ketangpai_sign_status_page.dart';
import 'ketangpai_source_page.dart';
import 'ketangpai_topic_page.dart';
import 'widget/ketangpai_course_showcase.dart';
import 'widget/ketangpai_course_tokens.dart';

class KetangpaiCourseStructPage extends StatefulWidget {
  final Course course;

  const KetangpaiCourseStructPage({super.key, required this.course});

  @override
  State<KetangpaiCourseStructPage> createState() =>
      _KetangpaiCourseStructPageState();
}

class _KetangpaiCourseStructPageState extends State<KetangpaiCourseStructPage> {
  Map<String, dynamic>? _courseDetail;
  bool _loading = true;

  final titles = const ['考试', '作业', '互动答题', '资料', '课件', '公告', '话题'];
  final PageController controller = PageController(initialPage: 0);
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
    });

    final detail = await KTCourseApi.getCourseDetail(widget.course.courseId);
    if (!mounted) {
      return;
    }
    setState(() {
      _courseDetail = detail;
      _loading = false;
    });
  }

  void _openAttendanceStatusPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            KetangpaiSignStatusPage(courseId: widget.course.courseId),
      ),
    );
  }

  void _openAttendanceStatsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KetangpaiAttendanceStatsPage(course: widget.course),
      ),
    );
  }

  void _openMembersPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KetangpaiMembersPage(
          course: widget.course,
          courseDetail: _courseDetail,
        ),
      ),
    );
  }

  String _valueOf(Iterable<dynamic> values, {String fallback = '暂无'}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  String _resolveHeroImage() {
    final detail = _courseDetail ?? const <String, dynamic>{};
    final theme = detail['theme'] is Map<String, dynamic>
        ? detail['theme'] as Map<String, dynamic>
        : null;
    final raw = theme?['bigpic']?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return widget.course.image;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    return raw;
  }

  Future<void> _showCourseInfoSheet({
    required String title,
    required String description,
  }) async {
    final detail = _courseDetail ?? const <String, dynamic>{};
    final courseName = _valueOf([detail['coursename'], widget.course.name]);
    final className = _valueOf([
      detail['classname'],
      widget.course.note,
      widget.course.name,
    ]);
    final teacher = _valueOf([detail['teachername'], widget.course.teacher]);
    final code = _valueOf([detail['code'], detail['coursecode']]);
    final school = _valueOf([detail['schoolname'], widget.course.schools]);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 16),
                _infoRow('课程', courseName),
                _infoRow('班级', className),
                _infoRow('教师', teacher),
                _infoRow('加课码', code),
                _infoRow('学校', school),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _selectPage(int index) {
    setState(() {
      _currentIndex = index;
    });
    final duration = ketangpaiMotionDuration(context);
    if (duration == Duration.zero) {
      controller.jumpToPage(index);
      return;
    }
    controller.animateToPage(
      index,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildExamPage() {
    return KetangpaiExamPage(course: widget.course);
  }

  Widget _buildHeroInfoTag(String label) {
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

  Widget _buildHeroPanel() {
    final detail = _courseDetail ?? const <String, dynamic>{};
    final courseName = _valueOf([detail['coursename'], widget.course.name]);
    final className = _valueOf([
      detail['classname'],
      widget.course.note,
      widget.course.name,
    ]);
    final code = _valueOf([detail['code'], detail['coursecode']]);
    final teacher = _valueOf([detail['teachername'], widget.course.teacher]);
    final school = _valueOf([detail['schoolname'], widget.course.schools]);

    return KetangpaiHeroPanel(
      eyebrow: 'COURSE DETAIL STAGE',
      title: courseName,
      subtitle: className,
      backgroundImageUrl: _resolveHeroImage(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KetangpaiGhostIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
            tooltip: '返回',
          ),
          const SizedBox(width: 8),
          KetangpaiGhostIconButton(
            icon: Icons.refresh_rounded,
            onTap: _loadDetail,
            tooltip: '刷新',
          ),
        ],
      ),
      badges: [
        _buildHeroInfoTag('加课码 $code'),
        _buildHeroInfoTag(teacher),
        _buildHeroInfoTag(school),
      ],
      primaryAction: KetangpaiActionButton(
        label: '考勤状态',
        icon: Icons.calendar_month_outlined,
        onTap: _openAttendanceStatusPage,
      ),
      secondaryAction: KetangpaiActionButton(
        label: '课程信息',
        icon: Icons.info_outline_rounded,
        filled: false,
        onTap: () {
          _showCourseInfoSheet(
            title: '课程介绍',
            description: '展示当前课堂派课程的基础信息、班级归属与加课码。',
          );
        },
      ),
      stats: [
        KetangpaiStatBadge(
          label: 'SECTION',
          value: titles[_currentIndex],
          icon: Icons.tune_rounded,
          highlight: true,
        ),
        KetangpaiStatBadge(
          label: 'MEMBERS',
          value: _loading ? '同步中' : '已就绪',
          icon: Icons.group_outlined,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final itemWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: KetangpaiStatementActionTile(
                title: '考勤',
                subtitle: '查看签到记录与当前考勤状态。',
                icon: Icons.calendar_month_outlined,
                onTap: _openAttendanceStatusPage,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: KetangpaiStatementActionTile(
                title: '表现',
                subtitle: '打开课堂表现与考勤统计页。',
                icon: Icons.grade_outlined,
                onTap: _openAttendanceStatsPage,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: KetangpaiStatementActionTile(
                title: '成绩概览',
                subtitle: '当前版本先展示课程概况，不改变原入口语义。',
                icon: Icons.token_outlined,
                onTap: () {
                  _showCourseInfoSheet(
                    title: '成绩概览',
                    description: '当前版本尚未接入课堂派成绩明细接口，这里先展示课程概况。',
                  );
                },
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: KetangpaiStatementActionTile(
                title: '成员',
                subtitle: '进入成员页，继续查看课程成员列表。',
                icon: Icons.person_2_outlined,
                onTap: _openMembersPage,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: KetangpaiStatementActionTile(
                title: '课程介绍',
                subtitle: '查看课程、班级、教师和学校信息。',
                icon: Icons.school_outlined,
                onTap: () {
                  _showCourseInfoSheet(
                    title: '课程介绍',
                    description: '展示当前课堂派课程的基础信息与归属班级。',
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    return KetangpaiShowcaseBackground(
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDetail,
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
                sliver: SliverToBoxAdapter(child: _buildHeroPanel()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  KetangpaiCourseTokens.pageInset,
                  KetangpaiCourseTokens.sectionGap,
                  KetangpaiCourseTokens.pageInset,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: _buildQuickActions()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  KetangpaiCourseTokens.pageInset,
                  KetangpaiCourseTokens.sectionGap,
                  KetangpaiCourseTokens.pageInset,
                  12,
                ),
                sliver: SliverToBoxAdapter(
                  child: KetangpaiSegmentedNav(
                    titles: titles,
                    currentIndex: _currentIndex,
                    onSelected: _selectPage,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  KetangpaiCourseTokens.pageInset,
                  0,
                  KetangpaiCourseTokens.pageInset,
                  24,
                ),
                sliver: SliverFillRemaining(
                  child: KetangpaiContentStage(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : PageView(
                            controller: controller,
                            onPageChanged: (value) {
                              setState(() {
                                _currentIndex = value;
                              });
                            },
                            children: [
                              _buildExamPage(),
                              KetangpaiHomeworkPage(course: widget.course),
                              KetangpaiAnswerQuestionPage(
                                course: widget.course,
                              ),
                              KetangpaiSourcePage(course: widget.course),
                              KetangpaiCourseWarePage(course: widget.course),
                              KetangpaiAnnouncementPage(course: widget.course),
                              KetangpaiTopicPage(course: widget.course),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }
}
