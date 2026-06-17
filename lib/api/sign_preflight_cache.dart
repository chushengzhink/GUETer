class SignPreflightContext {
  const SignPreflightContext({
    required this.platform,
    required this.userId,
    required this.activityId,
    required this.createdAt,
    this.detailUrl,
    this.resolvedUrl,
    this.referer,
    this.csrfToken,
    this.extra = const <String, String>{},
  });

  final String platform;
  final String userId;
  final String activityId;
  final DateTime createdAt;
  final String? detailUrl;
  final String? resolvedUrl;
  final String? referer;
  final String? csrfToken;
  final Map<String, String> extra;

  bool isFresh(Duration ttl, DateTime now) {
    return now.difference(createdAt) <= ttl;
  }
}

class SignPreflightCache {
  SignPreflightCache({this.ttl = const Duration(minutes: 3)});

  final Duration ttl;
  final Map<String, SignPreflightContext> _items =
      <String, SignPreflightContext>{};

  SignPreflightContext? read({
    required String platform,
    required String userId,
    required String activityId,
    DateTime? now,
  }) {
    final key = _key(
      platform: platform,
      userId: userId,
      activityId: activityId,
    );
    final item = _items[key];
    if (item == null) return null;
    if (!item.isFresh(ttl, now ?? DateTime.now())) {
      _items.remove(key);
      return null;
    }
    return item;
  }

  void write(SignPreflightContext context) {
    _items[_key(
          platform: context.platform,
          userId: context.userId,
          activityId: context.activityId,
        )] =
        context;
  }

  void remove({
    required String platform,
    required String userId,
    required String activityId,
  }) {
    _items.remove(
      _key(platform: platform, userId: userId, activityId: activityId),
    );
  }

  void clear() {
    _items.clear();
  }

  static String _key({
    required String platform,
    required String userId,
    required String activityId,
  }) {
    return '${platform.toLowerCase()}::$userId::$activityId';
  }
}
