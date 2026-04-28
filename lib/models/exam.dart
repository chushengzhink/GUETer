/// 考试信息模型
class ExamInfo {
  final String examId;
  final String classroomId;
  final String classroomName;
  final String title;
  final String? userAvatar;
  final int endTime; // 截止时间戳（秒）
  final int? startTime; // 开始时间戳（秒）
  final double? totalScore; // 总分
  final int? problemCount; // 题目数量
  final bool? showAnswer; // 是否显示答案
  final bool? showScore; // 是否显示分数

  ExamInfo({
    required this.examId,
    required this.classroomId,
    required this.classroomName,
    required this.title,
    this.userAvatar,
    required this.endTime,
    this.startTime,
    this.totalScore,
    this.problemCount,
    this.showAnswer,
    this.showScore,
  });

  factory ExamInfo.fromJson(Map<String, dynamic> json) {
    return ExamInfo(
      examId: json['exam_id']?.toString() ?? '',
      classroomId: json['classroom_id']?.toString() ?? '',
      classroomName: json['classroom_name'] ?? '',
      title: json['title'] ?? '',
      userAvatar: json['user_avatar'],
      endTime: json['end_time'] ?? json['deadline'] ?? 0,
      startTime: json['start_time'],
      totalScore: json['total_score']?.toDouble(),
      problemCount: json['problem_count'],
      showAnswer: json['show_answer'],
      showScore: json['show_score'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exam_id': examId,
      'classroom_id': classroomId,
      'classroom_name': classroomName,
      'title': title,
      'user_avatar': userAvatar,
      'end_time': endTime,
      'start_time': startTime,
      'total_score': totalScore,
      'problem_count': problemCount,
      'show_answer': showAnswer,
      'show_score': showScore,
    };
  }

  /// 获取北京时间的截止时间
  DateTime get endTimeBeijing {
    final utcDate = DateTime.fromMillisecondsSinceEpoch(endTime * 1000, isUtc: true);
    return utcDate.add(const Duration(hours: 8));
  }

  /// 检查 end_time 是否有效
  bool get _isEndTimeValid {
    // end_time 为 0 或小于 1970-01-02（时间戳 86400）视为无效
    if (endTime <= 86400) {
      return false;
    }

    // 检查是否为服务器默认值（如 0000-00-00 对应的时间戳）
    final date = endTimeBeijing;
    if (date.year < 2000) {
      return false;
    }

    return true;
  }

  /// 是否已过期
  bool get isExpired {
    // 如果 end_time 无效，默认显示为进行中（未过期）
    if (!_isEndTimeValid) {
      print('[ExamInfo] 考试 "$title" (ID: $examId) end_time=$endTime 无效，默认显示为进行中');
      return false;
    }

    final now = DateTime.now();
    final expired = now.isAfter(endTimeBeijing);
    print('[ExamInfo] 考试 "$title" (ID: $examId) end_time=$endTime (${endTimeBeijing.toIso8601String()}) 当前时间=${now.toIso8601String()} 已过期=$expired');
    return expired;
  }

  /// 剩余时间（秒）
  int get remainingSeconds {
    // 如果 end_time 无效，返回一个较大的正数表示未过期
    if (!_isEndTimeValid) {
      return 999999999;
    }

    final now = DateTime.now();
    return endTimeBeijing.difference(now).inSeconds;
  }
}

/// 考试Token信息
class ExamToken {
  final String token;
  final String examHost;
  final String userId;

  ExamToken({
    required this.token,
    required this.examHost,
    required this.userId,
  });

  factory ExamToken.fromJson(Map<String, dynamic> json) {
    return ExamToken(
      token: json['token'] ?? '',
      examHost: json['exam_host'] ?? 'https://examination.xuetangx.com',
      userId: json['user_id']?.toString() ?? '',
    );
  }
}

/// 题目类型枚举
enum ProblemType {
  shortAnswer('ShortAnswer', '主观题'),
  choice('Choice', '选择题'),
  multiChoice('MultiChoice', '多选题'),
  trueOrFalse('TrueOrFalse', '判断题'),
  fillBlank('FillBlank', '填空题'),
  unknown('Unknown', '未知');

  final String value;
  final String displayName;

  const ProblemType(this.value, this.displayName);

  static ProblemType fromString(String? type) {
    if (type == null) return ProblemType.unknown;
    for (var t in ProblemType.values) {
      if (t.value == type) return t;
    }
    return ProblemType.unknown;
  }
}

/// 题目模型
class ExamProblem {
  final int problemId;
  final String body; // 题目内容（可能包含HTML）
  final ProblemType type;
  final String typeText;
  final double score;
  final int index;
  final Map<String, dynamic> data; // 题目额外数据（选项等）
  final String? version;
  final int? libraryId;
  final int? maxRetry;

  ExamProblem({
    required this.problemId,
    required this.body,
    required this.type,
    required this.typeText,
    required this.score,
    required this.index,
    required this.data,
    this.version,
    this.libraryId,
    this.maxRetry,
  });

  factory ExamProblem.fromJson(Map<String, dynamic> json) {
    return ExamProblem(
      problemId: json['ProblemID'] ?? json['problem_id'] ?? 0,
      body: json['Body'] ?? json['body'] ?? '',
      type: ProblemType.fromString(json['Type'] ?? json['type']),
      typeText: json['TypeText'] ?? json['type_text'] ?? '',
      score: (json['Score'] ?? json['score'] ?? 0).toDouble(),
      index: json['index'] ?? 0,
      data: json['data'] ?? {},
      version: json['Version'] ?? json['version'],
      libraryId: json['LibraryID'] ?? json['library_id'],
      maxRetry: json['max_retry'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ProblemID': problemId,
      'Body': body,
      'Type': type.value,
      'TypeText': typeText,
      'Score': score,
      'index': index,
      'data': data,
      'Version': version,
      'LibraryID': libraryId,
      'max_retry': maxRetry,
    };
  }
}

/// 答案结果模型
class ProblemResult {
  final int problemId;
  final Map<String, dynamic> result; // 答案内容
  final int time; // 时间戳（毫秒）

  ProblemResult({
    required this.problemId,
    required this.result,
    required this.time,
  });

  factory ProblemResult.fromJson(Map<String, dynamic> json) {
    return ProblemResult(
      problemId: json['problem_id'] ?? 0,
      result: json['result'] ?? {},
      time: json['time'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'problem_id': problemId,
      'result': result,
      'time': time,
    };
  }

  /// 创建空答案
  static ProblemResult empty(int problemId) {
    return ProblemResult(
      problemId: problemId,
      result: {},
      time: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 创建图片答案
  static ProblemResult withImage(int problemId, String imageUrl) {
    return ProblemResult(
      problemId: problemId,
      result: {
        'content': '<div class="custom_ueditor_cn_body"><p><img src="$imageUrl" width="80%" height="auto"/></p></div>',
        'attachments': {
          'filelist': [],
        },
      },
      time: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 创建文本答案
  static ProblemResult withText(int problemId, String text) {
    return ProblemResult(
      problemId: problemId,
      result: {
        'content': '<div class="custom_ueditor_cn_body"><p>$text</p></div>',
        'attachments': {
          'filelist': [],
        },
      },
      time: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 是否为空答案
  bool get isEmpty => result.isEmpty;
}

/// 考试时间信息
class ExamTimeInfo {
  final bool hasLimit; // 是否有时间限制
  final int timePast; // 已用时间（秒）
  final int timeLeft; // 剩余时间（秒）

  ExamTimeInfo({
    required this.hasLimit,
    required this.timePast,
    required this.timeLeft,
  });

  factory ExamTimeInfo.fromJson(Map<String, dynamic> json) {
    return ExamTimeInfo(
      hasLimit: json['has_limit'] ?? false,
      timePast: json['time_past'] ?? 0,
      timeLeft: json['time_left'] ?? 0,
    );
  }
}
