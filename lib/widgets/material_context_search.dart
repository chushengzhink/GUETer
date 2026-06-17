import 'dart:async';

import 'package:flutter/material.dart';

import '../materials/material_index_models.dart';
import '../materials/material_index_service.dart';
import '../materials/material_search_context.dart';
import '../pages/file_preview_page.dart';
import '../pages/material_search_page.dart';

class MaterialSearchLauncher {
  const MaterialSearchLauncher._();

  static Future<T?> open<T>(
    BuildContext context, {
    MaterialSearchContext? searchContext,
    String? query,
    MaterialSourceType? sourceType,
    String? title,
    bool autoSearch = true,
  }) {
    final effectiveQuery = query ?? searchContext?.normalizedQuery ?? '';
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => MaterialSearchPage(
          initialQuery: effectiveQuery,
          initialSourceType: sourceType ?? searchContext?.sourceType,
          initialContextTitle: title,
          autoSearch: autoSearch && effectiveQuery.trim().isNotEmpty,
        ),
      ),
    );
  }
}

class MaterialRelatedPanel extends StatefulWidget {
  const MaterialRelatedPanel({
    super.key,
    required this.contextData,
    this.title = '相关资料',
    this.service,
    this.maxItems = 3,
    this.compact = true,
  });

  final MaterialSearchContext contextData;
  final String title;
  final MaterialIndexService? service;
  final int maxItems;
  final bool compact;

  @override
  State<MaterialRelatedPanel> createState() => _MaterialRelatedPanelState();
}

class _MaterialRelatedPanelState extends State<MaterialRelatedPanel> {
  late final MaterialIndexService _service =
      widget.service ?? MaterialIndexService();
  late Future<_MaterialRelatedState> _future = _load();

  @override
  void didUpdateWidget(covariant MaterialRelatedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextData.normalizedQuery !=
            widget.contextData.normalizedQuery ||
        oldWidget.contextData.sourceType != widget.contextData.sourceType ||
        oldWidget.contextData.sourcePathPrefix !=
            widget.contextData.sourcePathPrefix) {
      _future = _load();
    }
  }

  Future<_MaterialRelatedState> _load() async {
    final summary = await _service.summary();
    if (summary.indexed == 0) {
      return _MaterialRelatedState(summary: summary);
    }
    final results = await _service.search(
      query: widget.contextData.normalizedQuery,
      sourceType: widget.contextData.sourceType,
      limit: widget.maxItems,
      contextTerms: widget.contextData.contextTerms,
      sourcePathPrefix: widget.contextData.sourcePathPrefix,
    );
    return _MaterialRelatedState(summary: summary, results: results);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MaterialRelatedState>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return _MaterialRelatedLoading(title: widget.title);
        }
        if (data == null) return const SizedBox.shrink();
        if (data.summary.indexed == 0) {
          return _MaterialIndexHint(
            title: widget.title,
            onOpenSearch: () => MaterialSearchLauncher.open(
              context,
              searchContext: widget.contextData,
              title: widget.title,
            ),
          );
        }
        if (data.results.isEmpty) {
          return _MaterialEmptyHint(
            title: widget.title,
            query: widget.contextData.normalizedQuery,
            onOpenSearch: () => MaterialSearchLauncher.open(
              context,
              searchContext: widget.contextData,
              title: widget.title,
            ),
          );
        }
        return _MaterialResultCard(
          title: widget.title,
          results: data.results,
          compact: widget.compact,
          onOpenAll: () => MaterialSearchLauncher.open(
            context,
            searchContext: widget.contextData,
            title: widget.title,
          ),
        );
      },
    );
  }
}

class MaterialInlineSearchPanel extends StatefulWidget {
  const MaterialInlineSearchPanel({
    super.key,
    required this.contextData,
    this.title = '查找资料',
    this.service,
    this.maxItems = 5,
  });

  final MaterialSearchContext contextData;
  final String title;
  final MaterialIndexService? service;
  final int maxItems;

  @override
  State<MaterialInlineSearchPanel> createState() =>
      _MaterialInlineSearchPanelState();
}

class _MaterialInlineSearchPanelState extends State<MaterialInlineSearchPanel> {
  late final MaterialIndexService _service =
      widget.service ?? MaterialIndexService();
  late final TextEditingController _controller = TextEditingController(
    text: widget.contextData.normalizedQuery,
  );
  Timer? _debounce;
  bool _loading = false;
  List<MaterialSearchResult> _results = const <MaterialSearchResult>[];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _search);
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty && widget.contextData.contextTerms.isEmpty) {
      setState(() => _results = const <MaterialSearchResult>[]);
      return;
    }
    setState(() => _loading = true);
    final results = await _service.search(
      query: query,
      sourceType: widget.contextData.sourceType,
      limit: widget.maxItems,
      contextTerms: widget.contextData.contextTerms,
      sourcePathPrefix: widget.contextData.sourcePathPrefix,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.manage_search_outlined,
                      size: 18,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '打开完整资料搜索',
                    child: TextButton(
                      onPressed: () => MaterialSearchLauncher.open(
                        context,
                        searchContext: widget.contextData,
                        query: _controller.text,
                        title: widget.title,
                      ),
                      child: const Text('更多'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                onChanged: (_) => _scheduleSearch(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  hintText: '搜索当前场景相关资料',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._results
                    .take(3)
                    .map((result) => _CompactMaterialResultRow(result: result)),
              ] else if (!_loading) ...[
                const SizedBox(height: 8),
                Text(
                  '暂无匹配资料，可换关键词或进入完整搜索。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialResultCard extends StatelessWidget {
  const _MaterialResultCard({
    required this.title,
    required this.results,
    required this.compact,
    required this.onOpenAll,
  });

  final String title;
  final List<MaterialSearchResult> results;
  final bool compact;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 9 : 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.travel_explore_outlined,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$title · ${results.length}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: '查看更多相关资料',
                    child: TextButton(
                      onPressed: onOpenAll,
                      child: const Text('更多'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...results
                  .take(3)
                  .map((result) => _CompactMaterialResultRow(result: result)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMaterialResultRow extends StatelessWidget {
  const _CompactMaterialResultRow({required this.result});

  final MaterialSearchResult result;

  @override
  Widget build(BuildContext context) {
    final entry = result.entry;
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: '预览 ${entry.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () =>
            FilePreviewPage.open(context, entry.path, title: entry.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file_outlined, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.sourceLabel} · ${result.snippet}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialRelatedLoading extends StatelessWidget {
  const _MaterialRelatedLoading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 18,
              color: colors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('正在查找$title...')),
          ],
        ),
      ),
    );
  }
}

class _MaterialIndexHint extends StatelessWidget {
  const _MaterialIndexHint({required this.title, required this.onOpenSearch});

  final String title;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return _MaterialHintStrip(
      icon: Icons.manage_search_outlined,
      title: title,
      message: '资料索引未建立，可进入资料搜索后手动重建。',
      actionLabel: '去搜索',
      onAction: onOpenSearch,
    );
  }
}

class _MaterialEmptyHint extends StatelessWidget {
  const _MaterialEmptyHint({
    required this.title,
    required this.query,
    required this.onOpenSearch,
  });

  final String title;
  final String query;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return _MaterialHintStrip(
      icon: Icons.search_off_outlined,
      title: title,
      message: query.isEmpty ? '没有找到相关资料。' : '没有找到与“$query”匹配的资料。',
      actionLabel: '调整',
      onAction: onOpenSearch,
    );
  }
}

class _MaterialHintStrip extends StatelessWidget {
  const _MaterialHintStrip({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          children: [
            Icon(icon, size: 19, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: actionLabel,
              child: TextButton(onPressed: onAction, child: Text(actionLabel)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialRelatedState {
  const _MaterialRelatedState({
    required this.summary,
    this.results = const <MaterialSearchResult>[],
  });

  final MaterialIndexSummary summary;
  final List<MaterialSearchResult> results;
}
