import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../services/duplicate_file_scanner.dart';
import 'file_preview_page.dart';

class DuplicateCleanupPage extends StatefulWidget {
  const DuplicateCleanupPage({
    super.key,
    required this.roots,
    this.title = '查重清理',
  });

  final List<DuplicateScanRoot> roots;
  final String title;

  @override
  State<DuplicateCleanupPage> createState() => _DuplicateCleanupPageState();
}

class _DuplicateCleanupPageState extends State<DuplicateCleanupPage> {
  final DuplicateFileScanner _scanner = const DuplicateFileScanner();
  List<DuplicateFileGroup> _groups = const <DuplicateFileGroup>[];
  final Set<String> _selectedPaths = <String>{};
  bool _scanning = false;
  bool _deleting = false;
  String _status = '点击扫描开始查找重复文件。';

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _selectedPaths.clear();
      _status = '正在扫描文件...';
    });
    final groups = await _scanner.scan(
      widget.roots,
      onProgress: (message) {
        if (mounted) {
          setState(() => _status = message);
        }
      },
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _groups = groups;
      _scanning = false;
      _status = groups.isEmpty
          ? '没有发现重复文件。'
          : '发现 ${groups.length} 组重复文件，可释放 ${duplicateFormatBytes(_totalDuplicateBytes(groups))}。';
    });
  }

  void _selectKeepNewest() {
    final next = <String>{};
    for (final group in _groups) {
      for (var i = 1; i < group.files.length; i++) {
        next.add(group.files[i].path);
      }
    }
    setState(
      () => _selectedPaths
        ..clear()
        ..addAll(next),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedPaths.isEmpty || _deleting) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除重复文件'),
        content: Text('确认删除 ${_selectedPaths.length} 个本地文件？此操作不会删除云盘远端文件。'),
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
    setState(() => _deleting = true);
    final result = await _scanner.deleteFiles(_selectedPaths);
    if (!mounted) {
      return;
    }
    setState(() {
      _deleting = false;
      _selectedPaths.clear();
      _status =
          '已删除 ${result.deletedCount} 个文件，释放 ${duplicateFormatBytes(result.freedBytes)}'
          '${result.failedPaths.isEmpty ? '' : '，${result.failedPaths.length} 个失败'}。';
    });
    await _scan();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _scanning || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '扫描',
            onPressed: busy ? null : _scan,
            icon: const Icon(Icons.manage_search_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _CleanupHeader(
            status: _status,
            roots: widget.roots,
            scanning: _scanning,
            selectedCount: _selectedPaths.length,
            onScan: busy ? null : _scan,
            onKeepNewest: _groups.isEmpty || busy ? null : _selectKeepNewest,
            onDelete: _selectedPaths.isEmpty || busy ? null : _deleteSelected,
          ),
          Expanded(
            child: _groups.isEmpty
                ? Center(
                    child: Text(
                      _scanning ? '正在扫描...' : '暂无重复文件结果',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                    itemCount: _groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return _DuplicateGroupCard(
                        group: group,
                        selectedPaths: _selectedPaths,
                        onToggle: (path, selected) {
                          setState(() {
                            if (selected) {
                              _selectedPaths.add(path);
                            } else {
                              _selectedPaths.remove(path);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static int _totalDuplicateBytes(List<DuplicateFileGroup> groups) {
    return groups.fold<int>(0, (sum, group) => sum + group.duplicateBytes);
  }
}

class _CleanupHeader extends StatelessWidget {
  const _CleanupHeader({
    required this.status,
    required this.roots,
    required this.scanning,
    required this.selectedCount,
    required this.onScan,
    required this.onKeepNewest,
    required this.onDelete,
  });

  final String status;
  final List<DuplicateScanRoot> roots;
  final bool scanning;
  final int selectedCount;
  final VoidCallback? onScan;
  final VoidCallback? onKeepNewest;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: roots
                .map(
                  (root) => Chip(
                    label: Text(root.label),
                    avatar: const Icon(Icons.folder_outlined, size: 16),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onScan,
                icon: scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.manage_search_rounded),
                label: Text(scanning ? '扫描中' : '扫描'),
              ),
              OutlinedButton.icon(
                onPressed: onKeepNewest,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('保留最新'),
              ),
              FilledButton.tonalIcon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: Text('删除已选 $selectedCount'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  const _DuplicateGroupCard({
    required this.group,
    required this.selectedPaths,
    required this.onToggle,
  });

  final DuplicateFileGroup group;
  final Set<String> selectedPaths;
  final void Function(String path, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.file_copy_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${group.files.length} 个重复文件 · ${duplicateFormatBytes(group.sizeBytes)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(DuplicateFileScanner.shortHash(group.sha256)),
            ],
          ),
          const SizedBox(height: 8),
          ...group.files.map((file) {
            final selected = selectedPaths.contains(file.path);
            return CheckboxListTile(
              value: selected,
              onChanged: (value) => onToggle(file.path, value == true),
              contentPadding: EdgeInsets.zero,
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${file.sourceLabel} · ${_formatTime(file.modified)}\n${file.path}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              secondary: PopupMenuButton<_DuplicateAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _DuplicateAction.preview:
                      await FilePreviewPage.open(context, file.path);
                    case _DuplicateAction.openFolder:
                      await OpenFilex.open(p.dirname(file.path));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _DuplicateAction.preview,
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('预览'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _DuplicateAction.openFolder,
                    child: ListTile(
                      leading: Icon(Icons.folder_open_outlined),
                      title: Text('打开所在目录'),
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

  String _formatTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

enum _DuplicateAction { preview, openFolder }
