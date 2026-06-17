import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LayoutPreferences {
  const LayoutPreferences({
    this.navOrder = defaultNavOrder,
    this.hiddenNavIds = const <String>[],
    this.pinnedNavIds = const <String>[],
    this.toolCategoryOrder = const <String>[],
    this.toolActionOrder = const <String>[],
    this.hiddenToolActionIds = const <String>[],
    this.pinnedToolActionIds = const <String>[],
  });

  static const String storageKey = 'app_layout_preferences_v1';

  static const List<String> defaultNavOrder = <String>[
    'courses',
    'accounts',
    'todos',
    'tools',
    'settings',
  ];

  final List<String> navOrder;
  final List<String> hiddenNavIds;
  final List<String> pinnedNavIds;
  final List<String> toolCategoryOrder;
  final List<String> toolActionOrder;
  final List<String> hiddenToolActionIds;
  final List<String> pinnedToolActionIds;

  factory LayoutPreferences.fromJson(Map<String, dynamic> json) {
    return LayoutPreferences(
      navOrder: _readStringList(json['navOrder'], defaultNavOrder),
      hiddenNavIds: _readStringList(json['hiddenNavIds']),
      pinnedNavIds: _readStringList(json['pinnedNavIds']),
      toolCategoryOrder: _readStringList(json['toolCategoryOrder']),
      toolActionOrder: _readStringList(json['toolActionOrder']),
      hiddenToolActionIds: _readStringList(json['hiddenToolActionIds']),
      pinnedToolActionIds: _readStringList(json['pinnedToolActionIds']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'navOrder': navOrder,
      'hiddenNavIds': hiddenNavIds,
      'pinnedNavIds': pinnedNavIds,
      'toolCategoryOrder': toolCategoryOrder,
      'toolActionOrder': toolActionOrder,
      'hiddenToolActionIds': hiddenToolActionIds,
      'pinnedToolActionIds': pinnedToolActionIds,
    };
  }

  LayoutPreferences copyWith({
    List<String>? navOrder,
    List<String>? hiddenNavIds,
    List<String>? pinnedNavIds,
    List<String>? toolCategoryOrder,
    List<String>? toolActionOrder,
    List<String>? hiddenToolActionIds,
    List<String>? pinnedToolActionIds,
  }) {
    return LayoutPreferences(
      navOrder: navOrder ?? this.navOrder,
      hiddenNavIds: hiddenNavIds ?? this.hiddenNavIds,
      pinnedNavIds: pinnedNavIds ?? this.pinnedNavIds,
      toolCategoryOrder: toolCategoryOrder ?? this.toolCategoryOrder,
      toolActionOrder: toolActionOrder ?? this.toolActionOrder,
      hiddenToolActionIds: hiddenToolActionIds ?? this.hiddenToolActionIds,
      pinnedToolActionIds: pinnedToolActionIds ?? this.pinnedToolActionIds,
    );
  }

  LayoutPreferences normalized({
    required List<String> navIds,
    List<String> toolCategoryIds = const <String>[],
    List<String> toolActionIds = const <String>[],
  }) {
    return copyWith(
      navOrder: _mergeKnownOrder(navOrder, navIds),
      hiddenNavIds: hiddenNavIds.where(navIds.contains).toList(),
      pinnedNavIds: pinnedNavIds.where(navIds.contains).toList(),
      toolCategoryOrder: _mergeKnownOrder(toolCategoryOrder, toolCategoryIds),
      toolActionOrder: _mergeKnownOrder(toolActionOrder, toolActionIds),
      hiddenToolActionIds: hiddenToolActionIds
          .where(toolActionIds.contains)
          .toList(),
      pinnedToolActionIds: pinnedToolActionIds
          .where(toolActionIds.contains)
          .toList(),
    );
  }

  List<String> visibleNavOrder(List<String> navIds) {
    final normalizedOrder = _mergeKnownOrder(navOrder, navIds);
    return normalizedOrder.where((id) => !hiddenNavIds.contains(id)).toList();
  }

  List<String> visibleToolActionOrder(List<String> actionIds) {
    final normalizedOrder = _mergeKnownOrder(toolActionOrder, actionIds);
    return normalizedOrder
        .where((id) => !hiddenToolActionIds.contains(id))
        .toList();
  }

  static List<String> _readStringList(
    Object? value, [
    List<String> fallback = const <String>[],
  ]) {
    if (value is! List) {
      return List<String>.from(fallback);
    }
    return value.whereType<String>().where((id) => id.isNotEmpty).toList();
  }

  static List<String> _mergeKnownOrder(
    List<String> currentOrder,
    List<String> knownIds,
  ) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final id in currentOrder) {
      if (knownIds.contains(id) && seen.add(id)) {
        ordered.add(id);
      }
    }
    for (final id in knownIds) {
      if (seen.add(id)) {
        ordered.add(id);
      }
    }
    return ordered;
  }
}

class LayoutPreferencesStore {
  LayoutPreferencesStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesLoader;

  final ValueNotifier<LayoutPreferences> notifier =
      ValueNotifier<LayoutPreferences>(const LayoutPreferences());

  Future<LayoutPreferences> load() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(LayoutPreferences.storageKey);
    final value = parse(raw);
    notifier.value = value;
    return value;
  }

  Future<void> save(LayoutPreferences preferences) async {
    final prefs = await _preferencesLoader();
    await prefs.setString(
      LayoutPreferences.storageKey,
      jsonEncode(preferences.toJson()),
    );
    notifier.value = preferences;
  }

  Future<void> reset() async {
    final prefs = await _preferencesLoader();
    await prefs.remove(LayoutPreferences.storageKey);
    notifier.value = const LayoutPreferences();
  }

  @visibleForTesting
  static LayoutPreferences parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const LayoutPreferences();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return LayoutPreferences.fromJson(decoded);
      }
      if (decoded is Map) {
        return LayoutPreferences.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return const LayoutPreferences();
    }
    return const LayoutPreferences();
  }
}
