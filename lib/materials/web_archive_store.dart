import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'web_archive_models.dart';

class WebArchiveStore {
  WebArchiveStore({Future<SharedPreferences> Function()? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String itemsKey = 'web_archive_items_v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  static String idForUrl(String url) {
    return base64Url.encode(utf8.encode(normalizeUrl(url))).replaceAll('=', '');
  }

  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return trimmed;
    if (!parsed.hasScheme && trimmed.contains('.')) {
      return Uri.parse('https://$trimmed').toString();
    }
    return parsed.toString();
  }

  Future<List<WebArchiveItem>> loadItems() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(itemsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <WebArchiveItem>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <WebArchiveItem>[];
      final byUrl = <String, WebArchiveItem>{};
      for (final item in decoded.whereType<Map>()) {
        final archiveItem = WebArchiveItem.fromJson(
          item.map((key, value) => MapEntry('$key', value)),
        );
        if (archiveItem.url.trim().isEmpty) continue;
        byUrl[normalizeUrl(archiveItem.url)] = archiveItem.copyWith(
          url: normalizeUrl(archiveItem.url),
        );
      }
      return byUrl.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return <WebArchiveItem>[];
    }
  }

  Future<WebArchiveItem> upsertItem(WebArchiveItem item) async {
    final normalizedUrl = normalizeUrl(item.url);
    final now = DateTime.now();
    final items = await loadItems();
    final index = items.indexWhere(
      (existing) => normalizeUrl(existing.url) == normalizedUrl,
    );
    final existing = index >= 0 ? items[index] : null;
    final next = item.copyWith(
      id: existing?.id ?? item.id,
      url: normalizedUrl,
      createdAt: existing?.createdAt ?? item.createdAt,
      updatedAt: item.updatedAt == DateTime.fromMillisecondsSinceEpoch(0)
          ? now
          : item.updatedAt,
      lastOpenedAt: item.lastOpenedAt ?? existing?.lastOpenedAt,
      status: _statusAfterUpsert(existing?.status, item.status),
      tags: item.tags.isEmpty && existing != null
          ? existing.tags
          : _normalizeTags(item.tags),
    );
    if (index >= 0) {
      items[index] = next;
    } else {
      items.add(next);
    }
    await _saveItems(items);
    return next;
  }

  Future<WebArchiveItem> saveUrlOnly({
    required String url,
    String? title,
    List<String> tags = const <String>[],
    WebArchiveStatus status = WebArchiveStatus.fetchError,
  }) async {
    final normalizedUrl = normalizeUrl(url);
    final now = DateTime.now();
    return upsertItem(
      WebArchiveItem(
        id: idForUrl(normalizedUrl),
        url: normalizedUrl,
        title: title?.trim().isNotEmpty == true ? title!.trim() : normalizedUrl,
        tags: tags,
        status: status,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> deleteItem(String id) async {
    final items = await loadItems();
    await _saveItems(items.where((item) => item.id != id).toList());
  }

  Future<void> setStatus(String id, WebArchiveStatus status) async {
    final items = await loadItems();
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    items[index] = items[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    await _saveItems(items);
  }

  Future<void> updateTags(String id, List<String> tags) async {
    final items = await loadItems();
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    items[index] = items[index].copyWith(
      tags: _normalizeTags(tags),
      updatedAt: DateTime.now(),
    );
    await _saveItems(items);
  }

  Future<void> recordOpened(String id, {DateTime? openedAt}) async {
    final items = await loadItems();
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    items[index] = items[index].copyWith(
      lastOpenedAt: openedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _saveItems(items);
  }

  Future<List<WebArchiveItem>> refreshMissingStatuses() async {
    final items = await loadItems();
    var changed = false;
    final updated = <WebArchiveItem>[];
    for (final item in items) {
      final nextStatus = _statusForSnapshot(item);
      changed = changed || nextStatus != item.status;
      updated.add(item.copyWith(status: nextStatus));
    }
    if (changed) {
      await _saveItems(updated);
    }
    return updated;
  }

  Future<List<WebArchiveItem>> recentItems({int? limit}) async {
    final items = await loadItems();
    final visible =
        items
            .where(
              (item) =>
                  item.status != WebArchiveStatus.ignored &&
                  item.status != WebArchiveStatus.archived,
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return limit == null ? visible : visible.take(limit).toList();
  }

  Future<Directory> snapshotsDirectory({
    Future<Directory> Function()? directoryLoader,
  }) async {
    final base = await directoryLoader?.call();
    if (base != null) {
      final dir = Directory(p.join(base.path, 'web_archive'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    throw StateError(
      'A directory loader is required outside WebArchiveService.',
    );
  }

  WebArchiveStatus _statusAfterUpsert(
    WebArchiveStatus? current,
    WebArchiveStatus next,
  ) {
    return switch (current) {
      WebArchiveStatus.archived || WebArchiveStatus.ignored => current!,
      _ => next,
    };
  }

  WebArchiveStatus _statusForSnapshot(WebArchiveItem item) {
    if (item.status == WebArchiveStatus.archived ||
        item.status == WebArchiveStatus.ignored ||
        item.status == WebArchiveStatus.fetchError) {
      return item.status;
    }
    final path = item.textSnapshotPath.trim();
    if (path.isNotEmpty && !File(path).existsSync()) {
      return WebArchiveStatus.missing;
    }
    return item.status == WebArchiveStatus.missing
        ? WebArchiveStatus.saved
        : item.status;
  }

  List<String> _normalizeTags(List<String> tags) {
    return tags
        .expand((tag) => tag.split(RegExp(r'[,，\s]+')))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  Future<void> _saveItems(List<WebArchiveItem> items) async {
    final prefs = await _preferencesLoader();
    final byUrl = <String, WebArchiveItem>{};
    for (final item in items) {
      if (item.url.trim().isEmpty) continue;
      byUrl[normalizeUrl(item.url)] = item.copyWith(
        url: normalizeUrl(item.url),
      );
    }
    final sorted = byUrl.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      itemsKey,
      jsonEncode(sorted.map((item) => item.toJson()).toList()),
    );
  }
}
