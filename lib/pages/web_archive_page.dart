import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../materials/material_review_service.dart';
import '../materials/material_search_context.dart';
import '../materials/web_archive_models.dart';
import '../materials/web_archive_service.dart';
import '../materials/web_archive_store.dart';
import '../study/study_card_store.dart';
import '../widgets/material_context_search.dart';
import 'file_preview_page.dart';

class WebArchivePage extends StatefulWidget {
  const WebArchivePage({
    super.key,
    this.store,
    this.service,
    this.reviewService,
    this.studyCardStore,
  });

  final WebArchiveStore? store;
  final WebArchiveService? service;
  final MaterialReviewService? reviewService;
  final StudyCardStore? studyCardStore;

  @override
  State<WebArchivePage> createState() => _WebArchivePageState();
}

class _WebArchivePageState extends State<WebArchivePage> {
  late final WebArchiveStore _store = widget.store ?? WebArchiveStore();
  late final WebArchiveService _service =
      widget.service ?? WebArchiveService(store: _store);
  late final MaterialReviewService _reviewService =
      widget.reviewService ?? const MaterialReviewService();
  late final StudyCardStore _studyCardStore =
      widget.studyCardStore ?? StudyCardStore();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  List<WebArchiveItem> _items = const <WebArchiveItem>[];
  String _selectedTag = '';
  bool _busy = false;
  String _status = '粘贴链接后保存为本地网页资料快照。';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _searchController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _store.refreshMissingStatuses();
    final items = await _store.loadItems();
    if (!mounted) return;
    setState(() => _items = items);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _urlController.text = text;
  }

  Future<void> _archiveCurrentUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _status = '正在抓取网页并生成文本快照...';
    });
    final tags = _tagController.text
        .split(RegExp(r'[,，\s]+'))
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    try {
      final item = await _service.archiveUrl(url: url, tags: tags);
      if (!mounted) return;
      _urlController.clear();
      _tagController.clear();
      setState(() {
        _status = item.status == WebArchiveStatus.fetchError
            ? '已保存链接，但网页抓取失败。'
            : '已保存网页快照并加入资料库。';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openUrl(WebArchiveItem item) async {
    await _store.recordOpened(item.id);
    await _load();
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyUrl(WebArchiveItem item) async {
    await Clipboard.setData(ClipboardData(text: item.url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('链接已复制')));
  }

  Future<void> _previewSnapshot(WebArchiveItem item) async {
    if (item.textSnapshotPath.isEmpty) return;
    await FilePreviewPage.open(
      context,
      item.textSnapshotPath,
      title: item.displayTitle,
    );
    await _store.recordOpened(item.id);
    await _load();
  }

  Future<void> _addToLibrary(WebArchiveItem item) async {
    final libraryItem = await _service.addToMaterialLibrary(item);
    if (!mounted) return;
    final message = libraryItem == null ? '没有可入库的文本快照' : '已加入资料库';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createCard(WebArchiveItem item) async {
    if (item.textSnapshotPath.isEmpty ||
        !await File(item.textSnapshotPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可用的文本快照')));
      return;
    }
    final text = await File(item.textSnapshotPath).readAsString();
    if (!mounted) return;
    final draft = _reviewService
        .draftsFromText(
          sourcePath: item.textSnapshotPath,
          sourceName: item.displayTitle,
          text: text,
          maxDrafts: 1,
        )
        .firstOrNull;
    if (draft == null) return;
    final frontController = TextEditingController(text: draft.front);
    final backController = TextEditingController(text: draft.back);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('生成复习卡'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: frontController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '正面 / 问题'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: backController,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(labelText: '背面 / 摘录'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true || frontController.text.trim().isEmpty) return;
    await _reviewService.createCards(<MaterialReviewCardDraft>[
      draft.copyWith(
        front: frontController.text,
        back: backController.text,
        sourceSnippet: backController.text,
      ),
    ], _studyCardStore);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已生成复习卡片')));
  }

  Future<void> _deleteItem(WebArchiveItem item) async {
    await _store.deleteItem(item.id);
    await _load();
  }

  List<WebArchiveItem> get _visibleItems {
    final query = _searchController.text.trim().toLowerCase();
    return _items.where((item) {
      if (_selectedTag.isNotEmpty && !item.tags.contains(_selectedTag)) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.url.toLowerCase().contains(query) ||
          item.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  List<String> get _allTags {
    return _items.expand((item) => item.tags).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final tags = _allTags;
    final visibleItems = _visibleItems;
    return Scaffold(
      appBar: AppBar(title: const Text('网页归档箱')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '保存网页资料',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: '链接',
                      hintText: 'https://example.com/article',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: '粘贴剪贴板链接',
                        onPressed: _busy ? null : _pasteFromClipboard,
                        icon: const Icon(Icons.content_paste_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: '标签',
                      hintText: '课程 论文 Flutter',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_busy) const SizedBox(width: 8),
                      Expanded(child: Text(_status)),
                      FilledButton.icon(
                        onPressed: _busy ? null : _archiveCurrentUrl,
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('保存归档'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: '搜索标题、链接、摘要或标签',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedTag,
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem(value: '', child: Text('全部标签')),
                  ...tags.map(
                    (tag) => DropdownMenuItem(value: tag, child: Text(tag)),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedTag = value ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '暂无网页归档。可以从教程、GitHub 文档、通知链接开始保存。',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...visibleItems.map(
              (item) => _WebArchiveTile(
                item: item,
                onOpenUrl: () => _openUrl(item),
                onPreview: item.hasTextSnapshot
                    ? () => _previewSnapshot(item)
                    : null,
                onCopy: () => _copyUrl(item),
                onAddToLibrary: () => _addToLibrary(item),
                onCreateCard: () => _createCard(item),
                onSearchRelated: () => MaterialSearchLauncher.open(
                  context,
                  searchContext: MaterialSearchContext.webArchive(
                    title: item.displayTitle,
                    url: item.url,
                    tags: item.tags,
                  ),
                  title: '网页相关资料',
                ),
                onDelete: () => _deleteItem(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _WebArchiveTile extends StatelessWidget {
  const _WebArchiveTile({
    required this.item,
    required this.onOpenUrl,
    required this.onCopy,
    required this.onAddToLibrary,
    required this.onCreateCard,
    required this.onSearchRelated,
    required this.onDelete,
    this.onPreview,
  });

  final WebArchiveItem item;
  final VoidCallback onOpenUrl;
  final VoidCallback? onPreview;
  final VoidCallback onCopy;
  final VoidCallback onAddToLibrary;
  final VoidCallback onCreateCard;
  final VoidCallback onSearchRelated;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          _statusIcon(item.status),
          color: _statusColor(item.status),
        ),
        title: Text(
          item.displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_subtitle, maxLines: 4, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        onTap: onPreview ?? onOpenUrl,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'open':
                onOpenUrl();
              case 'preview':
                onPreview?.call();
              case 'copy':
                onCopy();
              case 'library':
                onAddToLibrary();
              case 'card':
                onCreateCard();
              case 'search':
                onSearchRelated();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem(value: 'open', child: Text('打开原链接')),
            if (onPreview != null)
              const PopupMenuItem(value: 'preview', child: Text('打开文本快照')),
            const PopupMenuItem(value: 'copy', child: Text('复制链接')),
            const PopupMenuItem(value: 'library', child: Text('加入资料库')),
            const PopupMenuItem(value: 'card', child: Text('生成复习卡')),
            const PopupMenuItem(value: 'search', child: Text('搜索相似资料')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('删除记录')),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final lines = <String>[
      item.url,
      if (item.description.trim().isNotEmpty) item.description.trim(),
      if (item.tags.isNotEmpty) '标签：${item.tags.join('、')}',
      '状态：${_statusLabel(item.status)}',
    ];
    return lines.join('\n');
  }

  static IconData _statusIcon(WebArchiveStatus status) {
    return switch (status) {
      WebArchiveStatus.saved => Icons.bookmark_added_outlined,
      WebArchiveStatus.fetchError => Icons.link_off_outlined,
      WebArchiveStatus.missing => Icons.report_problem_outlined,
      WebArchiveStatus.archived => Icons.archive_outlined,
      WebArchiveStatus.ignored => Icons.visibility_off_outlined,
    };
  }

  static Color _statusColor(WebArchiveStatus status) {
    return switch (status) {
      WebArchiveStatus.saved => Colors.green,
      WebArchiveStatus.fetchError => Colors.orange,
      WebArchiveStatus.missing => Colors.red,
      WebArchiveStatus.archived => Colors.blueGrey,
      WebArchiveStatus.ignored => Colors.grey,
    };
  }

  static String _statusLabel(WebArchiveStatus status) {
    return switch (status) {
      WebArchiveStatus.saved => '已保存',
      WebArchiveStatus.fetchError => '抓取失败',
      WebArchiveStatus.missing => '快照缺失',
      WebArchiveStatus.archived => '已归档',
      WebArchiveStatus.ignored => '已忽略',
    };
  }
}
