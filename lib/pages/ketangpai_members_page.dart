import 'package:flutter/material.dart';

import '../models/course.dart';
import '../session/account.dart';
import 'ketangpai_attendance_stats_page.dart';

class KetangpaiMembersPage extends StatelessWidget {
  const KetangpaiMembersPage({
    super.key,
    required this.course,
    this.courseDetail,
  });

  final Course course;
  final Map<String, dynamic>? courseDetail;

  String _valueOf(Iterable<dynamic> values, {String fallback = '暂无'}) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  int? _intValueOf(Iterable<dynamic> values) {
    for (final value in values) {
      final number = int.tryParse(value?.toString() ?? '');
      if (number != null) {
        return number;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final detail = courseDetail ?? const <String, dynamic>{};
    final currentUserId = AccountManager.currentSessionId;
    final account = currentUserId == null
        ? null
        : AccountManager.getAccountById(currentUserId);

    final className = _valueOf([detail['classname'], course.note, course.name]);
    final courseName = _valueOf([detail['coursename'], course.name]);
    final teacherName = _valueOf([
      detail['teachername'],
      detail['username'],
      course.teacher,
    ]);
    final courseCode = _valueOf([detail['code'], detail['coursecode']]);
    final schoolName = _valueOf([detail['schoolname'], course.schools]);
    final studentCount = _intValueOf([
      detail['studentcount'],
      detail['membercount'],
      detail['studentnum'],
      detail['totalstudent'],
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('成员')),
      body: ListView(
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(className),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _infoChip(
                        context,
                        Icons.person_outline,
                        '教师',
                        teacherName,
                      ),
                      _infoChip(
                        context,
                        Icons.groups_outlined,
                        '人数',
                        studentCount?.toString() ?? '未知',
                      ),
                      _infoChip(
                        context,
                        Icons.qr_code_2_outlined,
                        '加课码',
                        courseCode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('学校'),
                  subtitle: Text(schoolName),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('当前课堂派账号'),
                  subtitle: Text(account?.name ?? '暂无活跃账号'),
                  trailing: Text(account?.uid ?? ''),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: const Text('绑定手机号'),
                  subtitle: Text(account?.phone ?? '暂无'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KetangpaiAttendanceStatsPage(course: course),
                ),
              );
            },
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('查看签到与考勤统计'),
          ),
          if (studentCount == null) ...[
            const SizedBox(height: 12),
            Text(
              '当前版本优先保证课堂派课程详情闭环。成员列表接口尚未单独接入时，这里先展示课程与当前账号信息。',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: $value'),
        ],
      ),
    );
  }
}
