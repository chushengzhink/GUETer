import 'smart_models.dart';

class SmartBriefBuilder {
  const SmartBriefBuilder();

  SmartBrief build(List<SmartInsight> insights) {
    final active = insights
        .where((item) => item.status == SmartInsightStatus.active)
        .toList();
    final urgent = active
        .where((item) => item.priority == SmartInsightPriority.urgent)
        .length;
    final high = active
        .where((item) => item.priority == SmartInsightPriority.high)
        .length;
    if (active.isEmpty) {
      return const SmartBrief(
        title: '今天没有需要处理的智能建议',
        lines: <String>['资料、待办、复习和诊断状态暂未发现明显风险。'],
        totalCount: 0,
        urgentCount: 0,
        highCount: 0,
      );
    }

    final lines = <String>[];
    if (urgent > 0) {
      lines.add('有 $urgent 条紧急建议需要优先处理。');
    }
    if (high > 0) {
      lines.add('有 $high 条高优先级建议，建议今天检查。');
    }
    for (final insight in active.take(3)) {
      lines.add('${insight.type.labelZh}：${insight.title}');
    }

    return SmartBrief(
      title: '今日智能整理摘要',
      lines: lines,
      totalCount: active.length,
      urgentCount: urgent,
      highCount: high,
    );
  }
}
