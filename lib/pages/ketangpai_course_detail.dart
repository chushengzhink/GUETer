import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';
import 'ketangpai_announcement_page.dart';
import 'ketangpai_answer_question_page.dart';
import 'ketangpai_attendance_stats_page.dart';
import 'ketangpai_course_ware_page.dart';
import 'ketangpai_exam_page_v2.dart';
import 'ketangpai_homework_page.dart';
import 'ketangpai_sign_status_page.dart';
import 'ketangpai_source_page.dart';
import 'ketangpai_topic_page.dart';
import 'widget/ketangpai_sign_task_panel.dart';

class KetangpaiCourseDetailPage extends StatefulWidget {
  final Course course;

  const KetangpaiCourseDetailPage({super.key, required this.course});

  @override
  State<KetangpaiCourseDetailPage> createState() =>
      _KetangpaiCourseDetailPageState();
}

class _KetangpaiCourseDetailPageState extends State<KetangpaiCourseDetailPage> {
  Map<String, dynamic>? _courseDetail;
  Map<String, dynamic>? _signStatus;
  List<Course>? _signingCourses;
  List<dynamic>? _pendingSigns;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
    });

    final detail = await KTCourseApi.getCourseDetail(widget.course.courseId);
    final signStatus = await KTCourseApi.getSignStatus(widget.course.courseId);
    final signingCourses = await KTCourseApi.getSigningCourses();
    final pendingSigns = await KTCourseApi.getNotFinishSign(
      widget.course.courseId,
    );

    if (!mounted) return;
    setState(() {
      _courseDetail = detail;
      _signStatus = signStatus;
      _signingCourses = signingCourses
          .where((course) => course.courseId == widget.course.courseId)
          .toList();
      _pendingSigns = pendingSigns;
      _loading = false;
    });
  }

  bool get _hasActiveSignIn =>
      (_pendingSigns?.isNotEmpty ?? false) ||
      (_signingCourses != null && _signingCourses!.isNotEmpty);

  Future<void> _showRawData(String title, Map<String, dynamic>? data) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: SelectableText(
              _prettyJson(data),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _prettyJson(Map<String, dynamic>? data) {
    if (data == null) return '暂无数据';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: highlighted
          ? color.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionPanel(ColorScheme colorScheme) {
    final activeSubtitle = _hasActiveSignIn ? '当前课程有待处理签到' : '查看签到状态与考勤记录';
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '课堂工作台',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_hasActiveSignIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '签到中',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final width = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                Widget sized(Widget child) =>
                    SizedBox(width: width, child: child);
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    sized(
                      _buildActionTile(
                        title: '签到',
                        subtitle: activeSubtitle,
                        icon: Icons.how_to_reg_outlined,
                        color: Colors.green,
                        highlighted: _hasActiveSignIn,
                        onTap: () => _openPage(
                          KetangpaiSignStatusPage(
                            courseId: widget.course.courseId,
                          ),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '考试 V2',
                        subtitle: '进入迁移后的考试列表和答题页',
                        icon: Icons.assignment_outlined,
                        color: colorScheme.primary,
                        onTap: () => _openPage(
                          KetangpaiExamPageV2(course: widget.course),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '资料',
                        subtitle: '查看附件、外链并下载到资料库',
                        icon: Icons.folder_copy_outlined,
                        color: Colors.indigo,
                        onTap: () => _openPage(
                          KetangpaiSourcePage(course: widget.course),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '作业',
                        subtitle: '查看课堂派作业内容',
                        icon: Icons.fact_check_outlined,
                        color: Colors.orange,
                        onTap: () => _openPage(
                          KetangpaiHomeworkPage(course: widget.course),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '话题',
                        subtitle: '查看课程话题与讨论',
                        icon: Icons.forum_outlined,
                        color: Colors.teal,
                        onTap: () => _openPage(
                          KetangpaiTopicPage(course: widget.course),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '统计',
                        subtitle: '查看课堂表现和考勤统计',
                        icon: Icons.bar_chart_outlined,
                        color: Colors.blue,
                        onTap: () => _openPage(
                          KetangpaiAttendanceStatsPage(course: widget.course),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '课件',
                        subtitle: '打开课件与课程内容',
                        icon: Icons.menu_book_outlined,
                        color: Colors.purple,
                        onTap: () => _openPage(
                          KetangpaiCourseWarePage(course: widget.course),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '答疑',
                        subtitle: '查看互动答疑内容',
                        icon: Icons.question_answer_outlined,
                        color: Colors.brown,
                        onTap: () => _openPage(
                          KetangpaiAnswerQuestionPage(course: widget.course),
                        ),
                      ),
                    ),
                    sized(
                      _buildActionTile(
                        title: '公告',
                        subtitle: '查看课程公告',
                        icon: Icons.campaign_outlined,
                        color: Colors.redAccent,
                        onTap: () => _openPage(
                          KetangpaiAnnouncementPage(course: widget.course),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _courseDetail ?? <String, dynamic>{};
    final signStatus = _signStatus ?? <String, dynamic>{};

    final courseName =
        detail['coursename']?.toString().trim().isNotEmpty == true
        ? detail['coursename'].toString()
        : widget.course.name;
    final className = detail['classname']?.toString().trim().isNotEmpty == true
        ? detail['classname'].toString()
        : (widget.course.note ?? '');
    final code = detail['code']?.toString().trim().isNotEmpty == true
        ? detail['code'].toString()
        : (widget.course.note ?? '');
    final schoolName =
        detail['schoolname']?.toString().trim().isNotEmpty == true
        ? detail['schoolname'].toString()
        : (widget.course.schools ?? '');
    final teacherName = detail['teacher'] is Map<String, dynamic>
        ? (detail['teacher'] as Map<String, dynamic>)['name']?.toString() ??
              widget.course.teacher
        : widget.course.teacher;

    final attendedCount = signStatus['attended']?.toString() ?? '0';
    final totalCount = signStatus['total']?.toString() ?? '0';
    final lateCount = signStatus['late']?.toString() ?? '0';
    final absentCount = signStatus['absent']?.toString() ?? '0';

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(courseName),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '课堂派',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_hasActiveSignIn)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      '签到中',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          courseName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (className.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  KetangpaiSignTaskPanel(
                    course: widget.course,
                    courseId: widget.course.courseId,
                    initialTasks: _pendingSigns,
                  ),
                  const SizedBox(height: 16),
                  _buildActionPanel(colorScheme),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '课程信息',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            Icons.person_outline,
                            '授课教师',
                            teacherName,
                          ),
                          if (schoolName.isNotEmpty)
                            _buildInfoRow(
                              Icons.school_outlined,
                              '学校',
                              schoolName,
                            ),
                          if (code.isNotEmpty)
                            _buildInfoRow(
                              Icons.qr_code_2_outlined,
                              '课程码',
                              code,
                            ),
                          _buildInfoRow(
                            Icons.tag_outlined,
                            '课程ID',
                            widget.course.courseId,
                          ),
                          _buildInfoRow(
                            Icons.class_outlined,
                            '班级ID',
                            widget.course.classId,
                          ),
                          if ((widget.course.lessonId ?? '').isNotEmpty)
                            _buildInfoRow(
                              Icons.event_note_outlined,
                              '课次ID',
                              widget.course.lessonId!,
                            ),
                          if ((widget.course.beginDate ?? '').isNotEmpty &&
                              (widget.course.endDate ?? '').isNotEmpty)
                            _buildInfoRow(
                              Icons.calendar_today_outlined,
                              '课程时间',
                              '${widget.course.beginDate} 至 ${widget.course.endDate}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '考勤统计',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildStatCard(
                                '已签',
                                attendedCount,
                                Icons.check_circle_outline,
                                Colors.green,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                '总次数',
                                totalCount,
                                Icons.event_available_outlined,
                                Colors.blue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatCard(
                                '迟到',
                                lateCount,
                                Icons.access_time_outlined,
                                Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                '缺勤',
                                absentCount,
                                Icons.cancel_outlined,
                                Colors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.info_outline,
                            color: colorScheme.primary,
                          ),
                          title: const Text('查看课程详情数据'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showRawData('课程详情', _courseDetail),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.analytics_outlined,
                            color: colorScheme.primary,
                          ),
                          title: const Text('查看考勤统计数据'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showRawData('考勤统计', _signStatus),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
