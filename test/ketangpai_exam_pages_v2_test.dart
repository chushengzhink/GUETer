import 'package:course_helper/api/ketangpai_service.dart';
import 'package:course_helper/controllers/exam_controller.dart';
import 'package:course_helper/models/course.dart';
import 'package:course_helper/pages/ketangpai_exam_page_v2.dart';
import 'package:course_helper/pages/ketangpai_exam_question_page_v2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Course _course() {
  return Course(
    courseId: 'course-1',
    classId: 'class-1',
    image: '',
    name: '课堂派课程',
    teacher: 'Teacher',
    state: true,
  );
}

KetangpaiServiceResult<Map<String, dynamic>> _mapResult(
  Map<String, dynamic> data,
) {
  return KetangpaiServiceResult<Map<String, dynamic>>(
    success: true,
    message: 'ok',
    data: data,
    raw: data,
  );
}

KetangpaiServiceResult<List<Map<String, dynamic>>> _listResult(
  List<Map<String, dynamic>> data,
) {
  return KetangpaiServiceResult<List<Map<String, dynamic>>>(
    success: true,
    message: 'ok',
    data: data,
    raw: data,
  );
}

ExamController _examController({
  void Function(String subjectId, String answer)? onSave,
  void Function(String courseId, String paperId)? onSubmit,
}) {
  return ExamController(
    notifier: (_, _, _) {},
    listRequest: ({required courseId}) async {
      return _listResult([
        {
          'id': 'paper-1',
          'courseid': courseId,
          'title': '期末考试',
          'type': '1',
          'fullscore': '100',
          'submit_state': '2',
          'over': '0',
        },
      ]);
    },
    detailRequest: ({required courseId, required testPaperId}) async {
      return _mapResult({
        'testpaper': {'id': testPaperId, 'courseid': courseId, 'title': '期末考试'},
      });
    },
    questionsRequest: ({required courseId, required testPaperId}) async {
      return _mapResult({
        'lists': [
          {
            'id': 'single',
            'title': '<p>单选题</p>',
            'type': '2',
            'score': '5',
            'options': [
              {'id': 'a', 'subjectid': 'single', 'title': '<p>A</p>'},
              {'id': 'b', 'subjectid': 'single', 'title': '<p>B</p>'},
            ],
          },
          {
            'id': 'multi',
            'title': '<p>多选题</p>',
            'type': '3',
            'score': '6',
            'options': [
              {'id': 'm1', 'subjectid': 'multi', 'title': '<p>M1</p>'},
              {'id': 'm2', 'subjectid': 'multi', 'title': '<p>M2</p>'},
            ],
          },
          {
            'id': 'judge',
            'title': '<p>判断题</p>',
            'type': '1',
            'score': '2',
            'options': [
              {'id': 'true-id', 'subjectid': 'judge', 'title': '正确'},
              {'id': 'false-id', 'subjectid': 'judge', 'title': '错误'},
            ],
          },
          {'id': 'blank', 'title': '<p>填空题</p>', 'type': '5', 'score': '3'},
          {'id': 'short', 'title': '<p>简答题</p>', 'type': '4', 'score': '10'},
        ],
        'testpaper': {'id': testPaperId, 'courseid': courseId},
      });
    },
    saveRequest:
        ({
          required courseId,
          required testPaperId,
          required subjectId,
          required answer,
        }) async {
          onSave?.call(subjectId, answer);
          return _mapResult({'ok': true});
        },
    submitRequest: ({required courseId, required testPaperId}) async {
      onSubmit?.call(courseId, testPaperId);
      return _mapResult({'ok': true});
    },
  );
}

Future<void> _pumpQuestionPage(
  WidgetTester tester, {
  ExamController? controller,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: KetangpaiExamQuestionPageV2(
        courseId: 'course-1',
        paperId: 'paper-1',
        examController: controller ?? _examController(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    Get.reset();
  });

  testWidgets('exam list renders title, status and score', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: KetangpaiExamPageV2(
          course: _course(),
          examController: _examController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('期末考试'), findsOneWidget);
    expect(find.text('未提交'), findsOneWidget);
    expect(find.text('总分 100'), findsOneWidget);
  });

  testWidgets('question page renders single and multiple choice controls', (
    tester,
  ) async {
    await _pumpQuestionPage(tester);

    expect(find.byType(RadioListTile<String>), findsNWidgets(2));
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });

  testWidgets('judge question writes selected answer into cache', (
    tester,
  ) async {
    final controller = _examController();
    await _pumpQuestionPage(tester, controller: controller);

    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('正确'));
    await tester.pump();

    expect(controller.answerCache['judge'], 'true-id');
  });

  testWidgets('text answer is saved once after debounce', (tester) async {
    final saves = <String, String>{};
    final controller = _examController(
      onSave: (subjectId, answer) {
        saves[subjectId] = answer;
      },
    );
    await _pumpQuestionPage(tester, controller: controller);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('下一题'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).first, 'first');
    await tester.enterText(find.byType(TextField).first, 'final answer');
    await tester.pump(const Duration(milliseconds: 499));
    expect(saves, isEmpty);

    await tester.pump(const Duration(milliseconds: 2));
    expect(saves, containsPair('blank', 'final answer'));
  });

  testWidgets('PageView keeps text input state after switching pages', (
    tester,
  ) async {
    await _pumpQuestionPage(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('下一题'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).first, 'kept answer');
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上一题'));
    await tester.pumpAndSettle();

    expect(find.text('kept answer'), findsOneWidget);
  });

  testWidgets('dispose cancels pending debounce timer', (tester) async {
    var saveCount = 0;
    final controller = _examController(
      onSave: (_, _) {
        saveCount++;
      },
    );
    await _pumpQuestionPage(tester, controller: controller);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('下一题'));
      await tester.pumpAndSettle();
    }
    await tester.enterText(find.byType(TextField).first, 'pending');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 1));

    expect(saveCount, 0);
  });

  testWidgets('confirm submit calls submitExam', (tester) async {
    String? submittedCourseId;
    String? submittedPaperId;
    final controller = _examController(
      onSubmit: (courseId, paperId) {
        submittedCourseId = courseId;
        submittedPaperId = paperId;
      },
    );
    await _pumpQuestionPage(tester, controller: controller);

    await tester.tap(find.text('交卷'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '交卷').last);
    await tester.pumpAndSettle();

    expect(submittedCourseId, 'course-1');
    expect(submittedPaperId, 'paper-1');
  });
}
