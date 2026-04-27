class Course {
  final String courseId;
  final String classId;
  final String? cpi;
  final String image;
  final String name;
  final String teacher;
  final bool state;

  final String? note;
  String? schools;
  final String? beginDate;
  final String? endDate;

  final String? lessonId;

  Course({
    required this.courseId,
    required this.classId,
    this.cpi,
    required this.image,
    required this.name,
    required this.teacher,
    this.schools,
    this.note,
    required this.state,
    this.beginDate,
    this.endDate,
    this.lessonId,
  });

  static String _firstNonEmpty(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _teacherFromJson(Map<String, dynamic> json) {
    final direct = _firstNonEmpty(
      json['teachername'] ??
          json['teacherName'] ??
          json['teacherfactor'] ??
          json['username'] ??
          json['teacher'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }

    final teacherList = json['teacherlist'] ?? json['teacherList'];
    if (teacherList is List && teacherList.isNotEmpty) {
      for (final item in teacherList) {
        if (item is Map<String, dynamic>) {
          final nested = _firstNonEmpty(
            item['name'] ?? item['teachername'] ?? item['teacherName'],
          );
          if (nested.isNotEmpty) {
            return nested;
          }
        }
      }
    }

    final nestedTeacher = json['teacher'];
    if (nestedTeacher is Map<String, dynamic>) {
      final nested = _firstNonEmpty(
        nestedTeacher['name'] ?? nestedTeacher['teachername'],
      );
      if (nested.isNotEmpty) {
        return nested;
      }
    }

    return '未知教师';
  }

  static String _normalizeImageUrl(dynamic value) {
    final raw = _firstNonEmpty(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('//')) {
      return 'https:$raw';
    }
    if (raw.startsWith('/')) {
      return 'https://openapiv5.ketangpai.com$raw';
    }
    return raw;
  }

  factory Course.fromCXJson(Map<String, dynamic> json) {
    final content = json['content'];
    final courseData = content['course']['data'][0];

    return Course(
      courseId: courseData['id'].toString(),
      classId: content['id'].toString(),
      cpi: content['cpi'].toString(),
      image: courseData['imageurl'] ?? '',
      name: courseData['name'] ?? '未知课程',
      teacher: courseData['teacherfactor'] ?? '未知教师',
      schools: courseData['schools'],
      note: content['name'],
      state: content['state'] == 0,
      beginDate: content['beginDate'],
      endDate: content['endDate'],
    );
  }

  factory Course.fromRCJson(Map<String, dynamic> json) {
    return Course(
      courseId: json['course_id']?.toString() ?? '',
      classId: json['classroom_id']?.toString() ?? '',
      image: json['teacher']?['avatar'] ?? '',
      name: json['course_name'] ?? '未知课程',
      teacher: json['teacher']?['name'] ?? '未知教师',
      note: json['classroom_name'],
      state: true,
      lessonId: json['lesson_id'],
    );
  }

  factory Course.fromKTPJson(Map<String, dynamic> json) {
    final courseId = _firstNonEmpty(
      json['courseid'] ?? json['courseId'] ?? json['id'],
    );
    final classId = _firstNonEmpty(
      json['classid'] ??
          json['classId'] ??
          json['classroomid'] ??
          json['classroom_id'] ??
          json['classroomId'] ??
          json['lesson_id'] ??
          json['lessonId'] ??
          json['id'],
    );
    final teacherName = _teacherFromJson(json);
    final courseName = _firstNonEmpty(
      json['coursename'] ??
          json['course_name'] ??
          json['courseName'] ??
          json['name'],
      '未知课程',
    );
    final image = _normalizeImageUrl(
      json['minpic'] ??
          json['middlepic'] ??
          json['imageurl'] ??
          json['image'] ??
          json['avatar'],
    );
    final beginDate = json['begintime'] ?? json['beginDate'];
    final endDate = json['endtime'] ?? json['endDate'];
    final className = _firstNonEmpty(
      json['classname'] ?? json['classroom_name'] ?? json['classroomName'],
    );
    final code = _firstNonEmpty(json['code'] ?? json['coursecode']);
    final schoolName = _firstNonEmpty(
      json['schoolname'] ??
          json['schoolName'] ??
          json['school'] ??
          json['schools'],
    );

    return Course(
      courseId: courseId,
      classId: classId,
      cpi: json['cpi']?.toString(),
      image: image,
      name: courseName,
      teacher: teacherName,
      schools: schoolName.isEmpty ? null : schoolName,
      note: className.isNotEmpty
          ? className
          : (code.isNotEmpty ? '课程码: $code' : null),
      state: json['state'] == null ? true : json['state'].toString() != '0',
      beginDate: beginDate?.toString(),
      endDate: endDate?.toString(),
      lessonId: json['lesson_id']?.toString() ?? json['lessonId']?.toString(),
    );
  }

  Map<String, String> toJson() => {
    'courseId': courseId,
    'classId': classId,
    'cpi': cpi ?? '',
    'image': image,
    'name': name,
    'teacher': teacher,
    'schools': schools ?? '',
    'note': note ?? '',
    'state': state.toString(),
    'beginDate': beginDate ?? '',
    'endDate': endDate ?? '',
  };
}
