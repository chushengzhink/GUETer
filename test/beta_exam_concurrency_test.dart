import 'dart:async';
import 'package:course_helper/api/ketangpai_service.dart';
import 'package:course_helper/controllers/exam_controller.dart';
import 'package:flutter_test/flutter_test.dart';

KetangpaiServiceResult<Map<String, dynamic>> result({bool ok = true}) =>
    KetangpaiServiceResult(
      success: ok,
      message: ok ? 'ok' : 'offline',
      data: const {},
      raw: const {},
    );

void main() {
  test(
    'older save cannot overwrite a newer answer; writes are serialized',
    () async {
      final completions =
          <Completer<KetangpaiServiceResult<Map<String, dynamic>>>>[];
      final answers = <String>[];
      final controller = ExamController(
        notifier: (_, _, _) {},
        detailRequest: ({required courseId, required testPaperId}) async =>
            result(),
        questionsRequest: ({required courseId, required testPaperId}) async =>
            result(),
        saveRequest:
            ({
              required courseId,
              required testPaperId,
              required subjectId,
              required answer,
            }) {
              answers.add(answer);
              final completion =
                  Completer<KetangpaiServiceResult<Map<String, dynamic>>>();
              completions.add(completion);
              return completion.future;
            },
      );
      await controller.loadExamDetail('course', 'paper');
      controller.updateCachedAnswer('question', 'A');
      final first = controller.saveAnswer('question', 'A');
      controller.updateCachedAnswer('question', 'B');
      final second = controller.saveAnswer('question', 'B');
      expect(answers, ['A']);
      completions.first.complete(result());
      await first;
      expect(controller.answerCache['question'], 'B');
      expect(controller.unsavedAnswers, contains('question'));
      expect(answers, ['A', 'B']);
      completions.last.complete(result(ok: false));
      expect(await second, isFalse);
      expect(controller.answerCache['question'], 'B');
      expect(controller.unsavedAnswers, contains('question'));
      expect(controller.isSaving.value, isFalse);
      expect(answers.length, 2); // Failed writes are not automatically retried.
    },
  );

  test(
    'duplicate submission while pending or after success is suppressed',
    () async {
      final pending = Completer<KetangpaiServiceResult<Map<String, dynamic>>>();
      var submissions = 0;
      final controller = ExamController(
        notifier: (_, _, _) {},
        submitRequest: ({required courseId, required testPaperId}) {
          submissions++;
          return pending.future;
        },
      );
      final first = controller.submitExam('course', 'paper');
      expect(await controller.submitExam('course', 'paper'), isFalse);
      expect(submissions, 1);
      pending.complete(result());
      expect(await first, isTrue);
      expect(await controller.submitExam('course', 'paper'), isFalse);
      expect(submissions, 1);
    },
  );
}
