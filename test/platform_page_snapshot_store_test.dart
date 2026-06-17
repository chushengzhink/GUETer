import 'package:course_helper/platform.dart';
import 'package:course_helper/services/platform_page_snapshot_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores and reads snapshot by platform account and page', () async {
    final store = PlatformPageSnapshotStore();
    final updatedAt = DateTime(2026, 6, 8, 12);

    await store.writeList(
      platform: PlatformType.chaoxing,
      userId: 'user-a',
      page: 'courses',
      updatedAt: updatedAt,
      data: const <Map<String, dynamic>>[
        <String, dynamic>{'courseId': 'c1', 'name': '高等数学'},
      ],
    );

    final snapshot = await store.readList(
      platform: PlatformType.chaoxing,
      userId: 'user-a',
      page: 'courses',
    );

    expect(snapshot, isNotNull);
    expect(snapshot!.updatedAt, updatedAt);
    expect(snapshot.data, hasLength(1));
    expect(snapshot.data.first['courseId'], 'c1');
  });

  test('isolates snapshots by platform and account', () async {
    final store = PlatformPageSnapshotStore();

    await store.writeList(
      platform: PlatformType.chaoxing,
      userId: 'same-user',
      page: 'todos',
      data: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cx'},
      ],
    );
    await store.writeList(
      platform: PlatformType.tronclass,
      userId: 'same-user',
      page: 'todos',
      data: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'tc'},
      ],
    );
    await store.writeList(
      platform: PlatformType.chaoxing,
      userId: 'other-user',
      page: 'todos',
      data: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'other'},
      ],
    );

    final chaoxing = await store.readList(
      platform: PlatformType.chaoxing,
      userId: 'same-user',
      page: 'todos',
    );
    final tronclass = await store.readList(
      platform: PlatformType.tronclass,
      userId: 'same-user',
      page: 'todos',
    );
    final other = await store.readList(
      platform: PlatformType.chaoxing,
      userId: 'other-user',
      page: 'todos',
    );

    expect(chaoxing!.data.single['id'], 'cx');
    expect(tronclass!.data.single['id'], 'tc');
    expect(other!.data.single['id'], 'other');
  });

  test('stale status keeps data and does not delete snapshot', () async {
    final store = PlatformPageSnapshotStore();
    final updatedAt = DateTime(2026, 6, 8, 10);

    await store.writeList(
      platform: PlatformType.ketangpai,
      userId: 'u1',
      page: 'todos',
      updatedAt: updatedAt,
      data: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'todo-1'},
      ],
    );

    final status = await store.status(
      platform: PlatformType.ketangpai,
      userId: 'u1',
      page: 'todos',
      now: updatedAt.add(const Duration(minutes: 31)),
    );
    final snapshot = await store.readList(
      platform: PlatformType.ketangpai,
      userId: 'u1',
      page: 'todos',
    );

    expect(status, PlatformSnapshotStatus.stale);
    expect(snapshot, isNotNull);
    expect(snapshot!.data.single['id'], 'todo-1');
  });

  test('missing status is returned when no snapshot exists', () async {
    final store = PlatformPageSnapshotStore();

    final status = await store.status(
      platform: PlatformType.rainClassroom,
      userId: 'missing-user',
      page: 'courses',
    );

    expect(status, PlatformSnapshotStatus.missing);
  });
}
