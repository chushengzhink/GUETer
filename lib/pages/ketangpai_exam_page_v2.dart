import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/exam_controller.dart';
import '../models/course.dart';
import '../models/ketangpai_exam.dart';
import '../theme/components/app_card.dart';
import '../theme/components/app_empty_state.dart';
import '../theme/components/app_loading_indicator.dart';
import '../theme/design_tokens.dart';
import 'ketangpai_exam_question_page_v2.dart';

class KetangpaiExamPageV2 extends StatefulWidget {
  const KetangpaiExamPageV2({
    super.key,
    required this.course,
    this.examController,
  });

  final Course course;
  final ExamController? examController;

  @override
  State<KetangpaiExamPageV2> createState() => _KetangpaiExamPageV2State();
}

class _KetangpaiExamPageV2State extends State<KetangpaiExamPageV2> {
  late final String _controllerTag;
  late final ExamController _controller;

  @override
  void initState() {
    super.initState();
    _controllerTag = 'ketangpai-exam-list-${identityHashCode(this)}';
    _controller = Get.put(
      widget.examController ?? ExamController(),
      tag: _controllerTag,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadExamList(widget.course.courseId);
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<ExamController>(tag: _controllerTag)) {
      Get.delete<ExamController>(tag: _controllerTag);
    }
    super.dispose();
  }

  String _paperIdOf(KetangpaiExamSummary exam) {
    return exam.id.isNotEmpty
        ? exam.id
        : (exam.raw['testpaperid'] ?? exam.raw['testPaperId'] ?? '').toString();
  }

  String _typeLabelOf(KetangpaiExamSummary exam) {
    final type = exam.type.trim();
    if (type == '1') return '考试';
    if (type == '0') return '测试';
    return exam.activityLabel.trim().isNotEmpty ? exam.activityLabel : '测试';
  }

  String _statusLabelOf(KetangpaiExamSummary exam) {
    if (exam.over) return '已结束';
    if (exam.submitState >= 6) return '已批改';
    if (exam.submitState == 4) return '待批改';
    if (exam.submitState >= 3) return '已提交';
    return '未提交';
  }

  Color _statusColor(BuildContext context, KetangpaiExamSummary exam) {
    final scheme = Theme.of(context).colorScheme;
    if (exam.over) return scheme.outline;
    if (exam.submitState >= 6) return Colors.green;
    if (exam.submitState >= 3) return scheme.primary;
    return scheme.tertiary;
  }

  Widget _buildExamTile(KetangpaiExamSummary exam) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paperId = _paperIdOf(exam);
    final statusColor = _statusColor(context, exam);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: paperId.isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => KetangpaiExamQuestionPageV2(
                    courseId: widget.course.courseId,
                    paperId: paperId,
                    title: exam.title.isEmpty ? '考试作答' : exam.title,
                    readOnly: exam.over,
                  ),
                ),
              );
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Text(
              _typeLabelOf(exam),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.title.isEmpty ? '未命名考试' : exam.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      '总分 ${exam.fullScore.isEmpty ? '-' : exam.fullScore}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (exam.beginTime.isNotEmpty)
                      Text(
                        '开始 ${exam.beginTime}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _statusLabelOf(exam),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Obx(() {
      if (_controller.isLoading.value) {
        return const AppLoadingIndicator(message: '正在加载考试列表');
      }
      if (_controller.error.value.isNotEmpty) {
        return AppEmptyState(
          icon: Icons.error_outline,
          title: '加载失败',
          message: _controller.error.value,
          actionLabel: '重试',
          onAction: () => _controller.loadExamList(widget.course.courseId),
        );
      }
      if (_controller.examList.isEmpty) {
        return const AppEmptyState(
          icon: Icons.assignment_outlined,
          title: '暂无考试',
          message: '当前课程没有可显示的考试或测试',
        );
      }
      return RefreshIndicator(
        onRefresh: () => _controller.loadExamList(widget.course.courseId),
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _controller.examList.length,
          itemBuilder: (context, index) =>
              _buildExamTile(_controller.examList[index]),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.course.name} · 考试')),
      body: _buildBody(),
    );
  }
}
