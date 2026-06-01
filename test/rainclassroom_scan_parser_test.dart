import 'package:course_helper/utils/rainclassroom_scan_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RainClassroomScanParser', () {
    test('classifies lesson page QR URLs', () {
      final uri = Uri.parse(
        'https://www.yuketang.cn/lesson/student/v3/1679317067431740800?source=12',
      );

      final target = RainClassroomScanParser.classifyUri(uri);

      expect(target, isNotNull);
      expect(target!.kind, RainClassroomScanKind.lessonPage);
      expect(target.lessonId, '1679317067431740800');
    });

    test('classifies weixin lesson entry URLs as lesson page sign-in', () {
      final uri = Uri.parse(
        'https://www.yuketang.cn/v/lesson/lesson_info_entry/1679317067431740800?ppt_version=5&source=12&role=student',
      );

      final target = RainClassroomScanParser.classifyUri(uri);

      expect(target, isNotNull);
      expect(target!.kind, RainClassroomScanKind.lessonPage);
      expect(target.lessonId, '1679317067431740800');
    });

    test('classifies dynamic QR URLs', () {
      final uri = Uri.parse(
        'https://www.yuketang.cn/api/v3/lesson/check-in/dynamic-qr-code?c=abc&t=1&s=2&v=2',
      );

      final target = RainClassroomScanParser.classifyUri(uri);

      expect(target, isNotNull);
      expect(target!.kind, RainClassroomScanKind.dynamicQr);
      expect(target.lessonId, isNull);
    });

    test('extracts rain classroom target URL from encoded text', () {
      const raw =
          'redirect=https%3A%2F%2Fwww.yuketang.cn%2Flesson%2Fstudent%2Fv3%2F1679317067431740800%3Fsource%3D12';

      final targetUri = RainClassroomScanParser.extractTargetUriFromText(raw);

      expect(targetUri, isNotNull);
      expect(
        targetUri.toString(),
        'https://www.yuketang.cn/lesson/student/v3/1679317067431740800?source=12',
      );
    });

    test('extracts lesson info entry URL from copied wechat text', () {
      const raw =
          'https://www.yuketang.cn/v/lesson/lesson_info_entry/1679317067431740800?ppt_version=5&source=12&role=student';

      final targetUri = RainClassroomScanParser.extractTargetUriFromText(raw);

      expect(targetUri, isNotNull);
      expect(
        targetUri.toString(),
        'https://www.yuketang.cn/v/lesson/lesson_info_entry/1679317067431740800?ppt_version=5&source=12&role=student',
      );
    });
  });
}
