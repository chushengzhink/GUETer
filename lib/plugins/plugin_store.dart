import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plugin_manifest.dart';
import 'plugin_template.dart';

class InvalidPluginManifest {
  const InvalidPluginManifest({
    required this.directoryName,
    required this.path,
    required this.error,
  });

  final String directoryName;
  final String path;
  final String error;
}

class PluginStore {
  PluginStore({
    Future<SharedPreferences> Function()? preferencesLoader,
    Future<Directory> Function()? baseDirectoryLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       _baseDirectoryLoader = baseDirectoryLoader ?? _defaultPluginDirectory;

  static const String enabledPluginsKey = 'app_enabled_plugins_v1';
  static const String _settingsKeyPrefix = 'app_plugin_settings_v1:';

  final Future<SharedPreferences> Function() _preferencesLoader;
  final Future<Directory> Function() _baseDirectoryLoader;

  final ValueNotifier<List<PluginManifest>> enabledPluginsNotifier =
      ValueNotifier<List<PluginManifest>>(<PluginManifest>[]);
  final ValueNotifier<List<PluginManifest>> discoveredPluginsNotifier =
      ValueNotifier<List<PluginManifest>>(<PluginManifest>[]);
  final ValueNotifier<List<InvalidPluginManifest>> invalidPluginsNotifier =
      ValueNotifier<List<InvalidPluginManifest>>(<InvalidPluginManifest>[]);

  Future<Directory> pluginDirectory() {
    return _baseDirectoryLoader();
  }

  Future<Directory> pluginPrivateDirectory(String pluginId) async {
    final base = await _baseDirectoryLoader();
    final dir = Directory(p.join(base.path, pluginId, 'data'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<PluginManifest>> scan() async {
    final dir = await _baseDirectoryLoader();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final manifests = <PluginManifest>[];
    final invalid = <InvalidPluginManifest>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File(p.join(entity.path, 'plugin.json'));
      if (!await manifestFile.exists()) continue;
      try {
        final raw = await manifestFile.readAsString();
        manifests.add(PluginManifest.parse(raw, baseDirectory: entity.path));
      } catch (error) {
        invalid.add(
          InvalidPluginManifest(
            directoryName: p.basename(entity.path),
            path: manifestFile.path,
            error: error.toString(),
          ),
        );
      }
    }
    discoveredPluginsNotifier.value = manifests;
    invalidPluginsNotifier.value = invalid;
    await _refreshEnabledFrom(manifests);
    return manifests;
  }

  Future<PluginManifest> createExampleMod() async {
    final dir = await _baseDirectoryLoader();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = Directory(p.join(dir.path, 'gueter.example.mod'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    final manifestFile = File(p.join(target.path, 'plugin.json'));
    final readmeFile = File(p.join(target.path, 'README.md'));
    await readmeFile.writeAsString(_exampleReadme);
    await manifestFile.writeAsString(_exampleManifest);
    await scan();
    return PluginManifest.parse(_exampleManifest, baseDirectory: target.path);
  }

  Future<PluginManifest> createFromTemplate(PluginTemplate template) async {
    final dir = await _baseDirectoryLoader();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = Directory(p.join(dir.path, template.directoryName));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    final manifestFile = File(p.join(target.path, 'plugin.json'));
    final readmeFile = File(p.join(target.path, 'README.md'));
    await manifestFile.writeAsString(template.manifestJson());
    await readmeFile.writeAsString(
      template.readme.isEmpty
          ? '# ${template.title}\n\n${template.description}\n'
          : template.readme,
    );
    await scan();
    return PluginManifest.parse(
      template.manifestJson(),
      baseDirectory: target.path,
    );
  }

  Future<Set<String>> enabledPluginIds() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(enabledPluginsKey);
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } catch (_) {
      return <String>{};
    }
    return <String>{};
  }

  Future<void> setPluginEnabled(String pluginId, bool enabled) async {
    final prefs = await _preferencesLoader();
    final ids = await enabledPluginIds();
    if (enabled) {
      ids.add(pluginId);
    } else {
      ids.remove(pluginId);
    }
    await prefs.setString(enabledPluginsKey, jsonEncode(ids.toList()..sort()));
    await _refreshEnabledFrom(discoveredPluginsNotifier.value);
  }

  Future<Map<String, Object?>> pluginSettings(String pluginId) async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString('$_settingsKeyPrefix$pluginId');
    if (raw == null || raw.isEmpty) {
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

  Future<void> setPluginSettings(
    String pluginId,
    Map<String, Object?> settings,
  ) async {
    final prefs = await _preferencesLoader();
    await prefs.setString('$_settingsKeyPrefix$pluginId', jsonEncode(settings));
  }

  Future<Map<String, Object?>> effectivePluginSettings(
    PluginManifest manifest,
  ) async {
    final stored = await pluginSettings(manifest.id);
    final result = <String, Object?>{};
    for (final setting in manifest.settingsSchema) {
      if (stored.containsKey(setting.id)) {
        result[setting.id] = stored[setting.id];
      } else if (setting.defaultValue != null) {
        result[setting.id] = setting.defaultValue;
      }
    }
    return result;
  }

  Future<void> _refreshEnabledFrom(List<PluginManifest> manifests) async {
    final enabledIds = await enabledPluginIds();
    enabledPluginsNotifier.value = manifests
        .where((manifest) => enabledIds.contains(manifest.id))
        .toList();
  }

  static Future<Directory> _defaultPluginDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'plugins'));
  }
}

const String _exampleReadme = '''
# GUETer 示例 Mod

这是一个安全的声明式 Mod 示例。它不会读取账号、Cookie、Token 或云盘凭据。
''';

const String _exampleManifest = '''
{
  "id": "gueter.example.mod",
  "name": {"zh": "GUETer 示例 Mod", "en": "GUETer Example Mod"},
  "version": "1.0.0",
  "author": "GUETer",
  "description": {"zh": "演示工具入口、文件预览动作和健康中心入口。", "en": "Demonstrates tool entries, file preview actions, and health center entry."},
  "capabilities": ["toolEntry"],
  "permissions": ["clipboard", "localFileRead"],
  "entries": [
    {
      "id": "readme",
      "name": {"zh": "Mod 说明", "en": "Mod README"},
      "description": {"zh": "打开本地 Markdown 说明。", "en": "Open local Markdown documentation."},
      "icon": "markdown",
      "slots": ["tool", "command"],
      "action": {"type": "markdownPage", "path": "README.md"}
    },
    {
      "id": "copy-file-path",
      "name": {"zh": "复制文件路径", "en": "Copy File Path"},
      "description": {"zh": "在文件预览页复制当前文件路径。", "en": "Copy current file path from preview."},
      "icon": "copy",
      "slots": ["filePreview"],
      "fileExtensions": [".pdf", ".txt", ".md", ".json", ".csv", ".zip"],
      "action": {"type": "copyText", "text": "{filePath}"}
    },
    {
      "id": "health",
      "name": {"zh": "打开健康中心", "en": "Open Health Center"},
      "description": {"zh": "跳转请求与通知健康中心。", "en": "Open request and notification health center."},
      "icon": "health",
      "slots": ["tool", "health", "command"],
      "action": {"type": "openHealthCenter"}
    }
  ]
}
''';
