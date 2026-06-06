import 'dart:io';

import 'package:flutter/material.dart';

import '../session/app_settings.dart';
import 'plugin_context.dart';
import 'plugin_manifest.dart';
import 'plugin_runtime.dart';

class PluginActionMenuItem {
  const PluginActionMenuItem({required this.manifest, required this.entry});

  final PluginManifest manifest;
  final PluginEntry entry;
}

class PluginActionMenu {
  static List<PluginActionMenuItem> actionsFor(PluginActionContext context) {
    final manifests = AppSettings.pluginStore.enabledPluginsNotifier.value;
    final result = <PluginActionMenuItem>[];
    for (final manifest in manifests) {
      for (final entry in manifest.entries) {
        if (!_matchesContext(entry, context)) continue;
        if (!_matchesPlatform(entry)) continue;
        if (!_matchesFileExtension(entry, context)) continue;
        result.add(PluginActionMenuItem(manifest: manifest, entry: entry));
      }
    }
    return result;
  }

  static List<PopupMenuEntry<PluginActionMenuItem>> popupItems(
    BuildContext context,
    PluginActionContext actionContext,
  ) {
    final actions = actionsFor(actionContext);
    if (actions.isEmpty) {
      return const <PopupMenuEntry<PluginActionMenuItem>>[];
    }
    return <PopupMenuEntry<PluginActionMenuItem>>[
      const PopupMenuDivider(),
      ...actions.map((item) {
        final locale = Localizations.localeOf(context);
        final title = locale.languageCode == 'en'
            ? item.entry.name.en
            : item.entry.name.zh;
        return PopupMenuItem<PluginActionMenuItem>(
          value: item,
          child: ListTile(
            leading: Icon(PluginRuntime.iconFromName(item.entry.icon)),
            title: Text(title),
            subtitle: Text('Mod · ${item.entry.type.id}'),
          ),
        );
      }),
    ];
  }

  static Future<void> run(
    BuildContext context,
    PluginActionMenuItem item,
    PluginActionContext actionContext,
  ) {
    return PluginRuntime.runEntry(
      context,
      item.manifest,
      item.entry,
      actionContext: actionContext,
      filePath: actionContext.filePath,
    );
  }

  static bool _matchesContext(
    PluginEntry entry,
    PluginActionContext actionContext,
  ) {
    if (entry.contexts.isEmpty) return false;
    final type = actionContext.type;
    return type != null && entry.contexts.contains(type);
  }

  static bool _matchesPlatform(PluginEntry entry) {
    return entry.platforms.isEmpty ||
        entry.platforms.contains(Platform.operatingSystem.toLowerCase());
  }

  static bool _matchesFileExtension(
    PluginEntry entry,
    PluginActionContext actionContext,
  ) {
    if (entry.fileExtensions.isEmpty) return true;
    final ext = actionContext.fileExtension;
    return ext.isNotEmpty && entry.fileExtensions.contains(ext);
  }
}
