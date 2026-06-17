import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../platform.dart';

enum PlatformSnapshotStatus { fresh, stale, missing }

class PlatformPageSnapshot<T> {
  const PlatformPageSnapshot({
    required this.platform,
    required this.userId,
    required this.page,
    required this.updatedAt,
    required this.data,
    this.source = 'snapshot',
  });

  final PlatformType platform;
  final String userId;
  final String page;
  final DateTime updatedAt;
  final T data;
  final String source;

  PlatformSnapshotStatus status({
    DateTime? now,
    Duration staleAfter = const Duration(minutes: 30),
  }) {
    if ((now ?? DateTime.now()).difference(updatedAt) > staleAfter) {
      return PlatformSnapshotStatus.stale;
    }
    return PlatformSnapshotStatus.fresh;
  }
}

class PlatformPageSnapshotStore {
  PlatformPageSnapshotStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _prefix = 'platform_page_snapshot_v1_';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  Future<PlatformPageSnapshot<List<Map<String, dynamic>>>?> readList({
    required PlatformType platform,
    required String userId,
    required String page,
  }) async {
    final raw = (await _prefs).getString(_key(platform, userId, page));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final updatedAt = DateTime.tryParse(
        decoded['updatedAt']?.toString() ?? '',
      );
      final dataRaw = decoded['data'];
      if (updatedAt == null || dataRaw is! List) return null;
      return PlatformPageSnapshot<List<Map<String, dynamic>>>(
        platform: platform,
        userId: userId,
        page: page,
        updatedAt: updatedAt,
        source: decoded['source']?.toString() ?? 'snapshot',
        data: dataRaw
            .whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeList({
    required PlatformType platform,
    required String userId,
    required String page,
    required List<Map<String, dynamic>> data,
    DateTime? updatedAt,
    String source = 'network',
  }) async {
    await (await _prefs).setString(
      _key(platform, userId, page),
      jsonEncode(<String, dynamic>{
        'platform': platform.name,
        'userId': userId,
        'page': page,
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        'source': source,
        'data': data,
      }),
    );
  }

  Future<PlatformSnapshotStatus> status({
    required PlatformType platform,
    required String userId,
    required String page,
    DateTime? now,
    Duration staleAfter = const Duration(minutes: 30),
  }) async {
    final snapshot = await readList(
      platform: platform,
      userId: userId,
      page: page,
    );
    return snapshot?.status(now: now, staleAfter: staleAfter) ??
        PlatformSnapshotStatus.missing;
  }

  static String _key(PlatformType platform, String userId, String page) {
    return '$_prefix${platform.name}_${base64Url.encode(utf8.encode(userId))}_$page';
  }
}
