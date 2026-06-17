import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../materials/material_index_models.dart';
import '../materials/material_index_service.dart';
import '../materials/material_library_store.dart';
import '../materials/material_review_service.dart';
import '../smart/smart_models.dart';
import '../study/study_card_models.dart';
import '../study/study_card_store.dart';
import '../widgets/context_help.dart';
import '../widgets/smart_inline_panel.dart';
import 'file_preview_page.dart';
import 'study_center_page.dart';

class MaterialSearchPage extends StatefulWidget {
  const MaterialSearchPage({
    super.key,
    this.service,
    this.libraryStore,
    this.studyCardStore,
    this.reviewService,
    this.initialQuery,
    this.initialSourceType,
    this.initialContextTitle,
    this.autoSearch = false,
  });

  final MaterialIndexService? service;
  final MaterialLibraryStore? libraryStore;
  final StudyCardStore? studyCardStore;
  final MaterialReviewService? reviewService;
  final String? initialQuery;
  final MaterialSourceType? initialSourceType;
  final String? initialContextTitle;
  final bool autoSearch;

  @override
  State<MaterialSearchPage> createState() => _MaterialSearchPageState();
}

class _MaterialSearchPageState extends State<MaterialSearchPage> {
  late final MaterialIndexService _service =
      widget.service ?? MaterialIndexService();
  late final MaterialLibraryStore _libraryStore =
      widget.libraryStore ?? MaterialLibraryStore();
  late final StudyCardStore _studyCardStore =
      widget.studyCardStore ?? StudyCardStore();
  late final MaterialReviewService _reviewService =
      widget.reviewService ?? const MaterialReviewService();
  final TextEditingController _queryController = TextEditingController();
  MaterialSourceType? _sourceFilter;
  List<MaterialSearchResult> _results = const <MaterialSearchResult>[];
  final Set<String> _selectedResultIds = <String>{};
  List<MaterialLibraryItem> _inboxItems = const <MaterialLibraryItem>[];
  List<MaterialLibraryItem> _recentItems = const <MaterialLibraryItem>[];
  Map<String, StudySourceGroup> _sourceGroupsByPath =
      const <String, StudySourceGroup>{};
  MaterialIndexSummary? _summary;
  bool _busy = false;
  String _status = '输入关键词搜索本地资料。';

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialQuery?.trim() ?? '';
    _sourceFilter = widget.initialSourceType;
    _loadSummary();
    if (widget.autoSearch && _queryController.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    final summary = await _service.summary();
    await _libraryStore.refreshMissingStatuses();
    final inboxItems = await _libraryStore.inboxItems(limit: 6);
    final recentItems = await _libraryStore.recentItems(limit: 6);
    final sourceGroups = await _studyCardStore.sourceGroups();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _inboxItems = inboxItems;
      _recentItems = recentItems;
      _sourceGroupsByPath = <String, StudySourceGroup>{
        for (final group in sourceGroups) _sourceKey(group.sourcePath): group,
      };
    });
  }

  Future<void> _rebuildIndex() async {
    setState(() {
      _busy = true;
      _status = '正在重建索引...';
    });
    try {
      final entries = await _service.rebuildIndex(
        onProgress: (message) {
          if (!mounted) return;
          setState(() => _status = message);
        },
      );
      if (!mounted) return;
      setState(() {
        _status = '索引完成：${entries.length} 个文件。';
      });
      await _loadSummary();
      await _search();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '索引失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <MaterialSearchResult>[];
        _selectedResultIds.clear();
        _status = '输入关键词搜索本地资料。';
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在搜索...';
    });
    try {
      final results = await _service.search(
        query: query,
        sourceType: _sourceFilter,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _selectedResultIds.removeWhere(
          (id) => results.every((item) => item.entry.id != id),
        );
        _status = results.isEmpty ? '没有匹配结果。' : '找到 ${results.length} 条结果。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCardFromSearchResult(MaterialSearchResult result) async {
    final draft = _reviewService.draftFromSearchResult(result);
    final frontController = TextEditingController(text: draft.front);
    final backController = TextEditingController(text: draft.back);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('用当前片段生成复习卡'),
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
    if (saved != true || frontController.text.trim().isEmpty) {
      return;
    }
    final createResult = await _reviewService
        .createCards(<MaterialReviewCardDraft>[
          draft.copyWith(
            front: frontController.text,
            back: backController.text,
            sourceSnippet: backController.text,
          ),
        ], _studyCardStore);
    if (!mounted) return;
    await _loadSummary();
    if (!mounted) return;
    final message = createResult.successCount > 0 ? '已生成复习卡片' : '复习卡片生成失败';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createCardsFromSelectedResults() async {
    final drafts = _results
        .where((result) => _selectedResultIds.contains(result.entry.id))
        .map(_reviewService.draftFromSearchResult)
        .toList();
    if (drafts.isEmpty) return;
    final decks = await _studyCardStore.loadDecks();
    if (!mounted) return;
    final confirmed = await showDialog<List<MaterialReviewCardDraft>>(
      context: context,
      builder: (_) => _BatchCardDraftDialog(drafts: drafts, decks: decks),
    );
    if (confirmed == null || confirmed.isEmpty) return;
    final result = await _reviewService.createCards(confirmed, _studyCardStore);
    if (!mounted) return;
    setState(() => _selectedResultIds.clear());
    await _loadSummary();
    if (!mounted) return;
    final suffix = result.hasErrors ? '，${result.errors.length} 条失败' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已生成 ${result.successCount} 张复习卡$suffix')),
    );
  }

  void _toggleResultSelection(MaterialSearchResult result, bool selected) {
    setState(() {
      if (selected) {
        _selectedResultIds.add(result.entry.id);
      } else {
        _selectedResultIds.remove(result.entry.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final selectedCount = _selectedResultIds.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialContextTitle ?? '资料搜索'),
        actions: [
          _HeaderActionButton(
            tooltip: '资料建议',
            icon: Icons.tips_and_updates_outlined,
            onPressed: () => _showSupportSheet(
              title: '资料智能建议',
              child: const SmartInlinePanel(
                title: '资料智能建议',
                types: {SmartInsightType.material, SmartInsightType.review},
                showReasons: true,
              ),
            ),
          ),
          const ContextHelpHint(
            title: '资料页帮助',
            iconOnly: true,
            tips: [
              '首次使用资料搜索前先重建索引，PDF、文本和网页归档才会进入搜索范围。',
              '资料缺失只会提示，不会自动删除资料库记录。',
              '搜索片段可以生成复习卡，来源路径和片段会保留在卡片里。',
              '网页归档失败通常是登录态页面、403 或超时，可手动保存链接。',
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _MaterialSearchHeader(
            contextTitle: widget.initialContextTitle,
            queryController: _queryController,
            sourceFilter: _sourceFilter,
            summary: summary,
            status: _status,
            busy: _busy,
            resultCount: _results.length,
            selectedCount: selectedCount,
            onSearch: _search,
            onRebuildIndex: _rebuildIndex,
            onSourceChanged: (value) {
              setState(() => _sourceFilter = value);
              _search();
            },
          ),
          _MaterialLibraryOverviewSheet(
            summary: summary,
            inboxItems: _inboxItems,
            recentItems: _recentItems,
            sourceGroupsByPath: _sourceGroupsByPath,
            onOpen: _openLibraryItem,
            onViewCards: _showSourceCards,
            onArchive: (item) =>
                _setLibraryStatus(item, MaterialLibraryStatus.archived),
            onIgnore: (item) =>
                _setLibraryStatus(item, MaterialLibraryStatus.ignored),
          ),
          if (selectedCount > 0)
            _MaterialSelectionBar(
              count: selectedCount,
              onClear: () => setState(() => _selectedResultIds.clear()),
              onCreateCards: _createCardsFromSelectedResults,
            ),
          Expanded(
            child: _results.isEmpty
                ? _MaterialEmptySearchState(
                    hasQuery: _queryController.text.trim().isNotEmpty,
                    hasIndex: (summary?.indexed ?? 0) > 0,
                    query: _queryController.text.trim(),
                    sourceFilter: _sourceFilter,
                    onClearFilter: _sourceFilter == null
                        ? null
                        : () {
                            setState(() => _sourceFilter = null);
                            _search();
                          },
                    onRebuildIndex: _busy ? null : _rebuildIndex,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            final entry = result.entry;
                            final selected = _selectedResultIds.contains(
                              entry.id,
                            );
                            final sourceGroup =
                                _sourceGroupsByPath[_sourceKey(entry.path)];
                            return _MaterialResultTile(
                              result: result,
                              sourceGroup: sourceGroup,
                              selected: selected,
                              onSelected: (value) =>
                                  _toggleResultSelection(result, value),
                              onPreview: () => FilePreviewPage.open(
                                context,
                                entry.path,
                                title: entry.name,
                              ),
                              onOpenFolder: () =>
                                  OpenFilex.open(p.dirname(entry.path)),
                              onCreateCard: () =>
                                  _createCardFromSearchResult(result),
                              onViewSourceCards: sourceGroup == null
                                  ? null
                                  : () => _showSourceCardsForPath(
                                      entry.path,
                                      fallbackName: entry.name,
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportSheet({
    required String title,
    required Widget child,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }

  static String _sourceLabel(MaterialSourceType type) {
    return switch (type) {
      MaterialSourceType.openListDownload => '云盘下载',
      MaterialSourceType.offlinePackage => '云盘离线包',
      MaterialSourceType.fileToolOutput => '文件工具输出',
      MaterialSourceType.studySource => '复习卡片来源',
      MaterialSourceType.webArchive => '网页归档',
    };
  }

  Future<void> _openLibraryItem(MaterialLibraryItem item) async {
    await FilePreviewPage.open(context, item.path, title: item.name);
    await _loadSummary();
  }

  Future<void> _showSourceCards(MaterialLibraryItem item) {
    return _showSourceCardsForPath(item.path, fallbackName: item.name);
  }

  Future<void> _showSourceCardsForPath(
    String path, {
    required String fallbackName,
  }) async {
    final cards = await _studyCardStore.cardsForSource(path);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SourceCardsSheet(
        title: fallbackName,
        path: path,
        cards: cards,
        onOpenSource: () =>
            FilePreviewPage.open(context, path, title: fallbackName),
        onOpenStudyCenter: () {
          Navigator.of(context).pop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const StudyCenterPage()));
        },
      ),
    );
    await _loadSummary();
  }

  Future<void> _setLibraryStatus(
    MaterialLibraryItem item,
    MaterialLibraryStatus status,
  ) async {
    await _libraryStore.setStatus(item.id, status);
    await _loadSummary();
  }

  static String _sourceKey(String path) {
    return p.normalize(path.trim()).toLowerCase();
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: IconButton(onPressed: onPressed, icon: Icon(icon)),
      ),
    );
  }
}

class _MaterialSearchHeader extends StatelessWidget {
  const _MaterialSearchHeader({
    required this.contextTitle,
    required this.queryController,
    required this.sourceFilter,
    required this.summary,
    required this.status,
    required this.busy,
    required this.resultCount,
    required this.selectedCount,
    required this.onSearch,
    required this.onRebuildIndex,
    required this.onSourceChanged,
  });

  final String? contextTitle;
  final TextEditingController queryController;
  final MaterialSourceType? sourceFilter;
  final MaterialIndexSummary? summary;
  final String status;
  final bool busy;
  final int resultCount;
  final int selectedCount;
  final VoidCallback onSearch;
  final VoidCallback onRebuildIndex;
  final ValueChanged<MaterialSourceType?> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contextTitle == null ? '资料检索工作台' : contextTitle!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: '重建索引',
                child: FilledButton.tonalIcon(
                  onPressed: busy ? null : onRebuildIndex,
                  icon: const Icon(Icons.manage_search_outlined),
                  label: const Text('重建索引'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Tooltip(
                      message: '搜索',
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: onSearch,
                      ),
                    ),
              hintText: '搜索文件名、课程名、网页标题、正文关键词',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 7),
          _MaterialSourceFilterBar(
            selected: sourceFilter,
            onChanged: onSourceChanged,
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusPill(
                icon: Icons.fact_check_outlined,
                label: summary == null
                    ? '索引读取中'
                    : '索引 ${summary!.indexed}/${summary!.total}',
              ),
              _StatusPill(
                icon: Icons.format_list_bulleted_rounded,
                label: resultCount == 0 ? '暂无结果' : '$resultCount 条结果',
              ),
              if (selectedCount > 0)
                _StatusPill(
                  icon: Icons.checklist_rounded,
                  label: '已选 $selectedCount',
                ),
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialSourceFilterBar extends StatelessWidget {
  const _MaterialSourceFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final MaterialSourceType? selected;
  final ValueChanged<MaterialSourceType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <({MaterialSourceType? value, String label})>[
      (value: null, label: '全部'),
      for (final type in MaterialSourceType.values)
        (value: type, label: _MaterialSearchPageState._sourceLabel(type)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips) ...[
            ChoiceChip(
              label: Text(chip.label),
              selected: selected == chip.value,
              onSelected: (_) => onChanged(chip.value),
              labelStyle: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MaterialEmptySearchState extends StatelessWidget {
  const _MaterialEmptySearchState({
    required this.hasQuery,
    required this.hasIndex,
    required this.query,
    required this.sourceFilter,
    required this.onClearFilter,
    required this.onRebuildIndex,
  });

  final bool hasQuery;
  final bool hasIndex;
  final String query;
  final MaterialSourceType? sourceFilter;
  final VoidCallback? onClearFilter;
  final VoidCallback? onRebuildIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = !hasIndex
        ? '先建立资料索引'
        : hasQuery
        ? '没有找到匹配资料'
        : '输入关键词开始检索';
    final message = !hasIndex
        ? '索引会覆盖资料库、网页归档、PDF/OCR 文本和文件工具输出；不会自动扫描或修改原文件。'
        : hasQuery
        ? '当前关键词“$query”没有结果，可以清空筛选、换关键词，或重建索引。'
        : '资料检索支持文件名、路径和正文片段。结果可预览、打开目录或生成复习卡。';
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > 0 ? constraints.maxHeight : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasIndex ? Icons.search_outlined : Icons.manage_search,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (!hasIndex)
                          FilledButton.icon(
                            onPressed: onRebuildIndex,
                            icon: const Icon(Icons.manage_search_outlined),
                            label: const Text('建立索引'),
                          ),
                        if (sourceFilter != null)
                          OutlinedButton.icon(
                            onPressed: onClearFilter,
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text('清空筛选'),
                          ),
                        if (hasIndex)
                          OutlinedButton.icon(
                            onPressed: onRebuildIndex,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重建索引'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MaterialResultTile extends StatelessWidget {
  const _MaterialResultTile({
    required this.result,
    required this.sourceGroup,
    required this.selected,
    required this.onSelected,
    required this.onPreview,
    required this.onOpenFolder,
    required this.onCreateCard,
    required this.onViewSourceCards,
  });

  final MaterialSearchResult result;
  final StudySourceGroup? sourceGroup;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPreview;
  final VoidCallback onOpenFolder;
  final VoidCallback onCreateCard;
  final VoidCallback? onViewSourceCards;

  @override
  Widget build(BuildContext context) {
    final entry = result.entry;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '资料结果 ${entry.name}',
      child: Material(
        color: selected
            ? colors.secondaryContainer.withValues(alpha: 0.72)
            : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelected(!selected),
          onLongPress: onPreview,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelected(value ?? false),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconForSource(entry.sourceType), size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SourceBadge(label: entry.sourceLabel),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        result.snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            entry.path,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (sourceGroup != null)
                            _SourceBadge(
                              label: _sourceGroupSummary(sourceGroup!),
                              subtle: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ResultActions(
                  onPreview: onPreview,
                  onOpenFolder: onOpenFolder,
                  onCreateCard: onCreateCard,
                  onViewSourceCards: onViewSourceCards,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _iconForSource(MaterialSourceType type) {
    return switch (type) {
      MaterialSourceType.openListDownload => Icons.cloud_download_outlined,
      MaterialSourceType.offlinePackage => Icons.inventory_2_outlined,
      MaterialSourceType.fileToolOutput => Icons.description_outlined,
      MaterialSourceType.studySource => Icons.style_outlined,
      MaterialSourceType.webArchive => Icons.public_outlined,
    };
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label, this.subtle = false});

  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: subtle
            ? colors.surfaceContainerHighest
            : colors.tertiaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.onPreview,
    required this.onOpenFolder,
    required this.onCreateCard,
    required this.onViewSourceCards,
  });

  final VoidCallback onPreview;
  final VoidCallback onOpenFolder;
  final VoidCallback onCreateCard;
  final VoidCallback? onViewSourceCards;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '预览',
          child: IconButton(
            onPressed: onPreview,
            icon: const Icon(Icons.visibility_outlined),
          ),
        ),
        Tooltip(
          message: '生成复习卡',
          child: IconButton(
            onPressed: onCreateCard,
            icon: const Icon(Icons.style_outlined),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '更多操作',
          onSelected: (value) {
            switch (value) {
              case 'folder':
                onOpenFolder();
              case 'card':
                onCreateCard();
              case 'sourceCards':
                onViewSourceCards?.call();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'folder', child: Text('系统打开')),
            const PopupMenuItem(value: 'card', child: Text('用当前片段生成复习卡')),
            if (onViewSourceCards != null)
              const PopupMenuItem(value: 'sourceCards', child: Text('查看来源卡片')),
          ],
        ),
      ],
    );
  }
}

class _MaterialLibraryOverviewSheet extends StatelessWidget {
  const _MaterialLibraryOverviewSheet({
    required this.summary,
    required this.inboxItems,
    required this.recentItems,
    required this.sourceGroupsByPath,
    required this.onOpen,
    required this.onViewCards,
    required this.onArchive,
    required this.onIgnore,
  });

  final MaterialIndexSummary? summary;
  final List<MaterialLibraryItem> inboxItems;
  final List<MaterialLibraryItem> recentItems;
  final Map<String, StudySourceGroup> sourceGroupsByPath;
  final ValueChanged<MaterialLibraryItem> onOpen;
  final ValueChanged<MaterialLibraryItem> onViewCards;
  final ValueChanged<MaterialLibraryItem> onArchive;
  final ValueChanged<MaterialLibraryItem> onIgnore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: const Icon(Icons.folder_copy_outlined),
        title: const Text('资料库概况'),
        subtitle: Text(
          summary == null
              ? '正在读取资料库状态'
              : '收件箱 ${inboxItems.length} · 最近 ${recentItems.length} · 索引 ${summary!.indexed}/${summary!.total}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          _MaterialOverview(
            summary: summary,
            inboxItems: inboxItems,
            recentItems: recentItems,
            sourceGroupsByPath: sourceGroupsByPath,
            onOpen: onOpen,
            onViewCards: onViewCards,
            onArchive: onArchive,
            onIgnore: onIgnore,
          ),
        ],
      ),
    );
  }
}

class _MaterialSelectionBar extends StatelessWidget {
  const _MaterialSelectionBar({
    required this.count,
    required this.onClear,
    required this.onCreateCards,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onCreateCards;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Icon(Icons.checklist_rounded, color: colors.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(child: Text('已选择 $count 条资料片段')),
            TextButton(onPressed: onClear, child: const Text('取消选择')),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onCreateCards,
              icon: const Icon(Icons.style_outlined),
              label: const Text('批量生成复习卡'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialOverview extends StatelessWidget {
  const _MaterialOverview({
    required this.summary,
    required this.inboxItems,
    required this.recentItems,
    required this.sourceGroupsByPath,
    required this.onOpen,
    required this.onViewCards,
    required this.onArchive,
    required this.onIgnore,
  });

  final MaterialIndexSummary? summary;
  final List<MaterialLibraryItem> inboxItems;
  final List<MaterialLibraryItem> recentItems;
  final Map<String, StudySourceGroup> sourceGroupsByPath;
  final ValueChanged<MaterialLibraryItem> onOpen;
  final ValueChanged<MaterialLibraryItem> onViewCards;
  final ValueChanged<MaterialLibraryItem> onArchive;
  final ValueChanged<MaterialLibraryItem> onIgnore;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 680;
    final lists = [
      _MaterialListCard(
        title: '资料收件箱',
        emptyText: '暂无待整理资料',
        items: inboxItems,
        sourceGroupsByPath: sourceGroupsByPath,
        onOpen: onOpen,
        onViewCards: onViewCards,
        onArchive: onArchive,
        onIgnore: onIgnore,
      ),
      _MaterialListCard(
        title: '最近资料',
        emptyText: '暂无最近打开',
        items: recentItems,
        sourceGroupsByPath: sourceGroupsByPath,
        onOpen: onOpen,
        onViewCards: onViewCards,
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                icon: Icons.move_to_inbox_outlined,
                label: '收件箱',
                value: '${inboxItems.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                icon: Icons.history_rounded,
                label: '最近打开',
                value: '${recentItems.length}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                icon: Icons.manage_search_outlined,
                label: '索引概览',
                value: summary == null
                    ? '--'
                    : '${summary!.indexed}/${summary!.total}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: lists[0]),
              const SizedBox(width: 8),
              Expanded(child: lists[1]),
            ],
          )
        else
          Column(children: [lists[0], const SizedBox(height: 8), lists[1]]),
      ],
    );
  }
}

class _BatchCardDraftDialog extends StatefulWidget {
  const _BatchCardDraftDialog({required this.drafts, required this.decks});

  final List<MaterialReviewCardDraft> drafts;
  final List<StudyDeck> decks;

  @override
  State<_BatchCardDraftDialog> createState() => _BatchCardDraftDialogState();
}

class _BatchCardDraftDialogState extends State<_BatchCardDraftDialog> {
  late String _deckId = widget.decks.isEmpty
      ? StudyCardStore.defaultDeckId
      : widget.decks.first.id;
  late final List<_SelectableDraft> _drafts = widget.drafts
      .map((draft) => _SelectableDraft(draft: draft))
      .toList();

  @override
  Widget build(BuildContext context) {
    final selectedCount = _drafts.where((item) => item.selected).length;
    return AlertDialog(
      title: const Text('批量生成复习卡'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.decks.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _deckId,
                decoration: const InputDecoration(labelText: '卡组'),
                items: widget.decks
                    .map(
                      (deck) => DropdownMenuItem(
                        value: deck.id,
                        child: Text(deck.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _deckId = value);
                },
              ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _drafts.length,
                itemBuilder: (context, index) {
                  final item = _drafts[index];
                  return CheckboxListTile(
                    value: item.selected,
                    onChanged: (value) {
                      setState(() => item.selected = value ?? false);
                    },
                    title: Text(
                      item.draft.front,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.draft.back,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: selectedCount == 0
              ? null
              : () => Navigator.pop(
                  context,
                  _drafts
                      .where((item) => item.selected)
                      .map((item) => item.draft.copyWith(deckId: _deckId))
                      .toList(),
                ),
          child: Text('保存 $selectedCount 张'),
        ),
      ],
    );
  }
}

class _SelectableDraft {
  _SelectableDraft({required this.draft}) : selected = true;

  final MaterialReviewCardDraft draft;
  bool selected;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialListCard extends StatelessWidget {
  const _MaterialListCard({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.sourceGroupsByPath,
    required this.onOpen,
    required this.onViewCards,
    this.onArchive,
    this.onIgnore,
  });

  final String title;
  final String emptyText;
  final List<MaterialLibraryItem> items;
  final Map<String, StudySourceGroup> sourceGroupsByPath;
  final ValueChanged<MaterialLibraryItem> onOpen;
  final ValueChanged<MaterialLibraryItem> onViewCards;
  final ValueChanged<MaterialLibraryItem>? onArchive;
  final ValueChanged<MaterialLibraryItem>? onIgnore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(child: Text(emptyText)),
              )
            else
              ...items.map((item) {
                final group =
                    sourceGroupsByPath[_MaterialSearchPageState._sourceKey(
                      item.path,
                    )];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconForStatus(item.status)),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    group == null
                        ? item.sourceLabel
                        : '${item.sourceLabel}\n${_sourceGroupSummary(group)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onOpen(item),
                  trailing:
                      onArchive == null && onIgnore == null && group == null
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'cards':
                                onViewCards(item);
                              case 'archive':
                                onArchive?.call(item);
                              case 'ignore':
                                onIgnore?.call(item);
                            }
                          },
                          itemBuilder: (_) => [
                            if (group != null)
                              const PopupMenuItem(
                                value: 'cards',
                                child: Text('查看来源卡片'),
                              ),
                            if (onArchive != null)
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('归档'),
                              ),
                            if (onIgnore != null)
                              const PopupMenuItem(
                                value: 'ignore',
                                child: Text('忽略'),
                              ),
                          ],
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }

  static IconData _iconForStatus(MaterialLibraryStatus status) {
    return switch (status) {
      MaterialLibraryStatus.indexError => Icons.error_outline,
      MaterialLibraryStatus.missing => Icons.link_off_outlined,
      MaterialLibraryStatus.archived => Icons.archive_outlined,
      MaterialLibraryStatus.ignored => Icons.visibility_off_outlined,
      MaterialLibraryStatus.inbox => Icons.insert_drive_file_outlined,
    };
  }
}

class _SourceCardsSheet extends StatelessWidget {
  const _SourceCardsSheet({
    required this.title,
    required this.path,
    required this.cards,
    required this.onOpenSource,
    required this.onOpenStudyCenter,
  });

  final String title;
  final String path;
  final List<StudyCard> cards;
  final VoidCallback onOpenSource;
  final VoidCallback onOpenStudyCenter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenSource,
                    icon: const Icon(Icons.open_in_new_outlined),
                    label: const Text('打开来源'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenStudyCenter,
                    icon: const Icon(Icons.style_outlined),
                    label: const Text('去复习中心'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('来源卡片 ${cards.length} 张', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Expanded(
                child: cards.isEmpty
                    ? const Center(child: Text('暂无来源卡片'))
                    : ListView.separated(
                        itemCount: cards.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return ListTile(
                            leading: const Icon(Icons.style_outlined),
                            title: Text(card.front),
                            subtitle: Text(
                              card.back,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sourceGroupSummary(StudySourceGroup group) {
  return '已制卡 ${group.cardCount} 张 / 今日到期 ${group.dueCount} 张';
}
