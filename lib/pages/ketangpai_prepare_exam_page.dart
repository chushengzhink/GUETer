import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../api/course.dart';
import 'ketangpai_exam_execute_page.dart';

class KetangpaiPrepareExamPage extends StatefulWidget {
  final String courseId;
  final String testPaperId;

  const KetangpaiPrepareExamPage({super.key, required this.courseId, required this.testPaperId});

  @override
  State<KetangpaiPrepareExamPage> createState() => _KetangpaiPrepareExamPageState();
}

class _KetangpaiPrepareExamPageState extends State<KetangpaiPrepareExamPage> {
  bool _loading = true;
  Map<String, dynamic> _exam = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final data = await KTCourseApi.getExamInfo(widget.courseId, widget.testPaperId);
    if (!mounted) return;
    final exam = (data?['data']?['testpaper'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    setState(() {
      _exam = exam;
      _loading = false;
    });
  }

  String _stringValue(String key) => _exam[key]?.toString() ?? '';

  String _normalizeUrl(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    if (text.startsWith('//')) return 'https:$text';
    if (text.startsWith('/')) return 'https://openapiv5.ketangpai.com$text';
    return text;
  }

  bool get _isEnded {
    final over = _stringValue('over');
    if (over == '1') return true;

    final end = _stringValue('endtime').trim();
    if (end.isEmpty || end == '不限制') {
      return false;
    }
    final dt = DateTime.tryParse(end);
    if (dt == null) {
      return false;
    }
    return DateTime.now().isAfter(dt);
  }

  bool get _hasLessonLink {
    final lessonLink = _exam['lessonlink'];
    if (lessonLink is List) {
      return lessonLink.isNotEmpty;
    }
    return false;
  }

  String get _subjectCount {
    final direct = _exam['subjectcount'];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }
    final camel = _exam['subjectCount'];
    if (camel != null && camel.toString().isNotEmpty) {
      return camel.toString();
    }
    return '';
  }

  String get _createTimeText {
    final raw = _stringValue('createtime').trim();
    if (raw.isEmpty) {
      return '';
    }
    final timestamp = int.tryParse(raw);
    if (timestamp == null) {
      return raw;
    }
    final normalized = timestamp > 9999999999 ? timestamp : timestamp * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(normalized);
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  int get _submitStatus => int.tryParse(_stringValue('submit_status')) ?? 0;
  int get _submitState => int.tryParse(_stringValue('submit_state')) ?? 0;

  bool get _canViewPaper {
    final state = _submitState;
    final status = _submitStatus;
    if (state == 1 || (state == 2 && status == 1)) {
      return true;
    }
    if (state == 4) {
      return true;
    }
    if (state == 6 || state == 7 || (state == 8 && status == 3)) {
      return true;
    }
    if ((state == 8 && status == 4) || state == 9) {
      return true;
    }
    return false;
  }

  bool get _canContinueAnswer {
    final state = _submitState;
    final status = _submitStatus;
    return state == 2 && status != 1;
  }

  String get _actionButtonText {
    if (_isEnded && !_canContinueAnswer) {
      return _canViewPaper ? '查看试卷' : '已结束不可作答';
    }
    if (_canContinueAnswer) {
      return '继续答题';
    }
    if (_canViewPaper) {
      return '查看试卷';
    }
    return '开始答题';
  }

  void _openExamExecutePage() {
    if (_isEnded && !_canContinueAnswer && !_canViewPaper) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('考试已结束，当前不可作答')),
      );
      return;
    }

    final readOnly = _isEnded && !_canContinueAnswer;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KetangpaiExamExecutePage(
          courseId: widget.courseId,
          testPaperId: widget.testPaperId,
          readOnly: readOnly,
        ),
      ),
    );
  }

  Widget _statusBanner() {
    final submitStatus = _submitStatus;
    final submitState = _submitState;

    if (submitState == 1 || (submitState == 2 && submitStatus == 1)) {
      return _banner(Colors.grey.withValues(alpha: 0.2), Colors.black54, '未参与!', '测试已结束，点击下方“查看试卷”可以查看试卷');
    }
    if (submitState == 2 && submitStatus != 1) {
      return _banner(Colors.orange.withValues(alpha: 0.2), Colors.deepOrange, '未提交！', '您的试卷未提交，可以继续作答哦！');
    }
    if (submitState == 4) {
      return _banner(Colors.blue.withValues(alpha: 0.15), Colors.blueAccent, '成绩未公布，请您耐心等待！', '点击下方“查看试卷”可以查看作答情况');
    }
    if (submitState == 6 || submitState == 7 || (submitState == 8 && submitStatus == 3)) {
      return _banner(Colors.green.withValues(alpha: 0.15), Colors.green, '您的得分：${_stringValue('score')}/${_stringValue('total_score')}', '点击下方“查看试卷”可以查看作答情况');
    }
    if ((submitState == 8 && submitStatus == 4) || submitState == 9) {
      return _banner(Colors.orange.withValues(alpha: 0.15), Colors.deepOrange, '已提交，老师还未批改！', '点击下方“查看试卷”可以查看作答情况');
    }
    return _banner(Colors.greenAccent.withValues(alpha: 0.15), Colors.green, '进行中', '可直接开始答题');
  }

  Widget _banner(Color background, Color color, String title, String subtitle) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: background),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 18)),
                Text(subtitle, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('考试内容'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _statusBanner(),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(_stringValue('over') == '1' ? '已结束' : '进行中', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _stringValue('title'),
                                      style: const TextStyle(fontSize: 21),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(_stringValue('type') == '0' ? '普通测试' : '考试', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  const SizedBox(width: 10),
                                  if (_hasLessonLink)
                                    const Text('期末', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text('起止: ${_stringValue('begintime')}~${_stringValue('endtime').isEmpty ? '不限制' : _stringValue('endtime')}', style: const TextStyle(color: Colors.blueAccent, fontSize: 13)),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(_stringValue('type') == '0' ? '普通测试' : '考试', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  const SizedBox(width: 10),
                                  if (_hasLessonLink) const Text('期末', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_stringValue('description').trim().isNotEmpty && _stringValue('description').trim() != ' ')
                                Html(data: _stringValue('description')),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              Text('本试卷共$_subjectCount题', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ClipOval(
                                    child: Image.network(
                                      _normalizeUrl(_stringValue('avatar')),
                                      fit: BoxFit.cover,
                                      width: 30,
                                      height: 30,
                                      errorBuilder: (_, error, stackTrace) =>
                                          Container(
                                            width: 30,
                                            height: 30,
                                            color: Colors.grey.shade300,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(_stringValue('nickname')),
                                  const SizedBox(width: 10),
                                  if (_createTimeText.isNotEmpty) Text('发布于$_createTimeText', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isEnded && !_canContinueAnswer && !_canViewPaper)
                          ? null
                          : _openExamExecutePage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(_actionButtonText, style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 3)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
