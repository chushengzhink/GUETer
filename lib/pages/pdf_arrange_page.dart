import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../materials/material_index_models.dart';
import '../materials/material_library_store.dart';
import '../models/file_tool_models.dart';
import '../models/pdf_arrange_models.dart';
import '../services/file_output_share_service.dart';
import '../services/file_tool_history_store.dart';
import '../services/gueter_storage_service.dart';
import '../services/pdf_arrange_service.dart';
import '../session/app_settings.dart';
import 'file_preview_page.dart';

const Color _pdfArrangeAccent = Color(0xFFF97316);

class PdfArrangePage extends StatefulWidget {
  const PdfArrangePage({
    super.key,
    this.service = const PdfArrangeService(),
    this.initialFile,
    this.outputDirectory,
    this.historyStore,
    this.libraryStore,
    this.shareService,
  });

  final PdfArrangeService service;
  final File? initialFile;
  final Directory? outputDirectory;
  final FileToolHistoryStore? historyStore;
  final MaterialLibraryStore? libraryStore;
  final FileOutputShareService? shareService;

  @override
  State<PdfArrangePage> createState() => _PdfArrangePageState();
}

class _PdfArrangePageState extends State<PdfArrangePage> {
  late final FileToolHistoryStore _historyStore =
      widget.historyStore ?? FileToolHistoryStore();
  late final MaterialLibraryStore _libraryStore =
      widget.libraryStore ?? MaterialLibraryStore();
  late final FileOutputShareService _shareService =
      widget.shareService ?? FileOutputShareService();

  File? _file;
  List<PdfArrangePageItem> _items = const <PdfArrangePageItem>[];
  final List<List<PdfArrangePageItem>> _undoStack =
      <List<PdfArrangePageItem>>[];
  final List<List<PdfArrangePageItem>> _redoStack =
      <List<PdfArrangePageItem>>[];
  Set<String> _selectedIds = const <String>{};
  PdfArrangeLayoutMode _layoutMode = PdfArrangeLayoutMode.grid;
  double _thumbnailExtent = 112;
  bool _loading = false;
  bool _exporting = false;
  String _status = '选择一个 PDF 后开始编排页面。';
  String? _lastOutputPath;
  int _thumbnailDone = 0;
  int _thumbnailTotal = 0;

  int get _keptCount => _items.where((item) => !item.deleted).length;

  int get _deletedCount => _items.length - _keptCount;

  int get _rotatedCount =>
      _items.where((item) => !item.deleted && item.hasRotation).length;

  int get _duplicateCount {
    final seen = <int>{};
    var duplicates = 0;
    for (final item in _items) {
      if (!seen.add(item.originalPageNumber)) duplicates += 1;
    }
    return duplicates;
  }

  bool get _hasSelection => _selectedIds.isNotEmpty;

  bool get _hasChanges {
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.id != 'page-${item.originalPageNumber}') return true;
      if (item.currentIndex != item.originalPageNumber - 1) return true;
      if (item.deleted || item.hasRotation) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFile;
    if (initial != null) {
      unawaited(_loadFile(initial));
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    await _loadFile(File(path));
  }

  Future<void> _loadFile(File file) async {
    setState(() {
      _file = file;
      _items = const <PdfArrangePageItem>[];
      _undoStack.clear();
      _redoStack.clear();
      _selectedIds = const <String>{};
      _loading = true;
      _lastOutputPath = null;
      _thumbnailDone = 0;
      _thumbnailTotal = 0;
      _status = '正在读取 ${p.basename(file.path)}...';
    });
    try {
      final pages = await widget.service.loadPages(file);
      if (!mounted) return;
      setState(() {
        _items = pages;
        _loading = false;
        _thumbnailTotal = pages.length;
        _status = '已加载 ${pages.length} 页，正在生成缩略图...';
      });
      final withThumbnails = await widget.service.renderThumbnails(
        file: file,
        items: pages,
        performanceMode: AppSettings.performanceMode,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _thumbnailDone = done;
            _thumbnailTotal = total;
            _status = '正在生成缩略图 $done / $total';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _items = withThumbnails;
        _status = '已加载 ${withThumbnails.length} 页，可多选、复制、旋转或导出。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = const <PdfArrangePageItem>[];
        _selectedIds = const <String>{};
        _status = error.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _commitItems(
    List<PdfArrangePageItem> nextItems,
    String status, {
    Set<String>? selectedIds,
  }) {
    _undoStack.add(_items);
    _redoStack.clear();
    final ids = nextItems.map((item) => item.id).toSet();
    setState(() {
      _items = nextItems;
      _selectedIds = (selectedIds ?? _selectedIds)
          .where((id) => ids.contains(id))
          .toSet();
      _status = status;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    _commitItems(
      widget.service.reorder(_items, oldIndex, newIndex),
      '页面顺序已调整，导出后生效。',
    );
  }

  void _rotate(PdfArrangePageItem item, int delta) {
    _commitItems(
      widget.service.rotatePage(_items, item.id, delta),
      '第 ${item.originalPageNumber} 页已旋转，导出后生效。',
    );
  }

  void _setDeleted(PdfArrangePageItem item, bool deleted) {
    _commitItems(
      widget.service.setDeleted(_items, item.id, deleted),
      deleted
          ? '第 ${item.originalPageNumber} 页已标记删除。'
          : '第 ${item.originalPageNumber} 页已恢复。',
    );
  }

  void _rotateSelected(int delta) {
    if (!_hasSelection) return;
    _commitItems(
      widget.service.rotateMany(_items, _selectedIds, delta),
      '已旋转 ${_selectedIds.length} 个页面实例。',
    );
  }

  void _setSelectedDeleted(bool deleted) {
    if (!_hasSelection) return;
    _commitItems(
      widget.service.setDeletedMany(_items, _selectedIds, deleted),
      deleted
          ? '已标记删除 ${_selectedIds.length} 页。'
          : '已恢复 ${_selectedIds.length} 页。',
    );
  }

  void _restoreSelected() {
    if (!_hasSelection) return;
    _commitItems(
      widget.service.restoreMany(_items, _selectedIds),
      '已恢复选中页的删除和旋转状态。',
    );
  }

  void _duplicateSelected() {
    if (!_hasSelection) return;
    final beforeIds = _items.map((item) => item.id).toSet();
    final next = widget.service.duplicatePages(_items, _selectedIds);
    final duplicateIds = next
        .map((item) => item.id)
        .where((id) => !beforeIds.contains(id))
        .toSet();
    _commitItems(
      next,
      '已复制 ${duplicateIds.length} 个页面实例。',
      selectedIds: duplicateIds,
    );
  }

  void _restoreAll() {
    _commitItems(
      widget.service.restoreAll(_items),
      '已恢复全部页面、顺序和旋转。',
      selectedIds: const <String>{},
    );
  }

  void _selectAllPages() {
    setState(() {
      _selectedIds = _items.map((item) => item.id).toSet();
      _status = '已选择全部 ${_selectedIds.length} 页。';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds = const <String>{};
      _status = '已取消选择。';
    });
  }

  void _invertSelection() {
    setState(() {
      final current = _selectedIds;
      _selectedIds = _items
          .where((item) => !current.contains(item.id))
          .map((item) => item.id)
          .toSet();
      _status = '已反选，当前选择 ${_selectedIds.length} 页。';
    });
  }

  void _selectByPositionParity({required bool odd}) {
    setState(() {
      _selectedIds = _items
          .where((item) {
            final position = item.currentIndex + 1;
            return odd ? position.isOdd : position.isEven;
          })
          .map((item) => item.id)
          .toSet();
      _status = odd ? '已选择奇数位置页面。' : '已选择偶数位置页面。';
    });
  }

  void _toggleSelection(PdfArrangePageItem item) {
    setState(() {
      final next = Set<String>.from(_selectedIds);
      if (!next.add(item.id)) next.remove(item.id);
      _selectedIds = next;
      _status = next.isEmpty ? '已取消选择。' : '已选择 ${next.length} 页。';
    });
  }

  Future<void> _showRangeDialog() async {
    final range = await showDialog<String>(
      context: context,
      builder: (context) => const _RangeDialog(),
    );
    if (range == null) return;
    try {
      final selected = widget.service.selectByRange(_items, range);
      setState(() {
        _selectedIds = selected;
        _status = '已按范围选择 ${selected.length} 页。';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(_items);
    final ids = previous.map((item) => item.id).toSet();
    setState(() {
      _items = previous;
      _selectedIds = _selectedIds.where((id) => ids.contains(id)).toSet();
      _status = '已撤销上一步操作。';
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(_items);
    final ids = next.map((item) => item.id).toSet();
    setState(() {
      _items = next;
      _selectedIds = _selectedIds.where((id) => ids.contains(id)).toSet();
      _status = '已重做上一步操作。';
    });
  }

  Future<void> _export({
    PdfArrangeExportMode mode = PdfArrangeExportMode.keptPages,
  }) async {
    final sourceFile = _file;
    if (sourceFile == null || _items.isEmpty) return;
    setState(() {
      _exporting = true;
      _status = mode == PdfArrangeExportMode.selectedPages
          ? '正在导出选中页 PDF...'
          : '正在导出新 PDF...';
    });
    try {
      final outputDir =
          widget.outputDirectory ??
          await GueterStorageService.instance.publicDirectory(
            GueterPublicDirectory.pdfTools,
          );
      final result = await widget.service.exportArrangedPdf(
        sourceFile: sourceFile,
        items: _items,
        outputDirectory: outputDir,
        selectedIds: _selectedIds,
        mode: mode,
      );
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _lastOutputPath = result.outputPath;
        _status =
            'PDF 页面编排完成：保留 ${result.keptCount} 页，删除 ${result.deletedCount} 页，旋转 ${result.rotatedCount} 页，副本 ${result.duplicateCount} 页${result.selectedOnly ? '，仅导出选中页' : ''}。';
      });
      unawaited(_recordSuccess(sourceFile, result).catchError((_) {}));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF 页面编排完成')));
    } catch (error) {
      await _recordFailure(sourceFile, error.toString());
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _status = error.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _recordSuccess(
    File sourceFile,
    PdfArrangeExportResult result,
  ) async {
    final fileName = p.basename(result.outputPath);
    await _historyStore.append(
      FileToolHistoryRecord(
        scope: FileToolHistoryScope.pdf,
        toolName: 'PDF 页面编排',
        inputSummary: p.basename(sourceFile.path),
        outputPath: result.outputPath,
        timestamp: DateTime.now(),
        success: true,
        message:
            '保留 ${result.keptCount} 页，删除 ${result.deletedCount} 页，旋转 ${result.rotatedCount} 页，副本 ${result.duplicateCount} 页${result.selectedOnly ? '，仅导出选中页' : ''}',
      ),
    );
    await _libraryStore.upsertItem(
      path: result.outputPath,
      name: fileName,
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: 'PDF 页面编排',
    );
  }

  Future<void> _recordFailure(File sourceFile, String message) async {
    await _historyStore.append(
      FileToolHistoryRecord(
        scope: FileToolHistoryScope.pdf,
        toolName: 'PDF 页面编排',
        inputSummary: p.basename(sourceFile.path),
        outputPath: '',
        timestamp: DateTime.now(),
        success: false,
        message: message,
      ),
    );
  }

  Future<void> _openOutput() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;
    await FilePreviewPage.open(context, path);
  }

  Future<void> _shareOutput() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;
    await _shareService.shareOutput(path, text: 'PDF 页面编排输出');
  }

  Future<void> _openContainingFolder() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;
    await OpenFilex.open(p.dirname(path));
  }

  void _copyOutputPath() {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('输出路径已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _exporting;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            final canvas = _ArrangeCanvas(
              items: _items,
              selectedIds: _selectedIds,
              layoutMode: _layoutMode,
              thumbnailExtent: _thumbnailExtent,
              busy: busy,
              onPickPdf: busy ? null : _pickPdf,
              onToggleSelection: _toggleSelection,
              onReorder: busy ? null : _reorder,
              onRotateLeft: (item) => _rotate(item, -90),
              onRotateRight: (item) => _rotate(item, 90),
              onDelete: (item) => _setDeleted(item, true),
              onRestore: (item) => _setDeleted(item, false),
            );
            return Column(
              children: [
                _ArrangeCommandBar(
                  file: _file,
                  totalCount: _items.length,
                  keptCount: _keptCount,
                  deletedCount: _deletedCount,
                  rotatedCount: _rotatedCount,
                  duplicateCount: _duplicateCount,
                  selectedCount: _selectedIds.length,
                  hasChanges: _hasChanges,
                  loading: _loading,
                  thumbnailDone: _thumbnailDone,
                  thumbnailTotal: _thumbnailTotal,
                  layoutMode: _layoutMode,
                  thumbnailExtent: _thumbnailExtent,
                  status: _status,
                  lastOutputPath: _lastOutputPath,
                  onBack: () => Navigator.of(context).maybePop(),
                  onPickPdf: busy ? null : _pickPdf,
                  onUndo: busy || _undoStack.isEmpty ? null : _undo,
                  onRedo: busy || _redoStack.isEmpty ? null : _redo,
                  onLayoutModeChanged: busy
                      ? null
                      : (mode) => setState(() => _layoutMode = mode),
                  onThumbnailExtentChanged: busy
                      ? null
                      : (value) => setState(() => _thumbnailExtent = value),
                  onOpenOutput: _lastOutputPath == null ? null : _openOutput,
                  onShareOutput: _lastOutputPath == null ? null : _shareOutput,
                  onOpenFolder: _lastOutputPath == null
                      ? null
                      : _openContainingFolder,
                  onCopyOutput: _lastOutputPath == null
                      ? null
                      : _copyOutputPath,
                ),
                Expanded(
                  child: wide && _items.isNotEmpty
                      ? Row(
                          children: [
                            Expanded(child: canvas),
                            _ArrangeSidePanel(
                              keptCount: _keptCount,
                              selectedCount: _selectedIds.length,
                              busy: busy,
                              hasSelection: _hasSelection,
                              onSelectAll: _selectAllPages,
                              onClearSelection: _clearSelection,
                              onInvertSelection: _invertSelection,
                              onSelectOdd: () =>
                                  _selectByPositionParity(odd: true),
                              onSelectEven: () =>
                                  _selectByPositionParity(odd: false),
                              onSelectRange: _showRangeDialog,
                              onDuplicate: _hasSelection && !busy
                                  ? _duplicateSelected
                                  : null,
                              onRotateLeft: _hasSelection && !busy
                                  ? () => _rotateSelected(-90)
                                  : null,
                              onRotateRight: _hasSelection && !busy
                                  ? () => _rotateSelected(90)
                                  : null,
                              onDelete: _hasSelection && !busy
                                  ? () => _setSelectedDeleted(true)
                                  : null,
                              onRestore: _hasSelection && !busy
                                  ? _restoreSelected
                                  : null,
                              onRestoreAll: busy ? null : _restoreAll,
                              onExportSelected: _hasSelection && !busy
                                  ? () => _export(
                                      mode: PdfArrangeExportMode.selectedPages,
                                    )
                                  : null,
                              onExport: _keptCount == 0 || busy
                                  ? null
                                  : _export,
                            ),
                          ],
                        )
                      : canvas,
                ),
                if (_items.isNotEmpty && !wide)
                  _ArrangeExportBar(
                    keptCount: _keptCount,
                    selectedCount: _selectedIds.length,
                    busy: busy,
                    hasSelection: _hasSelection,
                    onSelectAll: _selectAllPages,
                    onClearSelection: _clearSelection,
                    onInvertSelection: _invertSelection,
                    onSelectOdd: () => _selectByPositionParity(odd: true),
                    onSelectEven: () => _selectByPositionParity(odd: false),
                    onSelectRange: _showRangeDialog,
                    onDuplicate: _hasSelection && !busy
                        ? _duplicateSelected
                        : null,
                    onRotateLeft: _hasSelection && !busy
                        ? () => _rotateSelected(-90)
                        : null,
                    onRotateRight: _hasSelection && !busy
                        ? () => _rotateSelected(90)
                        : null,
                    onDelete: _hasSelection && !busy
                        ? () => _setSelectedDeleted(true)
                        : null,
                    onRestore: _hasSelection && !busy ? _restoreSelected : null,
                    onRestoreAll: busy ? null : _restoreAll,
                    onExportSelected: _hasSelection && !busy
                        ? () =>
                              _export(mode: PdfArrangeExportMode.selectedPages)
                        : null,
                    onExport: _keptCount == 0 || busy ? null : _export,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArrangeCommandBar extends StatelessWidget {
  const _ArrangeCommandBar({
    required this.file,
    required this.totalCount,
    required this.keptCount,
    required this.deletedCount,
    required this.rotatedCount,
    required this.duplicateCount,
    required this.selectedCount,
    required this.hasChanges,
    required this.loading,
    required this.thumbnailDone,
    required this.thumbnailTotal,
    required this.layoutMode,
    required this.thumbnailExtent,
    required this.status,
    required this.lastOutputPath,
    required this.onBack,
    required this.onPickPdf,
    required this.onUndo,
    required this.onRedo,
    required this.onLayoutModeChanged,
    required this.onThumbnailExtentChanged,
    required this.onOpenOutput,
    required this.onShareOutput,
    required this.onOpenFolder,
    required this.onCopyOutput,
  });

  final File? file;
  final int totalCount;
  final int keptCount;
  final int deletedCount;
  final int rotatedCount;
  final int duplicateCount;
  final int selectedCount;
  final bool hasChanges;
  final bool loading;
  final int thumbnailDone;
  final int thumbnailTotal;
  final PdfArrangeLayoutMode layoutMode;
  final double thumbnailExtent;
  final String status;
  final String? lastOutputPath;
  final VoidCallback onBack;
  final VoidCallback? onPickPdf;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final ValueChanged<PdfArrangeLayoutMode>? onLayoutModeChanged;
  final ValueChanged<double>? onThumbnailExtentChanged;
  final VoidCallback? onOpenOutput;
  final VoidCallback? onShareOutput;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onCopyOutput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = thumbnailTotal == 0
        ? null
        : thumbnailDone / thumbnailTotal;
    return Material(
      color: colors.surface,
      elevation: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                _ToolIconBox(
                  icon: Icons.picture_as_pdf_outlined,
                  color: _pdfArrangeAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file == null ? 'PDF 页面编排' : p.basename(file!.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '撤销',
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo_outlined),
                ),
                IconButton(
                  tooltip: '重做',
                  onPressed: onRedo,
                  icon: const Icon(Icons.redo_outlined),
                ),
                FilledButton.icon(
                  onPressed: onPickPdf,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('选择 PDF'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetricChip(label: '总页数', value: '$totalCount'),
                _MetricChip(label: '保留', value: '$keptCount'),
                _MetricChip(label: '删除', value: '$deletedCount'),
                _MetricChip(label: '旋转', value: '$rotatedCount'),
                _MetricChip(label: '副本', value: '$duplicateCount'),
                _MetricChip(label: '选中', value: '$selectedCount'),
                _MetricChip(label: '状态', value: hasChanges ? '未导出' : '原始'),
                _ViewControls(
                  layoutMode: layoutMode,
                  thumbnailExtent: thumbnailExtent,
                  onLayoutModeChanged: onLayoutModeChanged,
                  onThumbnailExtentChanged: onThumbnailExtentChanged,
                ),
              ],
            ),
          ),
          if (lastOutputPath != null)
            _OutputResultStrip(
              path: lastOutputPath!,
              onOpenOutput: onOpenOutput,
              onShareOutput: onShareOutput,
              onOpenFolder: onOpenFolder,
              onCopyOutput: onCopyOutput,
            ),
          if (loading || (progress != null && progress < 1))
            LinearProgressIndicator(value: loading ? null : progress),
        ],
      ),
    );
  }
}

class _OutputResultStrip extends StatelessWidget {
  const _OutputResultStrip({
    required this.path,
    required this.onOpenOutput,
    required this.onShareOutput,
    required this.onOpenFolder,
    required this.onCopyOutput,
  });

  final String path;
  final VoidCallback? onOpenOutput;
  final VoidCallback? onShareOutput;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onCopyOutput;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colors.secondaryContainer.withValues(alpha: 0.36),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colors.secondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              p.basename(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            tooltip: '预览输出',
            onPressed: onOpenOutput,
            icon: const Icon(Icons.visibility_outlined, size: 18),
          ),
          IconButton(
            tooltip: '分享',
            onPressed: onShareOutput,
            icon: const Icon(Icons.share_outlined, size: 18),
          ),
          IconButton(
            tooltip: '所在目录',
            onPressed: onOpenFolder,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
          ),
          IconButton(
            tooltip: '复制路径',
            onPressed: onCopyOutput,
            icon: const Icon(Icons.copy_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ViewControls extends StatelessWidget {
  const _ViewControls({
    required this.layoutMode,
    required this.thumbnailExtent,
    required this.onLayoutModeChanged,
    required this.onThumbnailExtentChanged,
  });

  final PdfArrangeLayoutMode layoutMode;
  final double thumbnailExtent;
  final ValueChanged<PdfArrangeLayoutMode>? onLayoutModeChanged;
  final ValueChanged<double>? onThumbnailExtentChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<PdfArrangeLayoutMode>(
            segments: const [
              ButtonSegment(
                value: PdfArrangeLayoutMode.grid,
                icon: Icon(Icons.grid_view_rounded),
                label: Text('网格'),
              ),
              ButtonSegment(
                value: PdfArrangeLayoutMode.list,
                icon: Icon(Icons.view_list_rounded),
                label: Text('列表'),
              ),
            ],
            selected: {layoutMode},
            onSelectionChanged: onLayoutModeChanged == null
                ? null
                : (selection) => onLayoutModeChanged!(selection.first),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.photo_size_select_large_outlined, size: 18),
          Expanded(
            child: Slider(
              value: thumbnailExtent,
              min: 88,
              max: 144,
              divisions: 4,
              label: thumbnailExtent.round().toString(),
              onChanged: onThumbnailExtentChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrangeCanvas extends StatelessWidget {
  const _ArrangeCanvas({
    required this.items,
    required this.selectedIds,
    required this.layoutMode,
    required this.thumbnailExtent,
    required this.busy,
    required this.onPickPdf,
    required this.onToggleSelection,
    required this.onReorder,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
    required this.onRestore,
  });

  final List<PdfArrangePageItem> items;
  final Set<String> selectedIds;
  final PdfArrangeLayoutMode layoutMode;
  final double thumbnailExtent;
  final bool busy;
  final VoidCallback? onPickPdf;
  final ValueChanged<PdfArrangePageItem> onToggleSelection;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final ValueChanged<PdfArrangePageItem> onRotateLeft;
  final ValueChanged<PdfArrangePageItem> onRotateRight;
  final ValueChanged<PdfArrangePageItem> onDelete;
  final ValueChanged<PdfArrangePageItem> onRestore;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _ArrangeEmptyState(onPickPdf: onPickPdf);
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: layoutMode == PdfArrangeLayoutMode.grid
          ? _ArrangeGridView(
              items: items,
              selectedIds: selectedIds,
              thumbnailExtent: thumbnailExtent,
              busy: busy,
              onToggleSelection: onToggleSelection,
              onRotateLeft: onRotateLeft,
              onRotateRight: onRotateRight,
              onDelete: onDelete,
              onRestore: onRestore,
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: onReorder ?? (_, _) {},
              itemBuilder: (context, index) {
                final item = items[index];
                return _ArrangePageTile(
                  key: ValueKey(item.id),
                  item: item,
                  position: index + 1,
                  reorderIndex: index,
                  selected: selectedIds.contains(item.id),
                  busy: busy,
                  onToggleSelection: () => onToggleSelection(item),
                  onRotateLeft: () => onRotateLeft(item),
                  onRotateRight: () => onRotateRight(item),
                  onDelete: () => onDelete(item),
                  onRestore: () => onRestore(item),
                );
              },
            ),
    );
  }
}

class _ArrangeGridView extends StatelessWidget {
  const _ArrangeGridView({
    required this.items,
    required this.selectedIds,
    required this.thumbnailExtent,
    required this.busy,
    required this.onToggleSelection,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
    required this.onRestore,
  });

  final List<PdfArrangePageItem> items;
  final Set<String> selectedIds;
  final double thumbnailExtent;
  final bool busy;
  final ValueChanged<PdfArrangePageItem> onToggleSelection;
  final ValueChanged<PdfArrangePageItem> onRotateLeft;
  final ValueChanged<PdfArrangePageItem> onRotateRight;
  final ValueChanged<PdfArrangePageItem> onDelete;
  final ValueChanged<PdfArrangePageItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: thumbnailExtent + 92,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ArrangePageCard(
          item: item,
          position: index + 1,
          selected: selectedIds.contains(item.id),
          thumbnailExtent: thumbnailExtent,
          busy: busy,
          onToggleSelection: () => onToggleSelection(item),
          onRotateLeft: () => onRotateLeft(item),
          onRotateRight: () => onRotateRight(item),
          onDelete: () => onDelete(item),
          onRestore: () => onRestore(item),
        );
      },
    );
  }
}

class _ArrangePageCard extends StatelessWidget {
  const _ArrangePageCard({
    required this.item,
    required this.position,
    required this.selected,
    required this.thumbnailExtent,
    required this.busy,
    required this.onToggleSelection,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
    required this.onRestore,
  });

  final PdfArrangePageItem item;
  final int position;
  final bool selected;
  final double thumbnailExtent;
  final bool busy;
  final VoidCallback onToggleSelection;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  bool get _isDuplicate =>
      item.id.startsWith('page-${item.originalPageNumber}-copy');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderColor = selected
        ? _pdfArrangeAccent
        : item.deleted
        ? colors.error.withValues(alpha: 0.45)
        : colors.outlineVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: '位置 $position，原第 ${item.originalPageNumber} 页',
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: borderColor, width: selected ? 2 : 1),
        ),
        color: item.deleted
            ? colors.errorContainer.withValues(alpha: 0.30)
            : selected
            ? colors.primaryContainer.withValues(alpha: 0.30)
            : colors.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: busy ? null : onToggleSelection,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: busy ? null : (_) => onToggleSelection(),
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Text(
                        '#$position',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '页面操作',
                      enabled: !busy,
                      onSelected: (value) {
                        switch (value) {
                          case 'rotate-left':
                            onRotateLeft();
                          case 'rotate-right':
                            onRotateRight();
                          case 'delete':
                            onDelete();
                          case 'restore':
                            onRestore();
                        }
                      },
                      itemBuilder: (context) => [
                        if (!item.deleted) ...[
                          const PopupMenuItem(
                            value: 'rotate-left',
                            child: Text('左旋 90°'),
                          ),
                          const PopupMenuItem(
                            value: 'rotate-right',
                            child: Text('右旋 90°'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除'),
                          ),
                        ] else
                          const PopupMenuItem(
                            value: 'restore',
                            child: Text('恢复'),
                          ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _Thumbnail(item: item, width: thumbnailExtent),
                        Positioned(
                          left: 6,
                          top: 6,
                          child: _TinyBadge(
                            label: '原 ${item.originalPageNumber}',
                            color: colors.surface,
                            foreground: colors.onSurface,
                          ),
                        ),
                        if (item.hasRotation)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: _TinyBadge(
                              label: '${item.normalizedRotationDegrees}°',
                              color: colors.tertiaryContainer,
                              foreground: colors.onTertiaryContainer,
                            ),
                          ),
                        if (_isDuplicate)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: _TinyBadge(
                              label: '副本',
                              color: colors.secondaryContainer,
                              foreground: colors.onSecondaryContainer,
                            ),
                          ),
                        if (item.deleted)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.error.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: _TinyBadge(
                                  label: '跳过',
                                  color: colors.errorContainer,
                                  foreground: colors.onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrangePageTile extends StatelessWidget {
  const _ArrangePageTile({
    super.key,
    required this.item,
    required this.position,
    required this.reorderIndex,
    required this.selected,
    required this.busy,
    required this.onToggleSelection,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
    required this.onRestore,
  });

  final PdfArrangePageItem item;
  final int position;
  final int reorderIndex;
  final bool selected;
  final bool busy;
  final VoidCallback onToggleSelection;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: item.deleted
          ? colors.errorContainer.withValues(alpha: 0.35)
          : selected
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : colors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: reorderIndex,
              enabled: !busy,
              child: const Icon(Icons.drag_handle),
            ),
            Checkbox(
              value: selected,
              onChanged: busy ? null : (_) => onToggleSelection(),
            ),
            _Thumbnail(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '位置 $position · 原第 ${item.originalPageNumber} 页',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.deleted)
                        _TinyBadge(
                          label: '导出时跳过',
                          color: colors.errorContainer,
                          foreground: colors.onErrorContainer,
                        )
                      else
                        _TinyBadge(
                          label: '保留',
                          color: colors.secondaryContainer,
                          foreground: colors.onSecondaryContainer,
                        ),
                      if (item.hasRotation)
                        _TinyBadge(
                          label: '旋转 ${item.normalizedRotationDegrees}°',
                          color: colors.tertiaryContainer,
                          foreground: colors.onTertiaryContainer,
                        ),
                      if (item.id.startsWith(
                        'page-${item.originalPageNumber}-copy',
                      ))
                        _TinyBadge(
                          label: '页面副本',
                          color: colors.secondaryContainer,
                          foreground: colors.onSecondaryContainer,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '左旋 90°',
              onPressed: busy || item.deleted ? null : onRotateLeft,
              icon: const Icon(Icons.rotate_left_outlined),
            ),
            IconButton(
              tooltip: '右旋 90°',
              onPressed: busy || item.deleted ? null : onRotateRight,
              icon: const Icon(Icons.rotate_right_outlined),
            ),
            IconButton(
              tooltip: item.deleted ? '恢复' : '删除',
              onPressed: busy ? null : (item.deleted ? onRestore : onDelete),
              icon: Icon(
                item.deleted
                    ? Icons.restore_from_trash_outlined
                    : Icons.delete_outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrangeSidePanel extends StatelessWidget {
  const _ArrangeSidePanel({
    required this.keptCount,
    required this.selectedCount,
    required this.busy,
    required this.hasSelection,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onInvertSelection,
    required this.onSelectOdd,
    required this.onSelectEven,
    required this.onSelectRange,
    required this.onDuplicate,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
    required this.onRestore,
    required this.onRestoreAll,
    required this.onExportSelected,
    required this.onExport,
  });

  final int keptCount;
  final int selectedCount;
  final bool busy;
  final bool hasSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onInvertSelection;
  final VoidCallback onSelectOdd;
  final VoidCallback onSelectEven;
  final VoidCallback onSelectRange;
  final VoidCallback? onDuplicate;
  final VoidCallback? onRotateLeft;
  final VoidCallback? onRotateRight;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onRestoreAll;
  final VoidCallback? onExportSelected;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.outlineVariant)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '操作面板',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '保留 $keptCount 页 · 选中 $selectedCount 页',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _SelectionMenuButton(
            busy: busy,
            expanded: true,
            onSelectAll: onSelectAll,
            onClearSelection: onClearSelection,
            onInvertSelection: onInvertSelection,
            onSelectOdd: onSelectOdd,
            onSelectEven: onSelectEven,
            onSelectRange: onSelectRange,
          ),
          const SizedBox(height: 12),
          _SelectionBar(
            vertical: true,
            hasSelection: hasSelection,
            onDuplicate: onDuplicate,
            onRotateLeft: onRotateLeft,
            onRotateRight: onRotateRight,
            onDelete: onDelete,
            onRestore: onRestore,
            onExportSelected: onExportSelected,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRestoreAll,
            icon: const Icon(Icons.restart_alt_outlined),
            label: const Text('恢复全部'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('pdf-arrange-export-button'),
            onPressed: onExport,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt_outlined),
            label: const Text('导出新 PDF'),
          ),
        ],
      ),
    );
  }
}

class _ArrangeExportBar extends StatelessWidget {
  const _ArrangeExportBar({
    required this.keptCount,
    required this.selectedCount,
    required this.busy,
    required this.hasSelection,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onInvertSelection,
    required this.onSelectOdd,
    required this.onSelectEven,
    required this.onSelectRange,
    required this.onDuplicate,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
    required this.onRestore,
    required this.onRestoreAll,
    required this.onExportSelected,
    required this.onExport,
  });

  final int keptCount;
  final int selectedCount;
  final bool busy;
  final bool hasSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onInvertSelection;
  final VoidCallback onSelectOdd;
  final VoidCallback onSelectEven;
  final VoidCallback onSelectRange;
  final VoidCallback? onDuplicate;
  final VoidCallback? onRotateLeft;
  final VoidCallback? onRotateRight;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onRestoreAll;
  final VoidCallback? onExportSelected;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('保留 $keptCount 页 · 选中 $selectedCount 页')),
                _SelectionMenuButton(
                  busy: busy,
                  expanded: false,
                  onSelectAll: onSelectAll,
                  onClearSelection: onClearSelection,
                  onInvertSelection: onInvertSelection,
                  onSelectOdd: onSelectOdd,
                  onSelectEven: onSelectEven,
                  onSelectRange: onSelectRange,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onRestoreAll,
                  icon: const Icon(Icons.restart_alt_outlined, size: 18),
                  label: const Text('恢复'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('pdf-arrange-export-button'),
                  onPressed: onExport,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_outlined),
                  label: const Text('导出新 PDF'),
                ),
              ],
            ),
            if (hasSelection) ...[
              const SizedBox(height: 8),
              _SelectionBar(
                vertical: false,
                hasSelection: hasSelection,
                onDuplicate: onDuplicate,
                onRotateLeft: onRotateLeft,
                onRotateRight: onRotateRight,
                onDelete: onDelete,
                onRestore: onRestore,
                onExportSelected: onExportSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectionMenuButton extends StatelessWidget {
  const _SelectionMenuButton({
    required this.busy,
    required this.expanded,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onInvertSelection,
    required this.onSelectOdd,
    required this.onSelectEven,
    required this.onSelectRange,
  });

  final bool busy;
  final bool expanded;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onInvertSelection;
  final VoidCallback onSelectOdd;
  final VoidCallback onSelectEven;
  final VoidCallback onSelectRange;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '选择页面',
      enabled: !busy,
      onSelected: (value) {
        switch (value) {
          case 'all':
            onSelectAll();
          case 'clear':
            onClearSelection();
          case 'invert':
            onInvertSelection();
          case 'odd':
            onSelectOdd();
          case 'even':
            onSelectEven();
          case 'range':
            onSelectRange();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'all', child: Text('全选')),
        PopupMenuItem(value: 'clear', child: Text('取消选择')),
        PopupMenuItem(value: 'invert', child: Text('反选')),
        PopupMenuItem(value: 'odd', child: Text('奇数位')),
        PopupMenuItem(value: 'even', child: Text('偶数位')),
        PopupMenuItem(value: 'range', child: Text('页码范围')),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 14 : 10,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.checklist_outlined, size: 18),
              if (expanded) ...[
                const SizedBox(width: 8),
                const Text('选择页面'),
                const Spacer(),
                const Icon(Icons.arrow_drop_down),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.vertical,
    required this.hasSelection,
    required this.onDuplicate,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
    required this.onRestore,
    required this.onExportSelected,
  });

  final bool vertical;
  final bool hasSelection;
  final VoidCallback? onDuplicate;
  final VoidCallback? onRotateLeft;
  final VoidCallback? onRotateRight;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onExportSelected;

  @override
  Widget build(BuildContext context) {
    final children = [
      OutlinedButton.icon(
        onPressed: onDuplicate,
        icon: const Icon(Icons.content_copy_outlined),
        label: const Text('复制'),
      ),
      IconButton(
        tooltip: '批量左旋 90°',
        onPressed: onRotateLeft,
        icon: const Icon(Icons.rotate_left_outlined),
      ),
      IconButton(
        tooltip: '批量右旋 90°',
        onPressed: onRotateRight,
        icon: const Icon(Icons.rotate_right_outlined),
      ),
      IconButton(
        tooltip: '批量删除',
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline),
      ),
      IconButton(
        tooltip: '恢复选中',
        onPressed: onRestore,
        icon: const Icon(Icons.restore_outlined),
      ),
      FilledButton.icon(
        onPressed: onExportSelected,
        icon: const Icon(Icons.file_upload_outlined),
        label: const Text('仅导出选中'),
      ),
    ];
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasSelection ? '选中页操作' : '选中页面后可批量操作',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: child,
            ),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final child in children) ...[child, const SizedBox(width: 8)],
        ],
      ),
    );
  }
}

class _ArrangeEmptyState extends StatelessWidget {
  const _ArrangeEmptyState({required this.onPickPdf});

  final VoidCallback? onPickPdf;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_outlined,
              size: 56,
              color: _pdfArrangeAccent,
            ),
            const SizedBox(height: 16),
            Text(
              '选择 PDF 开始页面编排',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '支持单个 PDF 的网格整理、多选、复制、旋转、删除和导出新文件。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPickPdf,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('选择 PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, this.width = 72});

  final PdfArrangePageItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final bytes = item.thumbnailBytes;
    final child = bytes == null
        ? Center(
            child: Text(
              '${item.originalPageNumber}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          )
        : Image.memory(bytes, fit: BoxFit.cover);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          height: width * 4 / 3,
          child: Transform.rotate(
            angle: item.normalizedRotationDegrees * 3.141592653589793 / 180,
            child: Opacity(opacity: item.deleted ? 0.35 : 1, child: child),
          ),
        ),
      ),
    );
  }
}

class _ToolIconBox extends StatelessWidget {
  const _ToolIconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    required this.color,
    required this.foreground,
  });

  final String label;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog();

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择页码范围'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '当前位置范围',
          hintText: '例如 1-3,5,8',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('选择'),
        ),
      ],
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
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      label: Text('$label $value'),
    );
  }
}
