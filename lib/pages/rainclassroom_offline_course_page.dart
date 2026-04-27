import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../api/rainclassroom_exam.dart';
import '../models/course.dart';
import '../models/exam.dart';
import '../utils/global_palette.dart';
import '../utils/rain_auth_manager.dart';
import '../platform.dart';
import '../session/app_settings.dart';

class RainClassroomOfflineCoursePage extends StatefulWidget {
  final Course course;

  const RainClassroomOfflineCoursePage({super.key, required this.course});

  @override
  State<RainClassroomOfflineCoursePage> createState() =>
      _RainClassroomOfflineCoursePageState();
}

class _RainClassroomOfflineCoursePageState
    extends State<RainClassroomOfflineCoursePage> {
  bool _loading = true;
  Map<String, dynamic>? _classroomDetail;
  List<dynamic> _learnLogs = [];
  List<dynamic> _exams = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCourseDetail();
  }

  Future<void> _loadCourseDetail() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final classroomId = widget.course.classId ?? '';
      if (classroomId.isEmpty) {
        throw Exception('课程ID为空');
      }

      // 并行请求课程详情、学习记录和考试列表
      final results = await Future.wait([
        _fetchClassroomDetail(classroomId),
        _fetchLearnLogs(classroomId),
        _fetchExams(classroomId),
      ]);

      if (!mounted) return;

      setState(() {
        _classroomDetail = results[0] as Map<String, dynamic>?;
        _learnLogs = results[1] as List<dynamic>;
        _exams = results[2] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchClassroomDetail(String classroomId) async {
    try {
      final response = await ApiService.sendRequest(
        '/v2/api/web/classrooms/$classroomId',
        params: {'role': '5'},
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['errcode'] == 0 && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('获取课程详情失败: $e');
      return null;
    }
  }

  Future<List<dynamic>> _fetchLearnLogs(String classroomId) async {
    try {
      final response = await ApiService.sendRequest(
        '/v2/api/web/logs/learn/$classroomId',
        params: {
          'actype': '-1',
          'page': '0',
          'offset': '20',
          'sort': '-1',
        },
      );

      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        if (data['errcode'] == 0 && data['data'] != null) {
          final activities = data['data']['activities'];
          if (activities is List) {
            return activities;
          }
        }
      }
      return [];
    } catch (e) {
      debugPrint('获取学习记录失败: $e');
      return [];
    }
  }

  Future<List<dynamic>> _fetchExams(String classroomId) async {
    try {
      // 获取即将到来的考试
      final upcomingResponse = await ApiService.sendRequest(
        '/api/v3/classroom/on-lesson-upcoming-exam',
      );

      List<dynamic> exams = [];

      if (upcomingResponse.data is Map<String, dynamic>) {
        final data = upcomingResponse.data as Map<String, dynamic>;

        // 检查认证失效
        final code = data['code'];
        final msg = data['msg']?.toString() ?? '';
        if (code == 50000 || msg.toUpperCase().contains('UNAUTHENTICATED')) {
          debugPrint('获取考试列表: 认证失效');
          // 返回空列表，不抛出异常，避免影响其他数据加载
          return [];
        }

        if (data['code'] == 0 && data['data'] != null) {
          final upcomingExam = data['data']['upcomingExam'];
          if (upcomingExam is List) {
            exams.addAll(upcomingExam.where((exam) {
              if (exam is Map) {
                return exam['classroom_id'].toString() == classroomId;
              }
              return false;
            }));
          }
        }
      }

      // 获取学习记录中的考试活动
      try {
        final logsResponse = await ApiService.sendRequest(
          '/v2/api/web/logs/learn/$classroomId',
          params: {
            'actype': '5', // 5表示考试类型
            'page': '0',
            'offset': '50',
            'sort': '-1',
          },
        );

        if (logsResponse.data is Map<String, dynamic>) {
          final data = logsResponse.data as Map<String, dynamic>;
          if (data['errcode'] == 0 && data['data'] != null) {
            final activities = data['data']['activities'];
            if (activities is List) {
              for (var activity in activities) {
                if (activity is Map && activity['type'] == 5) {
                  // 避免重复添加
                  final examId = activity['id']?.toString() ?? '';
                  if (examId.isNotEmpty && !exams.any((e) => e['id']?.toString() == examId)) {
                    exams.add(activity);
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('获取学习记录中的考试失败: $e');
        // 继续返回已获取的考试列表
      }

      return exams;
    } catch (e) {
      debugPrint('获取考试列表失败: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = resolvePlatformPalette(
      PlatformManager().currentPlatform,
      fallback: resolveGlobalPalette(AppSettings.globalColorSchemeNotifier.value),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.course.name,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: palette.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourseDetail,
          ),
        ],
      ),
      body: _buildBody(palette),
    );
  }

  Widget _buildBody(GlobalPaletteData palette) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourseDetail,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCourseInfoCard(palette),
          const SizedBox(height: 16),
          _buildExamsSection(palette),
          const SizedBox(height: 16),
          _buildLearnLogsSection(palette),
        ],
      ),
    );
  }

  Widget _buildCourseInfoCard(GlobalPaletteData palette) {
    if (_classroomDetail == null) {
      return const SizedBox.shrink();
    }

    final detail = _classroomDetail!;
    final courseName = detail['course_name']?.toString() ?? '未知课程';
    final teacherName = detail['teacher_name']?.toString() ?? '未知教师';
    final teacherAvatar = detail['teacher_avatar']?.toString() ?? '';
    final studentsCount = detail['students_count']?.toString() ?? '0';
    final courseSign = detail['course_sign']?.toString() ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school,
                    color: palette.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '课程代码: $courseSign',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('教师', teacherName, Icons.person),
            const SizedBox(height: 8),
            _buildInfoRow('学生人数', '$studentsCount人', Icons.people),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLearnLogsSection(GlobalPaletteData palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学习记录',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: palette.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (_learnLogs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '暂无学习记录',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._learnLogs.map((log) => _buildLearnLogCard(log, palette)),
      ],
    );
  }

  Widget _buildExamsSection(GlobalPaletteData palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '考试列表',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: palette.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (_exams.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.quiz, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '暂无考试',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._exams.map((exam) => _buildExamCard(exam, palette)),
      ],
    );
  }

  Widget _buildExamCard(dynamic exam, GlobalPaletteData palette) {
    if (exam is! Map) return const SizedBox.shrink();

    final title = exam['title']?.toString() ?? '未知考试';
    final examId = exam['id']?.toString() ?? '';
    final startTime = exam['start_time'];
    final endTime = exam['end_time'];

    String statusText = '';
    String timeRangeText = '';
    Color statusColor = Colors.grey;

    if (startTime != null && endTime != null) {
      try {
        final start = DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
        final end = DateTime.fromMillisecondsSinceEpoch(endTime * 1000);
        final now = DateTime.now();

        final dateFormat = DateFormat('MM-dd HH:mm');
        timeRangeText = '${dateFormat.format(start)} - ${dateFormat.format(end)}';

        if (now.isBefore(start)) {
          statusText = '未开始';
          statusColor = Colors.blue;
        } else if (now.isAfter(end)) {
          statusText = '已结束';
          statusColor = Colors.grey;
        } else {
          statusText = '进行中';
          statusColor = Colors.green;
        }
      } catch (e) {
        timeRangeText = '';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.quiz, color: Colors.orange, size: 24),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timeRangeText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      timeRangeText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
            if (statusText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          if (examId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('考试ID无效')),
            );
            return;
          }

          // 使用 Chrome Custom Tabs 打开考试页面
          try {
            // 1. 生成考试 token
            final tokenResponse = await RainClassroomExamApi.generateExamToken(
              examId,
              widget.course.classId ?? '',
            );

            if (tokenResponse == null || tokenResponse['status'] != 200) {
              throw Exception('生成考试token失败');
            }

            final tokenData = tokenResponse['data'];
            if (tokenData == null) {
              throw Exception('考试token数据为空');
            }

            final token = tokenData['token'];
            final examHost = tokenData['exam_host'] ?? 'https://examination.xuetangx.com';
            final userId = tokenData['user_id']?.toString() ?? '';

            // 2. 构造考试登录 URL（移动端）
            final nextUrl = Uri.encodeComponent('$examHost/exam/$examId?isFrom=2&platform=mobile');
            final examUrl = '$examHost/login?exam_id=$examId&user_id=$userId&crypt=${Uri.encodeComponent(token)}&next=$nextUrl&language=zh&platform=mobile';

            // 3. 使用系统浏览器打开考试链接（Chrome Custom Tabs）
            final uri = Uri.parse(examUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            } else {
              throw Exception('无法打开考试链接');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('打开考试失败: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildLearnLogCard(dynamic log, GlobalPaletteData palette) {
    if (log is! Map) return const SizedBox.shrink();

    final title = log['title']?.toString() ?? '未知活动';
    final type = log['type']?.toString() ?? '';
    final time = log['time']?.toString() ?? '';

    IconData icon = Icons.article;
    Color iconColor = palette.primary;

    // 根据类型设置图标
    if (type.contains('video')) {
      icon = Icons.play_circle_outline;
      iconColor = Colors.blue;
    } else if (type.contains('exam') || type.contains('test')) {
      icon = Icons.quiz;
      iconColor = Colors.orange;
    } else if (type.contains('homework')) {
      icon = Icons.assignment;
      iconColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title),
        subtitle: time.isNotEmpty ? Text(time) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final activityId = log['id']?.toString() ?? '';
          if (activityId.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('活动ID无效')),
            );
            return;
          }

          try {
            // 直接构造移动端学习内容URL（雨课堂会自动使用当前浏览器的登录态）
            // 使用 m.yuketang.cn 移动端域名确保加载移动版界面
            final contentUrl = 'https://m.yuketang.cn/v2/web/studentCourse/${widget.course.classId}/activity/$activityId';
            final uri = Uri.parse(contentUrl);

            if (await canLaunchUrl(uri)) {
              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            } else {
              throw Exception('无法打开学习内容');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('打开学习内容失败: $e')),
              );
            }
          }
        },
      ),
    );
  }
}
