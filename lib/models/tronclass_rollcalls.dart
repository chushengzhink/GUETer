class RollcallsResponse {
  const RollcallsResponse({required this.rollcalls});

  final List<Rollcalls> rollcalls;

  factory RollcallsResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['rollcalls'];
    final rollcalls = rawList is List
        ? rawList
              .whereType<Map>()
              .map(
                (item) => Rollcalls.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <Rollcalls>[];
    return RollcallsResponse(rollcalls: rollcalls);
  }
}

class Rollcalls {
  const Rollcalls({
    required this.avatarBigUrl,
    required this.className,
    required this.courseId,
    required this.courseTitle,
    required this.createdBy,
    required this.createdByName,
    required this.departmentName,
    required this.gradeName,
    required this.groupSetId,
    required this.isExpired,
    required this.isNumber,
    required this.isRadar,
    required this.publishedAt,
    required this.rollcallId,
    required this.rollcallStatus,
    required this.rollcallTime,
    required this.scored,
    required this.source,
    required this.status,
    required this.studentRollcallId,
    required this.title,
    required this.type,
  });

  final String avatarBigUrl;
  final String className;
  final int courseId;
  final String courseTitle;
  final int createdBy;
  final String createdByName;
  final String departmentName;
  final String gradeName;
  final int groupSetId;
  final bool isExpired;
  final bool isNumber;
  final bool isRadar;
  final dynamic publishedAt;
  final int rollcallId;
  final String rollcallStatus;
  final String rollcallTime;
  final bool scored;
  final String source;
  final String status;
  final int studentRollcallId;
  final String title;
  final String type;

  factory Rollcalls.fromJson(Map<String, dynamic> json) {
    return Rollcalls(
      avatarBigUrl: _string(json, 'avatar_big_url'),
      className: _string(json, 'class_name'),
      courseId: _int(json, 'course_id'),
      courseTitle: _string(json, 'course_title'),
      createdBy: _int(json, 'created_by'),
      createdByName: _string(json, 'created_by_name'),
      departmentName: _string(json, 'department_name'),
      gradeName: _string(json, 'grade_name'),
      groupSetId: _int(json, 'group_set_id'),
      isExpired: _bool(json, 'is_expired'),
      isNumber: _bool(json, 'is_number'),
      isRadar: _bool(json, 'is_radar'),
      publishedAt: json['published_at'],
      rollcallId: _int(json, 'rollcall_id'),
      rollcallStatus: _string(json, 'rollcall_status'),
      rollcallTime: _string(json, 'rollcall_time'),
      scored: _bool(json, 'scored'),
      source: _string(json, 'source'),
      status: _string(json, 'status'),
      studentRollcallId: _int(json, 'student_rollcall_id'),
      title: _string(json, 'title'),
      type: _string(json, 'type'),
    );
  }

  String get mode {
    if (isNumber && !isRadar) {
      return 'number';
    }
    if (isRadar && !isNumber) {
      return 'radar';
    }
    return 'qrcode';
  }

  bool get isInProgress => rollcallStatus == 'in_progress';

  static String _string(Map<String, dynamic> json, String key) {
    return json[key]?.toString() ?? '';
  }

  static int _int(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase() ?? '';
    return text == 'true' || text == '1';
  }
}
