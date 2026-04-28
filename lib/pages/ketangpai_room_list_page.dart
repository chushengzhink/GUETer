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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final courses = await KTCourseApi.getCoursesList();

      if (!mounted) return;
      setState(() {
        _courses
          ..clear()
          ..addAll(courses);
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
                return ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KetangpaiCourseStructPage(course: course),
                    ),
                  ),
                  leading: Icon(
                    Icons.live_tv_outlined,
                    color: course.state ? Colors.green : Colors.grey,
                  ),
                  title: Text(course.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    course.state ? '正在上课' : '未上课',
                    style: const TextStyle(fontSize: 12),
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
