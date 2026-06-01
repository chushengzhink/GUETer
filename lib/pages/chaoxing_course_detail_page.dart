import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/chaoxing_chapter_api.dart';
import '../api/course.dart';
import '../models/active.dart';
import '../models/course.dart';
import 'actives/evaluate.dart';
import 'actives/questionnaire.dart';
import 'actives/quiz.dart';
import 'actives/sign_in/sign_in.dart';
import 'actives/topic_discuss.dart';
import 'actives/vote.dart';

class ChaoxingCourseDetailPage extends StatefulWidget {
  const ChaoxingCourseDetailPage({super.key, required this.course});

  final Course course;

  @override
  State<ChaoxingCourseDetailPage> createState() =>
      _ChaoxingCourseDetailPageState();
}

class _ChaoxingCourseDetailPageState extends State<ChaoxingCourseDetailPage> {
  bool _loading = true;
  List<Active> _activeList = const [];
  List<Map<String, dynamic>> _chapters = const [];
  List<Map<String, dynamic>> _unfinishedTasks = const [];

  List<Map<String, dynamic>> _normalizeMapList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final activeFuture = CXCourseApi.getActiveList(
        widget.course.courseId,
        widget.course.classId,
        widget.course.cpi ?? '',
      );
      final chapterFuture = ChaoxingChapterApi.getChapterList(
        widget.course.courseId,
        widget.course.classId,
      );
      final taskFuture = ChaoxingChapterApi.getUnfinishedTasks(
        widget.course.courseId,
        widget.course.classId,
        widget.course.cpi ?? '',
      );

      final results = await Future.wait([
        activeFuture,
        chapterFuture,
        taskFuture,
      ]);

      if (!mounted) {
        return;
      }

      final chapterData = results[1] as Map<String, dynamic>?;
      setState(() {
        _activeList = results[0] as List<Active>? ?? const [];
        _chapters = _normalizeMapList(chapterData?['points']);
        _unfinishedTasks = _normalizeMapList(results[2]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载课程详情失败: $e')));
    }
  }

  List<Map<String, dynamic>> get _homeworks {
    return _unfinishedTasks
        .where((item) => item['type']?.toString() == 'work')
        .toList();
  }

  List<Map<String, dynamic>> _tasksForChapter(String chapterId) {
    return _unfinishedTasks
        .where((item) => item['chapterId']?.toString() == chapterId)
        .toList();
  }

  String _taskTypeLabel(String type) {
    switch (type) {
      case 'video':
        return '视频';
      case 'document':
        return '文档';
      case 'read':
        return '阅读';
      case 'work':
        return '作业';
      default:
        return '任务';
    }
  }

  Future<void> _showRawItem(String title, Map<String, dynamic> item) async {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(item);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(prettyJson)),
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
              courseId: widget.course.courseId,
              classId: widget.course.classId,
              cpi: widget.course.cpi ?? '',
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
              courseId: widget.course.courseId,
              classId: widget.course.classId,
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
              courseId: widget.course.courseId,
              classId: widget.course.classId,
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
              courseId: widget.course.courseId,
              classId: widget.course.classId,
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
              courseId: widget.course.courseId,
              classId: widget.course.classId,
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

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('活动', _activeList.length),
            _summaryItem('章节', _chapters.length),
            _summaryItem('任务', _unfinishedTasks.length),
            _summaryItem('作业', _homeworks.length),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }

  Widget _buildActivitiesTab() {
    if (_activeList.isEmpty) {
      return const Center(child: Text('暂无活动'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _activeList.length,
      itemBuilder: (context, index) {
        final active = _activeList[index];
        return Card(
          child: ListTile(
            leading: Icon(
              active.getIcon(),
              color: active.status
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            title: Text(active.name),
            subtitle: Text(active.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openActive(active),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 2),
    );
  }

  Widget _buildChaptersTab() {
    if (_chapters.isEmpty) {
      return const Center(child: Text('暂无章节数据'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        final chapterId = chapter['id']?.toString() ?? '';
        final chapterTasks = _tasksForChapter(chapterId);
        return Card(
          child: ExpansionTile(
            title: Text(chapter['title']?.toString() ?? '未命名章节'),
            subtitle: Text(
              chapterTasks.isEmpty
                  ? '暂无未完成任务'
                  : '未完成任务 ${chapterTasks.length} 项',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chapter['need_unlock'] == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '未解锁',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const Icon(Icons.expand_more),
              ],
            ),
            children: chapterTasks.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('当前章节没有未完成任务'),
                      ),
                    ),
                  ]
                : chapterTasks.map((task) {
                    final type = task['type']?.toString() ?? 'task';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text(
                          _taskTypeLabel(type).substring(0, 1),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      title: Text(task['title']?.toString() ?? '学习任务'),
                      subtitle: Text(_taskTypeLabel(type)),
                      onTap: () => _showRawItem(
                        task['title']?.toString() ?? '学习任务',
                        task,
                      ),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildHomeworkTab() {
    if (_homeworks.isEmpty) {
      return const Center(child: Text('暂无未完成作业'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _homeworks.length,
      itemBuilder: (context, index) {
        final homework = _homeworks[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: Text(homework['title']?.toString() ?? '作业'),
            subtitle: Text(
              homework['chapterName']?.toString().trim().isNotEmpty == true
                  ? homework['chapterName'].toString()
                  : '课程作业',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                _showRawItem(homework['title']?.toString() ?? '作业', homework),
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.course.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: '活动'),
              Tab(text: '章节'),
              Tab(text: '作业'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildSummaryCard(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildActivitiesTab(),
                        _buildChaptersTab(),
                        _buildHomeworkTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
