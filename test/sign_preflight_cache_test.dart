import 'package:course_helper/api/sign_preflight_cache.dart';
import 'package:course_helper/api/sign_request_profile.dart';
import 'package:course_helper/platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns fresh preflight context and expires old entries', () {
    final now = DateTime(2026, 6, 8, 10);
    final cache = SignPreflightCache(ttl: const Duration(minutes: 3));
    cache.write(
      SignPreflightContext(
        platform: 'chaoxing',
        userId: 'u1',
        activityId: 'a1',
        createdAt: now,
        detailUrl: 'https://example.test/detail',
        referer: 'https://example.test/referer',
      ),
    );

    expect(
      cache.read(
        platform: 'chaoxing',
        userId: 'u1',
        activityId: 'a1',
        now: now.add(const Duration(minutes: 2)),
      ),
      isNotNull,
    );
    expect(
      cache.read(
        platform: 'chaoxing',
        userId: 'u1',
        activityId: 'a1',
        now: now.add(const Duration(minutes: 4)),
      ),
      isNull,
    );
  });

  test('cached preflight referer can feed profile headers only', () {
    final now = DateTime(2026, 6, 8, 10);
    final cache = SignPreflightCache(ttl: const Duration(minutes: 3));
    cache.write(
      SignPreflightContext(
        platform: 'chaoxing',
        userId: 'u1',
        activityId: 'a1',
        createdAt: now,
        detailUrl: 'https://mobilelearn.chaoxing.com/newsign/signDetail',
        referer:
            'https://mobilelearn.chaoxing.com/newsign/signDetail?activePrimaryId=a1&type=1',
      ),
    );

    final cached = cache.read(
      platform: 'chaoxing',
      userId: 'u1',
      activityId: 'a1',
      now: now,
    );
    final profile = SignRequestProfiles.chaoxingMobileLearn(
      referer: cached!.referer!,
    );
    final headers = profile.buildHeaders(
      const SignRequestContext(
        platform: PlatformType.chaoxing,
        url: 'https://mobilelearn.chaoxing.com/pptSign/stuSignajax',
        method: 'GET',
        contentKind: SignRequestContentKind.form,
      ),
    );

    expect(headers['Referer'], contains('/newsign/signDetail'));
    expect(headers['Origin'], 'https://mobilelearn.chaoxing.com');
    expect(headers, isNot(contains('activeId')));
  });
}
