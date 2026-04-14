class User {
  final String name;
  final String avatar;
  final String phone;
  final String uid;
  final String school;
  final String platform;
  final String token;

  User({
    required this.name,
    required this.avatar,
    required this.phone,
    required this.uid,
    required this.school,
    this.platform = 'chaoxing',
    this.token = ''
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
        name: json['name'] ?? '未知用户',
        avatar: json['avatar'] ?? '',
        phone: json['phone'] ?? '未知手机号',
        uid: json['uid'] ?? '0',
        school: json['school'] ?? '未知学校',
        platform: json['platform'] ?? 'chaoxing',
        token: json['token'] ?? ''
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
      'token': token
    };
  }

  bool get isChaoxing => platform.toLowerCase() == 'chaoxing';
  bool get isRainClassroom =>
      platform.toLowerCase() == 'rainclassroom' || platform == 'rainClassroom';
  bool get isTronclass => platform.toLowerCase() == 'tronclass';
  bool get isKetangpai => platform.toLowerCase() == 'ketangpai';
  bool get isWeizhuojiao => platform.toLowerCase() == 'weizhuojiao';
}