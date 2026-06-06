import 'dart:convert';

enum PluginPermission {
  network('network'),
  openExternalUrl('openExternalUrl'),
  embeddedWebView('embeddedWebView'),
  clipboard('clipboard'),
  localFileRead('localFileRead'),
  localFileWrite('localFileWrite');

  const PluginPermission(this.id);

  final String id;

  static PluginPermission? fromId(String id) {
    for (final permission in values) {
      if (permission.id == id) return permission;
    }
    return null;
  }
}

enum PluginActionType {
  openUrl('openUrl'),
  webView('webView'),
  markdownPage('markdownPage'),
  httpRequest('httpRequest'),
  copyText('copyText'),
  route('route'),
  previewFile('previewFile'),
  shareText('shareText'),
  shareFile('shareFile'),
  openFolder('openFolder'),
  openHealthCenter('openHealthCenter'),
  openDuplicateCleanup('openDuplicateCleanup'),
  sequence('sequence'),
  showMessage('showMessage'),
  pickFile('pickFile'),
  saveTextFile('saveTextFile'),
  openBuiltinTool('openBuiltinTool'),
  sendToLocalTransfer('sendToLocalTransfer'),
  openWithFileTool('openWithFileTool'),
  copyJsonField('copyJsonField');

  const PluginActionType(this.id);

  final String id;

  static PluginActionType? fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

enum PluginCapability {
  toolEntry('toolEntry'),
  filePreviewAction('filePreviewAction'),
  healthAction('healthAction'),
  quickCommand('quickCommand');

  const PluginCapability(this.id);

  final String id;

  static PluginCapability? fromId(String id) {
    for (final capability in values) {
      if (capability.id == id) return capability;
    }
    return null;
  }
}

enum PluginSlot {
  tool('tool'),
  command('command'),
  filePreview('filePreview'),
  health('health');

  const PluginSlot(this.id);

  final String id;

  static PluginSlot? fromId(String id) {
    for (final slot in values) {
      if (slot.id == id) return slot;
    }
    return switch (id) {
      'toolEntry' => PluginSlot.tool,
      'quickCommand' => PluginSlot.command,
      'filePreviewAction' => PluginSlot.filePreview,
      'healthAction' => PluginSlot.health,
      _ => null,
    };
  }

  static List<PluginSlot> fromCapabilities(
    List<PluginCapability> capabilities,
  ) {
    final slots = <PluginSlot>{};
    for (final capability in capabilities) {
      switch (capability) {
        case PluginCapability.toolEntry:
          slots.add(PluginSlot.tool);
        case PluginCapability.quickCommand:
          slots.add(PluginSlot.command);
        case PluginCapability.filePreviewAction:
          slots.add(PluginSlot.filePreview);
        case PluginCapability.healthAction:
          slots.add(PluginSlot.health);
      }
    }
    return slots.toList(growable: false);
  }
}

enum PluginContextType {
  file('file'),
  cloudFile('cloudFile'),
  offlinePackage('offlinePackage'),
  text('text'),
  healthIssue('healthIssue');

  const PluginContextType(this.id);

  final String id;

  static PluginContextType? fromId(String id) {
    for (final context in values) {
      if (context.id == id) return context;
    }
    return null;
  }
}

enum PluginSettingType {
  text('text'),
  toggle('toggle'),
  number('number'),
  choice('choice');

  const PluginSettingType(this.id);

  final String id;

  static PluginSettingType? fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

class PluginLocalizedText {
  const PluginLocalizedText({required this.zh, required this.en});

  final String zh;
  final String en;

  factory PluginLocalizedText.fromJson(Object? value, String fieldName) {
    if (value is! Map) {
      throw PluginManifestException('$fieldName 必须是对象。');
    }
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    final zh = map['zh'];
    final en = map['en'];
    if (zh is! String || zh.trim().isEmpty) {
      throw PluginManifestException('$fieldName.zh 为必填项。');
    }
    if (en is! String || en.trim().isEmpty) {
      throw PluginManifestException('$fieldName.en 为必填项。');
    }
    return PluginLocalizedText(zh: zh.trim(), en: en.trim());
  }
}

class PluginEntry {
  const PluginEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.action,
    this.icon = 'extension',
    this.category = 'plugins',
    this.tags = const <String>[],
    this.slots,
    this.fileExtensions = const <String>[],
    this.platforms = const <String>[],
    this.requiresPermissions = const <PluginPermission>[],
    this.contexts = const <PluginContextType>[],
    this.badge,
    this.priority = 0,
  });

  final String id;
  final PluginLocalizedText name;
  final PluginLocalizedText description;
  final PluginActionType type;
  final Map<String, dynamic> action;
  final String icon;
  final String category;
  final List<String> tags;
  final List<PluginSlot>? slots;
  final List<String> fileExtensions;
  final List<String> platforms;
  final List<PluginPermission> requiresPermissions;
  final List<PluginContextType> contexts;
  final String? badge;
  final int priority;

  factory PluginEntry.fromJson(Object? value) {
    if (value is! Map) {
      throw PluginManifestException('entries 中的条目必须是对象。');
    }
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    final id = _requiredString(map, 'id');
    final action = map['action'];
    if (action is! Map) {
      throw PluginManifestException('entry $id 的 action 必须是对象。');
    }
    final actionMap = action.map((key, item) => MapEntry(key.toString(), item));
    final typeValue = _requiredString(actionMap, 'type');
    final type = PluginActionType.fromId(typeValue);
    if (type == null) {
      throw PluginManifestException('不支持的插件动作: $typeValue。');
    }
    return PluginEntry(
      id: id,
      name: PluginLocalizedText.fromJson(map['name'], 'entry.name'),
      description: PluginLocalizedText.fromJson(
        map['description'],
        'entry.description',
      ),
      type: type,
      action: Map<String, dynamic>.from(actionMap),
      icon: (map['icon'] as String?)?.trim().isNotEmpty == true
          ? (map['icon'] as String).trim()
          : 'extension',
      category: (map['category'] as String?)?.trim().isNotEmpty == true
          ? (map['category'] as String).trim()
          : 'plugins',
      tags: _optionalStringList(map, 'tags'),
      slots: _optionalSlots(map['slots']),
      fileExtensions: _optionalNormalizedExtensions(map, 'fileExtensions'),
      platforms: _optionalLowercaseStringList(map, 'platforms'),
      requiresPermissions: _optionalPermissionList(map, 'requiresPermissions'),
      contexts: _optionalContextList(map, 'contexts'),
      badge: (map['badge'] as String?)?.trim().isNotEmpty == true
          ? (map['badge'] as String).trim()
          : null,
      priority: _optionalInt(map, 'priority'),
    );
  }

  List<PluginSlot> effectiveSlots(List<PluginCapability> defaultCapabilities) {
    final explicit = slots;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return PluginSlot.fromCapabilities(defaultCapabilities);
  }
}

class PluginSettingSchema {
  const PluginSettingSchema({
    required this.id,
    required this.type,
    required this.label,
    this.description,
    this.defaultValue,
    this.options = const <String>[],
  });

  final String id;
  final PluginSettingType type;
  final PluginLocalizedText label;
  final PluginLocalizedText? description;
  final Object? defaultValue;
  final List<String> options;

  factory PluginSettingSchema.fromJson(Object? value) {
    if (value is! Map) {
      throw const PluginManifestException('settingsSchema 中的条目必须是对象。');
    }
    final map = value.map((key, item) => MapEntry(key.toString(), item));
    final id = _requiredString(map, 'id');
    final typeValue = _requiredString(map, 'type');
    final type = PluginSettingType.fromId(typeValue);
    if (type == null) {
      throw PluginManifestException('不支持的设置类型: $typeValue。');
    }
    final options = _optionalStringList(map, 'options');
    if (type == PluginSettingType.choice && options.isEmpty) {
      throw PluginManifestException('choice 设置 $id 必须提供 options。');
    }
    return PluginSettingSchema(
      id: id,
      type: type,
      label: PluginLocalizedText.fromJson(map['label'], 'setting.label'),
      description: map['description'] == null
          ? null
          : PluginLocalizedText.fromJson(
              map['description'],
              'setting.description',
            ),
      defaultValue: map['defaultValue'],
      options: options,
    );
  }
}

class PluginManifest {
  const PluginManifest({
    this.manifestVersion = 1,
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.permissions,
    required this.entries,
    this.capabilities = const <PluginCapability>[PluginCapability.toolEntry],
    this.settingsSchema = const <PluginSettingSchema>[],
    this.allowedHosts = const <String>[],
    this.baseDirectory,
  });

  final int manifestVersion;
  final String id;
  final PluginLocalizedText name;
  final String version;
  final String author;
  final PluginLocalizedText description;
  final List<PluginPermission> permissions;
  final List<PluginEntry> entries;
  final List<PluginCapability> capabilities;
  final List<PluginSettingSchema> settingsSchema;
  final List<String> allowedHosts;
  final String? baseDirectory;

  factory PluginManifest.parse(String raw, {String? baseDirectory}) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw PluginManifestException('插件清单必须是 JSON 对象。');
    }
    return PluginManifest.fromJson(decoded, baseDirectory: baseDirectory);
  }

  factory PluginManifest.fromJson(
    Map<dynamic, dynamic> json, {
    String? baseDirectory,
  }) {
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    final permissionsRaw = map['permissions'];
    if (permissionsRaw is! List) {
      throw PluginManifestException('permissions 必须是数组。');
    }
    final permissions = <PluginPermission>[];
    for (final raw in permissionsRaw) {
      if (raw is! String) {
        throw PluginManifestException('permissions 中的值必须是字符串。');
      }
      final permission = PluginPermission.fromId(raw);
      if (permission == null) {
        throw PluginManifestException('不支持的权限: $raw。');
      }
      permissions.add(permission);
    }

    final entriesRaw = map['entries'];
    if (entriesRaw is! List || entriesRaw.isEmpty) {
      throw PluginManifestException('entries 必须是非空数组。');
    }

    final capabilities = _parseCapabilities(map['capabilities']);

    return PluginManifest(
      manifestVersion: _optionalVersion(map),
      id: _requiredString(map, 'id'),
      name: PluginLocalizedText.fromJson(map['name'], 'name'),
      version: _requiredString(map, 'version'),
      author: _requiredString(map, 'author'),
      description: PluginLocalizedText.fromJson(
        map['description'],
        'description',
      ),
      permissions: permissions,
      entries: entriesRaw.map(PluginEntry.fromJson).toList(),
      capabilities: capabilities,
      settingsSchema: _parseSettingsSchema(map['settingsSchema']),
      allowedHosts: _optionalHostList(map, 'allowedHosts'),
      baseDirectory: baseDirectory,
    );
  }
}

class PluginManifestException implements Exception {
  const PluginManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw PluginManifestException('$key 为必填项。');
  }
  return value.trim();
}

List<String> _optionalStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return const <String>[];
  if (value is! List) {
    throw PluginManifestException('$key must be a string array.');
  }
  final result = <String>[];
  for (final item in value) {
    if (item is! String) {
      throw PluginManifestException('$key values must be strings.');
    }
    final normalized = item.trim();
    if (normalized.isNotEmpty) {
      result.add(normalized);
    }
  }
  return result;
}

int _optionalInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw PluginManifestException('$key must be a number.');
}

List<PluginSlot>? _optionalSlots(Object? value) {
  if (value == null) return null;
  if (value is! List) {
    throw const PluginManifestException('entry.slots 必须是字符串数组。');
  }
  final result = <PluginSlot>[];
  for (final raw in value) {
    if (raw is! String) {
      throw const PluginManifestException('entry.slots 中的值必须是字符串。');
    }
    final slot = PluginSlot.fromId(raw);
    if (slot == null) {
      throw PluginManifestException('不支持的入口位置: $raw。');
    }
    result.add(slot);
  }
  return result;
}

List<String> _optionalNormalizedExtensions(
  Map<String, dynamic> map,
  String key,
) {
  return _optionalStringList(map, key)
      .map((value) {
        final lower = value.trim().toLowerCase();
        if (lower.isEmpty) return lower;
        return lower.startsWith('.') ? lower : '.$lower';
      })
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
}

List<String> _optionalLowercaseStringList(
  Map<String, dynamic> map,
  String key,
) {
  return _optionalStringList(
    map,
    key,
  ).map((value) => value.toLowerCase()).toList(growable: false);
}

List<PluginPermission> _optionalPermissionList(
  Map<String, dynamic> map,
  String key,
) {
  final raw = map[key];
  if (raw == null) return const <PluginPermission>[];
  if (raw is! List) {
    throw PluginManifestException('$key 必须是字符串数组。');
  }
  final result = <PluginPermission>[];
  for (final item in raw) {
    if (item is! String) {
      throw PluginManifestException('$key 中的值必须是字符串。');
    }
    final permission = PluginPermission.fromId(item);
    if (permission == null) {
      throw PluginManifestException('不支持的权限: $item。');
    }
    result.add(permission);
  }
  return result;
}

List<PluginContextType> _optionalContextList(
  Map<String, dynamic> map,
  String key,
) {
  final raw = map[key];
  if (raw == null) return const <PluginContextType>[];
  if (raw is! List) {
    throw PluginManifestException('$key 必须是字符串数组。');
  }
  final result = <PluginContextType>[];
  for (final item in raw) {
    if (item is! String) {
      throw PluginManifestException('$key 中的值必须是字符串。');
    }
    final context = PluginContextType.fromId(item);
    if (context == null) {
      throw PluginManifestException('不支持的上下文: $item。');
    }
    result.add(context);
  }
  return result;
}

List<PluginCapability> _parseCapabilities(Object? value) {
  if (value == null) {
    return const <PluginCapability>[PluginCapability.toolEntry];
  }
  if (value is! List) {
    throw const PluginManifestException('capabilities 必须是字符串数组。');
  }
  final result = <PluginCapability>[];
  for (final raw in value) {
    if (raw is! String) {
      throw const PluginManifestException('capabilities 中的值必须是字符串。');
    }
    final capability = PluginCapability.fromId(raw);
    if (capability == null) {
      throw PluginManifestException('不支持的 Mod 能力: $raw。');
    }
    result.add(capability);
  }
  return result.isEmpty
      ? const <PluginCapability>[PluginCapability.toolEntry]
      : result;
}

int _optionalVersion(Map<String, dynamic> map) {
  final value = map['manifestVersion'];
  if (value == null) return 1;
  if (value is int && value >= 1 && value <= 2) return value;
  throw const PluginManifestException('manifestVersion 只支持 1 或 2。');
}

List<PluginSettingSchema> _parseSettingsSchema(Object? value) {
  if (value == null) return const <PluginSettingSchema>[];
  if (value is! List) {
    throw const PluginManifestException('settingsSchema 必须是数组。');
  }
  return value.map(PluginSettingSchema.fromJson).toList(growable: false);
}

List<String> _optionalHostList(Map<String, dynamic> map, String key) {
  return _optionalStringList(map, key)
      .map((host) {
        final lower = host.trim().toLowerCase();
        if (lower.isEmpty || lower.contains('/') || lower.contains('@')) {
          throw PluginManifestException('$key 中包含非法 host: $host。');
        }
        return lower;
      })
      .toList(growable: false);
}
