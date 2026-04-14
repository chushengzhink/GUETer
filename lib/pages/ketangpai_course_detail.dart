import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';

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

    if (!mounted) return;
    setState(() {
      _courseDetail = detail;
      _signStatus = signStatus;
      _signingCourses = signingCourses
          .where((course) => course.courseId == widget.course.courseId)
          .toList();
      _loading = false;
    });
  }

  bool get _hasActiveSignIn =>
      _signingCourses != null && _signingCourses!.isNotEmpty;

  Future<void> _showSignInInfo() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('课堂派签到信息'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_hasActiveSignIn ? '检测到进行中的签到' : '当前未检测到进行中的签到'),
                const SizedBox(height: 12),
                SelectableText(_prettyJson(_courseDetail)),
                const SizedBox(height: 12),
                SelectableText(_prettyJson(_signStatus)),
              ],
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

  @override
  Widget build(BuildContext context) {
    final summaryText = _hasActiveSignIn ? '当前有进行中的签到' : '当前没有检测到进行中的签到';
    final detail = _courseDetail ?? <String, dynamic>{};
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('教师：$teacherName'),
                          if (schoolName.isNotEmpty) Text('学校：$schoolName'),
                          if (className.isNotEmpty) Text('班级：$className'),
                          if (code.isNotEmpty) Text('课程码：$code'),
                          Text('课程ID：${widget.course.courseId}'),
                          Text('班级ID：${widget.course.classId}'),
                          if ((widget.course.lessonId ?? '').isNotEmpty)
                            Text('课次ID：${widget.course.lessonId}'),
                          if ((widget.course.beginDate ?? '').isNotEmpty &&
                              (widget.course.endDate ?? '').isNotEmpty)
                            Text(
                              '时间：${widget.course.beginDate} 至 ${widget.course.endDate}',
                            ),
                          if ((widget.course.note ?? '').isNotEmpty)
                            Text('备注：${widget.course.note}'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _showSignInInfo,
                                  icon: const Icon(Icons.how_to_reg),
                                  label: const Text('查看签到信息'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summaryText,
                            style: TextStyle(
                              color: _hasActiveSignIn
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '课程详情',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _prettyJson(_courseDetail),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '考勤统计',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _prettyJson(_signStatus),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '原始接口数据',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _prettyJson(_courseDetail),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
