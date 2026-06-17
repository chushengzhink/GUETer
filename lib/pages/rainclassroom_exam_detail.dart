import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/rainclassroom_exam.dart';
import '../models/exam.dart';
import '../utils/rain_auth_manager.dart';

/// 认证失效异常
class _AuthExpiredException implements Exception {
  final String message;
  _AuthExpiredException(this.message);

  @override
  String toString() => message;
}

/// 雨课堂考试答题页面
class RainClassroomExamDetailPage extends StatefulWidget {
  final ExamInfo exam;

  const RainClassroomExamDetailPage({super.key, required this.exam});

  @override
  State<RainClassroomExamDetailPage> createState() =>
      _RainClassroomExamDetailPageState();
}

class _RainClassroomExamDetailPageState
    extends State<RainClassroomExamDetailPage> {
  bool _loading = true;
  String? _errorMessage;

  ExamToken? _examToken;
  Map<String, dynamic>? _examDetail; // 考试详情
  List<ExamProblem> _problems = [];
  final Map<int, ProblemResult> _answers = {}; // problemId -> ProblemResult
  int _currentProblemIndex = 0;

  Timer? _refreshTimer;
  ExamTimeInfo? _timeInfo;

  bool _examStarted = false; // 是否已开始考试

  @override
  void initState() {
    super.initState();
    _loadExamInfo();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 加载考试信息（不加载题目）
  Future<void> _loadExamInfo() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. 生成token
      final tokenResponse = await RainClassroomExamApi.generateExamToken(
        widget.exam.examId,
        widget.exam.classroomId,
      );

      if (tokenResponse == null) {
        throw Exception('生成token失败：网络请求失败');
      }

      // 检查认证失效
      if (tokenResponse['auth_expired'] == true) {
        final msg = tokenResponse['msg'] ?? '登录已过期，请返回课程列表重新登录雨课堂';
        throw _AuthExpiredException(msg);
      }

      if (tokenResponse['status'] == 401 || tokenResponse['status'] == 403) {
        throw _AuthExpiredException('登录已过期，请返回课程列表重新登录雨课堂');
      }

      if (tokenResponse['status'] != 200) {
        final msg = tokenResponse['msg'] ?? '未知错误';
        throw Exception('生成token失败: $msg');
      }

      final tokenData = tokenResponse['data'];
      if (tokenData == null) {
        throw Exception('生成token失败：返回数据为空');
      }

      _examToken = ExamToken.fromJson(tokenData);

      // 2. 登录考试系统
      final loginResponse = await RainClassroomExamApi.loginExamSystem(
        examId: widget.exam.examId,
        userId: _examToken!.userId,
        token: _examToken!.token,
        examHost: _examToken!.examHost,
      );

      if (loginResponse == null) {
        throw Exception('登录考试系统失败：网络请求失败');
      }

      // 检查认证失效
      if (loginResponse['auth_expired'] == true) {
        final msg = loginResponse['msg'] ?? '考试系统登录失败，认证已过期';
        throw _AuthExpiredException(msg);
      }

      if (loginResponse['status'] == 401 || loginResponse['status'] == 403) {
        throw _AuthExpiredException('考试系统登录失败，认证已过期');
      }

      if (loginResponse['status'] != 200) {
        final msg = loginResponse['msg'] ?? '未知错误';
        throw Exception('登录考试系统失败: $msg');
      }

      // 3. 获取考试详情
      final detailResponse = await RainClassroomExamApi.getExamDetail(
        widget.exam.examId,
        _examToken!.examHost,
      );

      if (detailResponse == null) {
        throw Exception('获取考试详情失败：网络请求失败');
      }

      if (detailResponse['errcode'] != 0) {
        final msg = detailResponse['errmsg'] ?? '未知错误';
        throw Exception('获取考试详情失败: $msg');
      }

      setState(() {
        _examDetail = detailResponse['data'];
        _loading = false;
      });
    } on _AuthExpiredException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _loading = false;
      });
      // 显示认证失效对话框
      if (mounted) {
        _showAuthExpiredDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// 显示认证失效对话框
  Future<void> _showAuthExpiredDialog() async {
    final success = await RainAuthManager.showAuthExpiredDialog(
      context,
      onLoginSuccess: () {
        // 登录成功后重新加载考试信息
        if (mounted) {
          _loadExamInfo();
        }
      },
    );

    // 如果用户选择返回而非重新登录，则返回上一页
    if (!success && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 开始考试（加载题目）
  Future<void> _startExam() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. 获取试卷内容
      final paperResponse = await RainClassroomExamApi.getExamPaper(
        widget.exam.examId,
        _examToken!.examHost,
      );

      if (paperResponse == null || paperResponse['errcode'] != 0) {
        throw Exception('获取试卷失败');
      }

      final problemsData = paperResponse['data']['problems'] as List;
      _problems = problemsData.map((e) => ExamProblem.fromJson(e)).toList();

      // 2. 获取缓存答案
      final cachedResponse = await RainClassroomExamApi.getCachedResults(
        widget.exam.examId,
        _examToken!.examHost,
      );

      if (cachedResponse != null && cachedResponse['errcode'] == 0) {
        final results = cachedResponse['data']['results'] as List?;
        if (results != null) {
          for (var result in results) {
            final pr = ProblemResult.fromJson(result);
            _answers[pr.problemId] = pr;
          }
        }
      }

      // 3. 启动定时刷新
      _startRefreshTimer();

      setState(() {
        _examStarted = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '开始考试失败: $e';
        _loading = false;
      });
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _refreshTime();
    });
    _refreshTime();
  }

  Future<void> _refreshTime() async {
    if (_examToken == null) return;

    final response = await RainClassroomExamApi.refreshExamTime(
      widget.exam.examId,
      _examToken!.examHost,
    );

    if (response != null && response['errcode'] == 0) {
      setState(() {
        _timeInfo = ExamTimeInfo.fromJson(response['data']);
      });
    }
  }

  Future<void> _saveAnswer() async {
    if (_examToken == null) return;

    final results = _answers.values.map((e) => e.toJson()).toList();
    final record = _answers.keys.toList();

    await RainClassroomExamApi.saveAnswer(
      examId: widget.exam.examId,
      examHost: _examToken!.examHost,
      results: results,
      record: record,
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('答案已保存')));
    }
  }

  Future<void> _submitPaper() async {
    if (_examToken == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认提交'),
        content: const Text('提交后将无法修改答案，确定要提交吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final results = _answers.values.map((e) => e.toJson()).toList();
    final record = _answers.keys.toList();

    final response = await RainClassroomExamApi.submitPaper(
      examId: widget.exam.examId,
      examHost: _examToken!.examHost,
      results: results,
      record: record,
    );

    if (mounted) {
      if (response != null && response['errcode'] == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提交成功')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提交失败')));
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final problem = _problems[_currentProblemIndex];
    final imageUrl = image.path;

    setState(() {
      _answers[problem.problemId] = ProblemResult.withImage(
        problem.problemId,
        imageUrl,
      );
    });

    _saveAnswer();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    final problem = _problems[_currentProblemIndex];
    final imageUrl = image.path;

    setState(() {
      _answers[problem.problemId] = ProblemResult.withImage(
        problem.problemId,
        imageUrl,
      );
    });

    _saveAnswer();
  }

  void _previousProblem() {
    if (_currentProblemIndex > 0) {
      setState(() {
        _currentProblemIndex--;
      });
    }
  }

  void _nextProblem() {
    if (_currentProblemIndex < _problems.length - 1) {
      setState(() {
        _currentProblemIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam.title),
        actions: [
          if (_examStarted && _timeInfo != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _formatTimeLeft(_timeInfo!.timeLeft),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          if (_examStarted)
            IconButton(icon: const Icon(Icons.save), onPressed: _saveAnswer),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _examStarted ? _buildBottomBar() : null,
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
              onPressed: _examStarted ? _startExam : _loadExamInfo,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    // 未开始考试，显示考试信息
    if (!_examStarted) {
      return _buildExamInfoView();
    }

    // 已开始考试，显示题目
    if (_problems.isEmpty) {
      return const Center(child: Text('暂无题目'));
    }

    final problem = _problems[_currentProblemIndex];
    final answer = _answers[problem.problemId];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProblemHeader(problem),
          const SizedBox(height: 16),
          _buildProblemBody(problem),
          const SizedBox(height: 24),
          _buildAnswerSection(problem, answer),
        ],
      ),
    );
  }

  Widget _buildExamInfoView() {
    if (_examDetail == null) {
      return const Center(child: Text('加载中...'));
    }

    final detail = _examDetail!;
    final startTime = detail['start_time'] != null
        ? DateTime.fromMillisecondsSinceEpoch(detail['start_time'])
        : null;
    final deadline = detail['deadline'] != null
        ? DateTime.fromMillisecondsSinceEpoch(detail['deadline'])
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              detail['title'] ?? widget.exam.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          _buildInfoRow(
            Icons.quiz_outlined,
            '题目数量',
            '${detail['problem_count'] ?? 0} 题',
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.score_outlined,
            '总分',
            '${detail['total_score'] ?? 0} 分',
          ),
          const SizedBox(height: 16),
          if (startTime != null)
            _buildInfoRow(
              Icons.access_time,
              '开始时间',
              _formatDateTime(startTime),
            ),
          if (startTime != null) const SizedBox(height: 16),
          if (deadline != null)
            _buildInfoRow(Icons.event, '截止时间', _formatDateTime(deadline)),
          if (deadline != null) const SizedBox(height: 16),
          if (detail['show_answer'] == true)
            _buildInfoRow(Icons.visibility, '显示答案', '是'),
          if (detail['show_answer'] == true) const SizedBox(height: 16),
          if (detail['show_score'] == true)
            _buildInfoRow(Icons.grade, '显示分数', '是'),
          if (detail['description'] != null &&
              detail['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '考试说明',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(detail['description']),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _startExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                '确认开考',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    );
  }

  Widget _buildProblemHeader(ExamProblem problem) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '第 ${problem.index + 1} 题',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(problem.typeText),
        ),
        const Spacer(),
        Text(
          '${problem.score} 分',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProblemBody(ExamProblem problem) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _stripHtml(problem.body),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildAnswerSection(ExamProblem problem, ProblemResult? answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '答案',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (answer == null || answer.isEmpty)
          _buildEmptyAnswer()
        else
          _buildAnswerPreview(answer),
        const SizedBox(height: 16),
        _buildAnswerActions(),
      ],
    );
  }

  Widget _buildEmptyAnswer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text('尚未作答', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildAnswerPreview(ProblemResult answer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('已作答（图片）'),
    );
  }

  Widget _buildAnswerActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library),
            label: const Text('从相册选择'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text('拍照'),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: _currentProblemIndex > 0 ? _previousProblem : null,
            child: const Text('上一题'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: Text(
                '${_currentProblemIndex + 1} / ${_problems.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_currentProblemIndex < _problems.length - 1)
            ElevatedButton(onPressed: _nextProblem, child: const Text('下一题'))
          else
            ElevatedButton(
              onPressed: _submitPaper,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('提交试卷'),
            ),
        ],
      ),
    );
  }

  String _formatTimeLeft(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }
}
