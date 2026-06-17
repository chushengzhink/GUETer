import 'package:course_helper/smart/smart_insight_store.dart';
import 'package:course_helper/smart/smart_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists done and ignored statuses by insight id', () async {
    final store = SmartInsightStore();

    await store.setStatus('a', SmartInsightStatus.done);
    await store.setStatus('b', SmartInsightStatus.ignored);

    final statuses = await store.loadStatuses();
    expect(statuses['a'], SmartInsightStatus.done);
    expect(statuses['b'], SmartInsightStatus.ignored);
  });

  test('applyStatuses hides inactive insights by default', () async {
    final store = SmartInsightStore();
    final insights = <SmartInsight>[_insight('a'), _insight('b')];

    await store.setStatus('a', SmartInsightStatus.ignored);

    final active = await store.applyStatuses(insights);
    final all = await store.applyStatuses(insights, includeInactive: true);

    expect(active.map((item) => item.id), <String>['b']);
    expect(all.first.status, SmartInsightStatus.ignored);
  });
}

SmartInsight _insight(String id) {
  return SmartInsight(
    id: id,
    type: SmartInsightType.today,
    title: id,
    summary: id,
    reason: id,
    sourceKind: 'test',
    sourceId: id,
    priority: SmartInsightPriority.medium,
    createdAt: DateTime(2026, 1, 1),
  );
}
