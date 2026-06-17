import 'package:course_helper/pages/smart_organizer_page.dart';
import 'package:course_helper/smart/smart_models.dart';
import 'package:course_helper/smart/smart_organizer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders sections, reasons and action buttons', (tester) async {
    final service = _FakeSmartOrganizerService(<SmartInsight>[
      _insight('a', SmartInsightType.today, '待处理建议'),
      _insight('b', SmartInsightType.material, '资料建议'),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: SmartOrganizerPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('智能整理'), findsOneWidget);
    expect(find.text('今日优先'), findsOneWidget);
    expect(find.text('资料整理'), findsOneWidget);
    expect(find.text('待处理建议'), findsOneWidget);
    expect(find.textContaining('为什么出现'), findsWidgets);
    expect(find.text('忽略'), findsWidgets);
  });

  testWidgets('ignoring an insight removes it from active list', (
    tester,
  ) async {
    final service = _FakeSmartOrganizerService(<SmartInsight>[
      _insight('a', SmartInsightType.today, '可忽略建议'),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: SmartOrganizerPage(service: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('忽略').first);
    await tester.pumpAndSettle();

    expect(service.ignoredIds, contains('a'));
    expect(find.text('可忽略建议'), findsNothing);
  });

  testWidgets('disabled switch shows local organizer disabled state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_smart_organizer_enabled': false,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SmartOrganizerPage(
          service: _FakeSmartOrganizerService(const <SmartInsight>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('已关闭'), findsWidgets);
  });
}

class _FakeSmartOrganizerService extends SmartOrganizerService {
  _FakeSmartOrganizerService(this.items);

  final List<SmartInsight> items;
  final Set<String> ignoredIds = <String>{};
  final Set<String> doneIds = <String>{};

  @override
  Future<List<SmartInsight>> generateInsights({
    bool includeInactive = false,
  }) async {
    return items
        .where((item) => includeInactive || !ignoredIds.contains(item.id))
        .where((item) => includeInactive || !doneIds.contains(item.id))
        .toList();
  }

  @override
  Future<void> ignore(String id) async {
    ignoredIds.add(id);
  }

  @override
  Future<void> markDone(String id) async {
    doneIds.add(id);
  }
}

SmartInsight _insight(String id, SmartInsightType type, String title) {
  return SmartInsight(
    id: id,
    type: type,
    title: title,
    summary: '摘要',
    reason: '本地规则命中',
    sourceKind: 'test',
    sourceId: id,
    priority: SmartInsightPriority.high,
    actions: const <SmartInsightAction>[
      SmartInsightAction(type: SmartInsightActionType.ignore, label: '忽略'),
      SmartInsightAction(type: SmartInsightActionType.markDone, label: '标记完成'),
    ],
    createdAt: DateTime(2026, 6, 8),
  );
}
