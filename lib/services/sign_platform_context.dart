import '../platform.dart';

class SignPlatformContext {
  const SignPlatformContext({
    required this.platformType,
    required this.platformKey,
    required this.platformLabel,
  });

  final PlatformType platformType;
  final String platformKey;
  final String platformLabel;

  static const chaoxing = SignPlatformContext(
    platformType: PlatformType.chaoxing,
    platformKey: 'chaoxing',
    platformLabel: '学习通',
  );

  static const rainClassroom = SignPlatformContext(
    platformType: PlatformType.rainClassroom,
    platformKey: 'rainclassroom',
    platformLabel: '雨课堂',
  );

  static const tronclass = SignPlatformContext(
    platformType: PlatformType.tronclass,
    platformKey: 'tronclass',
    platformLabel: '畅课',
  );

  static const ketangpai = SignPlatformContext(
    platformType: PlatformType.ketangpai,
    platformKey: 'ketangpai',
    platformLabel: '课堂派',
  );

  static const weizhuojiao = SignPlatformContext(
    platformType: PlatformType.weizhuojiao,
    platformKey: 'weizhuojiao',
    platformLabel: '微助教',
  );

  static const values = <SignPlatformContext>[
    chaoxing,
    rainClassroom,
    tronclass,
    ketangpai,
    weizhuojiao,
  ];

  static SignPlatformContext fromType(PlatformType platform) {
    return switch (platform) {
      PlatformType.chaoxing => chaoxing,
      PlatformType.rainClassroom => rainClassroom,
      PlatformType.tronclass => tronclass,
      PlatformType.ketangpai => ketangpai,
      PlatformType.weizhuojiao => weizhuojiao,
    };
  }

  static SignPlatformContext? tryParse(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final context in values) {
      if (normalized == context.platformKey ||
          normalized == context.platformLabel.toLowerCase() ||
          normalized == context.platformType.name.toLowerCase()) {
        return context;
      }
    }
    if (normalized == '雨课堂') return rainClassroom;
    return null;
  }

  static bool isAllFilter(String value) {
    final normalized = value.trim();
    return normalized.isEmpty || normalized == '全部' || normalized == '鍏ㄩ儴';
  }
}
