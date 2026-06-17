import 'dart:convert';

class UnipusAssistConfig {
  const UnipusAssistConfig({
    required this.username,
    this.password = '',
    this.rememberPassword = false,
    this.userAgent = '',
    this.tutorialId = '',
    this.reviewMode = false,
    this.autoOpenNext = true,
    this.unfinishedFirst = true,
    this.reminderSeconds = 90,
    this.openAiApiKey = '',
    this.openAiBaseUrl = 'https://api.openai.com',
    this.openAiModel = 'gpt-5-mini',
  });

  final String username;
  final String password;
  final bool rememberPassword;
  final String userAgent;
  final String tutorialId;
  final bool reviewMode;
  final bool autoOpenNext;
  final bool unfinishedFirst;
  final int reminderSeconds;
  final String openAiApiKey;
  final String openAiBaseUrl;
  final String openAiModel;

  UnipusAssistConfig copyWith({
    String? username,
    String? password,
    bool? rememberPassword,
    String? userAgent,
    String? tutorialId,
    bool? reviewMode,
    bool? autoOpenNext,
    bool? unfinishedFirst,
    int? reminderSeconds,
    String? openAiApiKey,
    String? openAiBaseUrl,
    String? openAiModel,
  }) {
    return UnipusAssistConfig(
      username: username ?? this.username,
      password: password ?? this.password,
      rememberPassword: rememberPassword ?? this.rememberPassword,
      userAgent: userAgent ?? this.userAgent,
      tutorialId: tutorialId ?? this.tutorialId,
      reviewMode: reviewMode ?? this.reviewMode,
      autoOpenNext: autoOpenNext ?? this.autoOpenNext,
      unfinishedFirst: unfinishedFirst ?? this.unfinishedFirst,
      reminderSeconds: reminderSeconds ?? this.reminderSeconds,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      openAiModel: openAiModel ?? this.openAiModel,
    );
  }

  Map<String, dynamic> toJson({bool includePassword = true}) {
    return <String, dynamic>{
      'username': username,
      'password': includePassword && rememberPassword ? password : '',
      'remember_password': rememberPassword,
      'user_agent': userAgent,
      'tutorial_id': tutorialId,
      'review_mode': reviewMode,
      'auto_open_next': autoOpenNext,
      'unfinished_first': unfinishedFirst,
      'reminder_seconds': reminderSeconds,
      'open_ai': <String, dynamic>{
        'api_key': openAiApiKey,
        'base_url': openAiBaseUrl,
        'model': openAiModel,
      },
    };
  }

  factory UnipusAssistConfig.fromJson(Map<String, dynamic> json) {
    final openAi = json['open_ai'];
    final openAiMap = openAi is Map ? Map<String, dynamic>.from(openAi) : null;
    return UnipusAssistConfig(
      username: json['username']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
      rememberPassword: json['remember_password'] == true,
      userAgent: json['user_agent']?.toString() ?? '',
      tutorialId: json['tutorial_id']?.toString() ?? '',
      reviewMode: json['review_mode'] == true,
      autoOpenNext: json['auto_open_next'] != false,
      unfinishedFirst: json['unfinished_first'] != false,
      reminderSeconds: _intValue(json['reminder_seconds'], 90),
      openAiApiKey: openAiMap?['api_key']?.toString() ?? '',
      openAiBaseUrl:
          openAiMap?['base_url']?.toString() ?? 'https://api.openai.com',
      openAiModel: openAiMap?['model']?.toString() ?? 'gpt-5-mini',
    );
  }

  static const empty = UnipusAssistConfig(username: '');
}

class UnipusCaptchaChallenge {
  const UnipusCaptchaChallenge({
    required this.imageBase64,
    required this.encodedCaptcha,
  });

  final String imageBase64;
  final String encodedCaptcha;

  List<int> imageBytes() {
    final base64Part = imageBase64.contains(',')
        ? imageBase64.split(',').last
        : imageBase64;
    return base64Decode(base64Part);
  }
}

class UnipusSessionInfo {
  const UnipusSessionInfo({
    required this.name,
    required this.token,
    required this.openId,
    required this.websocketUrl,
  });

  final String name;
  final String token;
  final String openId;
  final String websocketUrl;

  bool get isReady => token.isNotEmpty && openId.isNotEmpty;
}

class UnipusCourseBlock {
  const UnipusCourseBlock({
    required this.className,
    required this.dateRange,
    required this.startDate,
    required this.endDate,
    required this.courses,
  });

  final String className;
  final String dateRange;
  final String startDate;
  final String endDate;
  final List<UnipusCourse> courses;
}

class UnipusCourse {
  const UnipusCourse({
    required this.courseName,
    required this.status,
    required this.image,
    required this.courseUrl,
    required this.tutorialId,
    this.courseId,
    this.schoolId,
    this.eccId,
    this.classId,
    this.courseType,
  });

  final String courseName;
  final String status;
  final String image;
  final String courseUrl;
  final String tutorialId;
  final String? courseId;
  final String? schoolId;
  final String? eccId;
  final String? classId;
  final String? courseType;
}

class UnipusTaskNode {
  const UnipusTaskNode({
    required this.tutorialId,
    required this.title,
    required this.path,
    required this.leaf,
    required this.url,
    required this.required,
    required this.passed,
    required this.children,
  });

  final String tutorialId;
  final String title;
  final List<int> path;
  final String leaf;
  final String url;
  final bool required;
  final bool passed;
  final List<UnipusTaskNode> children;

  bool get isLeaf => url.isNotEmpty;
  String get pathLabel => path.join('.');
  String get displayTitle => pathLabel.isEmpty ? title : '$pathLabel $title';

  Iterable<UnipusTaskNode> flatten() sync* {
    yield this;
    for (final child in children) {
      yield* child.flatten();
    }
  }
}

class UnipusQueueItem {
  const UnipusQueueItem({
    required this.id,
    required this.courseName,
    required this.node,
    this.confirmed = false,
    this.openedAt,
    this.confirmedAt,
  });

  final String id;
  final String courseName;
  final UnipusTaskNode node;
  final bool confirmed;
  final DateTime? openedAt;
  final DateTime? confirmedAt;

  UnipusQueueItem copyWith({
    bool? confirmed,
    DateTime? openedAt,
    DateTime? confirmedAt,
  }) {
    return UnipusQueueItem(
      id: id,
      courseName: courseName,
      node: node,
      confirmed: confirmed ?? this.confirmed,
      openedAt: openedAt ?? this.openedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}

class UnipusAssistLog {
  const UnipusAssistLog({
    required this.timestamp,
    required this.message,
    this.level = UnipusLogLevel.info,
  });

  final DateTime timestamp;
  final String message;
  final UnipusLogLevel level;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'level': level.name,
    };
  }

  factory UnipusAssistLog.fromJson(Map<String, dynamic> json) {
    return UnipusAssistLog(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      message: json['message']?.toString() ?? '',
      level: UnipusLogLevel.values.firstWhere(
        (item) => item.name == json['level'],
        orElse: () => UnipusLogLevel.info,
      ),
    );
  }
}

enum UnipusLogLevel { info, warning, error, success }

int _intValue(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
