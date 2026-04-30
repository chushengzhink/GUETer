import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';
import 'ketangpai_course_struct.dart';

class KetangpaiRoomListPage extends StatefulWidget {
  const KetangpaiRoomListPage({super.key});

  @override
  State<KetangpaiRoomListPage> createState() => _KetangpaiRoomListPageState();
}

class _KetangpaiRoomListPageState extends State<KetangpaiRoomListPage> {
  final List<Course> _courses = [];
  final Set<String> _onlineCourseIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      // 并行获取所有课程和正在上课的课程
      final results = await Future.wait([
        KTCourseApi.getCoursesList(),
        KTCourseApi.getOnlineCourses(),
      ]);

      final allCourses = results[0];
      final onlineCourses = results[1];

      // 提取正在上课的课程 ID
      final onlineIds = onlineCourses.map((c) => c.courseId).toSet();

      // 标记正在上课的课程并排序（正在上课的排在前面）
      allCourses.sort((a, b) {
        final aOnline = onlineIds.contains(a.courseId);
        final bOnline = onlineIds.contains(b.courseId);
        if (aOnline && !bOnline) return -1;
        if (!aOnline && bOnline) return 1;
        return 0;
      });

      if (!mounted) return;
      setState(() {
        _courses
          ..clear()
          ..addAll(allCourses);
        _onlineCourseIds
          ..clear()
          ..addAll(onlineIds);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
          ? const Center(child: Text('暂无课程'))
          : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final course = _courses[index];
                final isOnline = _onlineCourseIds.contains(course.courseId);
                return ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KetangpaiCourseStructPage(course: course),
                    ),
                  ),
                  leading: Icon(
                    Icons.live_tv_outlined,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                  title: Text(
                    course.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isOnline ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        isOnline ? '正在上课' : '未上课',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      if (isOnline) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            '在线',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_outlined),
                );
              },
              itemCount: _courses.length,
              separatorBuilder: (context, index) => Container(
                color: Colors.grey,
                width: double.infinity,
                height: 0.5,
              ),
            ),
    );
  }
}
