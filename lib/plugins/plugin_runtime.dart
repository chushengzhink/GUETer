import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_all_windows/webview_all_windows.dart';

import '../app_entries/app_entry.dart';
import '../features/openlist/openlist_cloud_page.dart';
import '../pages/duplicate_cleanup_page.dart';
import '../pages/file_preview_page.dart';
import '../services/duplicate_file_scanner.dart';
import '../features/openlist/openlist_offline_package.dart';
import '../features/openlist/openlist_repository.dart';
import '../modules/local_transfer/model/transfer_source_file.dart';
import '../modules/local_transfer/ui/local_transfer_page.dart';
import '../modules/local_transfer/ui/local_transfer_send_page.dart';
import '../pages/file_tools_page.dart';
import '../pages/request_console_page.dart';
import '../pages/study_center_page.dart';
import '../services/file_output_share_service.dart';
import '../services/file_tool_service.dart';
import '../session/app_settings.dart';
import '../study/study_card_store.dart';
import 'plugin_context.dart';
import 'plugin_manifest.dart';

class PluginRuntime {
  static const Set<String> routeWhitelist = <String>{
    '/accounts',
    '/anonymous-chat',
    '/nearby-room',
    '/local-transfer',
    '/reading',
    '/settings',
    '/virtual-lan',
  };

  static List<ToolEntry> buildToolEntries(
    List<PluginManifest> manifests,
    BuildContext context,
  ) {
    final entries = <ToolEntry>[];
    for (final manifest in manifests) {
      for (final entry in manifest.entries) {
        final slots = entry.effectiveSlots(manifest.capabilities);
        if (!slots.contains(PluginSlot.tool) &&
            !slots.contains(PluginSlot.command)) {
          continue;
        }
        if (!_matchesPlatform(entry)) {
          continue;
        }
        entries.add(
          ToolEntry(
            id: 'plugin:${manifest.id}:${entry.id}',
            titleZh: entry.name.zh,
            titleEn: entry.name.en,
            subtitleZh: entry.description.zh,
            subtitleEn: entry.description.en,
            icon: iconFromName(entry.icon),
            color: const Color(0xFF64748B),
            categoryId: 'plugin:${entry.category}',
            categoryZh: '插件',
            categoryEn: '插件',
            categorySubtitleZh: '用户声明式扩展',
            categorySubtitleEn: '用户声明式扩展',
            categoryIcon: Icons.extension_outlined,
            categoryColor: const Color(0xFF64748B),
            tags: entry.tags,
            badge: entry.badge ?? '插件',
            priority: entry.priority,
            onTap: () => runEntry(context, manifest, entry),
          ),
        );
      }
    }
    return entries;
  }

  static Future<void> runEntry(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry, {
    String? filePath,
    PluginActionContext? actionContext,
  }) async {
    _requireEntryPermissions(manifest, entry);
    final resolvedContext =
        actionContext ?? PluginActionContext(filePath: filePath);
    _requireContext(entry, resolvedContext);
    switch (entry.type) {
      case PluginActionType.openUrl:
        _requirePermission(manifest, PluginPermission.openExternalUrl);
        final url = await _applyPlaceholders(
          _requiredActionString(entry, 'url'),
          manifest: manifest,
          actionContext: resolvedContext,
        );
        _validateHttpUrl(url);
        _validateAllowedHost(manifest, url);
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      case PluginActionType.webView:
        _requirePermission(manifest, PluginPermission.embeddedWebView);
        final url = await _applyPlaceholders(
          _requiredActionString(entry, 'url'),
          manifest: manifest,
          actionContext: resolvedContext,
        );
        _validateHttpUrl(url);
        _validateAllowedHost(manifest, url);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PluginWebViewPage(title: entry.name, url: url),
          ),
        );
        return;
      case PluginActionType.markdownPage:
        _requirePermission(manifest, PluginPermission.localFileRead);
        final path = _requiredActionString(entry, 'path');
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PluginMarkdownPage(
              title: entry.name,
              manifest: manifest,
              relativePath: path,
            ),
          ),
        );
        return;
      case PluginActionType.httpRequest:
        _requirePermission(manifest, PluginPermission.network);
        final method = ((entry.action['method'] as String?) ?? 'GET')
            .toUpperCase();
        if (method == 'POST' && entry.action['allowPost'] != true) {
          throw StateError('插件入口 ${entry.id} 使用 POST 时必须设置 allowPost=true。');
        }
        if (method != 'GET' && method != 'POST') {
          throw StateError('插件入口 ${entry.id} 只允许 GET 或 POST。');
        }
        final url = await _applyPlaceholders(
          _requiredActionString(entry, 'url'),
          manifest: manifest,
          actionContext: resolvedContext,
        );
        _validateHttpUrl(url);
        _validateAllowedHost(manifest, url);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PluginHttpResultPage(
              title: entry.name,
              url: url,
              method: method,
            ),
          ),
        );
        return;
      case PluginActionType.copyText:
        _requirePermission(manifest, PluginPermission.clipboard);
        final text = await _applyPlaceholders(
          _requiredActionString(entry, 'text'),
          manifest: manifest,
          actionContext: resolvedContext,
        );
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('插件文本已复制')));
        return;
      case PluginActionType.route:
        final route = _requiredActionString(entry, 'route');
        if (!routeWhitelist.contains(route)) {
          throw StateError('插件路由不在白名单内: $route');
        }
        await Navigator.of(context).pushNamed(route);
        return;
      case PluginActionType.previewFile:
        _requirePermission(manifest, PluginPermission.localFileRead);
        final path = await _resolveFileActionPath(
          entry,
          manifest,
          resolvedContext,
        );
        if (!context.mounted) return;
        await FilePreviewPage.open(context, path);
        return;
      case PluginActionType.shareText:
        final text = await _applyPlaceholders(
          _requiredActionString(entry, 'text'),
          manifest: manifest,
          actionContext: resolvedContext,
        );
        await Share.share(text);
        return;
      case PluginActionType.shareFile:
        _requirePermission(manifest, PluginPermission.localFileRead);
        final path = await _resolveFileActionPath(
          entry,
          manifest,
          resolvedContext,
        );
        await Share.shareXFiles([XFile(path)]);
        return;
      case PluginActionType.openFolder:
        _requirePermission(manifest, PluginPermission.localFileRead);
        final path = await _resolveFileActionPath(
          entry,
          manifest,
          resolvedContext,
        );
        await OpenFilex.open(p.dirname(path));
        return;
      case PluginActionType.openHealthCenter:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RequestConsolePage()));
        return;
      case PluginActionType.openDuplicateCleanup:
        final roots = await _duplicateCleanupRoots(entry);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                DuplicateCleanupPage(title: 'Mod 查重清理', roots: roots),
          ),
        );
        return;
      case PluginActionType.sequence:
        await _runSequence(context, manifest, entry, resolvedContext);
        return;
      case PluginActionType.showMessage:
        await _showMessage(context, manifest, entry, resolvedContext);
        return;
      case PluginActionType.pickFile:
        await _pickFileAndRun(context, manifest, entry, resolvedContext);
        return;
      case PluginActionType.saveTextFile:
        _requirePermission(manifest, PluginPermission.localFileWrite);
        await _saveTextFile(context, manifest, entry, resolvedContext);
        return;
      case PluginActionType.openBuiltinTool:
        await _openBuiltinTool(context, entry);
        return;
      case PluginActionType.sendToLocalTransfer:
        _requirePermission(manifest, PluginPermission.localFileRead);
        await _sendToLocalTransfer(context, manifest, entry, resolvedContext);
        return;
      case PluginActionType.openWithFileTool:
        _requirePermission(manifest, PluginPermission.localFileRead);
        await _openWithFileTool(context, manifest, entry, resolvedContext);
        return;
      case PluginActionType.copyJsonField:
        _requirePermission(manifest, PluginPermission.clipboard);
        await _copyJsonField(context, manifest, entry, resolvedContext);
        return;
    }
  }

  static IconData iconFromName(String icon) {
    return switch (icon) {
      'link' => Icons.link_outlined,
      'web' => Icons.public_outlined,
      'markdown' => Icons.article_outlined,
      'http' => Icons.cloud_outlined,
      'copy' => Icons.copy_outlined,
      'route' => Icons.alt_route_outlined,
      'school' => Icons.school_outlined,
      'tool' => Icons.build_outlined,
      'health' => Icons.health_and_safety_outlined,
      'folder' => Icons.folder_open_outlined,
      'share' => Icons.ios_share_outlined,
      'message' => Icons.chat_bubble_outline,
      'sequence' => Icons.playlist_play_outlined,
      'save' => Icons.save_outlined,
      _ => Icons.extension_outlined,
    };
  }

  static List<PluginBoundEntry> filePreviewActions(
    List<PluginManifest> manifests,
    String filePath,
  ) {
    final result = <PluginBoundEntry>[];
    for (final manifest in manifests) {
      for (final entry in manifest.entries) {
        final slots = entry.effectiveSlots(manifest.capabilities);
        if (!slots.contains(PluginSlot.filePreview)) {
          continue;
        }
        if (!_matchesPlatform(entry) ||
            !_matchesFileExtension(entry, filePath)) {
          continue;
        }
        result.add(PluginBoundEntry(manifest: manifest, entry: entry));
      }
    }
    return result;
  }

  static void _requirePermission(
    PluginManifest manifest,
    PluginPermission permission,
  ) {
    if (!manifest.permissions.contains(permission)) {
      throw StateError('插件 ${manifest.id} 缺少权限 ${permission.id}。');
    }
  }

  static void _requireEntryPermissions(
    PluginManifest manifest,
    PluginEntry entry,
  ) {
    for (final permission in entry.requiresPermissions) {
      _requirePermission(manifest, permission);
    }
  }

  static void _requireContext(
    PluginEntry entry,
    PluginActionContext actionContext,
  ) {
    if (entry.contexts.isEmpty) return;
    final type = actionContext.type;
    if (type == null || !entry.contexts.contains(type)) {
      throw StateError('插件入口 ${entry.id} 不支持当前上下文。');
    }
  }

  static String _requiredActionString(PluginEntry entry, String key) {
    final value = entry.action[key];
    if (value is! String || value.trim().isEmpty) {
      throw StateError('插件入口 ${entry.id} 缺少 action.$key。');
    }
    return value.trim();
  }

  static Future<String> _applyPlaceholders(
    String value, {
    PluginManifest? manifest,
    PluginActionContext? actionContext,
  }) async {
    final resolvedFilePath = actionContext?.filePath ?? '';
    final fileName =
        actionContext?.resolvedFileName ??
        (resolvedFilePath.isEmpty ? '' : p.basename(resolvedFilePath));
    final fileExt =
        actionContext?.fileExtension ??
        (resolvedFilePath.isEmpty
            ? ''
            : p.extension(resolvedFilePath).toLowerCase());
    final fileSize = actionContext?.fileSize?.toString() ?? '';
    final contextText = actionContext?.text ?? '';
    String appVersion = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      appVersion = '';
    }
    final settings = manifest == null
        ? const <String, Object?>{}
        : await AppSettings.pluginStore.effectivePluginSettings(manifest);
    var output = value
        .replaceAll('{filePath}', resolvedFilePath)
        .replaceAll(
          '{fileUri}',
          resolvedFilePath.isEmpty ? '' : Uri.file(resolvedFilePath).toString(),
        )
        .replaceAll('{fileName}', fileName)
        .replaceAll('{fileExt}', fileExt)
        .replaceAll('{fileSize}', fileSize)
        .replaceAll('{text}', contextText)
        .replaceAll('{appVersion}', appVersion)
        .replaceAll('{platform}', Platform.operatingSystem);
    for (final item in settings.entries) {
      output = output.replaceAll(
        '{setting.${item.key}}',
        '${item.value ?? ''}',
      );
    }
    for (final item
        in actionContext?.values.entries ??
            const Iterable<MapEntry<String, Object?>>.empty()) {
      output = output.replaceAll(
        '{context.${item.key}}',
        '${item.value ?? ''}',
      );
    }
    return output;
  }

  static Future<String> applyPlaceholdersForTests(
    String value, {
    String? filePath,
  }) async {
    return _applyPlaceholders(
      value,
      actionContext: PluginActionContext(filePath: filePath),
    );
  }

  static void _validateHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw StateError('插件 URL 只允许 http/https。');
    }
  }

  static void _validateAllowedHost(PluginManifest manifest, String value) {
    if (manifest.allowedHosts.isEmpty) return;
    final host = Uri.parse(value).host.toLowerCase();
    if (!manifest.allowedHosts.contains(host)) {
      throw StateError('插件 ${manifest.id} 不允许访问 host: $host。');
    }
  }

  static void validateAllowedHostForTests(
    PluginManifest manifest,
    String value,
  ) {
    _validateAllowedHost(manifest, value);
  }

  static Future<String> _resolveFileActionPath(
    PluginEntry entry,
    PluginManifest manifest,
    PluginActionContext actionContext,
  ) async {
    final explicit = entry.action['path'];
    final rawPath = explicit is String && explicit.trim().isNotEmpty
        ? await _applyPlaceholders(
            explicit.trim(),
            manifest: manifest,
            actionContext: actionContext,
          )
        : (actionContext.filePath ?? '');
    if (rawPath.trim().isEmpty) {
      throw StateError('插件入口 ${entry.id} 缺少文件路径。');
    }
    final normalized = p.normalize(rawPath);
    final baseDirectory = manifest.baseDirectory;
    final currentFilePath = actionContext.filePath == null
        ? null
        : p.normalize(actionContext.filePath!);
    final allowedByContext =
        currentFilePath != null && p.equals(normalized, currentFilePath);
    final allowedByPluginDir =
        baseDirectory != null && p.isWithin(baseDirectory, normalized);
    if (!allowedByContext && !allowedByPluginDir) {
      throw StateError('插件文件路径不在允许范围内。');
    }
    return normalized;
  }

  static bool _matchesFileExtension(PluginEntry entry, String filePath) {
    if (entry.fileExtensions.isEmpty) {
      return true;
    }
    final ext = p.extension(filePath).toLowerCase();
    return entry.fileExtensions.contains(ext);
  }

  static bool _matchesPlatform(PluginEntry entry) {
    if (entry.platforms.isEmpty) {
      return true;
    }
    return entry.platforms.contains(Platform.operatingSystem.toLowerCase());
  }

  static Future<void> _runSequence(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry,
    PluginActionContext actionContext,
  ) async {
    final rawSteps = entry.action['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      throw StateError('sequence 动作必须提供非空 steps。');
    }
    for (var index = 0; index < rawSteps.length; index++) {
      if (!context.mounted) return;
      final raw = rawSteps[index];
      if (raw is! Map) {
        throw StateError('sequence.steps[$index] 必须是对象。');
      }
      final step = _entryFromActionMap(entry, raw, suffix: 'step-$index');
      await runEntry(context, manifest, step, actionContext: actionContext);
    }
  }

  static PluginEntry _entryFromActionMap(
    PluginEntry parent,
    Map<dynamic, dynamic> raw, {
    required String suffix,
  }) {
    final action = raw.map((key, value) => MapEntry(key.toString(), value));
    final typeValue = action['type'];
    if (typeValue is! String || PluginActionType.fromId(typeValue) == null) {
      throw StateError('sequence 子动作缺少有效 type。');
    }
    return PluginEntry(
      id: '${parent.id}.$suffix',
      name: parent.name,
      description: parent.description,
      type: PluginActionType.fromId(typeValue)!,
      action: action,
      icon: parent.icon,
      category: parent.category,
      tags: parent.tags,
      slots: parent.slots,
      fileExtensions: parent.fileExtensions,
      platforms: parent.platforms,
      requiresPermissions: const <PluginPermission>[],
      contexts: parent.contexts,
      badge: parent.badge,
      priority: parent.priority,
    );
  }

  static Future<void> _showMessage(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry,
    PluginActionContext actionContext,
  ) async {
    final text = await _applyPlaceholders(
      _requiredActionString(entry, 'text'),
      manifest: manifest,
      actionContext: actionContext,
    );
    final mode = entry.action['mode']?.toString() ?? 'snackbar';
    if (!context.mounted) return;
    if (mode == 'dialog') {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Mod 消息'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static Future<void> _pickFileAndRun(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry,
    PluginActionContext actionContext,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null || path.isEmpty) return;
    final stat = await File(path).stat();
    final next = actionContext.copyWithFile(
      path,
      name: p.basename(path),
      size: stat.size,
    );
    final nextAction = entry.action['then'];
    if (nextAction is! Map) {
      return;
    }
    if (!context.mounted) return;
    await runEntry(
      context,
      manifest,
      _entryFromActionMap(entry, nextAction, suffix: 'picked'),
      actionContext: next,
    );
  }

  static Future<void> _saveTextFile(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry,
    PluginActionContext actionContext,
  ) async {
    final text = await _applyPlaceholders(
      _requiredActionString(entry, 'text'),
      manifest: manifest,
      actionContext: actionContext,
    );
    final fileName = (entry.action['fileName'] as String?)?.trim();
    final resolvedName = fileName?.isNotEmpty == true
        ? await _applyPlaceholders(
            fileName!,
            manifest: manifest,
            actionContext: actionContext,
          )
        : 'mod_${DateTime.now().millisecondsSinceEpoch}.txt';
    final target = await _resolveWritablePath(entry, manifest, resolvedName);
    await File(target).writeAsString(text, flush: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已保存：${p.basename(target)}')));
  }

  static Future<String> _resolveWritablePath(
    PluginEntry entry,
    PluginManifest manifest,
    String fileName,
  ) async {
    final safeName = p.basename(fileName).trim();
    if (safeName.isEmpty || safeName.contains('..')) {
      throw StateError('saveTextFile 文件名无效。');
    }
    final scope = entry.action['scope']?.toString() ?? 'pluginPrivate';
    if (scope != 'pluginPrivate') {
      throw StateError('saveTextFile 当前只允许写入插件私有目录。');
    }
    final dir = await AppSettings.pluginStore.pluginPrivateDirectory(
      manifest.id,
    );
    return p.join(dir.path, safeName);
  }

  static Future<void> _openBuiltinTool(
    BuildContext context,
    PluginEntry entry,
  ) async {
    final id = _requiredActionString(entry, 'tool');
    final Widget page = switch (id) {
      'fileTools' => const FileToolsPage(),
      'localTransfer' => const LocalTransferPage(),
      'cloud' => const OpenListCloudPage(),
      'health' => const RequestConsolePage(),
      'studyCards' => const StudyCenterPage(),
      _ => throw StateError('不支持的内置工具: $id'),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  static Future<void> _sendToLocalTransfer(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry,
    PluginActionContext actionContext,
  ) async {
    final path = await _resolveFileActionPath(entry, manifest, actionContext);
    final source = await TransferSourceFile.fromLocalPath(path);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalTransferSendPage(
          files: [source],
          sourceLabel: 'Mod：${entry.name.zh}',
        ),
      ),
    );
  }

  static Future<void> _openWithFileTool(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry,
    PluginActionContext actionContext,
  ) async {
    final mode = entry.action['toolAction']?.toString() ?? 'preview';
    final path = await _resolveFileActionPath(entry, manifest, actionContext);
    switch (mode) {
      case 'preview':
        if (!context.mounted) return;
        await FilePreviewPage.open(context, path);
        return;
      case 'share':
        await FileOutputShareService().shareOutput(path, text: entry.name.zh);
        return;
      case 'duplicateCleanup':
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DuplicateCleanupPage(
              title: 'Mod 文件查重',
              roots: [DuplicateScanRoot(label: '当前目录', path: p.dirname(path))],
            ),
          ),
        );
        return;
      case 'studyCard':
        await StudyCardStore().addCard(
          front: p.basename(path),
          back: '来自本地文件：${p.basename(path)}',
          sourceFileName: p.basename(path),
          sourcePath: path,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已生成复习卡片')));
        return;
      default:
        throw StateError('不支持的文件工具动作: $mode');
    }
  }

  static Future<void> _copyJsonField(
    BuildContext context,
    PluginManifest manifest,
    PluginEntry entry,
    PluginActionContext actionContext,
  ) async {
    final source = await _applyPlaceholders(
      _requiredActionString(entry, 'json'),
      manifest: manifest,
      actionContext: actionContext,
    );
    final field = _requiredActionString(entry, 'field');
    final decoded = jsonDecode(source);
    Object? value = decoded;
    for (final segment in field.split('.')) {
      if (value is Map && value.containsKey(segment)) {
        value = value[segment];
      } else {
        throw StateError('JSON 字段不存在: $field');
      }
    }
    await Clipboard.setData(ClipboardData(text: '${value ?? ''}'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON 字段已复制')));
  }

  static Future<List<DuplicateScanRoot>> _duplicateCleanupRoots(
    PluginEntry entry,
  ) async {
    final scope = entry.action['scope']?.toString() ?? 'downloads';
    switch (scope) {
      case 'downloads':
        return <DuplicateScanRoot>[
          DuplicateScanRoot(
            label: '云盘下载',
            path: await OpenListRepository.downloadDirectoryPath(),
          ),
        ];
      case 'offlinePackages':
        final dir =
            await OpenListOfflinePackageService.ensureOfflineRootDirectory();
        return <DuplicateScanRoot>[
          DuplicateScanRoot(label: '云盘离线包', path: dir.path),
        ];
      case 'fileTools':
        final dir = await FileToolService().ensureOutputDirectory();
        return <DuplicateScanRoot>[
          DuplicateScanRoot(label: '文件工具输出', path: dir.path),
        ];
      default:
        throw StateError('openDuplicateCleanup 只允许内置白名单目录。');
    }
  }
}

class PluginBoundEntry {
  const PluginBoundEntry({required this.manifest, required this.entry});

  final PluginManifest manifest;
  final PluginEntry entry;
}

class PluginMarkdownPage extends StatelessWidget {
  const PluginMarkdownPage({
    super.key,
    required this.title,
    required this.manifest,
    required this.relativePath,
  });

  final PluginLocalizedText title;
  final PluginManifest manifest;
  final String relativePath;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final pageTitle = locale.languageCode == 'en' ? title.en : title.zh;
    final baseDirectory = manifest.baseDirectory;
    final filePath = baseDirectory == null
        ? ''
        : p.normalize(p.join(baseDirectory, relativePath));
    final allowed =
        baseDirectory != null &&
        p.isWithin(baseDirectory, filePath) &&
        p.extension(filePath).toLowerCase() == '.md';

    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: !allowed
          ? const Center(child: Text('插件 Markdown 路径无效'))
          : FutureBuilder<String>(
              future: File(filePath).readAsString(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('读取失败: ${snapshot.error}'));
                }
                return Markdown(
                  data: snapshot.data ?? '',
                  padding: const EdgeInsets.all(16),
                );
              },
            ),
    );
  }
}

class PluginWebViewPage extends StatefulWidget {
  const PluginWebViewPage({super.key, required this.title, required this.url});

  final PluginLocalizedText title;
  final String url;

  @override
  State<PluginWebViewPage> createState() => _PluginWebViewPageState();
}

class _PluginWebViewPageState extends State<PluginWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _init();
  }

  Future<void> _init() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      WebViewPlatform.instance = WindowsWebViewPlatform();
    }
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => _loading = false);
        },
      ),
    );
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final pageTitle = locale.languageCode == 'en'
        ? widget.title.en
        : widget.title.zh;
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class PluginHttpResultPage extends StatefulWidget {
  const PluginHttpResultPage({
    super.key,
    required this.title,
    required this.url,
    required this.method,
  });

  final PluginLocalizedText title;
  final String url;
  final String method;

  @override
  State<PluginHttpResultPage> createState() => _PluginHttpResultPageState();
}

class _PluginHttpResultPageState extends State<PluginHttpResultPage> {
  late final Future<String> _resultFuture = _request();

  Future<String> _request() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final method = widget.method.toUpperCase();
    final response = method == 'POST'
        ? await dio.post(widget.url)
        : await dio.get(widget.url);
    final data = response.data;
    if (data is String) return data;
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final pageTitle = locale.languageCode == 'en'
        ? widget.title.en
        : widget.title.zh;
    return Scaffold(
      appBar: AppBar(title: Text(pageTitle)),
      body: FutureBuilder<String>(
        future: _resultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final text = snapshot.hasError
              ? '请求失败: ${snapshot.error}'
              : snapshot.data ?? '';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(text),
          );
        },
      ),
    );
  }
}
