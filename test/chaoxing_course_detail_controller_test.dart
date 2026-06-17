import 'dart:async';

import 'package:course_helper/core/async/app_async_state.dart';
import 'package:course_helper/features/courses/chaoxing/chaoxing_course_detail_controller.dart';
import 'package:course_helper/features/courses/chaoxing/chaoxing_course_detail_repository.dart';
import 'package:course_helper/features/courses/chaoxing/chaoxing_course_detail_state.dart';
import 'package:course_helper/models/active.dart';
import 'package:course_helper/models/course.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChaoxingCourseDetailRepository
    extends ChaoxingCourseDetailRepository {
  _FakeChaoxingCourseDetailRepository({required this.loader});

  final Future<ChaoxingCourseDetailState> Function(Course course) loader;

  @override
  Future<ChaoxingCourseDetailState> loadDetail(Course course) {
    return loader(course);
  }
}

void main() {
  final course = Course(
    courseId: 'course-1',
    classId: 'class-1',
    cpi: 'cpi-1',
    image: '',
    name: 'Course',
    teacher: 'Teacher',
    state: true,
  );

  Active active() {
    return Active(
      type: ActiveType.signIn.value,
      id: 'active-1',
      name: 'Sign',
      description: 'desc',
      startTime: 0,
      url: '',
      status: true,
      extras: const <String, dynamic>{},
    );
  }

  test('load publishes data state on success', () async {
    final controller = ChaoxingCourseDetailController(
      course: course,
      repository: _FakeChaoxingCourseDetailRepository(
        loader: (_) async => ChaoxingCourseDetailState(
          activities: [active()],
          chapters: const <Map<String, dynamic>>[],
          unfinishedTasks: const <Map<String, dynamic>>[],
        ),
      ),
    );

    await controller.load();

    expect(controller.state.status, AppAsyncStatus.data);
    expect(controller.state.data?.activities, hasLength(1));
  });

  test(
    'load publishes empty state when repository returns no content',
    () async {
      final controller = ChaoxingCourseDetailController(
        course: course,
        repository: _FakeChaoxingCourseDetailRepository(
          loader: (_) async => const ChaoxingCourseDetailState(
            activities: <Active>[],
            chapters: <Map<String, dynamic>>[],
            unfinishedTasks: <Map<String, dynamic>>[],
          ),
        ),
      );

      await controller.load();

      expect(controller.state.status, AppAsyncStatus.empty);
    },
  );

  test('load publishes error state on repository exception', () async {
    final controller = ChaoxingCourseDetailController(
      course: course,
      repository: _FakeChaoxingCourseDetailRepository(
        loader: (_) =>
            Future<ChaoxingCourseDetailState>.error(StateError('boom')),
      ),
    );

    await controller.load();

    expect(controller.state.status, AppAsyncStatus.error);
    expect(controller.state.error, isA<StateError>());
  });

  test('refresh keeps previous data while loading', () async {
    final gate = Completer<ChaoxingCourseDetailState>();
    var calls = 0;
    final controller = ChaoxingCourseDetailController(
      course: course,
      repository: _FakeChaoxingCourseDetailRepository(
        loader: (_) {
          calls++;
          if (calls == 1) {
            return Future.value(
              ChaoxingCourseDetailState(
                activities: [active()],
                chapters: const <Map<String, dynamic>>[],
                unfinishedTasks: const <Map<String, dynamic>>[],
              ),
            );
          }
          return gate.future;
        },
      ),
    );

    await controller.load();
    final refreshFuture = controller.refresh();

    expect(controller.state.status, AppAsyncStatus.loading);
    expect(controller.state.isRefreshing, isTrue);
    expect(controller.state.data?.activities, hasLength(1));

    gate.complete(
      ChaoxingCourseDetailState(
        activities: [active()],
        chapters: const <Map<String, dynamic>>[],
        unfinishedTasks: const <Map<String, dynamic>>[],
      ),
    );
    await refreshFuture;
  });
}
