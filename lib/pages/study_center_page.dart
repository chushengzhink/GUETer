import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../materials/material_search_context.dart';
import '../smart/smart_models.dart';
import '../study/study_card_models.dart';
import '../study/study_card_store.dart';
import '../widgets/context_help.dart';
import '../widgets/material_context_search.dart';
import '../widgets/smart_inline_panel.dart';
import 'file_preview_page.dart';

class StudyCenterPage extends StatefulWidget {
  const StudyCenterPage({super.key, this.store});

  final StudyCardStore? store;

  @override
  State<StudyCenterPage> createState() => _StudyCenterPageState();
}

class _StudyCenterPageState extends State<StudyCenterPage> {
  late final StudyCardStore _store = widget.store ?? StudyCardStore();
  late Future<_StudyCenterData> _future = _load();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCardIds = <String>{};
  String? _deckFilterId;
  bool _sourceOnly = false;
  bool _dueOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_StudyCenterData> _load() async {
    final decks = await _store.loadDecks();
    final cards = await _store.loadCards();
    final summary = await _store.summary();
    final now = DateTime.now();
    final due = cards.where((card) => card.isDue(now)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final sourceGroups = await _store.sourceGroups(now: now);
    return _StudyCenterData(
      decks: decks,
      cards: cards,
      dueCards: due,
      sourceGroups: sourceGroups,
      summary: summary,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  void _clearSelection() {
    setState(() => _selectedCardIds.clear());
  }

  Future<void> _addCard({_StudyCenterData? data}) async {
    final result = await showDialog<_NewCardDraft>(
      context: context,
      builder: (_) => _NewCardDialog(decks: data?.decks ?? const []),
    );
    if (result == null) return;
    await _store.addCard(
      deckId: result.deckId,
      front: result.front,
      back: result.back,
    );
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('复习卡片已创建')));
  }

  Future<void> _addDeck() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建卡组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '卡组名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    await _store.addDeck(title);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _renameDeck(StudyDeck deck) async {
    final controller = TextEditingController(text: deck.title);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名卡组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '卡组名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    await _store.renameDeck(deck.id, title);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _deleteDeck(StudyDeck deck) async {
    if (deck.id == StudyCardStore.defaultDeckId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('默认卡组不能删除')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除卡组'),
        content: Text('删除“${deck.title}”后，卡片会移动到默认卡组。'),
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
    if (confirmed != true) return;
    await _store.deleteDeck(deck.id);
    if (!mounted) return;
    if (_deckFilterId == deck.id) _deckFilterId = null;
    _refresh();
  }

  Future<void> _editCard(StudyCard card, _StudyCenterData data) async {
    final result = await showDialog<_NewCardDraft>(
      context: context,
      builder: (_) => _NewCardDialog(
        decks: data.decks,
        initialDeckId: card.deckId,
        initialFront: card.front,
        initialBack: card.back,
        title: '编辑复习卡片',
      ),
    );
    if (result == null) return;
    await _store.updateCard(
      cardId: card.id,
      deckId: result.deckId,
      front: result.front,
      back: result.back,
    );
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('复习卡片已更新')));
  }

  Future<void> _moveCard(StudyCard card, _StudyCenterData data) async {
    final deckId = await _pickDeck(data.decks, initialDeckId: card.deckId);
    if (deckId == null) return;
    await _store.moveCard(card.id, deckId);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _moveSelectedCards(_StudyCenterData data) async {
    final deckId = await _pickDeck(data.decks);
    if (deckId == null) return;
    await _store.moveCards(_selectedCardIds.toList(), deckId);
    if (!mounted) return;
    _clearSelection();
    _refresh();
  }

  Future<void> _deleteSelectedCards() async {
    final count = _selectedCardIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('批量删除卡片'),
        content: Text('确认删除已选择的 $count 张卡片吗？'),
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
    if (confirmed != true) return;
    await _store.deleteCards(_selectedCardIds.toList());
    if (!mounted) return;
    _clearSelection();
    _refresh();
  }

  Future<String?> _pickDeck(
    List<StudyDeck> decks, {
    String? initialDeckId,
  }) async {
    var selected = initialDeckId ?? StudyCardStore.defaultDeckId;
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('选择卡组'),
        content: DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: '目标卡组'),
          items: decks
              .map(
                (deck) =>
                    DropdownMenuItem(value: deck.id, child: Text(deck.title)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) selected = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('移动'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCards() async {
    final bundle = await _store.exportBundle();
    final directory = await getTemporaryDirectory();
    final fileName =
        'study_cards_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsString(bundle.toJsonString(), flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'GUETer 复习卡备份');
  }

  Future<void> _importCards() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final raw = file.bytes == null
        ? file.path == null
              ? null
              : await File(file.path!).readAsString()
        : String.fromCharCodes(file.bytes!);
    if (raw == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导入失败：无法读取所选文件')));
      return;
    }
    final result = await _store.importBundle(raw);
    if (!mounted) return;
    _refresh();
    final message = result.hasErrors
        ? '导入失败：${result.errors.first}'
        : '导入完成：${result.importedCards} 张卡片，跳过 ${result.skippedCards} 张';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _review(StudyCard card, StudyReviewRating rating) async {
    await _store.reviewCard(card.id, rating);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _deleteCard(StudyCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除卡片'),
        content: Text('确认删除“${card.front}”？'),
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
    if (confirmed != true) return;
    await _store.deleteCard(card.id);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _openSource(StudyCard card) async {
    final path = card.sourcePath;
    if (path == null || path.trim().isEmpty) return;
    await _openSourcePath(path, title: card.sourceFileName);
  }

  Future<void> _openSourcePath(String path, {String? title}) async {
    if (!File(path).existsSync() && !Directory(path).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('来源文件不存在或已移动')));
      return;
    }
    await FilePreviewPage.open(context, path, title: title);
  }

  Future<void> _openSourceGroup(
    _StudyCenterData data,
    StudySourceGroup group,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _StudySourceGroupPage(
          group: group,
          deckTitle: data.deckTitle,
          onReview: _review,
          onDelete: _deleteCard,
          onOpenSource: () =>
              _openSourcePath(group.sourcePath, title: group.sourceFileName),
        ),
      ),
    );
    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('复习中心'),
        actions: [
          IconButton(
            tooltip: '新建卡组',
            onPressed: _addDeck,
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportCards();
                case 'import':
                  _importCards();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('导出复习卡')),
              PopupMenuItem(value: 'import', child: Text('导入复习卡')),
            ],
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<_StudyCenterData>(
        future: _future,
        builder: (context, snapshot) {
          return FloatingActionButton.extended(
            onPressed: () => _addCard(data: snapshot.data),
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('新建卡片'),
          );
        },
      ),
      body: FutureBuilder<_StudyCenterData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('复习数据读取失败：${snapshot.error}'));
          }
          final data = snapshot.data!;
          final filteredCards = data.filteredCards(
            query: _searchController.text,
            deckId: _deckFilterId,
            sourceOnly: _sourceOnly,
            dueOnly: _dueOnly,
          );
          _selectedCardIds.removeWhere(
            (id) => !data.cards.any((card) => card.id == id),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _SummaryPanel(summary: data.summary),
              const SizedBox(height: 12),
              const SmartInlinePanel(
                title: '复习智能建议',
                types: {SmartInsightType.today, SmartInsightType.review},
              ),
              const SizedBox(height: 8),
              const ContextHelpHint(
                title: '复习中心帮助',
                tips: [
                  '今日到期卡片会按 SM-2 到期时间提示，不会改变调度逻辑。',
                  '来源文件缺失只提示，不会删除复习卡。',
                  '空背面或过长背面适合尽快编辑，避免复习时无效记忆。',
                  '可以按资料来源查看同一文件生成的全部卡片。',
                ],
              ),
              const SizedBox(height: 12),
              _DeckPanel(
                decks: data.decks,
                cards: data.cards,
                onRenameDeck: _renameDeck,
                onDeleteDeck: _deleteDeck,
              ),
              const SizedBox(height: 12),
              _SourceGroupPanel(
                groups: data.sourceGroups,
                onOpenGroup: (group) => _openSourceGroup(data, group),
              ),
              const SizedBox(height: 12),
              Text('今日待复习', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (data.dueCards.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('今天没有到期卡片。'),
                  ),
                )
              else
                ...data.dueCards.map(
                  (card) => _ReviewCardTile(
                    card: card,
                    deckTitle: data.deckTitle(card.deckId),
                    onReview: (rating) => _review(card, rating),
                    onDelete: () => _deleteCard(card),
                    onOpenSource: () => _openSource(card),
                  ),
                ),
              const SizedBox(height: 16),
              Text('全部卡片', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _CardFilterPanel(
                searchController: _searchController,
                decks: data.decks,
                deckFilterId: _deckFilterId,
                sourceOnly: _sourceOnly,
                dueOnly: _dueOnly,
                onChanged: () => setState(() {}),
                onDeckChanged: (value) => setState(() => _deckFilterId = value),
                onSourceOnlyChanged: (value) =>
                    setState(() => _sourceOnly = value),
                onDueOnlyChanged: (value) => setState(() => _dueOnly = value),
              ),
              if (_selectedCardIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                _BatchCardActionBar(
                  count: _selectedCardIds.length,
                  onClear: _clearSelection,
                  onMove: () => _moveSelectedCards(data),
                  onDelete: _deleteSelectedCards,
                ),
              ],
              const SizedBox(height: 8),
              if (data.cards.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('还没有卡片，可以手动创建，或从文件预览中生成。'),
                  ),
                )
              else if (filteredCards.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('没有匹配的卡片。'),
                  ),
                )
              else
                ...filteredCards
                    .take(80)
                    .map(
                      (card) => ListTile(
                        leading: Checkbox(
                          value: _selectedCardIds.contains(card.id),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedCardIds.add(card.id);
                              } else {
                                _selectedCardIds.remove(card.id);
                              }
                            });
                          },
                        ),
                        title: _StudyCardListTitle(card: card),
                        subtitle: Text(
                          '${data.deckTitle(card.deckId)} · 下次 ${_formatDateTime(card.dueAt)}',
                        ),
                        onTap: () {
                          setState(() {
                            if (_selectedCardIds.contains(card.id)) {
                              _selectedCardIds.remove(card.id);
                            } else {
                              _selectedCardIds.add(card.id);
                            }
                          });
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _editCard(card, data);
                              case 'move':
                                _moveCard(card, data);
                              case 'source':
                                _openSource(card);
                              case 'delete':
                                _deleteCard(card);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            const PopupMenuItem(
                              value: 'move',
                              child: Text('移动卡组'),
                            ),
                            if (card.sourcePath?.trim().isNotEmpty == true)
                              const PopupMenuItem(
                                value: 'source',
                                child: Text('打开来源'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _StudyCenterData {
  const _StudyCenterData({
    required this.decks,
    required this.cards,
    required this.dueCards,
    required this.sourceGroups,
    required this.summary,
  });

  final List<StudyDeck> decks;
  final List<StudyCard> cards;
  final List<StudyCard> dueCards;
  final List<StudySourceGroup> sourceGroups;
  final StudySummary summary;

  String deckTitle(String deckId) {
    return decks
        .firstWhere((deck) => deck.id == deckId, orElse: () => decks.first)
        .title;
  }

  List<StudyCard> filteredCards({
    required String query,
    required String? deckId,
    required bool sourceOnly,
    required bool dueOnly,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final now = DateTime.now();
    return cards.where((card) {
      if (deckId != null && card.deckId != deckId) return false;
      if (sourceOnly && card.sourcePath?.trim().isNotEmpty != true) {
        return false;
      }
      if (dueOnly && !card.isDue(now)) return false;
      if (normalizedQuery.isEmpty) return true;
      return card.front.toLowerCase().contains(normalizedQuery) ||
          card.back.toLowerCase().contains(normalizedQuery) ||
          (card.sourceFileName ?? '').toLowerCase().contains(normalizedQuery) ||
          (card.sourceSnippet ?? '').toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}

class _CardFilterPanel extends StatelessWidget {
  const _CardFilterPanel({
    required this.searchController,
    required this.decks,
    required this.deckFilterId,
    required this.sourceOnly,
    required this.dueOnly,
    required this.onChanged,
    required this.onDeckChanged,
    required this.onSourceOnlyChanged,
    required this.onDueOnlyChanged,
  });

  final TextEditingController searchController;
  final List<StudyDeck> decks;
  final String? deckFilterId;
  final bool sourceOnly;
  final bool dueOnly;
  final VoidCallback onChanged;
  final ValueChanged<String?> onDeckChanged;
  final ValueChanged<bool> onSourceOnlyChanged;
  final ValueChanged<bool> onDueOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: '搜索卡片',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: deckFilterId,
                    decoration: const InputDecoration(
                      labelText: '卡组筛选',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部卡组'),
                      ),
                      ...decks.map(
                        (deck) => DropdownMenuItem<String?>(
                          value: deck.id,
                          child: Text(deck.title),
                        ),
                      ),
                    ],
                    onChanged: onDeckChanged,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('有来源'),
                  selected: sourceOnly,
                  onSelected: onSourceOnlyChanged,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('已到期'),
                  selected: dueOnly,
                  onSelected: onDueOnlyChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchCardActionBar extends StatelessWidget {
  const _BatchCardActionBar({
    required this.count,
    required this.onClear,
    required this.onMove,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text('已选择 $count 张卡片')),
            TextButton(onPressed: onClear, child: const Text('取消选择')),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onMove,
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('批量移动'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('批量删除'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.summary});

  final StudySummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Metric(label: '今日到期', value: '${summary.dueCards}'),
            _Metric(label: '全部卡片', value: '${summary.totalCards}'),
            _Metric(label: '卡组', value: '${summary.deckCount}'),
            _Metric(
              label: '下次复习',
              value: summary.nextDueAt == null
                  ? '暂无'
                  : _formatDateTime(summary.nextDueAt!),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckPanel extends StatelessWidget {
  const _DeckPanel({
    required this.decks,
    required this.cards,
    required this.onRenameDeck,
    required this.onDeleteDeck,
  });

  final List<StudyDeck> decks;
  final List<StudyCard> cards;
  final ValueChanged<StudyDeck> onRenameDeck;
  final ValueChanged<StudyDeck> onDeleteDeck;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('卡组', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: decks.map((deck) {
                final count = cards
                    .where((card) => card.deckId == deck.id)
                    .length;
                return InputChip(
                  avatar: const Icon(Icons.folder_outlined, size: 18),
                  label: Text('${deck.title} · $count'),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: const Text('重命名卡组'),
                              onTap: () {
                                Navigator.pop(context);
                                onRenameDeck(deck);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete_outline),
                              title: const Text('删除卡组'),
                              enabled: deck.id != StudyCardStore.defaultDeckId,
                              onTap: () {
                                Navigator.pop(context);
                                onDeleteDeck(deck);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceGroupPanel extends StatelessWidget {
  const _SourceGroupPanel({required this.groups, required this.onOpenGroup});

  final List<StudySourceGroup> groups;
  final ValueChanged<StudySourceGroup> onOpenGroup;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('资料来源', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (groups.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('还没有来自资料的复习卡片。'),
              )
            else ...[
              MaterialRelatedPanel(
                title: '复习来源相关资料',
                contextData: MaterialSearchContext.reviewSource(
                  sourceFileName: groups.first.sourceFileName,
                  sourcePath: groups.first.sourcePath,
                  limit: 3,
                ),
                maxItems: 3,
              ),
              const SizedBox(height: 8),
              ...groups
                  .take(8)
                  .map(
                    (group) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(
                        group.sourceFileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '已制卡 ${group.cardCount} 张 · 今日到期 ${group.dueCount} 张\n${group.sourcePath}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => onOpenGroup(group),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudySourceGroupPage extends StatelessWidget {
  const _StudySourceGroupPage({
    required this.group,
    required this.deckTitle,
    required this.onReview,
    required this.onDelete,
    required this.onOpenSource,
  });

  final StudySourceGroup group;
  final String Function(String deckId) deckTitle;
  final Future<void> Function(StudyCard card, StudyReviewRating rating)
  onReview;
  final Future<void> Function(StudyCard card) onDelete;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.sourceFileName),
        actions: [
          IconButton(
            tooltip: '打开来源',
            onPressed: onOpenSource,
            icon: const Icon(Icons.open_in_new_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.sourcePath,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Metric(label: '来源卡片', value: '${group.cardCount}'),
                      _Metric(label: '今日到期', value: '${group.dueCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          MaterialRelatedPanel(
            title: '同来源资料',
            contextData: MaterialSearchContext.reviewSource(
              sourceFileName: group.sourceFileName,
              sourcePath: group.sourcePath,
              limit: 4,
            ),
            maxItems: 4,
          ),
          const SizedBox(height: 12),
          ...group.cards.map(
            (card) => _ReviewCardTile(
              card: card,
              deckTitle: deckTitle(card.deckId),
              onReview: (rating) => onReview(card, rating),
              onDelete: () => onDelete(card),
              onOpenSource: onOpenSource,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCardTile extends StatelessWidget {
  const _ReviewCardTile({
    required this.card,
    required this.deckTitle,
    required this.onReview,
    required this.onDelete,
    required this.onOpenSource,
  });

  final StudyCard card;
  final String deckTitle;
  final ValueChanged<StudyReviewRating> onReview;
  final VoidCallback onDelete;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.style_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deckTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
                if (card.sourcePath?.trim().isNotEmpty == true)
                  IconButton(
                    tooltip: '打开来源',
                    onPressed: onOpenSource,
                    icon: const Icon(Icons.open_in_new_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              card.front,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (card.back.trim().isNotEmpty) ...[
              const Divider(height: 22),
              Text(card.back),
            ],
            if (card.sourceFileName?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                '来源：${card.sourceFileName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onReview(StudyReviewRating.forgot),
                  child: const Text('忘记'),
                ),
                OutlinedButton(
                  onPressed: () => onReview(StudyReviewRating.hard),
                  child: const Text('困难'),
                ),
                FilledButton.tonal(
                  onPressed: () => onReview(StudyReviewRating.good),
                  child: const Text('记得'),
                ),
                FilledButton(
                  onPressed: () => onReview(StudyReviewRating.easy),
                  child: const Text('简单'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyCardListTitle extends StatelessWidget {
  const _StudyCardListTitle({required this.card});

  final StudyCard card;

  @override
  Widget build(BuildContext context) {
    final source = card.sourceFileName?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(card.front),
        if (source != null && source.isNotEmpty)
          Text(
            '来源：$source',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NewCardDialog extends StatefulWidget {
  const _NewCardDialog({
    required this.decks,
    this.initialDeckId,
    this.initialFront = '',
    this.initialBack = '',
    this.title = '新建复习卡片',
  });

  final List<StudyDeck> decks;
  final String? initialDeckId;
  final String initialFront;
  final String initialBack;
  final String title;

  @override
  State<_NewCardDialog> createState() => _NewCardDialogState();
}

class _NewCardDialogState extends State<_NewCardDialog> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  late String _deckId = widget.decks.isEmpty
      ? StudyCardStore.defaultDeckId
      : (widget.initialDeckId ?? widget.decks.first.id);

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.initialFront);
    _back = TextEditingController(text: widget.initialBack);
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
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
            TextField(
              controller: _front,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '正面 / 问题'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _back,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(labelText: '背面 / 答案'),
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
          onPressed: () {
            if (_front.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _NewCardDraft(
                deckId: _deckId,
                front: _front.text,
                back: _back.text,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _NewCardDraft {
  const _NewCardDraft({
    required this.deckId,
    required this.front,
    required this.back,
  });

  final String deckId;
  final String front;
  final String back;
}

String _formatDateTime(DateTime time) {
  return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
