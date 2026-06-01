import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../services/academic_api.dart';
import 'paper_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final AcademicApiService _academicApi = AcademicApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AcademicPaper> _favorites = <AcademicPaper>[];
  Set<String> _selectedKeys = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _academicApi.getFavorites();
    if (!mounted) {
      return;
    }

    final validSelections = _selectedKeys
        .where(
          (String key) =>
              favorites.any((AcademicPaper paper) => paper.selectionKey == key),
        )
        .toSet();

    setState(() {
      _favorites = favorites;
      _selectedKeys = validSelections;
      _loading = false;
    });
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  List<AcademicPaper> get _filteredFavorites {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _favorites;
    }
    return _favorites
        .where(
          (AcademicPaper paper) => paper.title.toLowerCase().contains(query),
        )
        .toList();
  }

  List<AcademicPaper> get _selectedPapers {
    return _favorites
        .where(
          (AcademicPaper paper) => _selectedKeys.contains(paper.selectionKey),
        )
        .toList();
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

  Future<void> _removeFavorite(AcademicPaper paper) async {
    setState(() {
      _favorites = _favorites
          .where((AcademicPaper item) => item.stableKey != paper.stableKey)
          .toList();
      _selectedKeys.remove(paper.selectionKey);
    });
    await _academicApi.removeFromFavorites(paper.stableKey);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已移除收藏: ${paper.title}')));
  }

  Future<void> _copySelectedBibtex() async {
    final selected = _selectedPapers;
    if (selected.isEmpty) {
      return;
    }

    final bibtex = <String>[];
    for (final AcademicPaper paper in selected) {
      bibtex.add(await _academicApi.getBibTeX(paper));
    }

    await Clipboard.setData(ClipboardData(text: bibtex.join('\n\n')));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${selected.length} 篇论文的 BibTeX')),
    );
  }

  Future<void> _exportSelectedPdf() async {
    final selected = _selectedPapers;
    if (selected.isEmpty) {
      return;
    }

    final bytes = await _academicApi.exportToPdf(selected);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'favorite-papers-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已导出 ${selected.length} 篇论文 PDF')));
  }

  Future<void> _openDetail(AcademicPaper paper) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PaperDetailPage(paper: paper)));
    await _loadFavorites();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: '按标题搜索收藏',
        prefixIcon: Icon(Icons.search_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.star_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.trim().isEmpty ? '还没有收藏论文。' : '没有匹配的收藏结果。',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(AcademicPaper paper) {
    final selected = _selectedKeys.contains(paper.selectionKey);
    final subtitle = <String>[
      paper.authorsText,
      paper.year?.toString() ?? '--',
      paper.source.displayName,
      if (paper.favoritedAt != null)
        '收藏于 ${paper.favoritedAt!.year}-${paper.favoritedAt!.month.toString().padLeft(2, '0')}-${paper.favoritedAt!.day.toString().padLeft(2, '0')}',
    ].join(' · ');

    return Dismissible(
      key: ValueKey<String>(paper.stableKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => _removeFavorite(paper),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          onTap: () => _openDetail(paper),
          onLongPress: () => _toggleSelection(paper, !selected),
          leading: Checkbox(
            value: selected,
            onChanged: (bool? value) => _toggleSelection(paper, value ?? false),
          ),
          title: Text(
            paper.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedKeys.length;
    final visibleFavorites = _filteredFavorites;

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      bottomNavigationBar: _favorites.isEmpty
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
                            : _copySelectedBibtex,
                        icon: const Icon(Icons.content_copy_outlined),
                        label: const Text('批量复制 BibTeX'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildSearchField(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: <Widget>[
                      Chip(
                        avatar: const Icon(Icons.star_outline, size: 18),
                        label: Text('收藏 ${_favorites.length}'),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        avatar: const Icon(Icons.checklist_outlined, size: 18),
                        label: Text('已选 $selectedCount'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: visibleFavorites.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: visibleFavorites.length,
                          itemBuilder: (BuildContext context, int index) {
                            return _buildFavoriteItem(visibleFavorites[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
