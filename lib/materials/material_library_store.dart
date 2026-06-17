import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'material_index_models.dart';

enum MaterialLibraryStatus {
  inbox('inbox'),
  archived('archived'),
  ignored('ignored'),
  missing('missing'),
  indexError('indexError');

  const MaterialLibraryStatus(this.id);

  final String id;

  static MaterialLibraryStatus fromId(String id) {
    return values.firstWhere(
      (status) => status.id == id,
      orElse: () => MaterialLibraryStatus.inbox,
    );
  }
}

class MaterialLibraryItem {
  const MaterialLibraryItem({
    required this.id,
    required this.path,
    required this.name,
    required this.sourceType,
    required this.sourceLabel,
    required this.importedAt,
    this.lastOpenedAt,
    this.status = MaterialLibraryStatus.inbox,
    this.tags = const <String>[],
  });

  final String id;
  final String path;
  final String name;
  final MaterialSourceType sourceType;
  final String sourceLabel;
  final DateTime importedAt;
  final DateTime? lastOpenedAt;
  final MaterialLibraryStatus status;
  final List<String> tags;

  MaterialLibraryItem copyWith({
    String? id,
    String? path,
    String? name,
    MaterialSourceType? sourceType,
    String? sourceLabel,
    DateTime? importedAt,
    DateTime? lastOpenedAt,
    MaterialLibraryStatus? status,
    List<String>? tags,
  }) {
    return MaterialLibraryItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      sourceType: sourceType ?? this.sourceType,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      importedAt: importedAt ?? this.importedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      status: status ?? this.status,
      tags: tags ?? this.tags,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'path': path,
      'name': name,
      'sourceType': sourceType.id,
      'sourceLabel': sourceLabel,
      'importedAt': importedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      'status': status.id,
      'tags': tags,
    };
  }

  factory MaterialLibraryItem.fromJson(Map<String, Object?> json) {
    final path = json['path']?.toString() ?? '';
    return MaterialLibraryItem(
      id: json['id']?.toString() ?? MaterialLibraryStore.idForPath(path),
      path: path,
      name: json['name']?.toString().trim().isNotEmpty == true
          ? json['name'].toString()
          : p.basename(path),
      sourceType: MaterialSourceType.fromId(
        json['sourceType']?.toString() ?? '',
      ),
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      importedAt:
          DateTime.tryParse(json['importedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt']?.toString() ?? ''),
      status: MaterialLibraryStatus.fromId(json['status']?.toString() ?? ''),
      tags:
          (json['tags'] as List?)
              ?.whereType<String>()
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList() ??
          const <String>[],
    );
  }
}

class MaterialLibraryStore {
  MaterialLibraryStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String itemsKey = 'material_library_items_v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  static String idForPath(String path) {
    return base64Url.encode(utf8.encode(p.normalize(path))).replaceAll('=', '');
  }

  Future<List<MaterialLibraryItem>> loadItems() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(itemsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <MaterialLibraryItem>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <MaterialLibraryItem>[];
      final byPath = <String, MaterialLibraryItem>{};
      for (final item in decoded.whereType<Map>()) {
        final libraryItem = MaterialLibraryItem.fromJson(
          item.map((key, value) => MapEntry('$key', value)),
        );
        if (libraryItem.path.trim().isEmpty) continue;
        byPath[p.normalize(libraryItem.path)] = libraryItem;
      }
      return byPath.values.toList();
    } catch (_) {
      return <MaterialLibraryItem>[];
    }
  }

  Future<MaterialLibraryItem> upsertItem({
    required String path,
    required String name,
    required MaterialSourceType sourceType,
    required String sourceLabel,
    MaterialLibraryStatus status = MaterialLibraryStatus.inbox,
    List<String> tags = const <String>[],
    DateTime? importedAt,
  }) async {
    final normalizedPath = p.normalize(path);
    final items = await loadItems();
    final index = items.indexWhere(
      (item) => p.equals(item.path, normalizedPath),
    );
    final now = importedAt ?? DateTime.now();
    final existing = index >= 0 ? items[index] : null;
    final item = MaterialLibraryItem(
      id: existing?.id ?? idForPath(normalizedPath),
      path: normalizedPath,
      name: name.trim().isNotEmpty ? name.trim() : p.basename(normalizedPath),
      sourceType: sourceType,
      sourceLabel: sourceLabel.trim(),
      importedAt: existing?.importedAt ?? now,
      lastOpenedAt: existing?.lastOpenedAt,
      status: _statusAfterUpsert(existing?.status, status),
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(),
    );
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
    await _saveItems(items);
    return item;
  }

  Future<MaterialLibraryItem> recordIndexEntry(MaterialIndexEntry entry) async {
    return upsertItem(
      path: entry.path,
      name: entry.name,
      sourceType: entry.sourceType,
      sourceLabel: entry.sourceLabel,
      status: entry.hasError
          ? MaterialLibraryStatus.indexError
          : MaterialLibraryStatus.inbox,
    );
  }

  Future<void> recordOpened({
    required String path,
    String? name,
    MaterialSourceType sourceType = MaterialSourceType.fileToolOutput,
    String sourceLabel = '本地资料',
    DateTime? openedAt,
  }) async {
    final normalizedPath = p.normalize(path);
    final items = await loadItems();
    final index = items.indexWhere(
      (item) => p.equals(item.path, normalizedPath),
    );
    final now = openedAt ?? DateTime.now();
    final openedName = name?.trim();
    final item = index >= 0
        ? items[index].copyWith(
            name: openedName != null && openedName.isNotEmpty
                ? openedName
                : items[index].name,
            lastOpenedAt: now,
            status: _statusForPath(normalizedPath, items[index].status),
          )
        : MaterialLibraryItem(
            id: idForPath(normalizedPath),
            path: normalizedPath,
            name: openedName != null && openedName.isNotEmpty
                ? openedName
                : p.basename(normalizedPath),
            sourceType: sourceType,
            sourceLabel: sourceLabel,
            importedAt: now,
            lastOpenedAt: now,
            status: _statusForPath(normalizedPath, MaterialLibraryStatus.inbox),
          );
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
    await _saveItems(items);
  }

  Future<void> setStatus(String id, MaterialLibraryStatus status) async {
    final items = await loadItems();
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    items[index] = items[index].copyWith(status: status);
    await _saveItems(items);
  }

  Future<List<MaterialLibraryItem>> inboxItems({int? limit}) async {
    final items =
        (await loadItems())
            .where((item) => item.status == MaterialLibraryStatus.inbox)
            .toList()
          ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return limit == null ? items : items.take(limit).toList();
  }

  Future<List<MaterialLibraryItem>> recentItems({int? limit}) async {
    final items =
        (await loadItems()).where((item) => item.lastOpenedAt != null).toList()
          ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    return limit == null ? items : items.take(limit).toList();
  }

  Future<List<MaterialLibraryItem>> refreshMissingStatuses() async {
    final items = await loadItems();
    var changed = false;
    final updated = <MaterialLibraryItem>[];
    for (final item in items) {
      final status = _statusForPath(item.path, item.status);
      changed = changed || status != item.status;
      updated.add(item.copyWith(status: status));
    }
    if (changed) {
      await _saveItems(updated);
    }
    return updated;
  }

  MaterialLibraryStatus _statusForPath(
    String path,
    MaterialLibraryStatus current,
  ) {
    if (current == MaterialLibraryStatus.ignored ||
        current == MaterialLibraryStatus.archived) {
      return current;
    }
    if (!File(path).existsSync() && !Directory(path).existsSync()) {
      return MaterialLibraryStatus.missing;
    }
    return current == MaterialLibraryStatus.missing
        ? MaterialLibraryStatus.inbox
        : current;
  }

  MaterialLibraryStatus _statusAfterUpsert(
    MaterialLibraryStatus? current,
    MaterialLibraryStatus next,
  ) {
    return switch (current) {
      MaterialLibraryStatus.archived ||
      MaterialLibraryStatus.ignored => current!,
      _ => next,
    };
  }

  Future<void> _saveItems(List<MaterialLibraryItem> items) async {
    final prefs = await _preferencesLoader();
    final byPath = <String, MaterialLibraryItem>{};
    for (final item in items) {
      if (item.path.trim().isEmpty) continue;
      byPath[p.normalize(item.path)] = item;
    }
    final sorted = byPath.values.toList()
      ..sort((a, b) => b.importedAt.compareTo(a.importedAt));
    await prefs.setString(
      itemsKey,
      jsonEncode(sorted.map((item) => item.toJson()).toList()),
    );
  }
}
