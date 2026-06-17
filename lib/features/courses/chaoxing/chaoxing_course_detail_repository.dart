import '../../../api/chaoxing_chapter_api.dart';
import '../../../api/course.dart';
import '../../../models/active.dart';
import '../../../models/course.dart';
import 'chaoxing_course_detail_state.dart';

class ChaoxingCourseDetailRepository {
  const ChaoxingCourseDetailRepository();

  Future<List<Active>?> loadActivities({
    required String courseId,
    required String classId,
    required String cpi,
  }) {
    return CXCourseApi.getActiveList(courseId, classId, cpi);
  }

  Future<ChaoxingCourseDetailState> loadDetail(Course course) async {
    final results =
        await Future.wait<dynamic>([
          CXCourseApi.getActiveList(
            course.courseId,
            course.classId,
            course.cpi ?? '',
          ).catchError((_) => <Active>[]),
          ChaoxingChapterApi.getChapterList(
            course.courseId,
            course.classId,
          ).catchError(
            (_) => <String, dynamic>{
              'hasLocked': false,
              'points': <Map<String, dynamic>>[],
            },
          ),
          ChaoxingChapterApi.getUnfinishedTasks(
            course.courseId,
            course.classId,
            course.cpi ?? '',
          ).catchError((_) => <Map<String, dynamic>>[]),
        ]).timeout(
          const Duration(seconds: 25),
          onTimeout: () => <dynamic>[
            <Active>[],
            <String, dynamic>{
              'hasLocked': false,
              'points': <Map<String, dynamic>>[],
            },
            <Map<String, dynamic>>[],
          ],
        );

    final chapterData = results[1] as Map<String, dynamic>?;
    return ChaoxingCourseDetailState(
      activities: results[0] as List<Active>? ?? const <Active>[],
      chapters: _normalizeMapList(chapterData?['points']),
      unfinishedTasks: _normalizeMapList(results[2]),
    );
  }

  static List<Map<String, dynamic>> _normalizeMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }
}
