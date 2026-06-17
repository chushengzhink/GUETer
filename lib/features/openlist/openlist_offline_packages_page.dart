import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../modules/local_transfer/model/transfer_source_file.dart';
import '../../modules/local_transfer/ui/local_transfer_send_page.dart';
import '../../pages/duplicate_cleanup_page.dart';
import '../../pages/file_preview_page.dart';
import '../../plugins/plugin_action_menu.dart';
import '../../plugins/plugin_context.dart';
import '../../plugins/plugin_manifest.dart';
import '../../services/duplicate_file_scanner.dart';
import 'openlist_offline_package.dart';

class OpenListOfflinePackagesPage extends StatefulWidget {
  const OpenListOfflinePackagesPage({super.key, this.service});

  final OpenListOfflinePackageService? service;

  @override
  State<OpenListOfflinePackagesPage> createState() =>
      _OpenListOfflinePackagesPageState();
}

class _OpenListOfflinePackagesPageState
    extends State<OpenListOfflinePackagesPage> {
  late final OpenListOfflinePackageService _service;
  final TextEditingController _queryController = TextEditingController();
  List<OpenListOfflinePackage> _packages = const <OpenListOfflinePackage>[];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OpenListOfflinePackageService();
    unawaited(_load());
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final packages = await _service.loadPackages();
    if (!mounted) {
      return;
    }
    setState(() {
      _packages = packages;
      _loading = false;
    });
  }

  Future<void> _check(OpenListOfflinePackage package) async {
    final updated = await _service.checkPackage(package);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated.hasMissingFiles || updated.hasRemoteChanges
              ? '已校验：存在缺失或远端变化'
              : '已校验：离线包可用',
        ),
      ),
    );
    await _load();
  }

  Future<void> _delete(OpenListOfflinePackage package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除离线包'),
        content: Text('确认删除“${package.name}”的本地缓存？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _service.deletePackage(package);
    await _load();
  }

  Future<void> _sendPackage(OpenListOfflinePackage package) async {
    final files = <TransferSourceFile>[];
    for (final file in package.files) {
      if (await File(file.localPath).exists()) {
        files.add(
          await TransferSourceFile.fromLocalPath(
            file.localPath,
            fileName: file.name,
          ),
        );
      }
    }
    if (!mounted) {
      return;
    }
    if (files.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('离线包内没有可发送的文件')));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalTransferSendPage(
          files: files,
          sourceLabel: '云盘离线包：${package.name}',
        ),
      ),
    );
  }

  Future<void> _runModAction(
    OpenListOfflinePackage package,
    PluginActionMenuItem action,
  ) async {
    try {
      final firstExisting = package.files
          .where((file) => File(file.localPath).existsSync())
          .cast<OpenListOfflineFile?>()
          .firstOrNull;
      await PluginActionMenu.run(
        context,
        action,
        PluginActionContext(
          type: PluginContextType.offlinePackage,
          filePath: firstExisting?.localPath,
          fileName: package.name,
          fileSize: package.totalSize,
          isDirectory: true,
          values: <String, Object?>{
            'remotePath': package.remotePath,
            'fileCount': package.fileCount,
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mod 执行失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePackages = _packages.where((package) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return package.name.toLowerCase().contains(query) ||
          package.remotePath.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('云盘离线包'),
        actions: [
          IconButton(
            onPressed: _openDuplicateCleanup,
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '查重清理',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _queryController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: '搜索离线包',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _queryController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: '清空搜索',
                      ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visiblePackages.isEmpty
                ? const Center(child: Text('还没有离线包'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: visiblePackages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final package = visiblePackages[index];
                      return _OfflinePackageTile(
                        package: package,
                        onOpen: () => _openPackage(package),
                        onCheck: () => _check(package),
                        onSend: () => _sendPackage(package),
                        onDelete: () => _delete(package),
                        modItems: PluginActionMenu.popupItems(
                          context,
                          PluginActionContext(
                            type: PluginContextType.offlinePackage,
                            fileName: package.name,
                            fileSize: package.totalSize,
                            isDirectory: true,
                            values: <String, Object?>{
                              'remotePath': package.remotePath,
                              'fileCount': package.fileCount,
                            },
                          ),
                        ),
                        onModAction: (action) => _runModAction(package, action),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPackage(OpenListOfflinePackage package) async {
    final firstExisting = package.files.cast<OpenListOfflineFile?>().firstWhere(
      (file) => file != null && File(file.localPath).existsSync(),
      orElse: () => null,
    );
    final path = firstExisting?.localPath ?? package.localPath;
    await FilePreviewPage.open(context, path, title: package.name);
  }

  Future<void> _openDuplicateCleanup() async {
    final root =
        await OpenListOfflinePackageService.ensureOfflineRootDirectory();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuplicateCleanupPage(
          title: '离线包查重清理',
          roots: [DuplicateScanRoot(label: '云盘离线包', path: root.path)],
        ),
      ),
    );
  }
}

class _OfflinePackageTile extends StatelessWidget {
  const _OfflinePackageTile({
    required this.package,
    required this.onOpen,
    required this.onCheck,
    required this.onSend,
    required this.onDelete,
    required this.modItems,
    required this.onModAction,
  });

  final OpenListOfflinePackage package;
  final VoidCallback onOpen;
  final VoidCallback onCheck;
  final VoidCallback onSend;
  final VoidCallback onDelete;
  final List<PopupMenuEntry<PluginActionMenuItem>> modItems;
  final ValueChanged<PluginActionMenuItem> onModAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = package.hasMissingFiles || package.hasRemoteChanges;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: warning
                      ? scheme.errorContainer
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  warning
                      ? Icons.sync_problem_rounded
                      : Icons.inventory_2_outlined,
                  color: warning
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${package.fileCount} 个文件 · ${_formatSize(package.totalSize)} · ${warning ? '需校验/更新' : '可离线打开'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<Object>(
                tooltip: '离线包操作',
                onSelected: (action) {
                  if (action is PluginActionMenuItem) {
                    onModAction(action);
                    return;
                  }
                  if (action is _OfflinePackageAction) {
                    switch (action) {
                      case _OfflinePackageAction.open:
                        onOpen();
                      case _OfflinePackageAction.check:
                        onCheck();
                      case _OfflinePackageAction.send:
                        onSend();
                      case _OfflinePackageAction.delete:
                        onDelete();
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _OfflinePackageAction.open,
                    child: ListTile(
                      leading: Icon(Icons.folder_open_outlined),
                      title: Text('打开'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _OfflinePackageAction.check,
                    child: ListTile(
                      leading: Icon(Icons.fact_check_outlined),
                      title: Text('刷新校验'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _OfflinePackageAction.send,
                    child: ListTile(
                      leading: Icon(Icons.send_to_mobile_outlined),
                      title: Text('局域网分发'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _OfflinePackageAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('删除本地包'),
                    ),
                  ),
                  ...modItems,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OfflinePackageAction { open, check, send, delete }

String _formatSize(int size) {
  if (size < 1024) {
    return '$size B';
  }
  final kb = size / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}
