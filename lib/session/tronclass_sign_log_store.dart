import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TronclassSignLogStore {
  static const String storageKey = 'tronclass_sign_logs_v1';

  Future<List<Map<String, dynamic>>> loadRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(storageKey) ?? const <String>[];
    return rawItems
        .map(_decode)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> saveRaw(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      storageKey,
      records.map((item) => jsonEncode(item)).toList(),
    );
  }

  Future<void> append(Map<String, dynamic> record) async {
    final records = await loadRaw();
    records.insert(0, record);
    await saveRaw(records);
  }

  Future<void> deleteAt(int index) async {
    final records = await loadRaw();
    if (index < 0 || index >= records.length) return;
    records.removeAt(index);
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
        return decoded.map((key, dynamicValue) => MapEntry(key.toString(), dynamicValue));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
