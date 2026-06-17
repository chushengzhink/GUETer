import '../../../models/active.dart';

class ChaoxingCourseDetailState {
  const ChaoxingCourseDetailState({
    required this.activities,
    required this.chapters,
    required this.unfinishedTasks,
  });

  final List<Active> activities;
  final List<Map<String, dynamic>> chapters;
  final List<Map<String, dynamic>> unfinishedTasks;

  List<Map<String, dynamic>> get homeworks {
    return unfinishedTasks
        .where((item) => item['type']?.toString() == 'work')
        .toList();
  }

  bool get isEmpty =>
      activities.isEmpty && chapters.isEmpty && unfinishedTasks.isEmpty;

  List<Map<String, dynamic>> tasksForChapter(String chapterId) {
    return unfinishedTasks
        .where((item) => item['chapterId']?.toString() == chapterId)
        .toList();
  }
}
