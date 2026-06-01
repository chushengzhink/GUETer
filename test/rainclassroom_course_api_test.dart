import 'package:course_helper/api/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RCCourseApi request builders', () {
    test('builds lesson page request body without joinIfNotIn', () {
      final body = RCCourseApi.buildCheckInRequestBody(
        '1679317067431740800',
        source: 12,
      );

      expect(body, {'source': 12, 'lessonId': '1679317067431740800'});
    });

    test('builds dynamic QR request body with joinIfNotIn', () {
      final body = RCCourseApi.buildCheckInRequestBody(
        '1679317067431740800',
        source: 21,
        joinIfNotIn: true,
      );

      expect(body, {
        'source': 21,
        'lessonId': '1679317067431740800',
        'joinIfNotIn': true,
      });
    });

    test('builds headers with referer and bearer token', () {
      final headers = RCCourseApi.buildCheckInHeaders(
        referer: RCCourseApi.buildLessonPageReferer('1679317067431740800'),
        bearerToken: 'abc123',
      );

      expect(
        headers['Referer'],
        contains('/lesson/student/v3/1679317067431740800?source=12'),
      );
      expect(headers['authorization'], 'Bearer abc123');
    });

    test('builds mini program request without bearer token', () {
      final body = RCCourseApi.buildCheckInRequestBody(
        '1680115241318773376',
        source: 11,
      );
      final headers = RCCourseApi.buildCheckInHeaders(
        referer: RCCourseApi.buildMiniProgramReferer(),
      );

      expect(body, {'source': 11, 'lessonId': '1680115241318773376'});
      expect(
        headers['Referer'],
        'https://servicewechat.com/wxdff6636b7cf6907d/207/page-frame.html',
      );
      expect(headers.containsKey('authorization'), isFalse);
    });
  });
}
