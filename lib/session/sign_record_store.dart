import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> append({
    required String platform,
    required String courseName,
    required String account,
    required String status,
    String detail = '',
    DateTime? signTime,
  }) async {
    final records = await loadRaw();
    final now = signTime ?? DateTime.now();
    records.insert(0, {
      'platform': platform,
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
