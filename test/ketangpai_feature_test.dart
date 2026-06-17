import 'package:course_helper/api/ketangpai_content_utils.dart';
import 'package:course_helper/api/ketangpai_response.dart';
import 'package:course_helper/api/ketangpai_service.dart';
import 'package:course_helper/api/kt_sign.dart';
import 'package:course_helper/models/ketangpai_exam.dart';
import 'package:course_helper/models/ketangpai_sign.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ketangpai response helpers', () {
    test('extracts list from supported payload shapes', () {
      expect(
        extractKetangpaiList({
          'status': 1,
          'data': {
            'list': [
              {'id': 1},
            ],
          },
        }),
        hasLength(1),
      );
      expect(
        extractKetangpaiList({
          'code': 10000,
          'data': [
            {'id': 2},
          ],
        }).single['id'],
        2,
      );
    });

    test('parses message from data info first', () {
      expect(
        ketangpaiMessageOf({
          'message': 'outer',
          'data': {'info': 'inner'},
        }),
        'inner',
      );
    });

    test('recognizes auth expired responses as failures', () {
      final expired = {
        'status': 0,
        'code': 20003,
        'message': '账号登陆已过期，请重新登陆',
        'data': <String, dynamic>{},
      };

      expect(isKetangpaiAuthExpired(expired), isTrue);
      expect(isKetangpaiSuccess(expired), isFalse);
      expect(
        isKetangpaiAuthExpired({
          'status': 1,
          'code': 10000,
          'message': '登录已过期，请重新登录',
        }),
        isTrue,
      );
    });
  });

  group('Ketangpai content helpers', () {
    test('normalizes resource links from nested attachments', () {
      final links = extractKetangpaiResourceLinks({
        'title': 'lesson',
        'attachments': [
          {'fileUrl': '//cdn.example.com/a.pdf', 'filename': 'a.pdf'},
          {'url': '/download/b.docx', 'name': 'b.docx'},
        ],
      });

      expect(links.map((link) => link.url), [
        'https://cdn.example.com/a.pdf',
        'https://openapiv5.ketangpai.com/download/b.docx',
      ]);
      expect(links.map((link) => link.name), ['a.pdf', 'b.docx']);
    });
  });

  group('Ketangpai sign helpers', () {
    test(
      'extracts scan params from full URL, raw query and html escaped query',
      () {
        expect(
          KTSignApi.extractScanParams(
            'https://w.ketangpai.com/check?ticketid=t1&expire=e1&sign=s1',
          ),
          {'ticketid': 't1', 'expire': 'e1', 'sign': 's1'},
        );
        expect(KTSignApi.extractScanParams('ticketid=t2&expire=e2&sign=s2'), {
          'ticketid': 't2',
          'expire': 'e2',
          'sign': 's2',
        });
        expect(
          KTSignApi.extractScanParams('ticketid=t3&amp;expire=e3&amp;sign=s3'),
          {'ticketid': 't3', 'expire': 'e3', 'sign': 's3'},
        );
      },
    );

    test('structured result preserves message, code and state', () {
      final result = KetangpaiSignResult.fromResponse({
        'code': 10000,
        'message': 'ok',
        'data': {'state': 8, 'info': 'signed'},
      });

      expect(result.success, isTrue);
      expect(result.message, 'signed');
      expect(result.code, 10000);
      expect(result.state, 8);
    });

    test('gps result requires explicit coordinates', () async {
      final result = await KTSignApi.gpsSignResult(
        token: 'token',
        signId: 'sign',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('经纬度'));
    });
  });

  group('Ketangpai sign models', () {
    test('scan payload validates full, escaped and missing params', () {
      final payload = KTSignApi.parseScanPayload(
        'https://w.ketangpai.com/check?ticketid=t1&amp;expire=e1&amp;sign=s1',
      );
      expect(payload.isValid, isTrue);
      expect(payload.ticketId, 't1');

      final missing = KTSignApi.parseScanPayload('ticketid=t2&sign=s2');
      expect(missing.isValid, isFalse);
      expect(missing.missingKeys, ['expire']);
    });

    test('location payload validates coordinates and default accuracy', () {
      final empty = KetangpaiLocationPayload.fromJson({'latitude': '25.3'});
      expect(empty.isValid, isFalse);
      expect(empty.accuracy, '100');

      final location = KetangpaiLocationPayload(
        latitude: '25.3',
        longitude: '110.4',
      );
      expect(location.isValid, isTrue);
      expect(location.toJson()['accuracy'], '100');
    });

    test('sign task and outcome parse mixed response shapes', () {
      final task = KetangpaiSignTask.fromJson({
        'id': 123,
        'type': '4',
        'name': 'GPS签到',
        'starttime': 100,
        'endtime': 200,
        'courseid': 'course-1',
      });
      expect(task.id, '123');
      expect(task.type, 4);
      expect(task.name, 'GPS签到');
      expect(task.courseId, 'course-1');

      final outcome = KetangpaiSignOutcome.fromJson({
        'code': 10000,
        'message': 'ok',
        'data': {'state': 8, 'info': 'signed'},
      });
      expect(outcome.success, isTrue);
      expect(outcome.message, 'signed');
      expect(outcome.state, 8);
    });
  });

  group('Ketangpai exam models', () {
    test('question type enum maps 1-6 and unknown values', () {
      expect(KetangpaiQuestionType.fromCode(1), KetangpaiQuestionType.judge);
      expect(
        KetangpaiQuestionType.fromCode('2'),
        KetangpaiQuestionType.singleChoice,
      );
      expect(
        KetangpaiQuestionType.fromCode(3),
        KetangpaiQuestionType.multipleChoice,
      );
      expect(
        KetangpaiQuestionType.fromCode(4),
        KetangpaiQuestionType.shortAnswer,
      );
      expect(
        KetangpaiQuestionType.fromCode(5),
        KetangpaiQuestionType.fillBlank,
      );
      expect(
        KetangpaiQuestionType.fromCode('6'),
        KetangpaiQuestionType.multipleChoiceAlt,
      );
      expect(KetangpaiQuestionType.fromCode(99), KetangpaiQuestionType.unknown);
    });

    test('exam summary accepts string, int and null fields', () {
      final summary = KetangpaiExamSummary.fromJson({
        'id': 123,
        'courseid': null,
        'title': '期末测试',
        'type': 1,
        'fullscore': 100,
        'timelength': '45',
        'over': '1',
        'submit_state': '8',
        'activitylabel': null,
      });

      expect(summary.id, '123');
      expect(summary.courseId, '');
      expect(summary.title, '期末测试');
      expect(summary.fullScore, '100');
      expect(summary.timeLength, 45);
      expect(summary.over, isTrue);
      expect(summary.submitState, 8);
      expect(summary.activityLabel, '');
    });

    test('exam detail parses cutscreen, lesson links and submit state', () {
      final detail = KetangpaiExamDetail.fromJson({
        'testpaper': {
          'id': 'paper-1',
          'courseid': 'course-1',
          'title': '考试',
          'description': '<p>desc</p>',
          'timelength': '60',
          'over': '0',
          'totalScore': '100',
          'subjectCount': '2',
          'submit_status': '3',
          'submit_state': 8,
          'score': '88',
          'nickname': 'Teacher',
          'avatar': 'avatar.png',
          'activitylabel': '考试',
          'cutscreen': {
            'cutscreenState': 1,
            'testpaperAllCount': '5',
            'studentCount': 2,
            'lastCount': '3',
            'testCode': 'abc',
            'isFirstJoin': 1,
          },
          'lessonlink': [
            {'type': '1', 'name': '期末'},
          ],
        },
      });

      expect(detail.id, 'paper-1');
      expect(detail.totalScore, 100);
      expect(detail.subjectCount, 2);
      expect(detail.submitStatus, 3);
      expect(detail.submitState, 8);
      expect(detail.cutScreen.enabled, isTrue);
      expect(detail.cutScreen.remainingCount, 3);
      expect(detail.lessonLinks.single.name, '期末');
    });

    test('exam paper preserves options and myanswer', () {
      final paper = KetangpaiExamPaper.fromJson({
        'lists': [
          {
            'id': 'q1',
            'title': '<p>题目</p>',
            'type': '3',
            'score': '5',
            'sort': '1',
            'difficulty': '2',
            'replenishtype': '多选题',
            'myanswer': 'a|b',
            'options': [
              {'id': 'a', 'subjectid': 'q1', 'title': '<p>A</p>'},
              {'id': 'b', 'subjectid': 'q1', 'title': '<p>B</p>'},
            ],
          },
        ],
        'handupState': '0',
        'rehandup': '1',
        'testpaper': {'title': '试卷'},
        'remainTimes': '2',
        'fallback_number': '1',
      });

      final question = paper.questions.single;
      expect(question.type, KetangpaiQuestionType.multipleChoice);
      expect(question.score, 5);
      expect(question.options, hasLength(2));
      expect(question.myAnswer, 'a|b');
      expect(paper.remainingTimes, 2);
      expect(paper.fallbackNumber, 1);
    });
  });

  group('Ketangpai service helpers', () {
    test('extracts scan params through service adapter', () {
      expect(
        KetangpaiService.extractScanParams(
          'https://w.ketangpai.com/checkIn?ticketid=t1&expire=e1&sign=s1',
        ),
        {'ticketid': 't1', 'expire': 'e1', 'sign': 's1'},
      );
      expect(
        KetangpaiService.extractScanParams(
          'ticketid=t2&amp;expire=e2&amp;sign=s2',
        ),
        {'ticketid': 't2', 'expire': 'e2', 'sign': 's2'},
      );
      expect(KetangpaiService.extractScanParams('ticketid=t3&sign=s3'), {
        'ticketid': 't3',
        'expire': '',
        'sign': 's3',
      });
    });

    test('maps scan success from data state', () {
      final result = KetangpaiService.mapResult(
        {
          'status': 0,
          'code': 0,
          'message': 'outer',
          'data': {'state': 8, 'info': 'signed'},
        },
        successWhen: (map) {
          final data = asKetangpaiMap(map['data']);
          return data?['state'] == 8;
        },
      );

      expect(result.success, isTrue);
      expect(result.message, 'signed');
      expect(result.state, 8);
    });

    test('extracts exam list from nested payloads', () {
      final result = KetangpaiService.listResult({
        'status': 1,
        'data': {
          'list': [
            {'id': 'paper-1'},
            {'id': 'paper-2'},
          ],
        },
      });

      expect(result.success, isTrue);
      expect(result.data, hasLength(2));
      expect(result.data!.first['id'], 'paper-1');
    });

    test('maps auth expired exam list response as failure', () {
      final result = KetangpaiService.listResult({
        'status': 0,
        'code': 20003,
        'message': '账号登陆已过期，请重新登陆',
        'data': <String, dynamic>{},
      });

      expect(result.success, isFalse);
      expect(result.authExpired, isTrue);
      expect(result.code, 20003);
      expect(result.message, '账号登陆已过期，请重新登陆');
      expect(result.data, isEmpty);
    });

    test('maps exam detail, question, save and submit responses', () {
      final detail = KetangpaiService.mapResult({
        'status': 1,
        'code': 10000,
        'data': {'testpaperid': 'paper-1'},
      });
      final questions = KetangpaiService.mapResult({
        'status': 1,
        'data': {
          'lists': [
            {'id': 'q1', 'type': '2'},
          ],
        },
      });
      final saved = KetangpaiService.mapResult({
        'code': 10000,
        'message': 'saved',
        'data': {},
      });
      final submitted = KetangpaiService.mapResult({
        'code': 10000,
        'message': 'submitted',
        'data': {},
      });

      expect(detail.success, isTrue);
      expect(detail.data?['testpaperid'], 'paper-1');
      expect(questions.success, isTrue);
      expect(questions.data?['lists'], isA<List>());
      expect(saved.success, isTrue);
      expect(saved.message, 'saved');
      expect(submitted.success, isTrue);
      expect(submitted.message, 'submitted');
    });
  });
}
