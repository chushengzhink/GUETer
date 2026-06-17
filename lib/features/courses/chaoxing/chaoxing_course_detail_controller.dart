import 'package:flutter/foundation.dart';

import '../../../core/async/app_async_state.dart';
import '../../../models/active.dart';
import '../../../models/course.dart';
import 'chaoxing_course_detail_repository.dart';
import 'chaoxing_course_detail_state.dart';

class ChaoxingCourseDetailController extends ChangeNotifier {
  ChaoxingCourseDetailController({
    required Course course,
    ChaoxingCourseDetailRepository repository =
        const ChaoxingCourseDetailRepository(),
  }) : _course = course,
       _repository = repository;

  final Course _course;
  final ChaoxingCourseDetailRepository _repository;

  AppAsyncState<ChaoxingCourseDetailState> _state =
      const AppAsyncState<ChaoxingCourseDetailState>.idle();

  AppAsyncState<ChaoxingCourseDetailState> get state => _state;

  Future<void> load() => _load(refresh: false);

  Future<void> refresh() => _load(refresh: true);

  Future<void> _load({required bool refresh}) async {
    final previous = _state.data;
    _state = AppAsyncState<ChaoxingCourseDetailState>.loading(
      previousData: previous,
      isRefreshing: refresh && previous != null,
    );
    notifyListeners();

    try {
      final next = await _repository.loadDetail(_course);
      _state = next.isEmpty
          ? const AppAsyncState<ChaoxingCourseDetailState>.empty()
          : AppAsyncState<ChaoxingCourseDetailState>.data(next);
    } catch (error, stackTrace) {
      _state = AppAsyncState<ChaoxingCourseDetailState>.error(
        error,
        stackTrace: stackTrace,
        data: previous,
      );
    }
    notifyListeners();
  }
}

class ChaoxingCourseActivitiesController extends ChangeNotifier {
  ChaoxingCourseActivitiesController({
    required String courseId,
    required String classId,
    required String cpi,
    ChaoxingCourseDetailRepository repository =
        const ChaoxingCourseDetailRepository(),
  }) : _courseId = courseId,
       _classId = classId,
       _cpi = cpi,
       _repository = repository;

  final String _courseId;
  final String _classId;
  final String _cpi;
  final ChaoxingCourseDetailRepository _repository;

  AppAsyncState<List<Active>> _state = const AppAsyncState<List<Active>>.idle();

  AppAsyncState<List<Active>> get state => _state;

  Future<void> load() => _load(refresh: false);

  Future<void> refresh() => _load(refresh: true);

  Future<void> _load({required bool refresh}) async {
    final previous = _state.data;
    _state = AppAsyncState<List<Active>>.loading(
      previousData: previous,
      isRefreshing: refresh && previous != null,
    );
    notifyListeners();

    try {
      final activities = await _repository.loadActivities(
        courseId: _courseId,
        classId: _classId,
        cpi: _cpi,
      );
      if (activities == null) {
        throw StateError('获取内容列表失败');
      }
      _state = activities.isEmpty
          ? const AppAsyncState<List<Active>>.empty()
          : AppAsyncState<List<Active>>.data(activities);
    } catch (error, stackTrace) {
      _state = AppAsyncState<List<Active>>.error(
        error,
        stackTrace: stackTrace,
        data: previous,
      );
    }
    notifyListeners();
  }
}
