import '../../models/course.dart';
import '../../platform.dart';

typedef CourseContext = (PlatformType, String, String);

/// Owns per-account caches and request generations. A superseded request may
/// finish, but cannot publish data or clear the newer request's busy state.
class CourseLoadController {
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
  }
}
