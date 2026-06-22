import 'package:course_helper/models/ketangpai_sign.dart';
import 'package:course_helper/pages/widget/ketangpai_sign_task_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPanel(
  WidgetTester tester, {
  required List<Map<String, dynamic>> tasks,
  required List<KetangpaiSignTask> handled,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: KetangpaiSignTaskPanel(
          courseId: 'course-1',
          initialTasks: tasks,
          showBatchEntry: false,
          taskAction: (context, task) async {
            handled.add(task);
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('KetangpaiSignTaskPanel', () {
    testWidgets('dispatches digital, GPS and scan task types', (tester) async {
      final handled = <KetangpaiSignTask>[];
      await _pumpPanel(
        tester,
        handled: handled,
        tasks: [
          {'id': 'sign-1', 'type': 1, 'name': '数字任务'},
          {'id': 'sign-2', 'type': 2, 'name': 'GPS任务'},
          {'id': 'sign-3', 'type': 3, 'name': '扫码任务'},
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey('ketangpai-sign-task-1-sign-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('ketangpai-sign-task-2-sign-2')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('ketangpai-sign-task-3-sign-3')),
      );
      await tester.pumpAndSettle();

      expect(handled.map((task) => task.type), [1, 2, 3]);
      expect(handled.map((task) => task.id), ['sign-1', 'sign-2', 'sign-3']);
    });

    testWidgets('does not dispatch unsupported type 4', (tester) async {
      final handled = <KetangpaiSignTask>[];
      await _pumpPanel(
        tester,
        handled: handled,
        tasks: [
          {'id': 'sign-4', 'type': 4, 'name': '未知任务'},
        ],
      );

      await tester.tap(
        find.byKey(const ValueKey('ketangpai-sign-task-4-sign-4')),
      );
      await tester.pump();

      expect(handled, isEmpty);
      expect(find.textContaining('暂不支持的课堂派签到类型: 4'), findsOneWidget);
    });
  });
}
