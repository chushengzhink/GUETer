import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';
import '../platform.dart';
import 'presentation.dart';
import 'rainclassroom_offline_course_page.dart';

class RainClassroomCourseDetailPage extends StatefulWidget {
  final Course course;

  const RainClassroomCourseDetailPage({super.key, required this.course});

  @override
  State<RainClassroomCourseDetailPage> createState() =>
      _RainClassroomCourseDetailPageState();
}

class _RainClassroomCourseDetailPageState
    extends State<RainClassroomCourseDetailPage> {
  Course? _resolvedCourse;
  Map<String, dynamic>? _onlinePayload;
  String? _resolvedLessonId;
  DateTime? _lastRefreshAt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String _prettyJson(dynamic value) {
    if (value == null) {
      return '暂无数据';
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  List<String> _topKeys(dynamic value, {int maxCount = 8}) {
    if (value is Map<String, dynamic>) {
      return value.keys.take(maxCount).map((key) => key.toString()).toList();
    }
    if (value is Map) {
      return value.keys.take(maxCount).map((key) => key.toString()).toList();
    }
    return const [];
  }

  String _normalizedId(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
    });

    final results = await Future.wait([
      RCCourseApi.getCoursesList(),
      RCCourseApi.getOnLessonAndUpcomingExam(),
    ]);

    if (!mounted) return;

    final courseList = results[0] as List<Course>?;
    final onlinePayload = results[1] as Map<String, dynamic>?;
    final resolvedCourse = _resolveCurrentCourse(courseList);
    final resolvedLessonId = _resolveLessonId(resolvedCourse, onlinePayload);

    debugPrint(
      '[YKT][detail-resolve] '
      'clicked course_id=${_normalizedId(widget.course.courseId)} '
      'classroom_id=${_normalizedId(widget.course.classId)} '
      'resolved course_id=${_normalizedId(resolvedCourse.courseId)} '
      'classroom_id=${_normalizedId(resolvedCourse.classId)} '
      'lesson_id=${_normalizedId(resolvedLessonId)} '
      'summary=${RCCourseApi.getLastCourseDebugSummary()}',
    );

    setState(() {
      _resolvedCourse = resolvedCourse;
      _onlinePayload = onlinePayload;
      _resolvedLessonId = resolvedLessonId;
      _lastRefreshAt = DateTime.now();
      _loading = false;
    });
  }

  Course _resolveCurrentCourse(List<Course>? courseList) {
    if (courseList == null || courseList.isEmpty) {
      return widget.course;
    }

    final targetClassId = _normalizedId(widget.course.classId);
    final targetCourseId = _normalizedId(widget.course.courseId);

    if (targetClassId.isNotEmpty) {
      for (final course in courseList) {
        if (_normalizedId(course.classId) == targetClassId) {
          return course;
        }
      }
    }

    if (targetClassId.isEmpty && targetCourseId.isNotEmpty) {
      final matchedCourses = courseList.where((course) {
        return _normalizedId(course.courseId) == targetCourseId;
      }).toList();
      if (matchedCourses.length == 1) {
        return matchedCourses.first;
      }
    }

    return widget.course;
  }

  String? _resolveLessonId(Course course, Map<String, dynamic>? payload) {
    final direct = _normalizedId(course.lessonId);
    if (direct.isNotEmpty) {
      return direct;
    }

    if (payload == null) {
      return null;
    }

    final onLessonClassrooms = payload['data']?['onLessonClassrooms'];
    if (onLessonClassrooms is! List) {
      return null;
    }

    final targetClassId = _normalizedId(course.classId);
    final targetCourseId = _normalizedId(course.courseId);
    final items = onLessonClassrooms.whereType<Map>().map((item) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();

    if (targetClassId.isNotEmpty) {
      for (final item in items) {
        final classroomId = _normalizedId(
          item['classroomId'] ?? item['classroom_id'],
        );
        if (classroomId == targetClassId) {
          final lessonId = _normalizedId(item['lessonId'] ?? item['lesson_id']);
          return lessonId.isEmpty ? null : lessonId;
        }
      }
      return null;
    }

    if (targetCourseId.isEmpty) {
      return null;
    }

    final matchedByCourseId = items.where((item) {
      final courseId = _normalizedId(item['courseId'] ?? item['course_id']);
      return courseId == targetCourseId;
    }).toList();

    if (matchedByCourseId.length != 1) {
      return null;
    }

    final lessonId = _normalizedId(
      matchedByCourseId.first['lessonId'] ?? matchedByCourseId.first['lesson_id'],
    );
    return lessonId.isEmpty ? null : lessonId;
  }

  Future<void> _openPresentation() async {
    // 离线课程直接使用classroom_id，不需要lessonId
    final classroomId = (_resolvedCourse?.classId ?? widget.course.classId).trim();

    if (classroomId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取课程ID')),
      );
      return;
    }

    // 检查是否有lessonId（在线课堂才需要）
    final lessonId = (_resolvedLessonId ?? '').trim();

    if (!mounted) return;

    // 如果有lessonId，使用原有逻辑进入在线课堂
    if (lessonId.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PresentationPage(
            lessonId: lessonId,
            title: _resolvedCourse?.name ?? widget.course.name,
          ),
        ),
      );
    } else {
      // 离线课程：跳转到离线课程详情页
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RainClassroomOfflineCoursePage(
            course: _resolvedCourse ?? widget.course,
          ),
        ),
      );
    }
  }

  Future<void> _showRawPayload() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('雨课堂原始数据'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(_prettyJson(_onlinePayload)),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Widget? action,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                action ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = _resolvedCourse ?? widget.course;
    final lessonId = (_resolvedLessonId ?? '').trim();
    final refreshedText = _lastRefreshAt == null
        ? '尚未刷新'
        : '最近刷新：${_formatClock(_lastRefreshAt!)}';
    final lessonText = lessonId.isEmpty
        ? '当前未检测到进行中的课堂'
        : '已解析 lessonId：$lessonId';
    final payloadKeys = _topKeys(_onlinePayload);

    return Scaffold(
      appBar: AppBar(
        title: Text(course.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadDetail,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _openPresentation,
        icon: const Icon(Icons.slideshow),
        label: const Text('进入课堂'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          course.teacher,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          refreshedText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lessonText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _loadDetail,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.75),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh),
                                label: const Text('刷新详情'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _loading ? null : _openPresentation,
                                icon: const Icon(Icons.slideshow),
                                label: const Text('进入课堂'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: '学习日志',
                    action: TextButton.icon(
                      onPressed: _loading ? null : _loadDetail,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新日志'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '这个页面把课程信息、在线课堂快照和进入课堂入口串到一起了。',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip('课程', Colors.blue),
                            _buildChip('快照', Colors.orange),
                            _buildChip('课堂入口', Colors.green),
                            if (lessonId.isNotEmpty) _buildChip('已解析课次', Colors.teal),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: '课程概览',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('课程ID', course.courseId),
                        _buildInfoRow('班级ID', course.classId),
                        _buildInfoRow('课次ID', lessonId.isEmpty ? '未解析' : lessonId),
                        _buildInfoRow('学校', course.schools ?? '未填写'),
                        _buildInfoRow('备注', course.note ?? '无'),
                        _buildInfoRow(
                          '起止时间',
                          (course.beginDate != null && course.endDate != null)
                              ? '${course.beginDate} 至 ${course.endDate}'
                              : '未设置',
                        ),
                        _buildInfoRow('服务器', PlatformManager().serverName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: '在线课堂快照',
                    action: TextButton.icon(
                      onPressed: _showRawPayload,
                      icon: const Icon(Icons.code),
                      label: const Text('原始数据'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (payloadKeys.isNotEmpty) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final key in payloadKeys) _buildChip(key, Colors.indigo),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        SelectableText(
                          _prettyJson(_onlinePayload),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    title: '操作建议',
                    child: Text(
                      lessonId.isEmpty
                          ? '当前课程没有解析到进行中的课堂。如果你确认正在上课，先刷新详情，或者回到课程列表重新拉取。'
                          : '已解析到课次，可以直接进入课堂查看 PPT、签到和活动。',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 84),
                ],
              ),
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
