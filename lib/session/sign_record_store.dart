import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../platform.dart';
import '../services/sign_platform_context.dart';

class SignRecordStore {
  static const String storageKey = 'sign_records_v1';
  static const int maxRecords = 800;

  Future<List<Map<String, dynamic>>> loadRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(storageKey) ?? const <String>[];
    return rawItems.map(_decode).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> saveRaw(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      storageKey,
      records.map((item) => jsonEncode(item)).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> loadForPlatform(String platform) async {
    final records = await loadRaw();
    if (SignPlatformContext.isAllFilter(platform)) {
      return records;
    }
    final context = SignPlatformContext.tryParse(platform);
    if (context == null) {
      return records
          .where((record) => (record['platform'] ?? '').toString() == platform)
          .toList();
    }
    return records
        .where((record) => _recordMatchesPlatform(record, context))
        .toList();
  }

  Future<Map<String, dynamic>?> latestForPlatform(String platform) async {
    final records = await loadForPlatform(platform);
    return records.isEmpty ? null : records.first;
  }

  Future<void> append({
    required String platform,
    PlatformType? platformType,
    String? platformKey,
    required String courseName,
    required String account,
    required String status,
    String detail = '',
    DateTime? signTime,
  }) async {
    final records = await loadRaw();
    final now = signTime ?? DateTime.now();
    final context =
        (platformType != null
            ? SignPlatformContext.fromType(platformType)
            : null) ??
        (platformKey == null
            ? null
            : SignPlatformContext.tryParse(platformKey)) ??
        SignPlatformContext.tryParse(platform);
    final effectivePlatform = context?.platformLabel ?? platform;
    final effectiveKey = context?.platformKey ?? platformKey ?? platform;

    if (SignPlatformContext.isAllFilter(effectivePlatform) ||
        SignPlatformContext.isAllFilter(effectiveKey)) {
      throw ArgumentError('签到记录平台不能为全部');
    }

    records.insert(0, {
      'platform': effectivePlatform,
      'platformKey': effectiveKey,
      if (context != null) 'platformType': context.platformType.name,
      'courseName': courseName,
      'account': account,
      'status': status,
      'detail': detail,
      'signTime': now.toIso8601String(),
      'timestamp': now.millisecondsSinceEpoch,
    });

    if (records.length > maxRecords) {
      records.removeRange(maxRecords, records.length);
    }
    await saveRaw(records);
  }

  bool _recordMatchesPlatform(
    Map<String, dynamic> record,
    SignPlatformContext context,
  ) {
    final key = (record['platformKey'] ?? '').toString();
    if (key.isNotEmpty) {
      return key == context.platformKey;
    }

    final type = (record['platformType'] ?? '').toString();
    if (type.isNotEmpty) {
      return type == context.platformType.name;
    }

    return (record['platform'] ?? '').toString() == context.platformLabel;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  Map<String, dynamic>? _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, dynamicValue) => MapEntry(key.toString(), dynamicValue),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
