import 'package:flutter/material.dart';
import 'package:course_helper/api/yuketang_courses.dart';

class RainCoursesPage extends StatefulWidget {
  const RainCoursesPage({super.key});

  @override
  State<RainCoursesPage> createState() => _RainCoursesPageState();
}

class _RainCoursesPageState extends State<RainCoursesPage> {
  List<YuketangCourse> _courses = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 不自动加载，仅在用户手动刷新时加载
  }

  // ignore: unused_element
  Future<void> _loadCourses() async {
    if (_isRefreshing) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final courses = await YuketangApi.fetchAllCourses();
      if (!mounted) return;

      setState(() {
        _courses = courses;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    try {
      final courses = await YuketangApi.fetchAllCourses();
      if (!mounted) return;

      setState(() {
        _courses = courses;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('雨课堂 — 所有课堂')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败：$_errorMessage'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _refresh, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _courses.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('未找到课堂')),
              ],
            )
          : ListView.separated(
              itemCount: _courses.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final c = _courses[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      c.courseName.isNotEmpty
                          ? c.courseName.characters.first
                          : c.name.characters.first,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    '${c.courseName}\n教师：${c.teacherName} · 学生：${c.studentsCount}',
                  ),
                  isThreeLine: true,
                  onTap: () {
                    // TODO: 根据 classroomId 跳转到班级详情/作业页面
                  },
                );
              },
            ),
    );
  }
}
