import 'package:course_helper/api/ketangpai_service.dart';
import 'package:course_helper/controllers/exam_controller.dart';
import 'package:course_helper/controllers/sign_controller.dart';
import 'package:course_helper/models/ketangpai_exam.dart';
import 'package:course_helper/models/ketangpai_sign.dart';
import 'package:course_helper/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

User _ketangpaiUser({String token = 'token'}) {
  return User(
    name: '课堂派用户',
    avatar: '',
    phone: '',
    uid: 'kt-user',
    school: '',
    platform: 'ketangpai',
    token: token,
  );
}

KetangpaiServiceResult<Map<String, dynamic>> _mapResult({
  bool success = true,
  String message = 'ok',
  Map<String, dynamic>? data,
  bool authExpired = false,
}) {
  return KetangpaiServiceResult<Map<String, dynamic>>(
    success: success,
    message: message,
    data: data ?? const <String, dynamic>{},
    raw: data ?? const <String, dynamic>{},
    authExpired: authExpired,
  );
}

KetangpaiServiceResult<List<Map<String, dynamic>>> _listResult({
  bool success = true,
  String message = 'ok',
  List<Map<String, dynamic>>? data,
  bool authExpired = false,
}) {
  return KetangpaiServiceResult<List<Map<String, dynamic>>>(
    success: success,
    message: message,
    data: data ?? const <Map<String, dynamic>>[],
    raw: data ?? const <Map<String, dynamic>>[],
    authExpired: authExpired,
  );
}

void main() {
  group('KtSignRecord', () {
    test('fromOutcome and toJson preserve sign result fields', () {
      final time = DateTime(2026, 6, 17, 8, 30);
      final record = KtSignRecord.fromOutcome(
        type: '扫码签到',
        signId: 'ticket-1',
        courseName: '课堂派扫码签到',
        account: 'user',
        time: time,
        outcome: const KetangpaiSignOutcome(
          success: true,
          message: 'signed',
          code: 10000,
          state: 8,
          raw: {'code': 10000},
        ),
      );

      expect(record.success, isTrue);
      expect(record.status, SignStatus.success);
      expect(record.toJson(), containsPair('signId', 'ticket-1'));
      expect(record.toJson(), containsPair('status', 'success'));
      expect(record.toJson(), containsPair('time', time.toIso8601String()));
    });
  });

  group('SignController', () {
    test('scanSign fails before request when token is missing', () async {
      var requested = false;
      final controller = SignController(
        accountProvider: () => _ketangpaiUser(token: ''),
        recordAppender: (_) async {},
        notifier: (_, _, _) {},
        scanSignRequest:
            ({
              required token,
              required signId,
              required rawQr,
              required code,
              required latitude,
              required longitude,
              required accuracy,
            }) async {
              requested = true;
              return _mapResult();
            },
      );

      final record = await controller.scanSign('ticketid=t1&expire=e1&sign=s1');

      expect(record.success, isFalse);
      expect(record.message, '未登录课堂派账号');
      expect(controller.signStatus.value, SignStatus.failed);
      expect(controller.records, hasLength(1));
      expect(requested, isFalse);
    });

    test('scanSign fails on missing QR parameters', () async {
      final controller = SignController(
        accountProvider: () => _ketangpaiUser(),
        recordAppender: (_) async {},
        notifier: (_, _, _) {},
      );

      final record = await controller.scanSign('ticketid=t1&sign=s1');

      expect(record.success, isFalse);
      expect(record.message, contains('expire'));
      expect(controller.error.value, contains('expire'));
    });

    test('numberSign fails on empty sign code', () async {
      final controller = SignController(
        accountProvider: () => _ketangpaiUser(),
        recordAppender: (_) async {},
        notifier: (_, _, _) {},
      );

      final record = await controller.numberSign('sign-1', ' ');

      expect(record.success, isFalse);
      expect(record.message, '签到码不能为空');
      expect(controller.signStatus.value, SignStatus.failed);
    });
  });

  group('ExamController', () {
    test('initializeAnswerCache preserves question myanswer', () {
      final controller = ExamController(notifier: (_, _, _) {});
      controller.initializeAnswerCache([
        KetangpaiExamQuestion.fromJson({
          'id': 'q1',
          'type': '3',
          'myanswer': 'a|b',
          'options': [
            {'id': 'a', 'subjectid': 'q1', 'title': 'A'},
            {'id': 'b', 'subjectid': 'q1', 'title': 'B'},
          ],
        }),
        KetangpaiExamQuestion.fromJson({
          'id': 'q2',
          'type': '4',
          'myanswer': '未作答',
        }),
      ]);

      expect(controller.answerCache, containsPair('q1', 'a|b'));
      expect(controller.answerCache.containsKey('q2'), isFalse);
    });

    test(
      'loadExamDetail initializes current exam, paper and answer cache',
      () async {
        final controller = ExamController(
          notifier: (_, _, _) {},
          detailRequest: ({required courseId, required testPaperId}) async {
            return _mapResult(
              data: {
                'testpaper': {
                  'id': testPaperId,
                  'courseid': courseId,
                  'title': '考试',
                },
              },
            );
          },
          questionsRequest: ({required courseId, required testPaperId}) async {
            return _mapResult(
              data: {
                'lists': [
                  {'id': 'q1', 'type': '2', 'myanswer': 'option-1'},
                ],
                'testpaper': {'id': testPaperId, 'courseid': courseId},
              },
            );
          },
        );

        await controller.loadExamDetail('course-1', 'paper-1');

        expect(controller.error.value, isEmpty);
        expect(controller.currentExam.value?.id, 'paper-1');
        expect(controller.currentPaper.value?.questions, hasLength(1));
        expect(controller.answerCache, containsPair('q1', 'option-1'));
      },
    );

    test('loadExamList surfaces auth expired and clears stale list', () async {
      final controller = ExamController(
        notifier: (_, _, _) {},
        listRequest: ({required courseId}) async {
          return _listResult(
            success: false,
            message: '账号登陆已过期，请重新登陆',
            authExpired: true,
          );
        },
      );
      controller.examList.add(
        KetangpaiExamSummary.fromJson({'id': 'old', 'title': 'old'}),
      );

      await controller.loadExamList('course-1');

      expect(controller.examList, isEmpty);
      expect(controller.error.value, '课堂派登录已过期，请重新登录后再试');
    });

    test('saveAnswer fails when exam detail has not been loaded', () async {
      final controller = ExamController(notifier: (_, _, _) {});

      final result = await controller.saveAnswer('q1', 'answer');

      expect(result, isFalse);
      expect(controller.error.value, '请先加载考试详情');
    });
  });
}
