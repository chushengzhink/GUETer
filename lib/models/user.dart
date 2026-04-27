class User {
  final String name;
  final String avatar;
  final String phone;
  final String uid;
  final String school;
  final String platform;
  final String token;
  final String password;
  final int? credentialExpiry; // Unix timestamp (seconds) when credential expires
  final int? lastRefreshTime; // Unix timestamp (seconds) of last successful refresh
  final String? refreshToken; // Platform-specific refresh token if available

  User({
    required this.name,
    required this.avatar,
    required this.phone,
    required this.uid,
    required this.school,
    this.platform = 'chaoxing',
    this.token = '',
    this.password = '',
    this.credentialExpiry,
    this.lastRefreshTime,
    this.refreshToken,
  });

  User copyWith({
    String? name,
    String? avatar,
    String? phone,
    String? uid,
    String? school,
    String? platform,
    String? token,
    String? password,
    int? credentialExpiry,
    int? lastRefreshTime,
    String? refreshToken,
  }) {
    return User(
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
      uid: uid ?? this.uid,
      school: school ?? this.school,
      platform: platform ?? this.platform,
      token: token ?? this.token,
      password: password ?? this.password,
      credentialExpiry: credentialExpiry ?? this.credentialExpiry,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'] ?? '未知用户',
      avatar: json['avatar'] ?? '',
      phone: json['phone'] ?? '未知手机号',
      uid: json['uid'] ?? '0',
      school: json['school'] ?? '未知学校',
      platform: json['platform'] ?? 'chaoxing',
      token: json['token'] ?? '',
      password: json['password'] ?? '',
      credentialExpiry: json['credentialExpiry'],
      lastRefreshTime: json['lastRefreshTime'],
      refreshToken: json['refreshToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'avatar': avatar,
      'phone': phone,
      'uid': uid,
      'school': school,
      'platform': platform,
      'token': token,
      'password': password,
      if (credentialExpiry != null) 'credentialExpiry': credentialExpiry,
      if (lastRefreshTime != null) 'lastRefreshTime': lastRefreshTime,
      if (refreshToken != null) 'refreshToken': refreshToken,
    };
  }

  bool get isChaoxing => platform.toLowerCase() == 'chaoxing';
  bool get isRainClassroom =>
      platform.toLowerCase() == 'rainclassroom' || platform == 'rainClassroom';
  bool get isTronclass => platform.toLowerCase() == 'tronclass';
  bool get isKetangpai => platform.toLowerCase() == 'ketangpai';
  bool get isWeizhuojiao => platform.toLowerCase() == 'weizhuojiao';

  /// Check if credential is expired or will expire soon
  bool isCredentialExpired({int bufferSeconds = 0}) {
    if (credentialExpiry == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now + bufferSeconds >= credentialExpiry!;
  }

  /// Get remaining credential validity in hours
  double? get credentialRemainingHours {
    if (credentialExpiry == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = credentialExpiry! - now;
    return remaining > 0 ? remaining / 3600.0 : 0.0;
  }
}
