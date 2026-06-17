Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapListOf(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

String _stringOf(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

int _intOf(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _doubleOf(dynamic value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _boolFlag(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}

enum KetangpaiQuestionType {
  judge(1, '判断题'),
  singleChoice(2, '单选题'),
  multipleChoice(3, '多选题'),
  shortAnswer(4, '简答题'),
  fillBlank(5, '填空题'),
  multipleChoiceAlt(6, '多选题'),
  unknown(0, '未知题型');

  const KetangpaiQuestionType(this.code, this.label);

  final int code;
  final String label;

  bool get isChoice =>
      this == judge ||
      this == singleChoice ||
      this == multipleChoice ||
      this == multipleChoiceAlt;

  bool get isMultipleChoice =>
      this == multipleChoice || this == multipleChoiceAlt;

  static KetangpaiQuestionType fromCode(dynamic value) {
    final code = _intOf(value);
    for (final type in KetangpaiQuestionType.values) {
      if (type.code == code) return type;
    }
    return KetangpaiQuestionType.unknown;
  }
}

class KetangpaiLessonLink {
  const KetangpaiLessonLink({required this.type, required this.name});

  final int type;
  final String name;

  factory KetangpaiLessonLink.fromJson(Map<String, dynamic> json) {
    return KetangpaiLessonLink(
      type: _intOf(json['type']),
      name: _stringOf(json['name']),
    );
  }

  Map<String, dynamic> toJson() => {'type': type, 'name': name};
}

class KetangpaiCutScreenPolicy {
  const KetangpaiCutScreenPolicy({
    required this.state,
    required this.totalAllowedCount,
    required this.usedCount,
    required this.remainingCount,
    this.testCode = '',
    this.isFirstJoin = 0,
  });

  final int state;
  final int totalAllowedCount;
  final int usedCount;
  final int remainingCount;
  final String testCode;
  final int isFirstJoin;

  bool get enabled => state == 1 || totalAllowedCount > 0;

  factory KetangpaiCutScreenPolicy.fromJson(Map<String, dynamic> json) {
    return KetangpaiCutScreenPolicy(
      state: _intOf(json['cutscreenState']),
      totalAllowedCount: _intOf(json['testpaperAllCount']),
      usedCount: _intOf(json['studentCount']),
      remainingCount: _intOf(json['lastCount']),
      testCode: _stringOf(json['testCode']),
      isFirstJoin: _intOf(json['isFirstJoin']),
    );
  }

  Map<String, dynamic> toJson() => {
    'cutscreenState': state,
    'testpaperAllCount': totalAllowedCount,
    'studentCount': usedCount,
    'lastCount': remainingCount,
    'testCode': testCode,
    'isFirstJoin': isFirstJoin,
  };
}

class KetangpaiExamSummary {
  const KetangpaiExamSummary({
    required this.id,
    required this.courseId,
    required this.title,
    required this.type,
    required this.fullScore,
    required this.beginTime,
    required this.endTime,
    required this.timeLength,
    required this.over,
    required this.submitState,
    required this.activityLabel,
    required this.raw,
  });

  final String id;
  final String courseId;
  final String title;
  final String type;
  final String fullScore;
  final String beginTime;
  final String endTime;
  final int timeLength;
  final bool over;
  final int submitState;
  final String activityLabel;
  final Map<String, dynamic> raw;

  factory KetangpaiExamSummary.fromJson(Map<String, dynamic> json) {
    return KetangpaiExamSummary(
      id: _stringOf(json['id'] ?? json['testpaperid']),
      courseId: _stringOf(json['courseid']),
      title: _stringOf(json['title']),
      type: _stringOf(json['type']),
      fullScore: _stringOf(json['fullscore'] ?? json['totalScore']),
      beginTime: _stringOf(json['begintime']),
      endTime: _stringOf(json['endtime']),
      timeLength: _intOf(json['timelength']),
      over: _boolFlag(json['over']),
      submitState: _intOf(json['submit_state']),
      activityLabel: _stringOf(json['activitylabel']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    ...raw,
    'id': id,
    'courseid': courseId,
    'title': title,
    'type': type,
    'fullscore': fullScore,
    'begintime': beginTime,
    'endtime': endTime,
    'timelength': timeLength,
    'over': over ? 1 : 0,
    'submit_state': submitState,
    'activitylabel': activityLabel,
  };
}

class KetangpaiExamDetail {
  const KetangpaiExamDetail({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.beginTime,
    required this.endTime,
    required this.timeLength,
    required this.over,
    required this.totalScore,
    required this.subjectCount,
    required this.submitStatus,
    required this.submitState,
    required this.score,
    required this.nickname,
    required this.avatar,
    required this.activityLabel,
    required this.cutScreen,
    required this.lessonLinks,
    required this.raw,
  });

  final String id;
  final String courseId;
  final String title;
  final String description;
  final String beginTime;
  final String endTime;
  final int timeLength;
  final bool over;
  final double totalScore;
  final int subjectCount;
  final int submitStatus;
  final int submitState;
  final String score;
  final String nickname;
  final String avatar;
  final String activityLabel;
  final KetangpaiCutScreenPolicy cutScreen;
  final List<KetangpaiLessonLink> lessonLinks;
  final Map<String, dynamic> raw;

  bool get canContinueAnswer => submitState == 2 && submitStatus != 1;

  factory KetangpaiExamDetail.fromJson(Map<String, dynamic> json) {
    final source = _mapOf(json['testpaper']).isNotEmpty
        ? _mapOf(json['testpaper'])
        : json;
    return KetangpaiExamDetail(
      id: _stringOf(source['id']),
      courseId: _stringOf(source['courseid']),
      title: _stringOf(source['title']),
      description: _stringOf(source['description']),
      beginTime: _stringOf(source['begintime']),
      endTime: _stringOf(source['endtime']),
      timeLength: _intOf(source['timelength']),
      over: _boolFlag(source['over']),
      totalScore: _doubleOf(source['totalScore'] ?? source['total_score']),
      subjectCount: _intOf(source['subjectCount'] ?? source['subjectcount']),
      submitStatus: _intOf(source['submit_status']),
      submitState: _intOf(source['submit_state']),
      score: _stringOf(source['score']),
      nickname: _stringOf(source['nickname']),
      avatar: _stringOf(source['avatar']),
      activityLabel: _stringOf(source['activitylabel']),
      cutScreen: KetangpaiCutScreenPolicy.fromJson(_mapOf(source['cutscreen'])),
      lessonLinks: _mapListOf(
        source['lessonlink'],
      ).map(KetangpaiLessonLink.fromJson).toList(),
      raw: Map<String, dynamic>.from(source),
    );
  }

  Map<String, dynamic> toJson() => {
    ...raw,
    'id': id,
    'courseid': courseId,
    'title': title,
    'description': description,
    'begintime': beginTime,
    'endtime': endTime,
    'timelength': timeLength,
    'over': over ? '1' : '0',
    'totalScore': totalScore,
    'subjectCount': subjectCount,
    'submit_status': submitStatus,
    'submit_state': submitState,
    'score': score,
    'nickname': nickname,
    'avatar': avatar,
    'activitylabel': activityLabel,
    'cutscreen': cutScreen.toJson(),
    'lessonlink': lessonLinks.map((item) => item.toJson()).toList(),
  };
}

class KetangpaiExamOption {
  const KetangpaiExamOption({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.status,
    required this.raw,
  });

  final String id;
  final String subjectId;
  final String title;
  final String status;
  final Map<String, dynamic> raw;

  factory KetangpaiExamOption.fromJson(Map<String, dynamic> json) {
    return KetangpaiExamOption(
      id: _stringOf(json['id']),
      subjectId: _stringOf(json['subjectid']),
      title: _stringOf(json['title']),
      status: _stringOf(json['status']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    ...raw,
    'id': id,
    'subjectid': subjectId,
    'title': title,
    'status': status,
  };
}

class KetangpaiExamQuestion {
  const KetangpaiExamQuestion({
    required this.id,
    required this.title,
    required this.type,
    required this.score,
    required this.sort,
    required this.difficulty,
    required this.replenishType,
    required this.options,
    this.myAnswer,
    required this.raw,
  });

  final String id;
  final String title;
  final KetangpaiQuestionType type;
  final double score;
  final int sort;
  final int difficulty;
  final String replenishType;
  final List<KetangpaiExamOption> options;
  final String? myAnswer;
  final Map<String, dynamic> raw;

  factory KetangpaiExamQuestion.fromJson(Map<String, dynamic> json) {
    return KetangpaiExamQuestion(
      id: _stringOf(json['id']),
      title: _stringOf(json['title']),
      type: KetangpaiQuestionType.fromCode(json['type']),
      score: _doubleOf(json['score']),
      sort: _intOf(json['sort']),
      difficulty: _intOf(json['difficulty']),
      replenishType: _stringOf(json['replenishtype']),
      options: _mapListOf(
        json['options'],
      ).map(KetangpaiExamOption.fromJson).toList(),
      myAnswer: json['myanswer']?.toString(),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    ...raw,
    'id': id,
    'title': title,
    'type': type.code.toString(),
    'score': score,
    'sort': sort,
    'difficulty': difficulty,
    'replenishtype': replenishType,
    'options': options.map((item) => item.toJson()).toList(),
    if (myAnswer != null) 'myanswer': myAnswer,
  };
}

class KetangpaiExamPaper {
  const KetangpaiExamPaper({
    required this.questions,
    required this.handupState,
    required this.rehandup,
    required this.detail,
    required this.remainingTimes,
    required this.fallbackNumber,
    required this.raw,
  });

  final List<KetangpaiExamQuestion> questions;
  final String handupState;
  final String rehandup;
  final KetangpaiExamDetail detail;
  final int remainingTimes;
  final int fallbackNumber;
  final Map<String, dynamic> raw;

  factory KetangpaiExamPaper.fromJson(Map<String, dynamic> json) {
    return KetangpaiExamPaper(
      questions: _mapListOf(
        json['lists'],
      ).map(KetangpaiExamQuestion.fromJson).toList(),
      handupState: _stringOf(json['handupState']),
      rehandup: _stringOf(json['rehandup']),
      detail: KetangpaiExamDetail.fromJson(_mapOf(json['testpaper'])),
      remainingTimes: _intOf(json['remainTimes']),
      fallbackNumber: _intOf(json['fallback_number']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    ...raw,
    'lists': questions.map((item) => item.toJson()).toList(),
    'handupState': handupState,
    'rehandup': rehandup,
    'testpaper': detail.toJson(),
    'remainTimes': remainingTimes,
    'fallback_number': fallbackNumber,
  };
}
