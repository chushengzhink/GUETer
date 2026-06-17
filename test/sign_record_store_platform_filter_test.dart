import 'package:course_helper/session/sign_record_store.dart';
import 'package:course_helper/platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads and finds latest records by platform', () async {
    final store = SignRecordStore();

    await store.append(
      platform: '学习通',
      platformType: PlatformType.chaoxing,
      courseName: 'course-a',
      account: 'alice',
      status: '成功',
    );
    await store.append(
      platform: '雨课堂',
      platformType: PlatformType.rainClassroom,
      courseName: 'course-b',
      account: 'bob',
      status: '失败',
      detail: 'network',
    );
    await store.append(
      platform: '学习通',
      platformType: PlatformType.chaoxing,
      courseName: 'course-c',
      account: 'carol',
      status: '失败',
    );

    final chaoxing = await store.loadForPlatform('学习通');
    expect(chaoxing, hasLength(2));
    expect(
      chaoxing.every((record) => record['platformKey'] == 'chaoxing'),
      isTrue,
    );
    expect(chaoxing.first['courseName'], 'course-c');

    final rain = await store.latestForPlatform('rainclassroom');
    expect(rain?['account'], 'bob');

    final all = await store.loadForPlatform('全部');
    expect(all, hasLength(3));
  });

  test('keeps legacy records filterable without platformKey', () async {
    final store = SignRecordStore();
    await store.saveRaw([
      {
        'platform': '畅课',
        'courseName': 'old-tc',
        'account': 'tc',
        'status': '成功',
        'timestamp': 2,
      },
      {
        'platform': '课堂派',
        'courseName': 'old-kt',
        'account': 'kt',
        'status': '失败',
        'timestamp': 1,
      },
    ]);

    final tronclass = await store.loadForPlatform('tronclass');
    final ketangpai = await store.loadForPlatform('课堂派');

    expect(tronclass, hasLength(1));
    expect(tronclass.single['courseName'], 'old-tc');
    expect(ketangpai, hasLength(1));
    expect(ketangpai.single['courseName'], 'old-kt');
  });

  test('rejects all as record platform', () async {
    final store = SignRecordStore();

    expect(
      () => store.append(
        platform: '全部',
        courseName: 'bad',
        account: 'alice',
        status: '失败',
      ),
      throwsArgumentError,
    );
  });
}
