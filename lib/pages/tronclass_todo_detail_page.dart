import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';

class TronclassTodoDetailPage extends StatefulWidget {
  final Map<String, dynamic> todo;

  const TronclassTodoDetailPage({super.key, required this.todo});

  @override
  State<TronclassTodoDetailPage> createState() =>
      _TronclassTodoDetailPageState();
}

class _TronclassTodoDetailPageState extends State<TronclassTodoDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _distribute;
  List<dynamic> _subjects = [];
  Map<int, List<int>> _answers = {};
  String? _error;

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
      final id = widget.todo['id'];

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

    if (shouldStart != true) return;

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
      final id = widget.todo['id'];

      final distributeEndpoint = type == 'questionnaire'
          ? '/api/questionnaire/$id/distribute'
          : '/api/${type}s/$id/distribute';

      final distributeResponse = await ApiService.sendRequest(distributeEndpoint);
      final distribute = distributeResponse.data;

      if (!mounted) return;
      setState(() {
        _distribute = distribute;
        _subjects = distribute['subjects'] ?? [];
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂未找到畅课，请手动完成')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂未找到畅课，请手动完成')),
      );
    }
  }

  Future<void> _saveAnswer() async {
    try {
      final type = widget.todo['type']?.toString() ?? '';
      final id = widget.todo['id'];
      final instanceId = _distribute?['exam_paper_instance_id'];

      if (instanceId == null) {
        throw Exception('无法获取试卷实例ID');
      }

      final subjects = _subjects.map((subject) {
        final subjectId = subject['id'];
        final answerOptionIds = _answers[subjectId] ?? [];

        return {
          'subject_id': subjectId,
          'answer_option_ids': answerOptionIds,
        };
      }).toList();

      final endpoint = type == 'questionnaire'
          ? '/api/questionnaire/$id/submissions/storage'
          : '/api/${type}s/$id/submissions/storage';

      await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: {
          'exam_paper_instance_id': instanceId,
          'subjects': subjects,
          if (type == 'exam') 'examFinished': false,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('答案已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
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
      final instanceId = _distribute?['exam_paper_instance_id'];

      if (instanceId == null) {
        throw Exception('无法获取试卷实例ID');
      }

      final subjects = _subjects.map((subject) {
        final subjectId = subject['id'];
        final answerOptionIds = _answers[subjectId] ?? [];

        return {
          'subject_id': subjectId,
          'answer_option_ids': answerOptionIds,
        };
      }).toList();

      final endpoint = type == 'questionnaire'
          ? '/api/questionnaire/$id/submissions'
          : '/api/${type}s/$id/submissions';

      await ApiService.sendRequest(
        endpoint,
        method: 'POST',
        body: {
          'exam_paper_instance_id': instanceId,
          'subjects': subjects,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提交成功')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败: $e')),
      );
    }
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
                      Text('加载失败', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
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
                      child: const Text('开始答题', style: TextStyle(fontSize: 16)),
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
    final scorePercentage = _detail?['data']?['score_percentage']?.toString() ?? '';
    final referenceAnswer = _detail?['data']?['reference_answer']?.toString() ?? '';

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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                Container(
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
                          '作业提交功能暂未实现，请前往畅课APP完成提交',
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamInfoView(String courseName, String endTimeStr) {
    final description = _detail?['data']?['description']?.toString() ?? '';
    final startTime = _detail?['start_time']?.toString() ?? '';
    final endTime = _detail?['end_time']?.toString() ?? '';
    final scorePercentage = _detail?['data']?['score_percentage']?.toString() ?? '';
    final totalScore = _detail?['total_score']?.toString() ?? '';
    final announceScoreStatus = _detail?['announce_score_status']?.toString() ?? '';
    final announceAnswerStatus = _detail?['announce_answer_status']?.toString() ?? '';
    final completionCriterion = _detail?['completion_criterion']?.toString() ?? '';

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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(startTime).toLocal()),
                  ),
                if (endTime.isNotEmpty)
                  _buildInfoRow(
                    '结束时间',
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(endTime).toLocal()),
                  ),
                if (scorePercentage.isNotEmpty)
                  _buildInfoRow('成绩占比', '$scorePercentage%'),
                if (totalScore.isNotEmpty)
                  _buildInfoRow('总分', totalScore),
                if (announceScoreStatus.isNotEmpty)
                  _buildInfoRow('成绩公布', _getAnnounceLabel(announceScoreStatus)),
                if (announceAnswerStatus.isNotEmpty)
                  _buildInfoRow('答案公布', _getAnnounceLabel(announceAnswerStatus)),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
            ...options.asMap().entries.map((entry) {
              final option = entry.value as Map<String, dynamic>;
              final optionId = option['id'] as int;
              final content = option['content']?.toString() ?? '';
              final isSelected = _answers[subjectId]?.contains(optionId) ?? false;

              if (type == 'single_selection') {
                return RadioListTile<int>(
                  title: _buildMathText(content),
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
              } else {
                return CheckboxListTile(
                  title: _buildMathText(content),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _answers[subjectId] = [...(_answers[subjectId] ?? []), optionId];
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
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMathText(String text) {
    final stripped = _stripHtml(text);
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

  List<Map<String, dynamic>> _splitMathText(String text) {
    final parts = <Map<String, dynamic>>[];
    final regex = RegExp(r'\\\((.*?)\\\)|\\\[(.*?)\\\]');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        parts.add({'text': text.substring(lastEnd, match.start), 'isMath': false});
      }

      final mathContent = match.group(1) ?? match.group(2) ?? '';
      parts.add({'text': mathContent, 'isMath': true});
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      parts.add({'text': text.substring(lastEnd), 'isMath': false});
    }

    return parts;
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
