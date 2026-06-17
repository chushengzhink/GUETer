import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/exam_controller.dart';
import '../models/ketangpai_exam.dart';
import '../theme/components/app_empty_state.dart';
import '../theme/components/app_loading_indicator.dart';
import '../theme/design_tokens.dart';

class KetangpaiExamQuestionPageV2 extends StatefulWidget {
  const KetangpaiExamQuestionPageV2({
    super.key,
    required this.courseId,
    required this.paperId,
    this.title = '考试作答',
    this.readOnly = false,
    this.examController,
  });

  final String courseId;
  final String paperId;
  final String title;
  final bool readOnly;
  final ExamController? examController;

  @override
  State<KetangpaiExamQuestionPageV2> createState() =>
      _KetangpaiExamQuestionPageV2State();
}

class _KetangpaiExamQuestionPageV2State
    extends State<KetangpaiExamQuestionPageV2> {
  final PageController _pageController = PageController();
  final Map<String, Timer> _saveTimers = <String, Timer>{};
  late final String _controllerTag;
  late final ExamController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controllerTag = 'ketangpai-exam-question-${identityHashCode(this)}';
    _controller = Get.put(
      widget.examController ?? ExamController(),
      tag: _controllerTag,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadExamDetail(widget.courseId, widget.paperId);
    });
  }

  @override
  void dispose() {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
    _pageController.dispose();
    if (Get.isRegistered<ExamController>(tag: _controllerTag)) {
      Get.delete<ExamController>(tag: _controllerTag);
    }
    super.dispose();
  }

  void _scheduleSave(String subjectId, String answer) {
    _controller.updateCachedAnswer(subjectId, answer);
    if (widget.readOnly) {
      return;
    }
    _saveTimers[subjectId]?.cancel();
    _saveTimers[subjectId] = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _controller.saveAnswer(subjectId, answer);
      _saveTimers.remove(subjectId);
    });
  }

  void _jumpTo(int index, int length) {
    final next = index.clamp(0, length - 1);
    _pageController.animateToPage(
      next,
      duration: AppDuration.normal,
      curve: AppCurves.standard,
    );
  }

  Future<void> _openAnswerCard(List<KetangpaiExamQuestion> questions) async {
    final target = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '答题卡 ${_controller.answerCache.length}/${questions.length}',
          ),
          content: SizedBox(
            width: 320,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: questions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
              ),
              itemBuilder: (context, index) {
                final question = questions[index];
                final answered = (_controller.answerCache[question.id] ?? '')
                    .trim()
                    .isNotEmpty;
                final selected = index == _currentIndex;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(index),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: answered
                          ? Theme.of(context).colorScheme.primaryContainer
                                .withValues(alpha: 0.55)
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Center(child: Text('${index + 1}')),
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
    if (target != null && questions.isNotEmpty) {
      _jumpTo(target, questions.length);
    }
  }

  Future<void> _submitExam(List<KetangpaiExamQuestion> questions) async {
    if (widget.readOnly) return;
    final unanswered = questions
        .where(
          (question) =>
              (_controller.answerCache[question.id] ?? '').trim().isEmpty,
        )
        .length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认交卷'),
        content: Text(
          unanswered > 0 ? '还有 $unanswered 道题未作答，确定交卷吗？' : '所有题目均已作答，确定交卷吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('交卷'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _controller.submitExam(widget.courseId, widget.paperId);
    }
  }

  Widget _buildBottomBar(List<KetangpaiExamQuestion> questions) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentIndex <= 0
                        ? null
                        : () => _jumpTo(_currentIndex - 1, questions.length),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('上一题'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _currentIndex >= questions.length - 1
                        ? null
                        : () => _jumpTo(_currentIndex + 1, questions.length),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('下一题'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openAnswerCard(questions),
                    icon: const Icon(Icons.grid_view_outlined),
                    label: const Text('答题卡'),
                  ),
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Obx(() {
                      final isSaving = _controller.isSaving.value;
                      return FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () => _submitExam(questions),
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_outlined),
                        label: Text(isSaving ? '提交中' : '交卷'),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (_controller.isLoading.value) {
        return const AppLoadingIndicator(message: '正在加载试题');
      }
      if (_controller.error.value.isNotEmpty &&
          _controller.currentPaper.value == null) {
        return AppEmptyState(
          icon: Icons.error_outline,
          title: '加载失败',
          message: _controller.error.value,
          actionLabel: '重试',
          onAction: () =>
              _controller.loadExamDetail(widget.courseId, widget.paperId),
        );
      }

      final questions =
          _controller.currentPaper.value?.questions ??
          const <KetangpaiExamQuestion>[];
      if (questions.isEmpty) {
        return const AppEmptyState(
          icon: Icons.quiz_outlined,
          title: '暂无试题',
          message: '当前试卷没有可显示的题目',
        );
      }

      return Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: questions.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _KetangpaiQuestionPageItem(
                  key: PageStorageKey<String>(
                    'ketangpai-question-${questions[index].id}',
                  ),
                  question: questions[index],
                  index: index,
                  total: questions.length,
                  controller: _controller,
                  readOnly: widget.readOnly,
                  onAnswerChanged: _scheduleSave,
                );
              },
            ),
          ),
          _buildBottomBar(questions),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _buildBody(),
    );
  }
}

class _KetangpaiQuestionPageItem extends StatefulWidget {
  const _KetangpaiQuestionPageItem({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    required this.controller,
    required this.readOnly,
    required this.onAnswerChanged,
  });

  final KetangpaiExamQuestion question;
  final int index;
  final int total;
  final ExamController controller;
  final bool readOnly;
  final void Function(String subjectId, String answer) onAnswerChanged;

  @override
  State<_KetangpaiQuestionPageItem> createState() =>
      _KetangpaiQuestionPageItemState();
}

class _KetangpaiQuestionPageItemState extends State<_KetangpaiQuestionPageItem>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _textController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.answerCache[widget.question.id] ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _KetangpaiQuestionPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _textController.text =
          widget.controller.answerCache[widget.question.id] ?? '';
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }

  String _optionText(KetangpaiExamOption option, int index) {
    final letter = String.fromCharCode(65 + index);
    final text = _stripHtml(option.title);
    return '$letter. ${text.isEmpty ? option.id : text}';
  }

  List<String> _imageUrls(String html) {
    return RegExp(
          '<img[^>]*src=["\\\']([^"\\\']+)["\\\'][^>]*>',
          caseSensitive: false,
        )
        .allMatches(html)
        .map((match) => match.group(1) ?? '')
        .where((src) => src.trim().isNotEmpty)
        .toList();
  }

  String _currentAnswer() {
    return widget.controller.answerCache[widget.question.id] ??
        widget.question.myAnswer ??
        '';
  }

  void _setAnswer(String answer) {
    widget.onAnswerChanged(widget.question.id, answer);
  }

  Widget _buildSingleChoice() {
    final answer = _currentAnswer();
    return RadioGroup<String>(
      groupValue: answer.isEmpty ? null : answer,
      onChanged: (value) {
        if (widget.readOnly) return;
        if (value != null) _setAnswer(value);
      },
      child: Column(
        children: widget.question.options.asMap().entries.map((entry) {
          final option = entry.value;
          return RadioListTile<String>(
            value: option.id,
            enabled: !widget.readOnly,
            title: Text(_optionText(option, entry.key)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMultipleChoice() {
    final selected = _currentAnswer()
        .split('|')
        .where((item) => item.trim().isNotEmpty)
        .toSet();
    return Column(
      children: widget.question.options.asMap().entries.map((entry) {
        final option = entry.value;
        final checked = selected.contains(option.id);
        return CheckboxListTile(
          value: checked,
          onChanged: widget.readOnly
              ? null
              : (value) {
                  final next = Set<String>.from(selected);
                  if (value == true) {
                    next.add(option.id);
                  } else {
                    next.remove(option.id);
                  }
                  _setAnswer(next.join('|'));
                },
          title: Text(_optionText(option, entry.key)),
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }

  Widget _buildJudge() {
    String answerForIndex(int index, String fallback) {
      if (widget.question.options.length > index) {
        return widget.question.options[index].id;
      }
      return fallback;
    }

    final current = _currentAnswer();
    final trueAnswer = answerForIndex(0, 'true');
    final falseAnswer = answerForIndex(1, 'false');
    Widget button(String label, String answer) {
      final selected = current == answer;
      return Expanded(
        child: FilledButton.tonal(
          onPressed: widget.readOnly ? null : () => _setAnswer(answer),
          style: FilledButton.styleFrom(
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          child: Text(label),
        ),
      );
    }

    return Row(
      children: [
        button('正确', trueAnswer),
        const SizedBox(width: AppSpacing.md),
        button('错误', falseAnswer),
      ],
    );
  }

  Widget _buildTextAnswer({required bool multiLine}) {
    return TextField(
      controller: _textController,
      enabled: !widget.readOnly,
      minLines: multiLine ? 5 : 2,
      maxLines: null,
      onChanged: _setAnswer,
      decoration: InputDecoration(hintText: multiLine ? '请输入简答题答案' : '请输入填空答案'),
    );
  }

  Widget _buildAnswerBody() {
    switch (widget.question.type) {
      case KetangpaiQuestionType.judge:
        return _buildJudge();
      case KetangpaiQuestionType.singleChoice:
        return _buildSingleChoice();
      case KetangpaiQuestionType.multipleChoice:
      case KetangpaiQuestionType.multipleChoiceAlt:
        return _buildMultipleChoice();
      case KetangpaiQuestionType.fillBlank:
        return _buildTextAnswer(multiLine: false);
      case KetangpaiQuestionType.shortAnswer:
        return _buildTextAnswer(multiLine: true);
      case KetangpaiQuestionType.unknown:
        return _buildTextAnswer(multiLine: true);
    }
  }

  String _scoreLabel(double score) {
    if (score == score.roundToDouble()) {
      return score.toInt().toString();
    }
    return score.toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final images = _imageUrls(widget.question.title);
    return SingleChildScrollView(
      key: PageStorageKey<String>('scroll-${widget.question.id}'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${widget.index + 1}/${widget.total}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(label: Text(widget.question.type.label)),
              Text(
                '${_scoreLabel(widget.question.score)} 分',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SelectableText(
            _stripHtml(widget.question.title),
            style: theme.textTheme.titleMedium,
          ),
          for (final image in images) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: Image.network(
                image,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    '图片加载失败：$image',
                    style: TextStyle(color: theme.colorScheme.error),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _buildAnswerBody(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
