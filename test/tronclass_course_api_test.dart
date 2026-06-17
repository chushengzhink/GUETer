import 'package:course_helper/api/course.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TCCourseApi course list parsing', () {
    test('parses root data list', () {
      final courses = TCCourseApi.parseCourseListPayload({
        'data': [
          {
            'id': 101,
            'name': 'Linear Algebra',
            'cover_url': 'https://example.test/cover.png',
            'teacher': {'name': 'Teacher A'},
          },
        ],
      });

      expect(courses, isNotNull);
      expect(courses, hasLength(1));
      expect(courses!.single.courseId, '101');
      expect(courses.single.name, 'Linear Algebra');
      expect(courses.single.teacher, 'Teacher A');
    });

    test('parses nested data items', () {
      final courses = TCCourseApi.parseCourseListPayload({
        'data': {
          'items': [
            {
              'id': 'course-1',
              'name': 'Physics',
              'teacher': {'name': 'Teacher B'},
            },
          ],
        },
      });

      expect(courses, isNotNull);
      expect(courses, hasLength(1));
      expect(courses!.single.courseId, 'course-1');
      expect(courses.single.name, 'Physics');
    });

    test('parses root list and root list key', () {
      final directList = TCCourseApi.parseCourseListPayload([
        {'id': 'direct', 'name': 'Direct Course'},
      ]);
      final listKey = TCCourseApi.parseCourseListPayload({
        'list': [
          {'id': 'list-key', 'name': 'List Course'},
        ],
      });

      expect(directList, hasLength(1));
      expect(directList!.single.courseId, 'direct');
      expect(listKey, hasLength(1));
      expect(listKey!.single.courseId, 'list-key');
    });

    test('returns null when response has no course list shape', () {
      expect(
        TCCourseApi.parseCourseListPayload({
          'data': {'total': 0},
        }),
        isNull,
      );
      expect(TCCourseApi.parseCourseListPayload('bad response'), isNull);
    });
  });
}
