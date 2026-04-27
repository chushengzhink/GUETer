import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';
import 'ketangpai_exam_page.dart';
import 'ketangpai_homework_page.dart';
import 'ketangpai_answer_question_page.dart';
import 'ketangpai_source_page.dart';
import 'ketangpai_course_ware_page.dart';
import 'ketangpai_announcement_page.dart';
import 'ketangpai_topic_page.dart';
import 'ketangpai_members_page.dart';
import 'ketangpai_sign_status_page.dart';

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
  final controller = PageController(initialPage: 0);
  int _currentIndex = 0;

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
    if (!mounted) return;
    setState(() {
      _courseDetail = detail;
      _loading = false;
    });
  }

  Widget _buildExamPage() {
    return KetangpaiExamPage(course: widget.course);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _courseDetail ?? <String, dynamic>{};
    final theme = detail['theme'] is Map<String, dynamic>
        ? detail['theme'] as Map<String, dynamic>
        : null;
    final bigPic = theme?['bigpic']?.toString() ?? '';
    final className = detail['classname']?.toString() ?? widget.course.name;
    final courseName = detail['coursename']?.toString() ?? widget.course.name;
    final code = detail['code']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('课程详情'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(
                    height: 210,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        if (bigPic.isNotEmpty)
                          Image.network(
                            bigPic.startsWith('http')
                                ? bigPic
                                : 'https:$bigPic',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 210,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: Colors.blueGrey.shade100),
                          )
                        else
                          Container(color: Colors.blueGrey.shade100),
                        Container(
                          width: double.infinity,
                          height: 210,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                className,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                courseName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '加课码：$code',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => KetangpaiSignStatusPage(
                                          courseId: widget.course.courseId,
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.calendar_month_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _quickAction('考勤', Icons.calendar_month_outlined, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => KetangpaiSignStatusPage(
                                courseId: widget.course.courseId,
                              ),
                            ),
                          );
                        }),
                        _quickAction('表现', Icons.grade_outlined, null),
                        _quickAction('成绩', Icons.token_outlined, null),
                        _quickAction('成员', Icons.person_2_outlined, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const KetangpaiMembersPage(),
                            ),
                          );
                        }),
                        _quickAction('课程介绍', Icons.school_outlined, null),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final selected = index == _currentIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentIndex = index;
                              });
                              controller.jumpToPage(index);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: selected
                                    ? Colors.blue
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? Colors.blue
                                      : Colors.grey.shade400,
                                ),
                              ),
                              child: Text(
                                titles[index],
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 8),
                        itemCount: titles.length,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: controller,
                      onPageChanged: (value) {
                        setState(() {
                          _currentIndex = value;
                        });
                      },
                      children: [
                        _buildExamPage(),
                        KetangpaiHomeworkPage(course: widget.course),
                        const KetangpaiAnswerQuestionPage(),
                        const KetangpaiSourcePage(),
                        const KetangpaiCourseWarePage(),
                        const KetangpaiAnnouncementPage(),
                        const KetangpaiTopicPage(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _quickAction(String title, IconData icon, VoidCallback? onPressed) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade50,
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
