import 'package:course_helper/features/courses/course_load_controller.dart';
import 'package:course_helper/platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'switching accounts invalidates stale responses including A to B to A',
    () {
      final controller = CourseLoadController();
      const a = (PlatformType.chaoxing, 'a', 'https://example.test');
      const b = (PlatformType.chaoxing, 'b', 'https://example.test');
      final first = controller.begin(a)!;
      expect(controller.begin(a), isNull);
      final second = controller.begin(b)!;
      expect(controller.accepts(first, a), isFalse);
      controller.finish(first);
      expect(controller.loading, isTrue);
      final third = controller.begin(a)!;
      expect(controller.accepts(first, a), isFalse);
      expect(controller.accepts(second, b), isFalse);
      expect(controller.accepts(third, a), isTrue);
      controller.invalidate();
      expect(controller.accepts(third, a), isFalse);
    },
  );
}
