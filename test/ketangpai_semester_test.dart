import 'dart:async';
import 'package:course_helper/features/courses/course_load_controller.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/ketangpai_semester.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'first-use defaults cover January, February and September boundaries',
    () {
      for (final sample in [
        (DateTime(2026, 1, 31), '2025-2026:1'),
        (DateTime(2026, 2, 1), '2025-2026:2'),
        (DateTime(2026, 8, 31), '2025-2026:2'),
        (DateTime(2026, 9, 1), '2026-2027:1'),
        (DateTime(2026, 12, 31), '2026-2027:1'),
        (DateTime(2027, 1, 1), '2026-2027:1'),
      ]) {
        expect(KetangpaiSemester.forDate(sample.$1).key, sample.$2);
      }
    },
  );
  test(
    'selection survives restart and is isolated by account and normalized site',
    () async {
      final store = KetangpaiSemesterStore();
      await store.select(
        'alice',
        'https://a.test/',
        const KetangpaiSemester(2024, 2),
      );
      await store.select(
        'bob',
        'https://a.test',
        const KetangpaiSemester(2023, 1),
      );
      await store.select(
        'alice',
        'https://b.test',
        const KetangpaiSemester(2022, 2),
      );
      final restored = KetangpaiSemesterStore();
      expect(
        (await restored.load('alice', 'https://a.test')).key,
        '2024-2025:2',
      );
      expect((await restored.load('bob', 'https://a.test')).key, '2023-2024:1');
      expect(
        (await restored.load('alice', 'https://b.test')).key,
        '2022-2023:2',
      );
      await restored.select(
        'alice',
        'https://a.test',
        const KetangpaiSemester(2025, 1),
      );
      expect(
        (await restored.load('alice', 'https://a.test')).key,
        '2025-2026:1',
      );
    },
  );
  test(
    'same-context refresh shares completion while semester changes invalidate old results',
    () async {
      final controller = CourseLoadController();
      const a = (PlatformType.ketangpai, 'a', 'https://a.test', '2025-2026:2');
      const b = (PlatformType.ketangpai, 'a', 'https://a.test', '2026-2027:1');
      final gate = Completer<void>();
      var calls = 0;
      Future<void> fetch() {
        calls++;
        return gate.future;
      }

      controller.switchContext(a);
      final generation = controller.begin(a)!;
      final first = controller.share(a, fetch);
      final duplicate = controller.share(a, fetch);
      expect(identical(first, duplicate), isTrue);
      expect(calls, 1);
      final next = controller.begin(b)!;
      expect(controller.accepts(generation, a), isFalse);
      controller.finish(generation);
      expect(controller.accepts(next, b), isTrue);
      gate.complete();
      await first;
    },
  );
}
