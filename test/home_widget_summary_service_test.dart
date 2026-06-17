import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:course_helper/services/home_widget_summary_service.dart';
import 'package:course_helper/study/study_card_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'todo_today_count': 2,
      'todo_nearest_title': '完成 2500520215 的作业',
    });
  });

  test('widget summary uses local counts and masks id-like text', () async {
    final service = HomeWidgetSummaryService(studyCardStore: StudyCardStore());
    await StudyCardStore().addCard(front: 'Q', back: 'A');

    final summary = await service.buildSummary();

    expect(summary.todoCount, 2);
    expect(summary.reviewDueCount, 1);
    expect(summary.nearestTodoTitle, isNot(contains('2500520215')));
    expect(summary.toJson().keys, contains('reviewDueCount'));
  });
}
