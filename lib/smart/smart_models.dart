import 'dart:convert';

enum SmartInsightType {
  today('today', '今日优先'),
  todoRisk('todoRisk', '待办风险'),
  material('material', '资料整理'),
  review('review', '复习建议'),
  output('output', '输出清理'),
  accountNetwork('accountNetwork', '账号与网络'),
  pluginSystem('pluginSystem', '插件与系统');

  const SmartInsightType(this.id, this.labelZh);

  final String id;
  final String labelZh;

  static SmartInsightType fromId(String id) {
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => SmartInsightType.today,
    );
  }
}

enum SmartInsightStatus {
  active('active', '待处理'),
  done('done', '已完成'),
  ignored('ignored', '已忽略');

  const SmartInsightStatus(this.id, this.labelZh);

  final String id;
  final String labelZh;

  static SmartInsightStatus fromId(String id) {
    return values.firstWhere(
      (status) => status.id == id,
      orElse: () => SmartInsightStatus.active,
    );
  }
}

enum SmartInsightPriority {
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高'),
  urgent('urgent', '紧急');

  const SmartInsightPriority(this.id, this.labelZh);

  final String id;
  final String labelZh;

  int get rank {
    return switch (this) {
      SmartInsightPriority.urgent => 4,
      SmartInsightPriority.high => 3,
      SmartInsightPriority.medium => 2,
      SmartInsightPriority.low => 1,
    };
  }

  static SmartInsightPriority fromId(String id) {
    return values.firstWhere(
      (priority) => priority.id == id,
      orElse: () => SmartInsightPriority.medium,
    );
  }
}

enum SmartInsightActionType {
  openCourses('openCourses'),
  openTodos('openTodos'),
  openMaterials('openMaterials'),
  openWebArchive('openWebArchive'),
  openStudyCenter('openStudyCenter'),
  openOutputManager('openOutputManager'),
  openDiagnostics('openDiagnostics'),
  rebuildIndex('rebuildIndex'),
  createStudyCards('createStudyCards'),
  addToLibrary('addToLibrary'),
  copyText('copyText'),
  markDone('markDone'),
  ignore('ignore');

  const SmartInsightActionType(this.id);

  final String id;

  static SmartInsightActionType fromId(String id) {
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => SmartInsightActionType.copyText,
    );
  }
}

class SmartInsightAction {
  const SmartInsightAction({
    required this.type,
    required this.label,
    this.targetId,
    this.targetPath,
    this.payload = const <String, Object?>{},
  });

  final SmartInsightActionType type;
  final String label;
  final String? targetId;
  final String? targetPath;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type.id,
      'label': label,
      'targetId': targetId,
      'targetPath': targetPath,
      'payload': payload,
    };
  }

  factory SmartInsightAction.fromJson(Map<String, Object?> json) {
    return SmartInsightAction(
      type: SmartInsightActionType.fromId(json['type']?.toString() ?? ''),
      label: json['label']?.toString() ?? '',
      targetId: json['targetId']?.toString(),
      targetPath: json['targetPath']?.toString(),
      payload: (json['payload'] is Map)
          ? (json['payload'] as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, Object?>{},
    );
  }
}

class SmartInsight {
  const SmartInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.reason,
    required this.sourceKind,
    required this.sourceId,
    required this.priority,
    this.status = SmartInsightStatus.active,
    this.actions = const <SmartInsightAction>[],
    required this.createdAt,
    this.dueAt,
    this.tags = const <String>[],
  });

  final String id;
  final SmartInsightType type;
  final String title;
  final String summary;
  final String reason;
  final String sourceKind;
  final String sourceId;
  final SmartInsightPriority priority;
  final SmartInsightStatus status;
  final List<SmartInsightAction> actions;
  final DateTime createdAt;
  final DateTime? dueAt;
  final List<String> tags;

  SmartInsight copyWith({
    SmartInsightStatus? status,
    List<SmartInsightAction>? actions,
  }) {
    return SmartInsight(
      id: id,
      type: type,
      title: title,
      summary: summary,
      reason: reason,
      sourceKind: sourceKind,
      sourceId: sourceId,
      priority: priority,
      status: status ?? this.status,
      actions: actions ?? this.actions,
      createdAt: createdAt,
      dueAt: dueAt,
      tags: tags,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.id,
      'title': title,
      'summary': summary,
      'reason': reason,
      'sourceKind': sourceKind,
      'sourceId': sourceId,
      'priority': priority.id,
      'status': status.id,
      'actions': actions.map((action) => action.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'dueAt': dueAt?.toIso8601String(),
      'tags': tags,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class SmartBrief {
  const SmartBrief({
    required this.title,
    required this.lines,
    required this.totalCount,
    required this.urgentCount,
    required this.highCount,
  });

  final String title;
  final List<String> lines;
  final int totalCount;
  final int urgentCount;
  final int highCount;
}
