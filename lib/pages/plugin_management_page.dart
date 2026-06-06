import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../plugins/plugin_manifest.dart';
import '../session/app_settings.dart';

class PluginManagementPage extends StatefulWidget {
  const PluginManagementPage({super.key});

  @override
  State<PluginManagementPage> createState() => _PluginManagementPageState();
}

class _PluginManagementPageState extends State<PluginManagementPage> {
  bool _busy = false;
  Set<String> _enabledIds = <String>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await AppSettings.pluginStore.scan();
    _enabledIds = await AppSettings.pluginStore.enabledPluginIds();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _importPluginDirectory() async {
    final source = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择包含 plugin.json 的插件目录',
    );
    if (source == null || source.isEmpty) return;
    final sourceDir = Directory(source);
    final manifestFile = File(p.join(sourceDir.path, 'plugin.json'));
    if (!await manifestFile.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('所选目录没有 plugin.json')));
      return;
    }
    try {
      final manifest = PluginManifest.parse(
        await manifestFile.readAsString(),
        baseDirectory: sourceDir.path,
      );
      final targetBase = await AppSettings.pluginStore.pluginDirectory();
      final target = Directory(p.join(targetBase.path, manifest.id));
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
      await _copyDirectory(sourceDir, target);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入失败: $e')));
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  Future<void> _openPluginFolder() async {
    final dir = await AppSettings.pluginStore.pluginDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final docs = await getApplicationSupportDirectory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('插件目录: ${dir.path}\n应用支持目录: ${docs.path}')),
    );
  }

  Future<void> _createExampleMod() async {
    setState(() => _busy = true);
    try {
      final manifest = await AppSettings.pluginStore.createExampleMod();
      _enabledIds = await AppSettings.pluginStore.enabledPluginIds();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已生成示例 Mod: ${manifest.id}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openPluginDetail(PluginManifest manifest) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PluginDetailPage(manifest: manifest)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifests = AppSettings.pluginStore.discoveredPluginsNotifier.value;
    final invalidManifests =
        AppSettings.pluginStore.invalidPluginsNotifier.value;
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('插件管理'),
        actions: [
          IconButton(
            tooltip: '生成示例',
            onPressed: _busy ? null : _createExampleMod,
            icon: const Icon(Icons.add_box_outlined),
          ),
          IconButton(
            tooltip: '扫描',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _importPluginDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('导入目录'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openPluginFolder,
                  icon: const Icon(Icons.info_outline),
                  label: const Text('查看目录'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '插件只能声明入口和受控动作，不能读取账号、Cookie、Token 或签到内部状态。启用插件前请确认权限声明。',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (!_busy && manifests.isEmpty && invalidManifests.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('尚未发现插件。导入包含 plugin.json 的目录后再扫描。'),
              ),
            ),
          if (invalidManifests.isNotEmpty) ...[
            Text('无效插件', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...invalidManifests.map((item) {
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.error_outline,
                    color: Colors.orange,
                  ),
                  title: Text(item.directoryName),
                  subtitle: Text('${item.path}\n${item.error}'),
                  isThreeLine: true,
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
          ...manifests.map((manifest) {
            final enabled = _enabledIds.contains(manifest.id);
            final title = locale.languageCode == 'en'
                ? manifest.name.en
                : manifest.name.zh;
            final description = locale.languageCode == 'en'
                ? manifest.description.en
                : manifest.description.zh;
            return Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: enabled,
                    title: Text(title),
                    subtitle: Text(
                      '$description\n${manifest.author} · ${manifest.version}\n'
                      '能力: ${manifest.capabilities.map((item) => item.id).join(', ')}\n'
                      '权限: ${manifest.permissions.map((p) => p.id).join(', ')}',
                    ),
                    isThreeLine: true,
                    onChanged: (value) async {
                      await AppSettings.pluginStore.setPluginEnabled(
                        manifest.id,
                        value,
                      );
                      _enabledIds = await AppSettings.pluginStore
                          .enabledPluginIds();
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        _RiskBadge(manifest: manifest),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _openPluginDetail(manifest),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('详情 / 校验'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  const _RiskBadge({required this.manifest});

  final PluginManifest manifest;

  @override
  Widget build(BuildContext context) {
    final hasNetwork = manifest.permissions.contains(PluginPermission.network);
    final hasFileRead = manifest.permissions.contains(
      PluginPermission.localFileRead,
    );
    final label = hasNetwork && hasFileRead
        ? '中风险'
        : hasNetwork || hasFileRead
        ? '低风险'
        : '基础风险';
    final color = hasNetwork && hasFileRead
        ? Colors.orange
        : Theme.of(context).colorScheme.primary;
    return Chip(
      avatar: Icon(Icons.shield_outlined, size: 18, color: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PluginDetailPage extends StatelessWidget {
  const _PluginDetailPage({required this.manifest});

  final PluginManifest manifest;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final title = locale.languageCode == 'en'
        ? manifest.name.en
        : manifest.name.zh;
    return Scaffold(
      appBar: AppBar(title: Text('$title 校验')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manifest.id,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('作者: ${manifest.author}'),
                  Text('版本: ${manifest.version}'),
                  Text('Manifest: v${manifest.manifestVersion}'),
                  Text('目录: ${manifest.baseDirectory ?? "未知"}'),
                  Text(
                    '插件级能力: ${_joinIds(manifest.capabilities.map((item) => item.id))}',
                  ),
                  Text(
                    '插件权限: ${_joinIds(manifest.permissions.map((item) => item.id))}',
                  ),
                  Text(
                    '允许网络 Host: ${manifest.allowedHosts.isEmpty ? "未限制" : manifest.allowedHosts.join(", ")}',
                  ),
                  Text(
                    '设置项: ${manifest.settingsSchema.isEmpty ? "无" : manifest.settingsSchema.map((item) => item.id).join(", ")}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('入口', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...manifest.entries.map((entry) {
            final entryTitle = locale.languageCode == 'en'
                ? entry.name.en
                : entry.name.zh;
            final slots = entry.effectiveSlots(manifest.capabilities);
            final required = entry.requiresPermissions.isEmpty
                ? '无'
                : entry.requiresPermissions.map((item) => item.id).join(', ');
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_iconForEntry(entry)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entryTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Chip(
                          label: Text(entry.type.id),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          label: '位置',
                          value: _joinIds(slots.map((item) => item.id)),
                        ),
                        _InfoChip(label: '入口权限', value: required),
                        _InfoChip(
                          label: '文件类型',
                          value: entry.fileExtensions.isEmpty
                              ? '不限'
                              : entry.fileExtensions.join(', '),
                        ),
                        _InfoChip(
                          label: '平台',
                          value: entry.platforms.isEmpty
                              ? '不限'
                              : entry.platforms.join(', '),
                        ),
                        _InfoChip(
                          label: '上下文',
                          value: entry.contexts.isEmpty
                              ? '不限'
                              : entry.contexts
                                    .map((item) => item.id)
                                    .join(', '),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _joinIds(Iterable<String> values) {
    final list = values.where((item) => item.trim().isNotEmpty).toList();
    return list.isEmpty ? '无' : list.join(', ');
  }

  static IconData _iconForEntry(PluginEntry entry) {
    return switch (entry.type) {
      PluginActionType.openUrl => Icons.link_outlined,
      PluginActionType.webView => Icons.public_outlined,
      PluginActionType.markdownPage => Icons.article_outlined,
      PluginActionType.httpRequest => Icons.cloud_outlined,
      PluginActionType.copyText => Icons.copy_outlined,
      PluginActionType.route => Icons.alt_route_outlined,
      PluginActionType.previewFile => Icons.preview_outlined,
      PluginActionType.shareText => Icons.ios_share_outlined,
      PluginActionType.shareFile => Icons.file_upload_outlined,
      PluginActionType.openFolder => Icons.folder_open_outlined,
      PluginActionType.openHealthCenter => Icons.health_and_safety_outlined,
      PluginActionType.openDuplicateCleanup => Icons.cleaning_services_outlined,
      PluginActionType.sequence => Icons.playlist_play_outlined,
      PluginActionType.showMessage => Icons.chat_bubble_outline,
      PluginActionType.pickFile => Icons.attach_file_outlined,
      PluginActionType.saveTextFile => Icons.save_outlined,
      PluginActionType.openBuiltinTool => Icons.apps_outlined,
      PluginActionType.sendToLocalTransfer => Icons.send_to_mobile_outlined,
      PluginActionType.openWithFileTool => Icons.build_circle_outlined,
      PluginActionType.copyJsonField => Icons.data_object_outlined,
    };
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text('$label: $value'),
      onPressed: null,
      visualDensity: VisualDensity.compact,
    );
  }
}
