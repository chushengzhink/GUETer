import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import '../models/file_tool_models.dart';

class FileToolHistoryStore {
  FileToolHistoryStore({
    Future<SharedPreferences> Function()? preferencesLoader,
    this.maxRecords = 100,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String storageKey = 'file_tool_history_v1';

  final Future<SharedPreferences> Function() _preferencesLoader;
  final int maxRecords;

  Future<List<FileToolHistoryRecord>> load({
    FileToolHistoryScope? scope,
  }) async {
    final prefs = await _preferencesLoader();
    final rawItems = prefs.getStringList(storageKey) ?? const <String>[];
    final records =
        rawItems
            .map(FileToolHistoryRecord.decode)
            .whereType<FileToolHistoryRecord>()
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (scope == null) {
      return records;
    }
    return records.where((record) => record.scope == scope).toList();
  }

  Future<void> append(FileToolHistoryRecord record) async {
    final records = await load();
    records.insert(0, record);
    if (records.length > maxRecords) {
      records.removeRange(maxRecords, records.length);
    }
    await _save(records);
  }

  Future<void> clear({FileToolHistoryScope? scope}) async {
    if (scope == null) {
      final prefs = await _preferencesLoader();
      await prefs.remove(storageKey);
      return;
    }
    final records = await load();
    await _save(records.where((record) => record.scope != scope).toList());
  }

  Future<void> removeByOutputPath(String path) {
    return removeManyByOutputPath(<String>[path]);
  }

  Future<void> removeManyByOutputPath(Iterable<String> paths) async {
    final normalizedTargets = paths
        .map((path) => p.normalize(path))
        .where((path) => path.trim().isNotEmpty)
        .toSet();
    if (normalizedTargets.isEmpty) return;
    final records = await load();
    await _save(
      records
          .where(
            (record) =>
                !normalizedTargets.contains(p.normalize(record.outputPath)),
          )
          .toList(),
    );
  }

  Future<void> _save(List<FileToolHistoryRecord> records) async {
    final prefs = await _preferencesLoader();
    await prefs.setStringList(
      storageKey,
      records.map((record) => record.encode()).toList(),
    );
  }
}
