import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'smart_models.dart';

class SmartInsightStore {
  SmartInsightStore({Future<SharedPreferences> Function()? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String statesKey = 'smart_insight_states_v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<Map<String, SmartInsightStatus>> loadStatuses() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(statesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, SmartInsightStatus>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, SmartInsightStatus>{};
      final result = <String, SmartInsightStatus>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        if (key.isEmpty) continue;
        final value = entry.value;
        if (value is Map) {
          result[key] = SmartInsightStatus.fromId(
            value['status']?.toString() ?? '',
          );
        } else {
          result[key] = SmartInsightStatus.fromId(value?.toString() ?? '');
        }
      }
      return result;
    } catch (_) {
      return <String, SmartInsightStatus>{};
    }
  }

  Future<void> setStatus(String id, SmartInsightStatus status) async {
    if (id.trim().isEmpty) return;
    final prefs = await _preferencesLoader();
    final states = await _loadRawStates(prefs);
    states[id] = <String, Object?>{
      'status': status.id,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(statesKey, jsonEncode(states));
  }

  Future<List<SmartInsight>> applyStatuses(
    List<SmartInsight> insights, {
    bool includeInactive = false,
  }) async {
    final statuses = await loadStatuses();
    final result = <SmartInsight>[];
    for (final insight in insights) {
      final status = statuses[insight.id] ?? SmartInsightStatus.active;
      final updated = insight.copyWith(status: status);
      if (includeInactive || status == SmartInsightStatus.active) {
        result.add(updated);
      }
    }
    return result;
  }

  Future<void> clear() async {
    final prefs = await _preferencesLoader();
    await prefs.remove(statesKey);
  }

  Future<Map<String, Object?>> _loadRawStates(SharedPreferences prefs) async {
    final raw = prefs.getString(statesKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return <String, Object?>{};
    }
    return <String, Object?>{};
  }
}
