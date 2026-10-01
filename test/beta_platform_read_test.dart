import 'dart:convert';
import 'package:course_helper/api/ketangpai_course.dart';
import 'package:course_helper/api/platform_read_exception.dart';
import 'package:course_helper/api/tronclass_sign_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Response<dynamic> response(
  dynamic data, {
  int status = 200,
  String? location,
}) => Response(
  data: data,
  statusCode: status,
  requestOptions: RequestOptions(path: '/list'),
  headers: Headers.fromMap({
    if (location != null) 'location': [location],
  }),
);
Matcher failure(PlatformReadFailure kind) =>
    throwsA(isA<PlatformReadException>().having((e) => e.kind, 'kind', kind));

void main() {
  test('Tronclass preserves JSON maps and text with actual rollcalls', () {
    final payload = {
      'rollcalls': [
        {
          'rollcall_id': '83',
          'course_title': '课程',
          'rollcall_status': 'in_progress',
          'is_expired': false,
        },
      ],
    };
    for (final data in [payload, jsonEncode(payload)]) {
      final parsed = TronclassSignApi.parseRollcalls(response(data));
      expect(parsed.rollcalls.single.rollcallId, 83);
      expect(parsed.rollcalls.single.isInProgress, isTrue);
    }
    expect(
      TronclassSignApi.parseRollcalls(response({'rollcalls': []})).rollcalls,
      isEmpty,
    );
  });
  test('Tronclass malformed responses never become an empty success', () {
    for (final data in [
      null,
      '',
      '<html>login</html>',
      [],
      {},
      {'rollcalls': null},
      {
        'rollcalls': ['bad'],
      },
    ]) {
      expect(
        () => TronclassSignApi.parseRollcalls(response(data)),
        failure(PlatformReadFailure.format),
      );
    }
  });
  test('HTTP and explicit login failures are distinct from a bad document', () {
    for (final status in [401, 403]) {
      expect(
        () => TronclassSignApi.parseRollcalls(response('', status: status)),
        failure(PlatformReadFailure.auth),
      );
    }
    expect(
      () => TronclassSignApi.parseRollcalls(
        response('', status: 302, location: '/auth/login'),
      ),
      failure(PlatformReadFailure.auth),
    );
    expect(
      () => TronclassSignApi.parseRollcalls(response({'error': 'not_login'})),
      failure(PlatformReadFailure.auth),
    );
    expect(
      () => TronclassSignApi.parseRollcalls(response('', status: 503)),
      failure(PlatformReadFailure.server),
    );
    final network = DioException(
      requestOptions: RequestOptions(path: '/list'),
      type: DioExceptionType.connectionTimeout,
    );
    expect(
      PlatformReadException.from(network).kind,
      PlatformReadFailure.network,
    );
  });
  test(
    'KTP numeric and string success codes accept each supported list shape',
    () {
      final items = [
        {'id': 'course1', 'coursename': '高等数学', 'username': '老师'},
      ];
      for (final codes in [
        {'status': 1, 'code': 10000},
        {'status': '1', 'code': '10000'},
      ]) {
        for (final data in [
          items,
          {'list': items},
          {'lists': items},
          {'rows': items},
          {'data': items},
        ]) {
          final courses = KTPCourseApi.parseCourseList(
            response({...codes, 'data': data}),
          );
          expect(courses.single.courseId, 'course1');
          expect(courses.single.name, '高等数学');
        }
      }
      expect(
        KTPCourseApi.parseCourseList(response({'status': '1', 'data': []})),
        isEmpty,
      );
    },
  );
  test(
    'KTP errors and invalid lists cannot replace cached courses with empty data',
    () {
      expect(
        () => KTPCourseApi.parseCourseList(
          response({'code': '20003', 'data': []}),
        ),
        failure(PlatformReadFailure.auth),
      );
      for (final codes in [
        {'status': 0},
        {'status': 0, 'code': 10000},
        {'status': 1, 'code': 40000},
      ]) {
        expect(
          () => KTPCourseApi.parseCourseList(response({...codes, 'data': []})),
          failure(PlatformReadFailure.business),
        );
      }
      for (final data in [
        null,
        {},
        {'other': []},
        ['bad'],
      ]) {
        expect(
          () => KTPCourseApi.parseCourseList(
            response({'status': 1, 'data': data}),
          ),
          failure(PlatformReadFailure.format),
        );
      }
    },
  );
  test('pending attendance supports data.lists', () {
    expect(
      KTPCourseApi.parseReadList(
        response({
          'status': '1',
          'code': '10000',
          'data': {
            'lists': [
              {'id': 'sign-1', 'type': '2'},
            ],
          },
        }),
      ).single['id'],
      'sign-1',
    );
  });
}
