import '../../models/course.dart';
import '../../platform.dart';

// Platform, account, endpoint, and semester (empty for other platforms).
typedef CourseContext = (PlatformType, String, String, String);

/// Owns per-account caches and request generations. A superseded request may
/// finish, but cannot publish data or clear the newer request's busy state.
class CourseLoadController {
  final _pending = <CourseContext, Future<void>>{};

  Future<void> share(CourseContext context, Future<void> Function() load) {
    final pending = _pending[context];
    if (pending != null) return pending;
    late final Future<void> request;
    request = load().whenComplete(() {
      if (identical(_pending[context], request)) _pending.remove(context);
    });
    _pending[context] = request;
    return request;
  }

  final courses = <CourseContext, List<Course>>{};
  final online = <CourseContext, List<Course>>{};
  final offline = <CourseContext, List<Course>>{};
  final timestamps = <CourseContext, DateTime>{};
  int _generation = 0;
  bool loading = false;
  CourseContext? context;

  void switchContext(CourseContext next) {
    if (context == next) return;
    context = next;
    invalidate();
  }

  int? begin(CourseContext next) {
    switchContext(next);
    if (loading) return null;
    loading = true;
    return ++_generation;
  }

  bool accepts(int generation, CourseContext expected) =>
      generation == _generation && context == expected;

  void finish(int generation) {
    if (generation == _generation) loading = false;
  }

  void invalidate() {
    _generation++;
    loading = false;
    _pending.clear();
  }
}
