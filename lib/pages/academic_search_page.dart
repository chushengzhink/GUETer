import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../services/academic_api.dart';
import 'favorites_page.dart';
import 'paper_detail_page.dart';

class AcademicSearchPage extends StatefulWidget {
  const AcademicSearchPage({super.key});

  @override
  State<AcademicSearchPage> createState() => _AcademicSearchPageState();
}

class _AcademicSearchPageState extends State<AcademicSearchPage> {
  final AcademicApiService _academicApi = AcademicApiService();
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<AcademicSearchSnapshot>? _searchSubscription;
  List<AcademicPaper> _papers = <AcademicPaper>[];
  Set<String> _selectedKeys = <String>{};
  Set<AcademicSource> _failedSources = <AcademicSource>{};
  bool _isSearching = false;
  bool _isRefreshing = false;
  bool _isShowingCachedResults = false;
  bool _hasSearched = false;
  String _activeQuery = '';
  String _lastFailureSignature = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybePrefetchVisibleRange);
  }

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入搜索关键词')));
      return;
    }

    await _searchSubscription?.cancel();

    if (!mounted) {
      return;
    }

    setState(() {
      _activeQuery = query;
      _hasSearched = true;
      _isSearching = true;
      _isRefreshing = true;
      _isShowingCachedResults = false;
      _papers = <AcademicPaper>[];
      _selectedKeys = <String>{};
      _failedSources = <AcademicSource>{};
      _lastFailureSignature = '';
    });

    _searchSubscription = _academicApi
        .searchPapersStream(query)
        .listen(
          (AcademicSearchSnapshot snapshot) {
            if (!mounted) {
              return;
            }

            final validSelections = _selectedKeys
                .where(
                  (String key) => snapshot.papers.any(
                    (AcademicPaper paper) => paper.selectionKey == key,
                  ),
                )
                .toSet();

            setState(() {
              _papers = snapshot.papers;
              _selectedKeys = validSelections;
              _failedSources = snapshot.failedSources;
              _isShowingCachedResults = snapshot.isFromCache;
              _isRefreshing = snapshot.isRefreshing;
              _isSearching = snapshot.isRefreshing;
            });

            _showPartialFailureIfNeeded(snapshot.failedSources);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _maybePrefetchVisibleRange();
              }
            });
          },
          onError: (Object error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isSearching = false;
              _isRefreshing = false;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('搜索失败: $error')));
          },
          onDone: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _isSearching = false;
              _isRefreshing = false;
              _isShowingCachedResults = false;
            });
          },
        );
  }

  void _showPartialFailureIfNeeded(Set<AcademicSource> failedSources) {
    if (failedSources.isEmpty) {
      return;
    }

    final signature =
        failedSources.map((AcademicSource item) => item.name).toList()..sort();
    final normalizedSignature = signature.join(',');
    if (normalizedSignature == _lastFailureSignature) {
      return;
    }

    _lastFailureSignature = normalizedSignature;
    final sourceNames = failedSources
        .map((AcademicSource item) => item.displayName)
        .join('、');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('部分来源加载失败: $sourceNames')));
  }

  void _toggleSelection(AcademicPaper paper, bool selected) {
    setState(() {
      if (selected) {
        _selectedKeys.add(paper.selectionKey);
      } else {
        _selectedKeys.remove(paper.selectionKey);
      }
    });
  }

  List<AcademicPaper> _selectedPapers() {
    return _papers
        .where(
          (AcademicPaper paper) => _selectedKeys.contains(paper.selectionKey),
        )
        .toList();
  }

  Future<void> _copySelectedBibTex() async {
    final selected = _selectedPapers();
    if (selected.isEmpty) {
      return;
    }

    final bibtexList = <String>[];
    for (final AcademicPaper paper in selected) {
      bibtexList.add(await _academicApi.getBibTeX(paper));
    }

    await Clipboard.setData(ClipboardData(text: bibtexList.join('\n\n')));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${selected.length} 篇论文的 BibTeX')),
    );
  }

  Future<void> _exportSelectedPdf() async {
    final selected = _selectedPapers();
    if (selected.isEmpty) {
      return;
    }

    final bytes = await _academicApi.exportToPdf(selected);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'academic-papers-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已导出 ${selected.length} 篇论文 PDF')));
  }

  void _maybePrefetchVisibleRange() {
    if (!_scrollController.hasClients || _papers.isEmpty) {
      return;
    }

    const double estimatedItemExtent = 160;
    final firstVisibleIndex = (_scrollController.offset / estimatedItemExtent)
        .floor();
    final startIndex = firstVisibleIndex < 0 ? 0 : firstVisibleIndex;
    final endIndex = (startIndex + 5).clamp(0, _papers.length);

    for (int index = startIndex; index < endIndex; index++) {
      unawaited(_academicApi.prefetchPaperDetail(_papers[index]));
    }
  }

  Future<void> _openPaperDetail(AcademicPaper paper) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PaperDetailPage(paper: paper)));
  }

  Future<void> _openFavorites() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
  }

  Widget _buildSearchBar() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _performSearch(),
            decoration: const InputDecoration(
              hintText: '输入关键词搜索论文',
              prefixIcon: Icon(Icons.search_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _performSearch,
          icon: const Icon(Icons.travel_explore_outlined),
          label: const Text('搜索'),
        ),
      ],
    );
  }

  Widget _buildStatusBar() {
    final selectedCount = _selectedKeys.length;
    final failureText = _failedSources.isEmpty
        ? null
        : '失败来源: ${_failedSources.map((AcademicSource item) => item.displayName).join('、')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_isRefreshing) const LinearProgressIndicator(),
        if (_isRefreshing) const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            if (_activeQuery.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.tag_outlined, size: 18),
                label: Text('关键词: $_activeQuery'),
              ),
            if (_isShowingCachedResults)
              const Chip(
                avatar: Icon(Icons.history_toggle_off_outlined, size: 18),
                label: Text('缓存结果'),
              ),
            Chip(
              avatar: const Icon(Icons.library_books_outlined, size: 18),
              label: Text('结果: ${_papers.length}'),
            ),
            Chip(
              avatar: const Icon(Icons.checklist_outlined, size: 18),
              label: Text('已选: $selectedCount'),
            ),
          ],
        ),
        if (failureText != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            failureText,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final message = !_hasSearched
        ? '输入关键词后可同时搜索 CrossRef 和 arXiv。'
        : _isSearching
        ? '正在搜索论文...'
        : '没有找到匹配结果。';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperCard(AcademicPaper paper) {
    final selected = _selectedKeys.contains(paper.selectionKey);
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      paper.authorsText,
      paper.year?.toString() ?? '--',
      paper.source.displayName,
      '引用 ${paper.citationCount?.toString() ?? '--'}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openPaperDetail(paper),
        onLongPress: () => _toggleSelection(paper, !selected),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: selected,
                onChanged: (bool? value) =>
                    _toggleSelection(paper, value ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      paper.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitleParts.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if ((paper.venue ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        paper.venue!.trim(),
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedKeys.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('论文检索'),
        actions: <Widget>[
          IconButton(
            onPressed: _openFavorites,
            icon: const Icon(Icons.star_outline),
            tooltip: '我的收藏',
          ),
        ],
      ),
      bottomNavigationBar: _papers.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selectedCount == 0
                            ? null
                            : _copySelectedBibTex,
                        icon: const Icon(Icons.content_copy_outlined),
                        label: const Text('批量导出 BibTeX'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: selectedCount == 0
                            ? null
                            : _exportSelectedPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('批量导出 PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: <Widget>[
                _buildSearchBar(),
                const SizedBox(height: 12),
                _buildStatusBar(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _papers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _papers.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildPaperCard(_papers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
