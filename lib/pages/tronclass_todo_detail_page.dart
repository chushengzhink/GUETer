// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';
import '../api/tronclass_homework_upload_api.dart';

class TronclassTodoDetailPage extends StatefulWidget {
  final Map<String, dynamic> todo;

  const TronclassTodoDetailPage({super.key, required this.todo});

  @override
  State<TronclassTodoDetailPage> createState() =>
      _TronclassTodoDetailPageState();
}

class _TronclassTodoDetailPageState extends State<TronclassTodoDetailPage> {
  bool _loading = true;
  bool _submittingHomework = false;
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _distribute;
  List<dynamic> _subjects = [];
  final Map<int, List<int>> _answers = {};
  final List<File> _selectedHomeworkFiles = <File>[];
  final _homeworkUploadApi = const TronclassHomeworkUploadApi();
  String? _error;
  String? _classroomExamStartTime;
  String? _homeworkProgress;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final type = widget.todo['type']?.toString() ?? '';
      final id = _intId(widget.todo['id']);

      if (type == 'homework') {
        await _loadHomeworkDetail(id);
      } else {
        await _loadExamOrQuestionnaireDetail(type, id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadHomeworkDetail(int id) async {
    final response = await ApiService.sendRequest('/api/activities/$id');
    final detail = response.data;

    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _loadExamOrQuestionnaireDetail(String type, int id) async {
    String endpoint;
    if (type == 'exam') {
      endpoint = '/api/exams/$id';
    } else if (type == 'questionnaire') {
      endpoint = '/api/questionnaires/$id';
    } else if (type == 'classroom') {
      endpoint = '/api/classroom-exams/$id';
    } else {
      throw Exception('不支持的类型: $type');
    }

    final response = await ApiService.sendRequest(endpoint);
    final detail = response.data;

    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _startExam() async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('答题提示'),
        content: const Text('建议从畅课APP原生答题，本应用答题模式并不完善。'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context, false);
              await _launchTronclassApp();
            },
            child: const Text('跳转畅课APP'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (shouldStart != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认'),
        content: const Text('是否确认在此答题？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _loadDistributeAndStartExam();
  }

  Future<void> _loadDistributeAndStartExam() async {
    setState(() => _loading = true);

    try {
      final type = widget.todo['type']?.toString() ?? '';
      final id = _intId(widget.todo['id']);

      final distributeEndpoint = _distributeEndpoint(type, id);

      final distributeResponse = await ApiService.sendRequest(
        distributeEndpoint,
      );
      final distribute = distributeResponse.data;

      if (!mounted) return;
      setState(() {
        _distribute = distribute;
        _subjects = distribute['subjects'] ?? [];
        if (type == 'classroom') {
          _classroomExamStartTime ??= _utcIsoSeconds(DateTime.now());
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _launchTronclassApp() async {
    const packageName = 'com.wisdomgarden.trpc';
    final uri = Uri.parse('intent://#Intent;package=$packageName;end');

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂未找到畅课，请手动完成')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂未找到畅课，请手动完成')));
    }
  }

  Future<void> _pickHomeworkFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    _addHomeworkFiles(
      result.files.map((file) => file.path).whereType<String>().map(File.new),
    );
  }

  Future<void> _pickHomeworkImages() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isEmpty || !mounted) return;
    _addHomeworkFiles(images.map((image) => File(image.path)));
  }

  Future<void> _pickHomeworkVideo() async {
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video == null || !mounted) return;
    _addHomeworkFiles(<File>[File(video.path)]);
  }

  void _addHomeworkFiles(Iterable<File> files) {
    final existingPaths = _selectedHomeworkFiles
        .map((file) => file.path)
        .toSet();
    final additions = files
        .where((file) => file.path.isNotEmpty && existingPaths.add(file.path))
        .toList(growable: false);
    if (additions.isEmpty) return;
    setState(() {
      _selectedHomeworkFiles.addAll(additions);
    });
  }

  void _removeHomeworkFile(File file) {
    setState(() {
      _selectedHomeworkFiles.removeWhere((item) => item.path == file.path);
    });
  }

  Future<void> _submitHomeworkUpload() async {
    if (_selectedHomeworkFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择要提交的附件')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认提交'),
        content: Text(
          '将提交 ${_selectedHomeworkFiles.length} 个附件。提交后请以畅课平台状态为准。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('提交'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submittingHomework = true;
      _homeworkProgress = '准备上传';
    });

    try {
      await _homeworkUploadApi.uploadAndSubmit(
        activityId: _intId(widget.todo['id']),
        files: List<File>.from(_selectedHomeworkFiles),
        onProgress: (index, total, message) {
          if (!mounted) return;
          setState(() {
            _homeworkProgress = '$message ($index/$total)';
          });
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('作业提交成功')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingHomework = false;
        _homeworkProgress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败: ${_friendlySubmitError(e)}')),
      );
    }
  }

  Future<void> _saveAnswer() async {
    try {
      final type = widget.todo['type']?.toString() ?? '';
      final id = widget.todo['id'];

      if (type == 'classroom') {
        await _submitClassroomAnswer(_intId(id));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('答案已保存')));
        return;
      }

      final instanceId = _distribute?['exam_paper_instance_id'];

      if (instanceId == null) {
        throw Exception('无法获取试卷实例ID');
      }

      final subjects = _subjects.map((subject) {
        final subjectId = subject['id'];
        final answerOptionIds = _answers[subjectId] ?? [];

        return {'subject_id': subjectId, 'answer_option_ids': answerOptionIds};
      }).toList();

      final endpoint = _storageEndpoint(type, _intId(id));

      await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: {
          'exam_paper_instance_id': instanceId,
          'subjects': subjects,
          if (type == 'exam' || type == 'classroom') 'examFinished': false,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('答案已保存')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: ${_friendlySubmitError(e)}')),
      );
    }
  }

  Future<void> _submitAnswer() async {
    final unansweredCount = _subjects.where((subject) {
      final subjectId = subject['id'] as int;
      final answers = _answers[subjectId] ?? [];
      return answers.isEmpty;
    }).length;

    if (unansweredCount > 0) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: Text('还有 $unansweredCount 道题未作答，确定要提交吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续提交'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    } else {
      final shouldSubmit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认提交'),
          content: const Text('确定要提交答案吗？提交后将无法修改。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定提交'),
            ),
          ],
        ),
      );

      if (shouldSubmit != true) return;
    }

    try {
      final type = widget.todo['type']?.toString() ?? '';
      final id = widget.todo['id'];

      if (type == 'classroom') {
        await _submitClassroomAnswer(_intId(id));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提交成功')));
        Navigator.pop(context, true);
        return;
      }

      final instanceId = _distribute?['exam_paper_instance_id'];

      if (instanceId == null) {
        throw Exception('无法获取试卷实例ID');
      }

      final subjects = _subjects.map((subject) {
        final subjectId = subject['id'];
        final answerOptionIds = _answers[subjectId] ?? [];

        return {'subject_id': subjectId, 'answer_option_ids': answerOptionIds};
      }).toList();

      final endpoint = _submitEndpoint(type, _intId(id));

      await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: {'exam_paper_instance_id': instanceId, 'subjects': subjects},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提交成功')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败: ${_friendlySubmitError(e)}')),
      );
    }
  }

  Future<void> _submitClassroomAnswer(int classroomId) async {
    final instanceId = _distribute?['exam_paper_instance_id'];
    if (instanceId == null) {
      throw Exception('无法获取试卷实例ID');
    }
    if (_subjects.isEmpty) {
      throw Exception('未加载到互动测试题目');
    }

    _classroomExamStartTime ??= _utcIsoSeconds(DateTime.now());
    final subjectId = _classroomSubmitSubjectId();
    final endpoint = '/api/classroom/$classroomId/submit/$subjectId';

    await ApiService.sendRequest(
      endpoint,
      method: 'POST',
      body: {
        'subjects': _classroomSubmissionSubjects(),
        'exam_paper_instance_id': instanceId,
        'exam_start_time': _classroomExamStartTime,
      },
    );
  }

  int _classroomSubmitSubjectId() {
    int? fallbackSubjectId;
    int? lastAnsweredSubjectId;

    for (final subject in _subjects) {
      if (subject is! Map) continue;
      final subjectId = _intId(subject['id']);
      if (subjectId == 0) continue;
      fallbackSubjectId = subjectId;
      if ((_answers[subjectId] ?? const <int>[]).isNotEmpty) {
        lastAnsweredSubjectId = subjectId;
      }
    }

    final subjectId = lastAnsweredSubjectId ?? fallbackSubjectId;
    if (subjectId == null) {
      throw Exception('无法获取互动测试题目ID');
    }
    return subjectId;
  }

  List<Map<String, dynamic>> _classroomSubmissionSubjects() {
    return _subjects.whereType<Map>().map((subject) {
      final subjectId = _intId(subject['id']);
      return {
        'subject_id': subjectId,
        'answer': '',
        'answer_option_ids': _answers[subjectId] ?? const <int>[],
        'correct_answers': const [],
        'answers': const [],
        'attachments': const [],
        'content': '',
        'alternates': const [],
        'sort': _intId(subject['sort']),
      };
    }).toList();
  }

  String _utcIsoSeconds(DateTime value) {
    return '${value.toUtc().toIso8601String().split('.').first}Z';
  }

  String _friendlySubmitError(Object error) {
    if (error is TronclassHomeworkUploadException) {
      return error.message;
    }
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return '互动测试提交接口返回 $statusCode';
      }
      return '网络请求失败，请稍后重试';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _exportQuestions() async {
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先进入测试并加载题目后再导出')));
      return;
    }

    final text = _buildExportText();
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可导出的题目内容')));
      return;
    }

    await Share.share(
      text,
      subject: widget.todo['title']?.toString() ?? '测试题目',
    );
  }

  String _buildExportText() {
    final buffer = StringBuffer();
    final title = widget.todo['title']?.toString() ?? '测试';
    final courseName = widget.todo['course_name']?.toString() ?? '';

    if (courseName.isNotEmpty) {
      buffer.writeln('课程：$courseName');
    }
    buffer.writeln('测试：$title');
    buffer.writeln();

    for (var i = 0; i < _subjects.length; i++) {
      final subject = _subjects[i];
      if (subject is! Map<String, dynamic>) continue;
      final description = _plainText(subject['description']?.toString() ?? '');
      buffer.writeln('${i + 1}. $description');

      final options = subject['options'];
      if (options is List) {
        for (var j = 0; j < options.length; j++) {
          final option = options[j];
          if (option is! Map<String, dynamic>) continue;
          buffer.writeln(
            '${_optionLabel(j)}. ${_plainText(option['content']?.toString() ?? '')}',
          );
        }
      }

      if (i != _subjects.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString().trim();
  }

  int _intId(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _distributeEndpoint(String type, int id) {
    if (type == 'questionnaire') return '/api/questionnaire/$id/distribute';
    if (type == 'classroom') return '/api/classroom/$id/distribute';
    return '/api/${type}s/$id/distribute';
  }

  String _storageEndpoint(String type, int id) {
    if (type == 'questionnaire') {
      return '/api/questionnaire/$id/submissions/storage';
    }
    if (type == 'classroom') return '/api/classroom/$id/submissions/storage';
    return '/api/${type}s/$id/submissions/storage';
  }

  String _submitEndpoint(String type, int id) {
    if (type == 'questionnaire') return '/api/questionnaire/$id/submissions';
    if (type == 'classroom') return '/api/classroom/$id/submissions';
    return '/api/${type}s/$id/submissions';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.todo['title']?.toString() ?? '任务详情';
    final courseName = widget.todo['course_name']?.toString() ?? '';
    final endTimeStr = widget.todo['end_time']?.toString() ?? '';
    final type = widget.todo['type']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1DB6C2),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_loading && type != 'homework')
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: _exportQuestions,
              tooltip: '导出题目',
            ),
          if (!_loading && _distribute != null && type != 'homework')
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveAnswer,
              tooltip: '保存答案',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDetail,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          : type == 'homework'
          ? _buildHomeworkView(courseName, endTimeStr)
          : _distribute == null
          ? _buildExamInfoView(courseName, endTimeStr)
          : _buildExamView(courseName, endTimeStr),
      bottomNavigationBar: !_loading && _detail != null
          ? _distribute == null && type != 'homework'
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: _startExam,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB6C2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          '开始答题',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  )
                : _distribute != null
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: _submitAnswer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB6C2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('提交', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  )
                : null
          : null,
    );
  }

  Widget _buildHomeworkView(String courseName, String endTimeStr) {
    final description = _detail?['data']?['description']?.toString() ?? '';
    final homeworkType = _detail?['data']?['homework_type']?.toString() ?? '';
    final scorePercentage =
        _detail?['data']?['score_percentage']?.toString() ?? '';
    final referenceAnswer =
        _detail?['data']?['reference_answer']?.toString() ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (endTimeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '截止时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(endTimeStr).toLocal())}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('作业类型', _getHomeworkTypeLabel(homeworkType)),
                if (scorePercentage.isNotEmpty)
                  _buildInfoRow('分值占比', '$scorePercentage%'),
                const SizedBox(height: 16),
                const Text(
                  '作业要求',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(_stripHtml(description)),
                if (referenceAnswer.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '参考答案',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(_stripHtml(referenceAnswer)),
                ],
                const SizedBox(height: 24),
                if (homeworkType == 'file_upload')
                  _buildHomeworkUploadPanel()
                else
                  _buildUnsupportedHomeworkSubmitNotice(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamInfoView(String courseName, String endTimeStr) {
    final description = _detail?['data']?['description']?.toString() ?? '';
    final startTime =
        _detail?['start_time']?.toString() ??
        _detail?['start_at']?.toString() ??
        widget.todo['start_time']?.toString() ??
        '';
    final endTime =
        _detail?['end_time']?.toString() ??
        _detail?['finish_at']?.toString() ??
        widget.todo['end_time']?.toString() ??
        '';
    final scorePercentage =
        _detail?['data']?['score_percentage']?.toString() ?? '';
    final totalScore = _detail?['total_score']?.toString() ?? '';
    final announceScoreStatus =
        _detail?['announce_score_status']?.toString() ?? '';
    final announceAnswerStatus =
        _detail?['announce_answer_status']?.toString() ?? '';
    final completionCriterion =
        _detail?['completion_criterion']?.toString() ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (endTimeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '截止时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(endTimeStr).toLocal())}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (startTime.isNotEmpty)
                  _buildInfoRow(
                    '开始时间',
                    DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(DateTime.parse(startTime).toLocal()),
                  ),
                if (endTime.isNotEmpty)
                  _buildInfoRow(
                    '结束时间',
                    DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(DateTime.parse(endTime).toLocal()),
                  ),
                if (scorePercentage.isNotEmpty)
                  _buildInfoRow('成绩占比', '$scorePercentage%'),
                if (totalScore.isNotEmpty) _buildInfoRow('总分', totalScore),
                if (announceScoreStatus.isNotEmpty)
                  _buildInfoRow('成绩公布', _getAnnounceLabel(announceScoreStatus)),
                if (announceAnswerStatus.isNotEmpty)
                  _buildInfoRow(
                    '答案公布',
                    _getAnnounceLabel(announceAnswerStatus),
                  ),
                if (completionCriterion.isNotEmpty)
                  _buildInfoRow('完成指标', completionCriterion),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '测试要求',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(_stripHtml(description)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamView(String courseName, String endTimeStr) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courseName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (endTimeStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '截止时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(endTimeStr).toLocal())}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _subjects.length,
            itemBuilder: (context, index) {
              return _buildSubjectCard(_subjects[index], index + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHomeworkUploadPanel() {
    final canSubmit = _selectedHomeworkFiles.isNotEmpty && !_submittingHomework;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '提交附件',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _submittingHomework ? null : _pickHomeworkFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('选择文件'),
            ),
            OutlinedButton.icon(
              onPressed: _submittingHomework ? null : _pickHomeworkImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('选择照片'),
            ),
            OutlinedButton.icon(
              onPressed: _submittingHomework ? null : _pickHomeworkVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('选择视频'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedHomeworkFiles.isEmpty)
          Text('尚未选择附件', style: TextStyle(color: Colors.grey[600]))
        else
          ..._selectedHomeworkFiles.map(_buildSelectedHomeworkFileTile),
        if (_submittingHomework) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(_homeworkProgress ?? '正在提交'),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canSubmit ? _submitHomeworkUpload : null,
            icon: _submittingHomework
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_submittingHomework ? '正在提交' : '提交作业'),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedHomeworkFileTile(File file) {
    final name = p.basename(file.path);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_fileIconFor(name)),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: FutureBuilder<int>(
          future: file.length(),
          builder: (context, snapshot) {
            final size = snapshot.data;
            return Text(size == null ? file.path : _formatFileSize(size));
          },
        ),
        trailing: IconButton(
          tooltip: '移除',
          icon: const Icon(Icons.close),
          onPressed: _submittingHomework
              ? null
              : () => _removeHomeworkFile(file),
        ),
      ),
    );
  }

  Widget _buildUnsupportedHomeworkSubmitNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '该作业类型暂未支持本地提交，请前往畅课 APP 完成提交',
              style: TextStyle(color: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }

  IconData _fileIconFor(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    if (<String>{
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
    }.contains(extension)) {
      return Icons.image_outlined;
    }
    if (<String>{'.mp4', '.mov', '.avi', '.mkv'}.contains(extension)) {
      return Icons.movie_outlined;
    }
    if (extension == '.pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getHomeworkTypeLabel(String type) {
    switch (type) {
      case 'file_upload':
        return '文件上传';
      case 'text':
        return '文本作业';
      case 'url':
        return '网址作业';
      default:
        return type;
    }
  }

  String _getAnnounceLabel(String status) {
    switch (status) {
      case 'immediate_announce':
        return '立即公布';
      case 'no_announce':
        return '不公布';
      case 'after_end_time':
        return '结束后公布';
      default:
        return status;
    }
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, int number) {
    final subjectId = subject['id'] as int;
    final description = subject['description']?.toString() ?? '';
    final options = subject['options'] as List<dynamic>? ?? [];
    final type = subject['type']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第 $number 题',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1DB6C2),
              ),
            ),
            const SizedBox(height: 8),
            _buildMathText(description),
            const SizedBox(height: 16),
            if (type == 'single_selection')
              ...options.asMap().entries.map((entry) {
                final option = entry.value as Map<String, dynamic>;
                final optionId = option['id'] as int;
                final content = option['content']?.toString() ?? '';

                return RadioListTile<int>(
                  title: _buildOptionTitle(entry.key, content),
                  value: optionId,
                  groupValue: _answers[subjectId]?.firstOrNull,
                  onChanged: (value) {
                    setState(() {
                      _answers[subjectId] = value != null ? [value] : [];
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              })
            else
              ...options.asMap().entries.map((entry) {
                final option = entry.value as Map<String, dynamic>;
                final optionId = option['id'] as int;
                final content = option['content']?.toString() ?? '';
                final isSelected =
                    _answers[subjectId]?.contains(optionId) ?? false;

                return CheckboxListTile(
                  title: _buildOptionTitle(entry.key, content),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _answers[subjectId] = [
                          ...(_answers[subjectId] ?? []),
                          optionId,
                        ];
                      } else {
                        _answers[subjectId] = (_answers[subjectId] ?? [])
                            .where((id) => id != optionId)
                            .toList();
                      }
                    });
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMathText(String text) {
    final stripped = _plainText(text);
    final parts = _splitMathText(stripped);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((part) {
        if (part['isMath'] == true) {
          try {
            return Math.tex(
              part['text'] as String,
              textStyle: const TextStyle(fontSize: 16),
            );
          } catch (e) {
            return Text(
              part['text'] as String,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            );
          }
        } else {
          return Text(
            part['text'] as String,
            style: const TextStyle(fontSize: 16),
          );
        }
      }).toList(),
    );
  }

  Widget _buildOptionTitle(int index, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_optionLabel(index)}. ',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Expanded(child: _buildMathText(content)),
      ],
    );
  }

  List<Map<String, dynamic>> _splitMathText(String text) {
    final parts = <Map<String, dynamic>>[];
    final regex = RegExp(
      r'\\\((.*?)\\\)|\\\[(.*?)\\\]|\$\$(.*?)\$\$|\$([^$\n]+)\$',
      dotAll: true,
    );
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        parts.add({
          'text': text.substring(lastEnd, match.start),
          'isMath': false,
        });
      }

      final mathContent =
          match.group(1) ??
          match.group(2) ??
          match.group(3) ??
          match.group(4) ??
          '';
      parts.add({'text': mathContent, 'isMath': true});
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      parts.add({'text': text.substring(lastEnd), 'isMath': false});
    }

    return parts;
  }

  String _stripHtml(String html) {
    return _plainText(html);
  }

  String _plainText(String html) {
    if (html.trim().isEmpty) return '';
    var normalized = html
        .replaceAllMapped(
          RegExp(
            r'''<img[^>]*(?:data-latex|alt|title)=["']([^"']+)["'][^>]*>''',
            caseSensitive: false,
          ),
          (match) => ' ${match.group(1) ?? ''} ',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll('&nbsp;', ' ');

    final document = html_parser.parseFragment(normalized);
    normalized = document.text ?? normalized;
    return normalized
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
  }

  String _optionLabel(int index) {
    const labels = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index >= 0 && index < labels.length) return labels[index];
    return (index + 1).toString();
  }
}
