import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../models/file_output_manager_models.dart';
import '../models/file_tool_models.dart';
import '../materials/material_search_context.dart';
import '../services/file_output_manager_service.dart';
import '../services/file_output_share_service.dart';
import '../session/app_settings.dart';
import '../smart/smart_models.dart';
import '../widgets/context_help.dart';
import '../widgets/material_context_search.dart';
import '../widgets/smart_inline_panel.dart';
import 'file_preview_page.dart';

enum _OutputFilter {
  all,
  pdf,
  file,
  ocr,
  openList,
  offline,
  exports,
  scanned,
  missing,
}

enum _OutputSort { timeDesc, sizeDesc, sourceAsc }

class FileOutputManagerPage extends StatefulWidget {
  const FileOutputManagerPage({
    super.key,
    FileOutputManagerService? service,
    FileOutputShareService? shareService,
  }) : _service = service,
       _shareService = shareService;

  final FileOutputManagerService? _service;
  final FileOutputShareService? _shareService;

  @override
  State<FileOutputManagerPage> createState() => _FileOutputManagerPageState();
}

class _FileOutputManagerPageState extends State<FileOutputManagerPage> {
  late final FileOutputManagerService _service =
      widget._service ?? FileOutputManagerService();
  late final FileOutputShareService _shareService =
      widget._shareService ?? FileOutputShareService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<FileOutputItem> _items = <FileOutputItem>[];
  bool _loading = true;
  String? _error;
  String _query = '';
  _OutputFilter _filter = _OutputFilter.all;
  _OutputSort _sort = _OutputSort.timeDesc;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) return;
        setState(() {
          _query = _searchController.text;
        });
      });
    });
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _tr(String zh, String en) => _isEnglish ? en : zh;

  List<FileOutputItem> get _visibleItems {
    final normalizedQuery = _query.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (!_matchesFilter(item)) return false;
      if (normalizedQuery.isEmpty) return true;
      return item.name.toLowerCase().contains(normalizedQuery) ||
          item.toolName.toLowerCase().contains(normalizedQuery) ||
          item.sourceLabel.toLowerCase().contains(normalizedQuery) ||
          item.path.toLowerCase().contains(normalizedQuery);
    }).toList();
    filtered.sort((a, b) {
      return switch (_sort) {
        _OutputSort.timeDesc => b.timestamp.compareTo(a.timestamp),
        _OutputSort.sizeDesc => b.sizeBytes.compareTo(a.sizeBytes),
        _OutputSort.sourceAsc => a.sourceLabel.compareTo(b.sourceLabel),
      };
    });
    return filtered;
  }

  List<FileOutputItem> get _selectedItems {
    return _items.where((item) => _selectedIds.contains(item.id)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.loadOutputs(
        performanceMode: AppSettings.performanceMode,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _selectedIds.removeWhere((id) => !items.any((item) => item.id == id));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  bool _matchesFilter(FileOutputItem item) {
    return switch (_filter) {
      _OutputFilter.all => true,
      _OutputFilter.pdf =>
        item.scope == FileToolHistoryScope.pdf ||
            item.sourceLabel.contains('PDF'),
      _OutputFilter.file =>
        item.scope == FileToolHistoryScope.file ||
            item.sourceLabel.contains('文件工具'),
      _OutputFilter.ocr => item.sourceLabel.contains('OCR'),
      _OutputFilter.openList =>
        item.sourceLabel.contains('OpenList') ||
            item.sourceLabel.contains('云盘'),
      _OutputFilter.offline => item.sourceLabel.contains('离线包'),
      _OutputFilter.exports => item.sourceLabel.contains('分享导出'),
      _OutputFilter.scanned => item.status == FileOutputStatus.scanOnly,
      _OutputFilter.missing => item.status == FileOutputStatus.missing,
    };
  }

  void _toggleSelection(FileOutputItem item, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(item.id);
      } else {
        _selectedIds.remove(item.id);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
  }

  Future<void> _preview(FileOutputItem item) async {
    if (!item.canPreview) return;
    await FilePreviewPage.open(context, item.path, title: item.name);
  }

  Future<void> _openFolder(FileOutputItem item) async {
    if (!item.exists) return;
    final target = item.isDirectory ? item.path : p.dirname(item.path);
    await OpenFilex.open(target);
  }

  Future<void> _share(FileOutputItem item) async {
    if (!item.canShare) return;
    try {
      await _shareService.shareOutput(item.path, text: '输出文件管家');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _shareSelected() async {
    final items = _selectedItems.where((item) => item.exists).toList();
    if (items.isEmpty) return;
    if (items.length == 1) {
      await _share(items.single);
      return;
    }
    final files = items.where((item) => !item.isDirectory).toList();
    if (files.isEmpty) {
      _showSnack(
        _tr(
          '批量分享暂不支持全部为文件夹的选择，请单项分享。',
          'Batch sharing folders is not supported yet.',
        ),
      );
      return;
    }
    await Share.shareXFiles(
      files.map((item) => XFile(item.path)).toList(),
      text: _tr('输出文件管家批量分享', 'File output manager batch share'),
    );
    if (files.length != items.length) {
      _showSnack(
        _tr(
          '已跳过文件夹；文件夹可使用单项分享。',
          'Folders were skipped; share folders one by one.',
        ),
      );
    }
  }

  Future<void> _copyPath(FileOutputItem item) async {
    await Clipboard.setData(ClipboardData(text: item.path));
    _showSnack(_tr('已复制路径', 'Path copied'));
  }

  Future<void> _copySelectedPaths() async {
    final text = _selectedItems.map((item) => item.path).join('\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack(_tr('已复制选中路径', 'Selected paths copied'));
  }

  Future<void> _addToLibrary(Iterable<FileOutputItem> items) async {
    final count = await _service.addToMaterialLibrary(items);
    await _load();
    _showSnack(_tr('已加入资料库 $count 项', 'Added $count item(s) to materials'));
  }

  Future<void> _hideHistory(Iterable<FileOutputItem> items) async {
    final targets = items.where((item) => item.hasHistory).toList();
    await _service.removeFromHistory(targets.map((item) => item.path));
    _clearSelection();
    await _load();
    _showSnack(
      _tr('已从历史隐藏 ${targets.length} 项', 'Hidden ${targets.length} item(s)'),
    );
  }

  Future<void> _deleteItems(Iterable<FileOutputItem> items) async {
    final targets = items.where((item) => item.canDelete).toList();
    if (targets.isEmpty) return;
    final hasExternal = targets.any(
      (item) => item.status == FileOutputStatus.external,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tr('删除输出文件', 'Delete output files')),
        content: Text(
          hasExternal
              ? _tr(
                  '选中项包含外部路径。确认后会删除真实文件或文件夹，原始输入文件不会自动纳入管家，但请确认这些路径确实是输出产物。',
                  'The selection includes external paths. Confirm only if these files are output artifacts.',
                )
              : _tr(
                  '确认删除 ${targets.length} 个输出文件或文件夹？此操作不会进入应用内回收站。',
                  'Delete ${targets.length} output file(s) or folder(s)?',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('删除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final count = await _service.deleteOutputs(targets);
    _clearSelection();
    await _load();
    _showSnack(_tr('已删除 $count 项', 'Deleted $count item(s)'));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final summary = FileOutputManagerSummary.fromItems(_items);
    final visibleItems = _visibleItems;
    return Scaffold(
      key: const ValueKey('outputManagerPage'),
      appBar: AppBar(
        title: Text(_tr('输出文件管家', 'Output Manager')),
        actions: [
          IconButton(
            tooltip: _tr('刷新', 'Refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _load)
            : Column(
                children: [
                  _SummaryPanel(summary: summary),
                  if (_items.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: MaterialRelatedPanel(
                        title: '输出相关资料',
                        contextData: MaterialSearchContext.output(
                          path: _items.first.path,
                          name: _items.first.name,
                          limit: 3,
                        ),
                        maxItems: 3,
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SmartInlinePanel(
                      title: '输出智能建议',
                      types: {SmartInsightType.output},
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: ContextHelpHint(
                      title: '输出文件帮助',
                      tips: [
                        '输出文件管家只管理工具产物，不会自动删除原始输入文件。',
                        '缺失历史可以隐藏，真实文件缺失不会自动清理记录。',
                        '未入库输出可加入资料库，后续能搜索或生成复习卡。',
                        '外部路径删除前需要确认，避免误删非工具产物。',
                      ],
                    ),
                  ),
                  _Toolbar(
                    controller: _searchController,
                    filter: _filter,
                    sort: _sort,
                    onFilterChanged: (value) => setState(() {
                      _filter = value;
                    }),
                    onSortChanged: (value) => setState(() {
                      _sort = value;
                    }),
                    tr: _tr,
                  ),
                  if (_selectedIds.isNotEmpty)
                    _SelectionBar(
                      count: _selectedIds.length,
                      onClear: _clearSelection,
                      onShare: _shareSelected,
                      onCopy: _copySelectedPaths,
                      onAddToLibrary: () => _addToLibrary(_selectedItems),
                      onHideHistory: () => _hideHistory(_selectedItems),
                      onDelete: () => _deleteItems(_selectedItems),
                      tr: _tr,
                    ),
                  Expanded(
                    child: visibleItems.isEmpty
                        ? _EmptyState(hasAnyItems: _items.isNotEmpty, tr: _tr)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: visibleItems.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = visibleItems[index];
                              return _OutputTile(
                                item: item,
                                selected: _selectedIds.contains(item.id),
                                onSelectedChanged: (selected) =>
                                    _toggleSelection(item, selected),
                                onPreview: item.canPreview
                                    ? () => _preview(item)
                                    : null,
                                onOpenFolder: item.exists
                                    ? () => _openFolder(item)
                                    : null,
                                onShare: item.canShare
                                    ? () => _share(item)
                                    : null,
                                onCopy: () => _copyPath(item),
                                onSearchRelated: () =>
                                    MaterialSearchLauncher.open(
                                      context,
                                      searchContext:
                                          MaterialSearchContext.output(
                                            path: item.path,
                                            name: item.name,
                                          ),
                                      title: '输出相关资料',
                                    ),
                                onAddToLibrary: item.exists
                                    ? () =>
                                          _addToLibrary(<FileOutputItem>[item])
                                    : null,
                                onHideHistory: item.canHideHistory
                                    ? () => _hideHistory(<FileOutputItem>[item])
                                    : null,
                                onDelete: item.canDelete
                                    ? () => _deleteItems(<FileOutputItem>[item])
                                    : null,
                                tr: _tr,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.summary});

  final FileOutputManagerSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(label: '总数', value: '${summary.totalCount}'),
              _MetricChip(label: '可用', value: '${summary.availableCount}'),
              _MetricChip(label: '缺失', value: '${summary.missingCount}'),
              _MetricChip(
                label: '占用',
                value: _formatBytes(summary.totalSizeBytes),
              ),
              if (summary.updatedAt != null)
                _MetricChip(
                  label: '最近',
                  value: _formatDate(summary.updatedAt!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.tr,
  });

  final TextEditingController controller;
  final _OutputFilter filter;
  final _OutputSort sort;
  final ValueChanged<_OutputFilter> onFilterChanged;
  final ValueChanged<_OutputSort> onSortChanged;
  final String Function(String zh, String en) tr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('outputManagerSearchField'),
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: tr('搜索文件名、工具、路径', 'Search name, tool, or path'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<_OutputFilter>(
                  key: const ValueKey('outputManagerFilter'),
                  initialValue: filter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr('来源筛选', 'Source'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _OutputFilter.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_filterLabel(value, tr)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onFilterChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<_OutputSort>(
                  key: const ValueKey('outputManagerSort'),
                  initialValue: sort,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: tr('排序', 'Sort'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _OutputSort.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_sortLabel(value, tr)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onShare,
    required this.onCopy,
    required this.onAddToLibrary,
    required this.onHideHistory,
    required this.onDelete,
    required this.tr,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onAddToLibrary;
  final VoidCallback onHideHistory;
  final VoidCallback onDelete;
  final String Function(String zh, String en) tr;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('outputManagerSelectionBar'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text(tr('已选 $count 项', '$count selected')),
            const Spacer(),
            IconButton(
              tooltip: tr('分享', 'Share'),
              onPressed: onShare,
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: tr('复制路径', 'Copy paths'),
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded),
            ),
            PopupMenuButton<String>(
              key: const ValueKey('outputSelectionBatchMenu'),
              tooltip: tr('批量操作', 'Batch actions'),
              onSelected: (value) {
                switch (value) {
                  case 'library':
                    onAddToLibrary();
                  case 'hide':
                    onHideHistory();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const ValueKey('outputBatchAddToLibrary'),
                  value: 'library',
                  child: Text(tr('批量加入资料库', 'Add to materials')),
                ),
                PopupMenuItem(
                  key: const ValueKey('outputBatchHideHistory'),
                  value: 'hide',
                  child: Text(tr('批量隐藏历史', 'Hide history')),
                ),
                PopupMenuItem(
                  key: const ValueKey('outputBatchDelete'),
                  value: 'delete',
                  child: Text(tr('批量删除文件', 'Delete files')),
                ),
              ],
            ),
            IconButton(
              tooltip: tr('取消选择', 'Clear selection'),
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputTile extends StatelessWidget {
  const _OutputTile({
    required this.item,
    required this.selected,
    required this.onSelectedChanged,
    required this.onPreview,
    required this.onOpenFolder,
    required this.onShare,
    required this.onCopy,
    required this.onSearchRelated,
    required this.onAddToLibrary,
    required this.onHideHistory,
    required this.onDelete,
    required this.tr,
  });

  final FileOutputItem item;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback? onPreview;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onShare;
  final VoidCallback onCopy;
  final VoidCallback onSearchRelated;
  final VoidCallback? onAddToLibrary;
  final VoidCallback? onHideHistory;
  final VoidCallback? onDelete;
  final String Function(String zh, String en) tr;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        key: ValueKey('outputItem:${item.id}'),
        leading: Checkbox(
          value: selected,
          onChanged: (value) => onSelectedChanged(value ?? false),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(item: item),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.sourceLabel} · ${item.toolName} · ${_formatBytes(item.sizeBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          key: ValueKey('outputItemMenu:${item.id}'),
          tooltip: tr('更多操作', 'More actions'),
          onSelected: (value) {
            switch (value) {
              case 'preview':
                onPreview?.call();
              case 'folder':
                onOpenFolder?.call();
              case 'share':
                onShare?.call();
              case 'copy':
                onCopy();
              case 'search':
                onSearchRelated();
              case 'library':
                onAddToLibrary?.call();
              case 'hide':
                onHideHistory?.call();
              case 'delete':
                onDelete?.call();
            }
          },
          itemBuilder: (context) => [
            if (onPreview != null)
              PopupMenuItem(
                key: ValueKey('outputActionPreview:${item.id}'),
                value: 'preview',
                child: Text(tr('预览', 'Preview')),
              ),
            if (onOpenFolder != null)
              PopupMenuItem(
                key: ValueKey('outputActionFolder:${item.id}'),
                value: 'folder',
                child: Text(tr('打开所在目录', 'Open folder')),
              ),
            if (onShare != null)
              PopupMenuItem(
                key: ValueKey('outputActionShare:${item.id}'),
                value: 'share',
                child: Text(tr('分享', 'Share')),
              ),
            PopupMenuItem(
              key: ValueKey('outputActionCopy:${item.id}'),
              value: 'copy',
              child: Text(tr('复制路径', 'Copy path')),
            ),
            PopupMenuItem(
              key: ValueKey('outputActionSearch:${item.id}'),
              value: 'search',
              child: Text(tr('查相似资料', 'Find related materials')),
            ),
            if (onAddToLibrary != null)
              PopupMenuItem(
                key: ValueKey('outputActionLibrary:${item.id}'),
                value: 'library',
                child: Text(
                  item.inMaterialLibrary
                      ? tr('更新资料库记录', 'Update material record')
                      : tr('加入资料库', 'Add to materials'),
                ),
              ),
            if (onHideHistory != null)
              PopupMenuItem(
                key: ValueKey('outputActionHide:${item.id}'),
                value: 'hide',
                child: Text(
                  item.status == FileOutputStatus.missing
                      ? tr('从历史移除', 'Remove from history')
                      : tr('隐藏历史', 'Hide history'),
                ),
              ),
            if (onDelete != null)
              PopupMenuItem(
                key: ValueKey('outputActionDelete:${item.id}'),
                value: 'delete',
                child: Text(tr('删除文件', 'Delete file')),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.item});

  final FileOutputItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (item.status) {
      FileOutputStatus.available => colors.primary,
      FileOutputStatus.missing => colors.error,
      FileOutputStatus.external => colors.tertiary,
      FileOutputStatus.scanOnly => colors.secondary,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          item.status.labelZh,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAnyItems, required this.tr});

  final bool hasAnyItems;
  final String Function(String zh, String en) tr;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('outputManagerEmptyState'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasAnyItems
              ? tr('当前筛选下没有输出文件。', 'No outputs match this filter.')
              : tr('还没有可管理的输出文件。', 'No output files yet.'),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

String _filterLabel(
  _OutputFilter value,
  String Function(String zh, String en) tr,
) {
  return switch (value) {
    _OutputFilter.all => tr('全部', 'All'),
    _OutputFilter.pdf => tr('PDF 工具', 'PDF tools'),
    _OutputFilter.file => tr('文件工具', 'File tools'),
    _OutputFilter.ocr => tr('OCR', 'OCR'),
    _OutputFilter.openList => tr('OpenList 下载', 'OpenList'),
    _OutputFilter.offline => tr('离线包', 'Offline'),
    _OutputFilter.exports => tr('分享导出', 'Exports'),
    _OutputFilter.scanned => tr('扫描发现', 'Scanned'),
    _OutputFilter.missing => tr('缺失', 'Missing'),
  };
}

String _sortLabel(_OutputSort value, String Function(String zh, String en) tr) {
  return switch (value) {
    _OutputSort.timeDesc => tr('按时间', 'Time'),
    _OutputSort.sizeDesc => tr('按大小', 'Size'),
    _OutputSort.sourceAsc => tr('按来源', 'Source'),
  };
}

String _formatDate(DateTime value) {
  return '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}
