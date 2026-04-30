import 'package:flutter/material.dart';
import '../api/rainclassroom_exam.dart';
import '../models/exam.dart';
import 'rainclassroom_exam_detail.dart';

/// 雨课堂考试列表页面
class RainClassroomExamListPage extends StatefulWidget {
  const RainClassroomExamListPage({super.key});

  @override
  State<RainClassroomExamListPage> createState() => _RainClassroomExamListPageState();
}

class _RainClassroomExamListPageState extends State<RainClassroomExamListPage> {
  List<ExamInfo> _exams = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await RainClassroomExamApi.getExamList();

      if (response == null) {
        setState(() {
          _errorMessage = '网络请求失败，请检查网络连接';
          _loading = false;
        });
        return;
      }

      // 检查认证失效
      if (response['auth_expired'] == true || response['code'] == 50000) {
        setState(() {
          _errorMessage = '登录已过期，请返回课程列表页面重新登录雨课堂';
          _loading = false;
        });
        return;
      }

      if (response['code'] == 0) {
        final data = response['data'];
        final upcomingExams = data['upcomingExam'] as List?;

        if (upcomingExams != null) {
          setState(() {
            _exams = upcomingExams.map((e) => ExamInfo.fromJson(e)).toList();
            _loading = false;
          });
        } else {
          setState(() {
            _exams = [];
            _loading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = response['msg'] ?? '获取考试列表失败';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载失败: $e';
        _loading = false;
      });
    }
  }

  String _formatTime(int timestamp) {
    final utcDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
    final beijingDate = utcDate.add(const Duration(hours: 8));
    return '${beijingDate.year}-${beijingDate.month.toString().padLeft(2, '0')}-${beijingDate.day.toString().padLeft(2, '0')} '
        '${beijingDate.hour.toString().padLeft(2, '0')}:${beijingDate.minute.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(int seconds) {
    if (seconds < 0) return '已过期';

    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (days > 0) {
      return '剩余 $days 天 $hours 小时';
    } else if (hours > 0) {
      return '剩余 $hours 小时 $minutes 分钟';
    } else {
      return '剩余 $minutes 分钟';
    }
  }

  void _enterExam(ExamInfo exam) {
    if (exam.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('考试已过期')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RainClassroomExamDetailPage(exam: exam),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExams,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadExams,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_exams.isEmpty) {
      return const Center(
        child: Text('暂无考试'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExams,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _exams.length,
        itemBuilder: (context, index) {
          final exam = _exams[index];
          return _buildExamCard(exam);
        },
      ),
    );
  }

  Widget _buildExamCard(ExamInfo exam) {
    final isExpired = exam.isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _enterExam(exam),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已过期',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                exam.classroomName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '截止: ${_formatTime(exam.endTime)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    isExpired ? Icons.error_outline : Icons.timer_outlined,
                    size: 16,
                    color: isExpired ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatRemaining(exam.remainingSeconds),
                    style: TextStyle(
                      fontSize: 14,
                      color: isExpired ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (exam.problemCount != null || exam.totalScore != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (exam.problemCount != null) ...[
                      Icon(Icons.quiz_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${exam.problemCount} 题',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (exam.totalScore != null) ...[
                      Icon(Icons.score_outlined, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '总分 ${exam.totalScore}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
