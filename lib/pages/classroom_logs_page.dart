import 'package:flutter/material.dart';

import 'package:course_helper/api/classroom_logs.dart';

class ClassroomLogsPage extends StatefulWidget {
  final int courseId;
  final int classroomId;

  const ClassroomLogsPage({
    super.key,
    required this.courseId,
    required this.classroomId,
  });

  @override
  State<ClassroomLogsPage> createState() => _ClassroomLogsPageState();
}

class _ClassroomLogsPageState extends State<ClassroomLogsPage> {
  late Future<Map<String, dynamic>> _futureLogs;
  final ClassroomLogsApi _api = ClassroomLogsApi();

  @override
  void initState() {
    super.initState();
    _futureLogs = _api.fetchClassroomLogs(
      courseId: widget.courseId,
      classroomId: widget.classroomId,
    );
  }

  String _formatTime(int unixSeconds) {
    if (unixSeconds <= 0) return '-';
    final time = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
    return '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('教学活动列表'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureLogs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('错误: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('未找到数据'));
          }

          final data = snapshot.data!;
          final classroomInfo = ClassroomInfo.fromJson(data);
          final activities = _api.parseActivities(data);

          return Column(
            children: [
              ListTile(
                title: Text(classroomInfo.courseName),
                subtitle: Text(
                  '${classroomInfo.classroomName} - ${classroomInfo.studentsCount}名学生',
                ),
              ),
              Expanded(
                child: activities.isEmpty
                    ? const Center(child: Text('暂无活动'))
                    : ListView.builder(
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return ListTile(
                            leading: Icon(
                              activity.type == 14
                                  ? Icons.video_library
                                  : Icons.assignment,
                            ),
                            title: Text(activity.title),
                            subtitle: Text(
                              '创建时间: ${_formatTime(activity.createTime)}',
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
