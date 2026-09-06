import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/exam_controller.dart';
import '../models/ketangpai_exam.dart';
import '../session/account.dart';
import '../theme/components/app_empty_state.dart';
import '../theme/components/app_loading_indicator.dart';
import '../theme/design_tokens.dart';
import '../widgets/unsaved_changes_guard.dart';

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
  late final Worker _paperWorker;
  Timer? _remainingTimer;
  int? _serverRemainingSeconds;
  int _remainingTickSeconds = 0;
  DateTime? _remainingAnchor;
  int _currentIndex = 0;
  bool _submitFlowActive = false;

  @override
  void initState() {
    super.initState();
    _controllerTag = 'ketangpai-exam-question-${identityHashCode(this)}';
    _controller = Get.put(
      widget.examController ?? ExamController(),
      tag: _controllerTag,
    );
    _paperWorker = ever<KetangpaiExamPaper?>(
      _controller.currentPaper,
      _syncRemainingTimeFromPaper,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadExamDetail(widget.courseId, widget.paperId);
    });
  }

  @override
  void dispose() {
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();
    _remainingTimer?.cancel();
    _paperWorker.dispose();
    _pageController.dispose();
    if (Get.isRegistered<ExamController>(tag: _controllerTag)) {
      Get.delete<ExamController>(tag: _controllerTag);
    }
    super.dispose();
  }

  void _syncRemainingTimeFromPaper(KetangpaiExamPaper? paper) {
    _remainingTimer?.cancel();
    _remainingTimer = null;

    final remainingSeconds = paper?.remainingTimes ?? 0;
    if (widget.readOnly || remainingSeconds <= 0) {
      if (!mounted) return;
      setState(() {
        _serverRemainingSeconds = null;
        _remainingTickSeconds = 0;
        _remainingAnchor = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _serverRemainingSeconds = remainingSeconds;
      _remainingTickSeconds = 0;
      _remainingAnchor = DateTime.now();
    });
    _remainingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _remainingTickSeconds++;
      final remaining = _remainingSeconds;
      if (remaining != null && remaining <= 0) {
        _remainingTimer?.cancel();
        _remainingTimer = null;
      }
      setState(() {});
    });
  }

  int? get _remainingSeconds {
    final serverRemainingSeconds = _serverRemainingSeconds;
    final anchor = _remainingAnchor;
    if (serverRemainingSeconds == null || anchor == null) return null;
    final elapsed = math.max(
      DateTime.now().difference(anchor).inSeconds,
      _remainingTickSeconds,
    );
    return math.max(0, serverRemainingSeconds - elapsed);
  }

  String _formatRemainingTime(int seconds) {
    if (seconds <= 0) return '已到时';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    if (hours > 0) {
      return '剩余 ${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(secs)}';
    }
    return '剩余 ${twoDigits(minutes)}:${twoDigits(secs)}';
  }

  Widget _buildRemainingCountdown() {
    if (widget.readOnly) return const SizedBox.shrink();
    final remaining = _remainingSeconds;
    if (remaining == null) return const SizedBox.shrink();
    final urgent = remaining <= 300;
    final color = urgent
        ? const Color(0xFFD93025)
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.34)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            _formatRemainingTime(remaining),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleSave(String subjectId, String answer) {
    _controller.updateCachedAnswer(subjectId, answer);
    if (widget.readOnly) {
      return;
    }
    _saveTimers[subjectId]?.cancel();
    late final Timer timer;
    timer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final saved = await _controller.saveAnswer(subjectId, answer);
      if (identical(_saveTimers[subjectId], timer)) {
        _saveTimers.remove(subjectId);
      }
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _controller.error.value.isEmpty
                  ? '答案保存失败'
                  : _controller.error.value,
            ),
          ),
        );
      }
    });
    _saveTimers[subjectId] = timer;
  }

  Future<bool> _flushPendingSaves() async {
    if (widget.readOnly ||
        (_saveTimers.isEmpty && _controller.unsavedAnswers.isEmpty)) {
      return true;
    }

    final pendingIds = {
      ..._saveTimers.keys,
      ..._controller.unsavedAnswers,
    }.toList();
    for (final timer in _saveTimers.values) {
      timer.cancel();
    }
    _saveTimers.clear();

    for (final subjectId in pendingIds) {
      final answer = _controller.answerCache[subjectId] ?? '';
      final saved = await _controller.saveAnswer(subjectId, answer);
      if (!saved) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _controller.error.value.isEmpty
                    ? '题目 $subjectId 保存失败，已停止交卷'
                    : _controller.error.value,
              ),
            ),
          );
        }
        return false;
      }
    }
    return _controller.unsavedAnswers.isEmpty;
  }

  void _jumpTo(int index, int length) {
    final next = index.clamp(0, length - 1);
    FocusScope.of(context).unfocus();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(next);
      return;
    }
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
                          ? Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.16)
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
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: answered
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
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
    if (mounted && target != null && questions.isNotEmpty) {
      _jumpTo(target, questions.length);
    }
  }

  Future<void> _submitExam(List<KetangpaiExamQuestion> questions) async {
    if (widget.readOnly ||
        _submitFlowActive ||
        _controller.isSubmitting.value) {
      return;
    }
    setState(() => _submitFlowActive = true);
    try {
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
      if (confirm == true && mounted) {
        final flushed = await _flushPendingSaves();
        if (!flushed || !mounted) return;
        final submitted = await _controller.submitExam(
          widget.courseId,
          widget.paperId,
        );
        if (submitted && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('交卷成功')));
        }
      }
    } finally {
      if (mounted) setState(() => _submitFlowActive = false);
    }
  }

  String _identityWatermarkText() {
    final detail = _controller.currentPaper.value?.detail;
    final raw = detail?.raw ?? const <String, dynamic>{};

    String pick(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        final value = source[key]?.toString().trim();
        if (value != null && value.isNotEmpty && value != 'null') {
          return value;
        }
      }
      return '';
    }

    final name = pick(raw, const [
      'nickname',
      'name',
      'realname',
      'realName',
      'studentname',
      'studentName',
      'username',
      'userName',
    ]);
    final number = pick(raw, const [
      'studentId',
      'studentid',
      'stuno',
      'stuNo',
      'sno',
      'number',
      'uid',
      'userid',
      'userId',
    ]);

    if (name.isNotEmpty && number.isNotEmpty) return '$name\n$number';
    if (name.isNotEmpty) return name;
    if (number.isNotEmpty) return number;

    final account = AccountManager.currentAccount;
    if (account == null || !account.isKetangpai) return '';
    final accountName = account.name.trim();
    final accountNumber =
        (account.studentId?.trim().isNotEmpty == true
                ? account.studentId
                : account.uid)
            ?.trim();
    if (accountName.isNotEmpty &&
        accountNumber != null &&
        accountNumber.isNotEmpty) {
      return '$accountName\n$accountNumber';
    }
    return accountName.isNotEmpty ? accountName : account.uid;
  }

  Widget _buildTopActions(List<KetangpaiExamQuestion> questions) {
    if (questions.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRemainingCountdown(),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton(
            onPressed: () => _openAnswerCard(questions),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF238BC2),
              side: BorderSide(color: Color(0xFF238BC2), width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              minimumSize: const Size(0, 34),
              textStyle: TextStyle(fontSize: 14),
            ),
            child: const Text('答题卡'),
          ),
        ),
        if (!widget.readOnly)
          Obx(() {
            final saving =
                _controller.isSaving.value ||
                _submitFlowActive ||
                _controller.isSubmitted.value;
            return TextButton(
              onPressed: saving ? null : () => _submitExam(questions),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                _controller.isSubmitted.value
                    ? '已交卷'
                    : _controller.isSubmitting.value
                    ? '提交中'
                    : saving
                    ? '保存中'
                    : '交卷',
              ),
            );
          }),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomBar(List<KetangpaiExamQuestion> questions) {
    final isFirst = _currentIndex <= 0;
    final isLast = _currentIndex >= questions.length - 1;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              final isSaving = _controller.isSaving.value;
              final hasPending = _saveTimers.isNotEmpty;
              final error = _controller.error.value;
              final text = isSaving
                  ? '正在保存答案'
                  : hasPending
                  ? '答案待保存'
                  : error.isNotEmpty
                  ? '保存异常：$error'
                  : '';
              if (text.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: error.isNotEmpty
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              );
            }),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('ketangpai-prev-question'),
                    onPressed: isFirst
                        ? null
                        : () => _jumpTo(_currentIndex - 1, questions.length),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCED3DA),
                      disabledForegroundColor: const Color(0xFFCED3DA),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(isFirst ? '第一题' : '上一题'),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey('ketangpai-next-question'),
                    onPressed: isLast
                        ? null
                        : () => _jumpTo(_currentIndex + 1, questions.length),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      disabledBackgroundColor: const Color(0xFFE9EDF4),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      disabledForegroundColor: const Color(0xFFB6BDC7),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('下一题'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPager(List<KetangpaiExamQuestion> questions) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _ExamWatermarkPainter(_identityWatermarkText()),
          ),
        ),
        Positioned.fill(
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
                readOnly:
                    widget.readOnly ||
                    _submitFlowActive ||
                    _controller.isSubmitted.value,
                onAnswerChanged: _scheduleSave,
              );
            },
          ),
        ),
      ],
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
          if (_controller.error.value.isNotEmpty)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _controller.error.value,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _buildQuestionPager(questions)),
          _buildBottomBar(questions),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => UnsavedChangesGuard(
        hasChanges: !widget.readOnly && _controller.unsavedAnswers.isNotEmpty,
        isBusy: _controller.isSaving.value || _submitFlowActive,
        onSave: _flushPendingSaves,
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            surfaceTintColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 52,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 22),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            titleSpacing: 0,
            title: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
            ),
            actions: [
              Obx(() {
                final questions =
                    _controller.currentPaper.value?.questions ??
                    const <KetangpaiExamQuestion>[];
                return _buildTopActions(questions);
              }),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          body: _buildBody(),
        ),
      ),
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
    return '$letter.${text.isEmpty ? option.id : text}';
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
            activeColor: Theme.of(context).colorScheme.secondary,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Theme.of(context).colorScheme.secondary;
              }
              return const Color(0xFFD9DDE2);
            }),
            contentPadding: EdgeInsets.zero,
            visualDensity: const VisualDensity(horizontal: -2, vertical: 0),
            title: Text(
              _optionText(option, entry.key),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 18,
                height: 1.25,
              ),
            ),
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
          enabled: !widget.readOnly,
          activeColor: Theme.of(context).colorScheme.secondary,
          checkColor: Theme.of(context).colorScheme.onSecondary,
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Theme.of(context).colorScheme.secondary;
            }
            return const Color(0xFFD9DDE2);
          }),
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
          title: Text(
            _optionText(option, entry.key),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 18,
              height: 1.25,
            ),
          ),
          contentPadding: EdgeInsets.zero,
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
                ? Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.16)
                : const Color(0xFFF5F6F8),
            foregroundColor: selected
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
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
      style: TextStyle(
        fontSize: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: multiLine ? '请输入简答题答案' : '请输入填空答案',
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
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
    return score.toStringAsFixed(1);
  }

  String _typeLabel() {
    switch (widget.question.type) {
      case KetangpaiQuestionType.judge:
        return '判断题';
      case KetangpaiQuestionType.singleChoice:
        return '单选题';
      case KetangpaiQuestionType.multipleChoice:
      case KetangpaiQuestionType.multipleChoiceAlt:
        return '多选题';
      case KetangpaiQuestionType.fillBlank:
        return '填空题';
      case KetangpaiQuestionType.shortAnswer:
        return '简答题';
      case KetangpaiQuestionType.unknown:
        return '未知题型';
    }
  }

  String _difficultyLabel() {
    return switch (widget.question.difficulty) {
      1 => '低',
      3 || 4 || 5 => '高',
      _ => '中',
    };
  }

  Widget _buildQuestionMeta() {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 19,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(
            text: '${widget.index + 1}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text:
                '/${widget.total}  ${_typeLabel()} (分值${_scoreLabel(widget.question.score)}分，难度：${_difficultyLabel()})',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final images = _imageUrls(widget.question.title);
    return SingleChildScrollView(
      key: PageStorageKey<String>('scroll-${widget.question.id}'),
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionMeta(),
          const SizedBox(height: 18),
          SelectableText(
            _stripHtml(widget.question.title),
            style: TextStyle(
              color: Color(0xFF3F4248),
              fontSize: 19,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          for (final image in images) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                image,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    '图片加载失败：$image',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildAnswerBody(),
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}

class _ExamWatermarkPainter extends CustomPainter {
  const _ExamWatermarkPainter(this.text);

  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.trim().isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFCFD3DA).withValues(alpha: 0.24),
          fontSize: 14,
          height: 1.18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 180);

    const horizontalGap = 210.0;
    const verticalGap = 190.0;
    for (var y = 48.0; y < size.height + verticalGap; y += verticalGap) {
      final rowOffset = ((y / verticalGap).floor().isEven) ? 0.0 : 88.0;
      for (
        var x = -60.0 + rowOffset;
        x < size.width + horizontalGap;
        x += horizontalGap
      ) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-math.pi / 8);
        painter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExamWatermarkPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}
