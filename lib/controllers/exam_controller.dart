import 'package:get/get.dart';

import '../api/ketangpai_service.dart';
import '../models/ketangpai_exam.dart';

typedef KetangpaiExamListRequest =
    Future<KetangpaiServiceResult<List<Map<String, dynamic>>>> Function({
      required String courseId,
    });

typedef KetangpaiExamDetailRequest =
    Future<KetangpaiServiceResult<Map<String, dynamic>>> Function({
      required String courseId,
      required String testPaperId,
    });

typedef KetangpaiExamSaveRequest =
    Future<KetangpaiServiceResult<Map<String, dynamic>>> Function({
      required String courseId,
      required String testPaperId,
      required String subjectId,
      required String answer,
    });

typedef KetangpaiExamSubmitRequest =
    Future<KetangpaiServiceResult<Map<String, dynamic>>> Function({
      required String courseId,
      required String testPaperId,
    });

typedef KetangpaiExamNotifier =
    void Function(String title, String message, bool success);

class ExamController extends GetxController {
  ExamController({
    KetangpaiExamListRequest? listRequest,
    KetangpaiExamDetailRequest? detailRequest,
    KetangpaiExamDetailRequest? questionsRequest,
    KetangpaiExamSaveRequest? saveRequest,
    KetangpaiExamSubmitRequest? submitRequest,
    KetangpaiExamNotifier? notifier,
  }) : _listRequest = listRequest ?? _getExamList,
       _detailRequest = detailRequest ?? _getExamDetail,
       _questionsRequest = questionsRequest ?? _getExamQuestions,
       _saveRequest = saveRequest ?? _saveAnswer,
       _submitRequest = submitRequest ?? _submitExam,
       _notifier = notifier ?? _defaultNotifier;

  final RxList<KetangpaiExamSummary> examList = <KetangpaiExamSummary>[].obs;
  final Rx<KetangpaiExamDetail?> currentExam = Rx<KetangpaiExamDetail?>(null);
  final Rx<KetangpaiExamPaper?> currentPaper = Rx<KetangpaiExamPaper?>(null);
  final RxMap<String, String> answerCache = <String, String>{}.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool isSubmitted = false.obs;
  final RxSet<String> unsavedAnswers = <String>{}.obs;
  final Map<String, Future<bool>> _pendingSaves = {};
  int _activeSaves = 0;
  final RxString error = ''.obs;

  final KetangpaiExamListRequest _listRequest;
  final KetangpaiExamDetailRequest _detailRequest;
  final KetangpaiExamDetailRequest _questionsRequest;
  final KetangpaiExamSaveRequest _saveRequest;
  final KetangpaiExamSubmitRequest _submitRequest;
  final KetangpaiExamNotifier _notifier;

  String? _currentCourseId;
  String? _currentPaperId;

  Future<void> loadExamList(String courseId) async {
    final trimmedCourseId = courseId.trim();
    if (trimmedCourseId.isEmpty) {
      _setError('课程 ID 不能为空');
      examList.clear();
      return;
    }

    isLoading.value = true;
    error.value = '';
    try {
      final result = await _listRequest(courseId: trimmedCourseId);
      if (!result.success) {
        _setError(_messageForResult(result, '考试列表加载失败'));
        examList.clear();
        return;
      }
      examList.assignAll(
        (result.data ?? const <Map<String, dynamic>>[]).map(
          KetangpaiExamSummary.fromJson,
        ),
      );
    } catch (e) {
      _setError('考试列表加载异常: $e');
      examList.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadExamDetail(String courseId, String paperId) async {
    final trimmedCourseId = courseId.trim();
    final trimmedPaperId = paperId.trim();
    if (trimmedCourseId.isEmpty || trimmedPaperId.isEmpty) {
      _setError('课程 ID 或试卷 ID 不能为空');
      return;
    }

    isLoading.value = true;
    error.value = '';
    if (_currentCourseId != trimmedCourseId ||
        _currentPaperId != trimmedPaperId) {
      isSubmitted.value = false;
    }
    _currentCourseId = trimmedCourseId;
    _currentPaperId = trimmedPaperId;
    try {
      final results = await Future.wait([
        _detailRequest(courseId: trimmedCourseId, testPaperId: trimmedPaperId),
        _questionsRequest(
          courseId: trimmedCourseId,
          testPaperId: trimmedPaperId,
        ),
      ]);
      final detailResult = results[0];
      final questionsResult = results[1];

      if (!detailResult.success) {
        _setError(_messageForResult(detailResult, '考试详情加载失败'));
        currentExam.value = null;
      } else {
        currentExam.value = KetangpaiExamDetail.fromJson(
          detailResult.data ?? const <String, dynamic>{},
        );
      }

      if (!questionsResult.success) {
        _setError(_messageForResult(questionsResult, '考试题目加载失败'));
        currentPaper.value = null;
        answerCache.clear();
        return;
      }

      final paper = KetangpaiExamPaper.fromJson(
        questionsResult.data ?? const <String, dynamic>{},
      );
      currentPaper.value = paper;
      initializeAnswerCache(paper.questions);
    } catch (e) {
      _setError('考试详情加载异常: $e');
      currentExam.value = null;
      currentPaper.value = null;
      answerCache.clear();
    } finally {
      isLoading.value = false;
    }
  }

  void initializeAnswerCache(List<KetangpaiExamQuestion> questions) {
    final next = <String, String>{};
    for (final question in questions) {
      final answer = question.myAnswer?.trim() ?? '';
      if (question.id.isNotEmpty && answer.isNotEmpty && answer != '未作答') {
        next[question.id] = answer;
      }
    }
    answerCache.assignAll(next);
    unsavedAnswers.clear();
  }

  void updateCachedAnswer(String subjectId, String answer) {
    final trimmedSubjectId = subjectId.trim();
    if (trimmedSubjectId.isEmpty) return;
    answerCache[trimmedSubjectId] = answer;
    unsavedAnswers.add(trimmedSubjectId);
  }

  Future<bool> saveAnswer(String subjectId, String answer) {
    final id = subjectId.trim();
    final previous = _pendingSaves[id];
    // Serialize explicitly requested edits for the same answer. Never retry a
    // failed write automatically, and never let an old response replace input.
    late final Future<bool> request;
    request =
        (() async {
          if (previous != null) await previous;
          return _saveAnswerNow(id, answer);
        })().whenComplete(() {
          if (identical(_pendingSaves[id], request)) _pendingSaves.remove(id);
        });
    _pendingSaves[id] = request;
    return request;
  }

  Future<bool> _saveAnswerNow(String subjectId, String answer) async {
    final courseId = _currentCourseId;
    final paperId = _currentPaperId;
    if (courseId == null ||
        courseId.isEmpty ||
        paperId == null ||
        paperId.isEmpty) {
      _setError('请先加载考试详情');
      return false;
    }

    final trimmedSubjectId = subjectId.trim();
    if (trimmedSubjectId.isEmpty) {
      _setError('题目 ID 不能为空');
      return false;
    }

    _activeSaves++;
    isSaving.value = true;
    error.value = '';
    try {
      final result = await _saveRequest(
        courseId: courseId,
        testPaperId: paperId,
        subjectId: trimmedSubjectId,
        answer: answer,
      );
      if (!result.success) {
        _setError(_messageForResult(result, '答案保存失败'));
        _notifier('保存答案', error.value, false);
        return false;
      }
      if (answerCache[trimmedSubjectId] == null ||
          answerCache[trimmedSubjectId] == answer) {
        answerCache[trimmedSubjectId] = answer;
        unsavedAnswers.remove(trimmedSubjectId);
      }
      _notifier('保存答案', result.message.isEmpty ? '保存成功' : result.message, true);
      return true;
    } catch (e) {
      _setError('答案保存异常: $e');
      _notifier('保存答案', error.value, false);
      return false;
    } finally {
      _activeSaves--;
      isSaving.value = _activeSaves > 0 || isSubmitting.value;
    }
  }

  Future<bool> submitExam(String courseId, String paperId) async {
    if (isSubmitting.value || isSubmitted.value) return false;
    final trimmedCourseId = courseId.trim();
    final trimmedPaperId = paperId.trim();
    if (trimmedCourseId.isEmpty || trimmedPaperId.isEmpty) {
      _setError('课程 ID 或试卷 ID 不能为空');
      return false;
    }

    isSubmitting.value = true;
    isSaving.value = true;
    error.value = '';
    try {
      await Future.wait(_pendingSaves.values.toList());
      for (final entry in answerCache.entries.toList()) {
        final saveResult = await _saveRequest(
          courseId: trimmedCourseId,
          testPaperId: trimmedPaperId,
          subjectId: entry.key,
          answer: entry.value,
        );
        if (!saveResult.success) {
          _setError(_messageForResult(saveResult, '题目 ${entry.key} 保存失败'));
          _notifier('提交试卷', error.value, false);
          return false;
        }
      }

      final submitResult = await _submitRequest(
        courseId: trimmedCourseId,
        testPaperId: trimmedPaperId,
      );
      if (!submitResult.success) {
        _setError(_messageForResult(submitResult, '试卷提交失败'));
        _notifier('提交试卷', error.value, false);
        return false;
      }

      unsavedAnswers.clear();
      isSubmitted.value = true;
      _notifier(
        '提交试卷',
        submitResult.message.isEmpty ? '提交成功' : submitResult.message,
        true,
      );
      return true;
    } catch (e) {
      _setError('试卷提交异常: $e');
      _notifier('提交试卷', error.value, false);
      return false;
    } finally {
      isSubmitting.value = false;
      isSaving.value = _activeSaves > 0;
    }
  }

  void _setError(String message) {
    error.value = message;
  }

  String _messageForResult(
    KetangpaiServiceResult<dynamic> result,
    String fallback,
  ) {
    if (result.authExpired) {
      return '课堂派登录已过期，请重新登录后再试';
    }
    return result.message.isEmpty ? fallback : result.message;
  }

  static Future<KetangpaiServiceResult<List<Map<String, dynamic>>>>
  _getExamList({required String courseId}) {
    return KetangpaiService.getExamList(courseId: courseId);
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> _getExamDetail({
    required String courseId,
    required String testPaperId,
  }) {
    return KetangpaiService.getExamDetail(
      courseId: courseId,
      testPaperId: testPaperId,
    );
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>>
  _getExamQuestions({required String courseId, required String testPaperId}) {
    return KetangpaiService.getExamQuestions(
      courseId: courseId,
      testPaperId: testPaperId,
    );
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> _saveAnswer({
    required String courseId,
    required String testPaperId,
    required String subjectId,
    required String answer,
  }) {
    return KetangpaiService.saveAnswer(
      courseId: courseId,
      testPaperId: testPaperId,
      subjectId: subjectId,
      answer: answer,
    );
  }

  static Future<KetangpaiServiceResult<Map<String, dynamic>>> _submitExam({
    required String courseId,
    required String testPaperId,
  }) {
    return KetangpaiService.submitExam(
      courseId: courseId,
      testPaperId: testPaperId,
    );
  }

  static void _defaultNotifier(String title, String message, bool success) {
    Get.snackbar(
      title,
      message.isEmpty ? (success ? '操作成功' : '操作失败') : message,
    );
  }
}
