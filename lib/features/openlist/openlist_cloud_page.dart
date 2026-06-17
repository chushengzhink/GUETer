import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/async/app_async_state.dart';
import '../../modules/local_transfer/model/transfer_source_file.dart';
import '../../modules/local_transfer/ui/local_transfer_send_page.dart';
import '../../pages/file_preview_page.dart';
import '../../plugins/plugin_action_menu.dart';
import '../../plugins/plugin_context.dart';
import '../../plugins/plugin_manifest.dart';
import 'openlist_controller.dart';
import 'openlist_models.dart';
import 'openlist_offline_packages_page.dart';
import 'openlist_repository.dart';

class OpenListCloudPage extends StatefulWidget {
  const OpenListCloudPage({super.key, this.controller});

  final OpenListController? controller;

  @override
  State<OpenListCloudPage> createState() => _OpenListCloudPageState();
}

class _OpenListCloudPageState extends State<OpenListCloudPage> {
  late final OpenListController _controller;
  late final bool _ownsController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? OpenListController();
    _ownsController = widget.controller == null;
    _searchController = TextEditingController();
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.load();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_searchController.text != _controller.query) {
      _searchController.text = _controller.query;
    }
    setState(() {});
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final paths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      return;
    }

    try {
      await _controller.uploadFiles(paths);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('上传完成')));
    } catch (error) {
      if (!mounted) return;
      final message = friendlyOpenListUploadError(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openFile(OpenListFileItem item) async {
    try {
      final path = await _controller.downloadFile(item);
      if (!mounted) return;
      await FilePreviewPage.open(context, path, title: item.name);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败：$error')));
    }
  }

  Future<void> _copyRawUrl(OpenListFileItem item) async {
    try {
      final rawUrl = await _controller.resolveRawUrl(item);
      await Clipboard.setData(ClipboardData(text: rawUrl));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制直链')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('复制直链失败：$error')));
    }
  }

  Future<void> _shareFile(OpenListFileItem item) async {
    try {
      final path = await _controller.downloadFile(item);
      await Share.shareXFiles([XFile(path)], text: item.name);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败：$error')));
    }
  }

  Future<void> _sendToLocalNetwork(OpenListFileItem item) async {
    try {
      final path = await _controller.localPathForFile(item);
      final sourceFile = await TransferSourceFile.fromLocalPath(
        path,
        fileName: item.name,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LocalTransferSendPage(
            files: [sourceFile],
            sourceLabel: '云盘文件：${item.name}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('局域网发送准备失败：$error')));
    }
  }

  Future<void> _runModAction(
    OpenListFileItem item,
    PluginActionMenuItem action,
  ) async {
    try {
      final path = item.isDir ? null : await _controller.localPathForFile(item);
      if (!mounted) return;
      await PluginActionMenu.run(
        context,
        action,
        PluginActionContext(
          type: PluginContextType.cloudFile,
          filePath: path,
          fileName: item.name,
          fileSize: item.size,
          isDirectory: item.isDir,
          values: <String, Object?>{
            'remotePath': _joinRemotePath(_controller.currentPath, item.name),
            'isDirectory': item.isDir,
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

  Future<void> _saveOffline(OpenListFileItem item) async {
    try {
      await _controller.saveOfflinePackage(item);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已离线保存：${item.name}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('离线保存失败：$error')));
    }
  }

  Future<void> _saveCurrentDirectoryOffline() async {
    try {
      await _controller.saveCurrentDirectoryOffline();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前目录已保存为离线包')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('离线保存失败：$error')));
    }
  }

  Future<void> _openOfflinePackages() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OpenListOfflinePackagesPage()),
    );
  }

  Future<void> _createOpenListShare(OpenListFileItem item) async {
    try {
      final url = await _controller.createShare(item);
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制分享链接')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建分享链接失败：$error')));
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => const _CreateFolderDialog(),
    );
    if (folderName == null || folderName.trim().isEmpty) {
      return;
    }

    try {
      await _controller.createFolder(folderName);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('文件夹已创建')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('新建文件夹失败：$error')));
    }
  }

  Future<void> _openDownloadDirectory() async {
    try {
      final path = await _controller.downloadDirectoryPath();
      final result = await OpenFilex.open(path);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isEmpty ? '无法打开下载目录' : result.message),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开下载目录失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy =
        _controller.uploading ||
        _controller.downloading ||
        _controller.offlineSaving;
    return Scaffold(
      appBar: AppBar(
        title: const Text('云盘共享'),
        actions: [
          IconButton(
            tooltip: '打开下载目录',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: busy ? null : _openDownloadDirectory,
          ),
          IconButton(
            tooltip: '离线包',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: busy ? null : _openOfflinePackages,
          ),
          IconButton(
            tooltip: '保存当前目录',
            icon: const Icon(Icons.offline_pin_outlined),
            onPressed: busy ? null : _saveCurrentDirectoryOffline,
          ),
          if (_controller.canUpload)
            IconButton(
              tooltip: '上传',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: busy ? null : _pickAndUpload,
            ),
          if (_controller.canCreateFolder)
            IconButton(
              tooltip: '新建文件夹',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: busy ? null : _showCreateFolderDialog,
            ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: busy ? null : _controller.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _CloudHeader(controller: _controller),
          if (busy || _controller.transferMessage.isNotEmpty)
            _TransferStrip(controller: _controller),
          _CloudToolbar(
            controller: _controller,
            searchController: _searchController,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final state = _controller.state;
    final listing = state.data;
    if (state.status == AppAsyncStatus.loading && listing == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError && listing == null) {
      return _CloudErrorState(
        message: state.error.toString(),
        onRetry: () => _controller.load(path: _controller.currentPath),
      );
    }

    if (listing == null) {
      return const SizedBox.shrink();
    }
    final items = _controller.visibleItems;

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 120), _CloudEmptyState()],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _CloudFileTile(
                  item: item,
                  onTap: item.isDir
                      ? () => _controller.openFolder(item)
                      : () => _openFile(item),
                  onOpen: item.isDir ? null : () => _openFile(item),
                  onEnterFolder: item.isDir
                      ? () => _controller.openFolder(item)
                      : null,
                  onCopyLink: item.isDir ? null : () => _copyRawUrl(item),
                  onCreateShare: _controller.canCreateShare
                      ? () => _createOpenListShare(item)
                      : null,
                  onShare: item.isDir ? null : () => _shareFile(item),
                  onSaveOffline: () => _saveOffline(item),
                  onLocalSend: item.isDir
                      ? null
                      : () => _sendToLocalNetwork(item),
                  modItems: PluginActionMenu.popupItems(
                    context,
                    PluginActionContext(
                      type: PluginContextType.cloudFile,
                      fileName: item.name,
                      fileSize: item.size,
                      isDirectory: item.isDir,
                      values: <String, Object?>{
                        'remotePath': _joinRemotePath(
                          _controller.currentPath,
                          item.name,
                        ),
                        'isDirectory': item.isDir,
                      },
                    ),
                  ),
                  onModAction: (action) => _runModAction(item, action),
                );
              },
            ),
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建文件夹'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '文件夹名称',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('创建'),
        ),
      ],
    );
  }
}

class _CloudHeader extends StatelessWidget {
  const _CloudHeader({required this.controller});

  final OpenListController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = controller.session;
    final modeLabel = session?.isReadWrite == true ? '读写' : '只读';
    final usernameLabel = session?.username ?? '连接中';
    final accessMessage = controller.canUpload
        ? '已登录畅课，可上传文件。'
        : '未登录畅课时仅可浏览和下载；登录畅课后可上传文件。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.breadcrumbPaths.map((path) {
              final selected = path == controller.currentPath;
              return ActionChip(
                avatar: Icon(
                  path == '/' ? Icons.home_outlined : Icons.folder_outlined,
                  size: 16,
                ),
                label: Text(OpenListRepository.displayNameForPath(path)),
                onPressed: selected ? null : () => controller.goToPath(path),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusPill(label: usernameLabel, icon: Icons.person_outline),
              const SizedBox(width: 8),
              _StatusPill(label: modeLabel, icon: Icons.verified_user_outlined),
              const SizedBox(width: 8),
              ...controller.capabilityLabels.expand(
                (label) => [
                  _StatusPill(label: label, icon: Icons.cloud_queue),
                  const SizedBox(width: 8),
                ],
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  controller.currentPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _CloudAccessNotice(message: accessMessage),
        ],
      ),
    );
  }
}

class _CloudAccessNotice extends StatelessWidget {
  const _CloudAccessNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '云盘需要连接校园网或校园 VPN 才能访问。$message',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudToolbar extends StatelessWidget {
  const _CloudToolbar({
    required this.controller,
    required this.searchController,
  });

  final OpenListController controller;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: controller.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜索当前目录',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          searchController.clear();
                          controller.setQuery('');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<OpenListSortKey>(
            tooltip: '排序',
            initialValue: controller.sortKey,
            onSelected: controller.setSort,
            itemBuilder: (context) => const [
              PopupMenuItem(value: OpenListSortKey.name, child: Text('按名称')),
              PopupMenuItem(value: OpenListSortKey.type, child: Text('按类型')),
              PopupMenuItem(value: OpenListSortKey.size, child: Text('按大小')),
              PopupMenuItem(
                value: OpenListSortKey.modified,
                child: Text('按修改时间'),
              ),
            ],
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    controller.sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(_sortLabel(controller.sortKey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferStrip extends StatelessWidget {
  const _TransferStrip({required this.controller});

  final OpenListController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      color: scheme.primaryContainer.withValues(alpha: 0.65),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.transferMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
          if (controller.transferProgress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: controller.transferProgress),
          ],
        ],
      ),
    );
  }
}

class _CloudFileTile extends StatelessWidget {
  const _CloudFileTile({
    required this.item,
    required this.onTap,
    required this.onOpen,
    required this.onEnterFolder,
    required this.onCopyLink,
    required this.onCreateShare,
    required this.onShare,
    required this.onSaveOffline,
    required this.onLocalSend,
    required this.modItems,
    required this.onModAction,
  });

  final OpenListFileItem item;
  final VoidCallback onTap;
  final VoidCallback? onOpen;
  final VoidCallback? onEnterFolder;
  final VoidCallback? onCopyLink;
  final VoidCallback? onCreateShare;
  final VoidCallback? onShare;
  final VoidCallback? onSaveOffline;
  final VoidCallback? onLocalSend;
  final List<PopupMenuEntry<PluginActionMenuItem>> modItems;
  final ValueChanged<PluginActionMenuItem> onModAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = item.isDir
        ? const Color(0xFF0D9488)
        : const Color(0xFF2563EB);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.isDir
                      ? Icons.folder_rounded
                      : Icons.insert_drive_file_outlined,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.isDir
                          ? _formatDate(item.modified)
                          : '${_formatSize(item.size)} · ${_formatDate(item.modified)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isDir)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    PopupMenuButton<Object>(
                      tooltip: '文件夹操作',
                      onSelected: (action) {
                        if (action is PluginActionMenuItem) {
                          onModAction(action);
                          return;
                        }
                        final callback = action is _FileAction
                            ? switch (action) {
                                _FileAction.open => onEnterFolder,
                                _FileAction.saveOffline => onSaveOffline,
                                _ => null,
                              }
                            : null;
                        callback?.call();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _FileAction.open,
                          child: ListTile(
                            leading: Icon(Icons.folder_open_outlined),
                            title: Text('进入文件夹'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _FileAction.saveOffline,
                          child: ListTile(
                            leading: Icon(Icons.offline_pin_outlined),
                            title: Text('离线保存文件夹'),
                          ),
                        ),
                        ...modItems,
                      ],
                    ),
                  ],
                )
              else
                PopupMenuButton<Object>(
                  tooltip: '文件操作',
                  onSelected: (action) {
                    if (action is PluginActionMenuItem) {
                      onModAction(action);
                      return;
                    }
                    final callback = action is _FileAction
                        ? switch (action) {
                            _FileAction.open => onOpen,
                            _FileAction.copyLink => onCopyLink,
                            _FileAction.createShare => onCreateShare,
                            _FileAction.share => onShare,
                            _FileAction.saveOffline => onSaveOffline,
                            _FileAction.localSend => onLocalSend,
                          }
                        : null;
                    callback?.call();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _FileAction.open,
                      child: ListTile(
                        leading: Icon(Icons.download_rounded),
                        title: Text('下载并打开'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _FileAction.copyLink,
                      child: ListTile(
                        leading: Icon(Icons.link_rounded),
                        title: Text('复制直链'),
                      ),
                    ),
                    if (onCreateShare != null)
                      const PopupMenuItem(
                        value: _FileAction.createShare,
                        child: ListTile(
                          leading: Icon(Icons.cloud_sync_outlined),
                          title: Text('创建分享链接'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: _FileAction.share,
                      child: ListTile(
                        leading: Icon(Icons.ios_share_outlined),
                        title: Text('分享文件'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _FileAction.saveOffline,
                      child: ListTile(
                        leading: Icon(Icons.offline_pin_outlined),
                        title: Text('离线保存'),
                      ),
                    ),
                    if (onLocalSend != null)
                      const PopupMenuItem(
                        value: _FileAction.localSend,
                        child: ListTile(
                          leading: Icon(Icons.send_to_mobile_outlined),
                          title: Text('局域网发送'),
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

enum _FileAction { open, copyLink, createShare, share, saveOffline, localSend }

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudEmptyState extends StatelessWidget {
  const _CloudEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 46,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text('当前目录为空'),
        ],
      ),
    );
  }
}

class _CloudErrorState extends StatelessWidget {
  const _CloudErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              '请先确认已连接校园网或校园 VPN。',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

String _sortLabel(OpenListSortKey key) {
  return switch (key) {
    OpenListSortKey.name => '名称',
    OpenListSortKey.type => '类型',
    OpenListSortKey.size => '大小',
    OpenListSortKey.modified => '时间',
  };
}

String _joinRemotePath(String parent, String name) {
  final normalizedParent = parent.trim().isEmpty ? '/' : parent.trim();
  if (normalizedParent == '/') {
    return '/$name';
  }
  return '$normalizedParent/$name';
}

@visibleForTesting
String friendlyOpenListUploadError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('broken pipe') ||
      text.contains('connection reset') ||
      text.contains('send timeout') ||
      text.contains('receive timeout') ||
      text.contains('connection') ||
      text.contains('socketexception')) {
    return '上传连接中断，请确认校园网/VPN 稳定后重试。';
  }
  if (text.contains('cannot upload') || text.contains('permission')) {
    return '当前账号或目录没有上传权限，请重新登录畅课后再试。';
  }
  return '上传失败，请稍后重试。';
}

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

String _formatDate(DateTime? value) {
  if (value == null) {
    return '未知时间';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
