Map<String, dynamic> _mapOf(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
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

class KetangpaiScanSignPayload {
  const KetangpaiScanSignPayload({
    required this.ticketId,
    required this.expire,
    required this.sign,
    this.raw = '',
  });

  final String ticketId;
  final String expire;
  final String sign;
  final String raw;

  bool get isValid => missingKeys.isEmpty;

  List<String> get missingKeys => <String>[
    if (ticketId.trim().isEmpty) 'ticketid',
    if (expire.trim().isEmpty) 'expire',
    if (sign.trim().isEmpty) 'sign',
  ];

  factory KetangpaiScanSignPayload.fromMap(
    Map<String, String> map, {
    String raw = '',
  }) {
    return KetangpaiScanSignPayload(
      ticketId: map['ticketid'] ?? '',
      expire: map['expire'] ?? '',
      sign: map['sign'] ?? '',
      raw: raw,
    );
  }

  factory KetangpaiScanSignPayload.fromJson(Map<String, dynamic> json) {
    return KetangpaiScanSignPayload(
      ticketId: _stringOf(json['ticketid'] ?? json['ticketId']),
      expire: _stringOf(json['expire']),
      sign: _stringOf(json['sign']),
      raw: _stringOf(json['raw']),
    );
  }

  Map<String, dynamic> toJson() => {
    'ticketid': ticketId,
    'expire': expire,
    'sign': sign,
    'raw': raw,
  };
}

class KetangpaiSignTask {
  const KetangpaiSignTask({
    required this.id,
    required this.type,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.courseId,
    required this.raw,
  });

  final String id;
  final int type;
  final String name;
  final String startTime;
  final String endTime;
  final String courseId;
  final Map<String, dynamic> raw;

  factory KetangpaiSignTask.fromJson(Map<String, dynamic> json) {
    return KetangpaiSignTask(
      id: _stringOf(json['id'] ?? json['signId']),
      type: _intOf(json['type'] ?? json['signType']),
      name: _stringOf(json['name'] ?? json['title'], '签到'),
      startTime: _stringOf(json['starttime'] ?? json['startTime']),
      endTime: _stringOf(json['endtime'] ?? json['endTime']),
      courseId: _stringOf(json['courseid'] ?? json['courseId']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    ...raw,
    'id': id,
    'type': type,
    'name': name,
    'starttime': startTime,
    'endtime': endTime,
    'courseid': courseId,
  };
}

class KetangpaiSignOutcome {
  const KetangpaiSignOutcome({
    required this.success,
    required this.message,
    this.code,
    this.state,
    required this.raw,
  });

  final bool success;
  final String message;
  final int? code;
  final int? state;
  final dynamic raw;

  factory KetangpaiSignOutcome.fromJson(Map<String, dynamic> json) {
    final data = _mapOf(json['data']);
    final state = data.containsKey('state') ? _intOf(data['state']) : null;
    final code = json.containsKey('code') ? _intOf(json['code']) : null;
    return KetangpaiSignOutcome(
      success:
          json['success'] == true ||
          json['status'] == 1 ||
          json['status'] == '1' ||
          code == 10000 ||
          state == 8,
      message: _stringOf(
        data['info'] ?? json['message'] ?? json['msg'] ?? data['message'],
      ),
      code: code,
      state: state,
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    if (code != null) 'code': code,
    if (state != null) 'state': state,
    'raw': raw,
  };
}

class KetangpaiLocationPayload {
  const KetangpaiLocationPayload({
    required this.latitude,
    required this.longitude,
    this.accuracy = '100',
  });

  final String latitude;
  final String longitude;
  final String accuracy;

  bool get isValid => latitude.trim().isNotEmpty && longitude.trim().isNotEmpty;

  factory KetangpaiLocationPayload.fromJson(Map<String, dynamic> json) {
    return KetangpaiLocationPayload(
      latitude: _stringOf(json['latitude']),
      longitude: _stringOf(json['longitude']),
      accuracy: _stringOf(json['accuracy'], '100'),
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
  };
}
