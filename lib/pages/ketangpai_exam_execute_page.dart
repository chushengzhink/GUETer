import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../api/course.dart';

class KetangpaiExamExecutePage extends StatefulWidget {
  final String courseId;
  final String testPaperId;
  final bool readOnly;

  const KetangpaiExamExecutePage({
    super.key,
    required this.courseId,
    required this.testPaperId,
    this.readOnly = false,
  });

  @override
  State<KetangpaiExamExecutePage> createState() => _KetangpaiExamExecutePageState();
}

class _KetangpaiExamExecutePageState extends State<KetangpaiExamExecutePage> {
  final PageController _pageController = PageController(initialPage: 0);
  final Map<String, dynamic> _answers = <String, dynamic>{};
  final Map<String, TextEditingController> _textControllers = <String, TextEditingController>{};

  bool _loading = true;
  List<Map<String, dynamic>> _questions = [];
  int _currentPageNumber = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final response = await KTCourseApi.getExamQuestions(widget.courseId, widget.testPaperId);
    final rawList = response?['data']?['lists'];
    final list = rawList is List
        ? rawList.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    _initializeSavedAnswers(list);
    if (!mounted) return;
    setState(() {
      _questions = list;
      _loading = false;
    });
  }

  void _initializeSavedAnswers(List<Map<String, dynamic>> questions) {
    _answers.clear();
    for (final question in questions) {
      final questionId = _questionId(question);
      if (questionId.isEmpty) {
        continue;
      }
      final type = int.tryParse(_questionType(question)) ?? 0;
      final raw = question['myanswer']?.toString() ?? '';
      if (raw.isEmpty || raw == '未作答') {
        continue;
      }

      if (type == 1 || type == 2) {
        _answers[questionId] = <String>[raw];
      } else if (type == 3 || type == 6) {
        _answers[questionId] = raw.split('|').where((e) => e.trim().isNotEmpty).toList();
      } else {
        _answers[questionId] = _parseHtmlPText(raw);
      }
    }
  }

  String _parseHtmlPText(String html) {
    final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).allMatches(html);
    if (pMatches.isNotEmpty) {
      return pMatches
          .map((m) => _stripHtml(m.group(1) ?? ''))
          .where((e) => e.isNotEmpty)
          .join('\n');
    }
    return _stripHtml(html);
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
  }

  Widget _buildQuestionTitle(String rawTitle) {
    final latexPattern = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$|\\\[(.+?)\\\]|\\\((.+?)\\\)', dotAll: true);
    final matches = latexPattern.allMatches(rawTitle).toList();

    if (matches.isEmpty) {
      return SelectableText(_stripHtml(rawTitle), style: const TextStyle(fontSize: 18));
    }

    final children = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final text = _stripHtml(rawTitle.substring(lastEnd, match.start));
        if (text.isNotEmpty) {
          children.add(TextSpan(text: text));
        }
      }

      final latex = match.group(1) ?? match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      if (latex.isNotEmpty) {
        try {
          children.add(WidgetSpan(
            child: Math.tex(
              latex,
              textStyle: const TextStyle(fontSize: 18),
              mathStyle: MathStyle.text,
            ),
          ));
        } catch (e) {
          children.add(TextSpan(text: latex, style: const TextStyle(color: Colors.red)));
        }
      }

      lastEnd = match.end;
    }

    if (lastEnd < rawTitle.length) {
      final text = _stripHtml(rawTitle.substring(lastEnd));
      if (text.isNotEmpty) {
        children.add(TextSpan(text: text));
      }
    }

    return SelectableText.rich(
      TextSpan(children: children, style: const TextStyle(fontSize: 18)),
    );
  }

  List<String> _extractImageUrls(String html) {
    final matches = RegExp('<img[^>]*src=["\\\']([^"\\\']+)["\\\'][^>]*>', caseSensitive: false)
        .allMatches(html);
    return matches
        .map((m) => m.group(1) ?? '')
        .where((src) => src.trim().isNotEmpty)
        .toList();
  }

  String _parseParagraphText(String html) {
    final pMatch = RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true).firstMatch(html);
    if (pMatch != null) {
      return _stripHtml(pMatch.group(1) ?? '');
    }
    return _stripHtml(html);
  }

  String _questionId(Map<String, dynamic> question) => question['id']?.toString() ?? '';
  String _questionType(Map<String, dynamic> question) => question['type']?.toString() ?? '0';
  String _questionTitle(Map<String, dynamic> question) => question['title']?.toString() ?? '';
  String _questionLabel(Map<String, dynamic> question) => question['replenishtype']?.toString() ?? '';
  String _questionScore(Map<String, dynamic> question) => question['score']?.toString() ?? '';
  String _difficultyLabel(Map<String, dynamic> question) {
    switch (int.tryParse(question['difficulty']?.toString() ?? '') ?? 0) {
      case 1:
        return '易';
      case 2:
        return '中';
      case 3:
        return '难';
      default:
        return '未知';
    }
  }

  List<Map<String, dynamic>> _optionsOf(Map<String, dynamic> question) {
    final raw = question['options'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return <Map<String, dynamic>>[];
  }

  List<String> _questionImages(Map<String, dynamic> question) {
    return _extractImageUrls(question['title']?.toString() ?? '');
  }

  void _setAnswer(String questionId, dynamic value) {
    setState(() {
      _answers[questionId] = value;
    });
  }

  bool _hasAnswer(Map<String, dynamic> question) {
    final questionId = _questionId(question);
    final type = int.tryParse(_questionType(question)) ?? 0;
    final answer = _answers[questionId];

    if (type == 1 || type == 2 || type == 3 || type == 6) {
      return answer is List && answer.isNotEmpty;
    }
    return answer != null && answer.toString().trim().isNotEmpty;
  }

  String _answerForSubmit(Map<String, dynamic> question) {
    final questionId = _questionId(question);
    final type = int.tryParse(_questionType(question)) ?? 0;
    dynamic answer = _answers[questionId];

    if (type == 1 || type == 2) {
      return (answer is List && answer.isNotEmpty) ? answer.first.toString() : '';
    }
    if (type == 3 || type == 6) {
      return (answer is List) ? answer.join('|') : '';
    }
    return answer?.toString() ?? '';
  }

  Future<void> _saveSingleAnswer(Map<String, dynamic> question) async {
    if (widget.readOnly) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前为只读模式，不可保存作答')),
        );
      }
      return;
    }

    final questionId = _questionId(question);
    if (questionId.isEmpty) {
      return;
    }
    final result = await KTCourseApi.submitExamAnswer(
      courseId: widget.courseId,
      testPaperId: widget.testPaperId,
      subjectId: questionId,
      answer: _answerForSubmit(question),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result ? '保存成功' : '保存失败')),
    );
  }

  Widget _buildSingleChoice(Map<String, dynamic> question, {required bool multi}) {
    final questionId = _questionId(question);
    final options = _optionsOf(question);
    final selected = (_answers[questionId] as List<String>?) ?? <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final optionId = option['id']?.toString() ?? '';
        final optionTitle = _parseParagraphText(option['title']?.toString() ?? '');
        final letter = String.fromCharCode(65 + index);
        final isSelected = selected.contains(optionId);
        return CheckboxListTile(
          value: isSelected,
          title: Text('$letter.$optionTitle'),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) {
            if (widget.readOnly) return;
            final next = List<String>.from(selected);
            if (multi) {
              if (value == true) {
                if (!next.contains(optionId)) next.add(optionId);
              } else {
                next.remove(optionId);
              }
              _setAnswer(questionId, next);
            } else {
              _setAnswer(questionId, value == true ? [optionId] : <String>[]);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildJudge(Map<String, dynamic> question) {
    return _buildSingleChoice(question, multi: false);
  }

  Widget _buildFillBlank(Map<String, dynamic> question) {
    final questionId = _questionId(question);
    final controller = _textControllers.putIfAbsent(questionId, () => TextEditingController(text: _answers[questionId]?.toString() ?? ''));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          maxLines: null,
          minLines: 3,
          enabled: !widget.readOnly,
          onChanged: (value) => _setAnswer(questionId, value),
          decoration: const InputDecoration(
            hintText: '请在此处输入答案。若为多空填空题，则输入时每空答案需占一行',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: widget.readOnly ? null : () => _saveSingleAnswer(question),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.transparent),
            shape: const RoundedRectangleBorder(),
            backgroundColor: Colors.greenAccent,
          ),
          child: const Text('保存答案', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildShortAnswer(Map<String, dynamic> question) {
    final questionId = _questionId(question);
    final controller = _textControllers.putIfAbsent(questionId, () => TextEditingController(text: _answers[questionId]?.toString() ?? ''));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          maxLines: null,
          minLines: 4,
          enabled: !widget.readOnly,
          onChanged: (value) => _setAnswer(questionId, value),
          decoration: const InputDecoration(
            hintText: '请输入简答题答案',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: widget.readOnly ? null : () => _saveSingleAnswer(question),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.transparent),
            shape: const RoundedRectangleBorder(),
            backgroundColor: Colors.greenAccent,
          ),
          child: const Text('保存答案', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildQuestion(Map<String, dynamic> question) {
    final type = int.tryParse(_questionType(question)) ?? 0;
    final questionId = _questionId(question);
    final title = _questionTitle(question);
    final images = _questionImages(question);

    Widget body;
    if (type == 1) {
      body = _buildJudge(question);
    } else if (type == 2) {
      body = _buildSingleChoice(question, multi: false);
    } else if (type == 3 || type == 6) {
      body = _buildSingleChoice(question, multi: true);
    } else if (type == 4) {
      body = _buildShortAnswer(question);
    } else if (type == 5) {
      body = _buildFillBlank(question);
    } else {
      body = const SizedBox.shrink();
    }

    final answered = _hasAnswer(question);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_currentPageNumber.toString(), style: const TextStyle(color: Colors.blue, fontSize: 20)),
              Text('/${_questions.length}', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 5),
              Text(_questionLabel(question), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 5),
              Text('(分值${_questionScore(question)}分，难度：${_difficultyLabel(question)})', style: const TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuestionTitle(title),
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Center(
                child: Image.network(
                  images.first,
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width - 150,
                ),
              ),
            )
          else
            const SizedBox(height: 12),
          body,
          const SizedBox(height: 18),
          Text(
            answered ? '已作答' : '未作答',
            style: TextStyle(color: answered ? Colors.blue : Colors.grey),
          ),
          if (questionId.isNotEmpty && !(type == 4 || type == 5))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton(
                onPressed: widget.readOnly ? null : () => _saveSingleAnswer(question),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.transparent),
                  shape: const RoundedRectangleBorder(),
                  backgroundColor: Colors.greenAccent,
                ),
                child: const Text('保存答案', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveAllAnswer() async {
    if (widget.readOnly) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前为只读模式，不可保存作答')),
        );
      }
      return;
    }

    for (final question in _questions) {
      final questionId = _questionId(question);
      final answer = _answerForSubmit(question);
      await KTCourseApi.submitExamAnswer(
        courseId: widget.courseId,
        testPaperId: widget.testPaperId,
        subjectId: questionId,
        answer: answer,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存完毕')));
    }
  }

  Future<void> _submitPaper() async {
    if (widget.readOnly) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前为只读模式，不可提交试卷')),
        );
      }
      return;
    }

    final unansweredCount = _questions.where((q) => !_hasAnswer(q)).length;
    final answeredCount = _questions.where(_hasAnswer).length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提交确认'),
        content: Text(
          unansweredCount > 0
              ? '您还有 $unansweredCount 道题未作答（已答 $answeredCount/${_questions.length}），确定要提交吗？'
              : '已完成全部 ${_questions.length} 道题，确定提交试卷吗？',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确定提交')),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }

    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _saveAllAnswer();
    final result = await KTCourseApi.submitExamPaper(widget.courseId, widget.testPaperId);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result ? '提交成功' : '提交失败')),
    );
  }

  Future<void> _openAnswerCard() async {
    if (_questions.isEmpty) {
      return;
    }
    final target = await showDialog<int>(
      context: context,
      builder: (context) {
        final answeredCount = _questions.where(_hasAnswer).length;
        return AlertDialog(
          title: Text('答题卡($answeredCount/${_questions.length})'),
          content: SizedBox(
            width: 320,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: _questions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final question = _questions[index];
                final answered = _hasAnswer(question);
                final selected = index + 1 == _currentPageNumber;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(index),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: answered
                          ? Colors.blue.withValues(alpha: 0.16)
                          : Colors.grey.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? Colors.blue : Colors.transparent),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: answered ? Colors.blue : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );

    if (target == null || target < 0 || target >= _questions.length) {
      return;
    }
    setState(() {
      _currentPageNumber = target + 1;
    });
    _pageController.jumpToPage(target);
  }

  void _changePage(int offset) {
    final nextPage = (_currentPageNumber + offset).clamp(1, _questions.length);
    setState(() {
      _currentPageNumber = nextPage;
    });
    _pageController.animateToPage(
      nextPage - 1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_questions.isNotEmpty ? _stripHtml(_questions.first['paperTitle']?.toString() ?? '考试作答') : '考试作答'),
        actions: [
          Container(
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              onPressed: _openAnswerCard,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Colors.blue),
              ),
              child: const Text('答题卡', style: TextStyle(color: Colors.blue)),
            ),
          ),
          if (!widget.readOnly)
            Container(
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                onPressed: _submitPaper,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.transparent),
                ),
                child: const Text('提交', style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? const Center(child: Text('暂无试题'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (value) {
                      setState(() {
                        _currentPageNumber = value + 1;
                      });
                    },
                    children: _questions.map((question) => _buildQuestion(question)).toList(),
                  ),
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentPageNumber <= 1 ? null : () => _changePage(-1),
                    child: const Text('上一题'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentPageNumber >= _questions.length ? null : () => _changePage(1),
                    child: const Text('下一题'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!widget.readOnly)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveAllAnswer,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('保存所有题目作答', style: TextStyle(color: Colors.white)),
                ),
              )
            else
              const SizedBox(
                width: double.infinity,
                child: Text(
                  '当前试卷为只读模式',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
