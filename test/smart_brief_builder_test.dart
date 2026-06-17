import 'package:course_helper/smart/smart_brief_builder.dart';
import 'package:course_helper/smart/smart_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds empty local summary', () {
    final brief = const SmartBriefBuilder().build(const <SmartInsight>[]);

    expect(brief.totalCount, 0);
    expect(brief.title, contains('没有'));
  });

  test('counts urgent and high priority insights', () {
    final brief = const SmartBriefBuilder().build(<SmartInsight>[
      _insight('a', SmartInsightPriority.urgent),
      _insight('b', SmartInsightPriority.high),
      _insight('c', SmartInsightPriority.low),
    ]);

    expect(brief.totalCount, 3);
    expect(brief.urgentCount, 1);
    expect(brief.highCount, 1);
    expect(brief.lines.join('\n'), contains('紧急'));
  });
}

SmartInsight _insight(String id, SmartInsightPriority priority) {
  return SmartInsight(
    id: id,
    type: SmartInsightType.todoRisk,
    title: '待办 $id',
    summary: 'summary',
    reason: 'reason',
    sourceKind: 'test',
    sourceId: id,
    priority: priority,
    createdAt: DateTime(2026, 1, 1),
  );
}
