import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/academic_api.dart';

class PaperDetailPage extends StatefulWidget {
  const PaperDetailPage({super.key, required this.paper});

  final AcademicPaper paper;

  @override
  State<PaperDetailPage> createState() => _PaperDetailPageState();
}

class _PaperDetailPageState extends State<PaperDetailPage> {
  final AcademicApiService _academicApi = AcademicApiService();

  late AcademicPaper _paper;
  List<AcademicReference> _references = <AcademicReference>[];
  List<AcademicNote> _notes = <AcademicNote>[];
  String _bibtex = '';
  bool _loading = true;
  bool _favoriteLoading = false;
  bool _isFavorite = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _paper = widget.paper;
    _loadPageData();
  }

  Future<void> _loadPageData() async {
    final favorite = await _academicApi.getFavoritePaper(_paper.stableKey);
    if (favorite != null) {
      _paper = favorite;
    }

    final favoriteFuture = _academicApi.isFavorite(_paper.stableKey);
    final notesFuture = _academicApi.getNotes(_paper.stableKey);

    try {
      final detail = await _academicApi.getPaperDetail(
        _paper.id,
        _paper.source,
      );
      final bibtex = await _academicApi.getBibTeX(detail);

      List<AcademicReference> references = <AcademicReference>[];
      if (detail.source == AcademicSource.crossRef &&
          (detail.doi ?? '').trim().isNotEmpty) {
        references = await _academicApi.getReferences(detail.doi!);
      }

      final isFavorite = await favoriteFuture;
      final notes = await notesFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _paper = detail;
        _bibtex = bibtex;
        _references = references;
        _notes = notes;
        _isFavorite = isFavorite;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      final fallbackBibtex = await _academicApi.getBibTeX(_paper);
      final isFavorite = await favoriteFuture;
      final notes = await notesFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _bibtex = fallbackBibtex;
        _notes = notes;
        _isFavorite = isFavorite;
        _loading = false;
      });
    }
  }

  Future<void> _reloadNotes() async {
    final notes = await _academicApi.getNotes(_paper.stableKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
    });
  }

  Future<void> _refreshEnrichedFavorite() async {
    final favorite = await _academicApi.getFavoritePaper(_paper.stableKey);
    final bibtex = await _academicApi.getBibTeX(favorite ?? _paper);
    if (!mounted) {
      return;
    }
    setState(() {
      if (favorite != null) {
        _paper = favorite;
      }
      _bibtex = bibtex;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteLoading) {
      return;
    }

    setState(() {
      _favoriteLoading = true;
    });

    try {
      if (_isFavorite) {
        await _academicApi.removeFromFavorites(_paper.stableKey);
      } else {
        await _academicApi.addToFavorites(_paper);
      }
      final updatedFavorite = await _academicApi.isFavorite(_paper.stableKey);
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite = updatedFavorite;
      });
      if (updatedFavorite) {
        await _refreshEnrichedFavorite();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updatedFavorite ? '已加入收藏' : '已取消收藏')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _favoriteLoading = false;
        });
      }
    }
  }

  Future<void> _copyBibtex() async {
    await Clipboard.setData(ClipboardData(text: _bibtex));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('BibTeX 已复制到剪贴板')));
  }

  Future<void> _exportCurrentPaperPdf() async {
    setState(() {
      _exporting = true;
    });

    try {
      final bytes = await _academicApi.exportToPdf(<AcademicPaper>[_paper]);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'paper-${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _openOriginalPdf() async {
    final pdfUrl = _paper.pdfUrl;
    if (pdfUrl == null || pdfUrl.trim().isEmpty) {
      return;
    }

    final uri = Uri.tryParse(pdfUrl);
    if (uri == null) {
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开原文 PDF')));
  }

  Future<void> _openReferenceDetail(AcademicReference reference) async {
    if ((reference.doi ?? '').trim().isEmpty) {
      return;
    }

    final referencePaper = AcademicPaper(
      id: reference.doi!,
      source: AcademicSource.crossRef,
      title: reference.title,
      authors: reference.authorsText == 'Unknown'
          ? const <String>[]
          : reference.authorsText
                .split(',')
                .map((String item) => item.trim())
                .where((String item) => item.isNotEmpty)
                .toList(),
      year: reference.year,
      venue: reference.journal,
      doi: reference.doi,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PaperDetailPage(paper: referencePaper)),
    );
  }

  Future<void> _showNoteEditor({AcademicNote? note}) async {
    final controller = TextEditingController(text: note?.content ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(note == null ? '新增笔记' : '编辑笔记'),
          content: TextField(
            controller: controller,
            maxLines: 10,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: '支持纯文本或简单 Markdown',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    if (note == null) {
      await _academicApi.addNote(_paper.stableKey, result);
    } else {
      await _academicApi.updateNote(_paper.stableKey, note.id, result);
    }
    await _reloadNotes();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(note == null ? '笔记已添加' : '笔记已更新')));
  }

  Future<void> _deleteNote(AcademicNote note) async {
    await _academicApi.deleteNote(_paper.stableKey, note.id);
    await _reloadNotes();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('笔记已删除')));
  }

  String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _metadataSourceLabel(String raw) {
    switch (raw) {
      case 'crossRef':
        return 'CrossRef';
      case 'semanticScholar':
        return 'Semantic Scholar';
      case 'arxiv':
        return 'arXiv';
      default:
        return raw;
    }
  }

  String _metadataFieldLabel(String raw) {
    switch (raw) {
      case 'venue':
        return '期刊/会议';
      case 'abstractText':
        return '摘要';
      case 'doi':
        return 'DOI';
      case 'volume':
        return '卷';
      case 'issue':
        return '期';
      case 'pages':
        return '页码';
      case 'pdfUrl':
        return 'PDF';
      case 'detailUrl':
        return '详情链接';
      case 'year':
        return '年份';
      default:
        return raw;
    }
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    List<Widget> actions = const <Widget>[],
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata() {
    final items = <MapEntry<String, String>>[
      MapEntry('来源', _paper.source.displayName),
      MapEntry('作者', _paper.authorsText),
      MapEntry('年份', _paper.year?.toString() ?? '--'),
      MapEntry(
        '期刊/会议',
        _paper.venue?.trim().isNotEmpty == true ? _paper.venue!.trim() : '--',
      ),
      MapEntry('DOI', _paper.doi ?? '--'),
      MapEntry('引用量', _paper.citationCount?.toString() ?? '--'),
      MapEntry('卷', _paper.volume ?? '--'),
      MapEntry('期', _paper.issue ?? '--'),
      MapEntry('页码', _paper.pages ?? '--'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...items.map(
          (MapEntry<String, String> item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 88,
                  child: Text(
                    item.key,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    item.value,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_paper.metadataOrigins.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '数据来源',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _paper.metadataOrigins.entries.map((
              MapEntry<String, String> entry,
            ) {
              return Chip(
                label: Text(
                  '${_metadataFieldLabel(entry.key)} · ${_metadataSourceLabel(entry.value)}',
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildReferenceList() {
    if (_paper.source != AcademicSource.crossRef ||
        (_paper.doi ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    if (_references.isEmpty) {
      return _buildSection(
        title: '参考文献',
        child: Text(
          _loading ? '正在加载参考文献...' : '暂无可用参考文献。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return _buildSection(
      title: '参考文献',
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        children: _references.map((AcademicReference reference) {
          final canOpen = (reference.doi ?? '').trim().isNotEmpty;
          return ListTile(
            leading: Icon(
              canOpen ? Icons.article_outlined : Icons.notes_outlined,
            ),
            title: Text(reference.title),
            subtitle: Text(
              reference.rawCitation ?? reference.authorsText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: canOpen ? const Icon(Icons.chevron_right) : null,
            onTap: canOpen ? () => _openReferenceDetail(reference) : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotesSection() {
    return _buildSection(
      title: '笔记',
      actions: <Widget>[
        IconButton(
          onPressed: () => _showNoteEditor(),
          icon: const Icon(Icons.add_comment_outlined),
          tooltip: '新增笔记',
        ),
      ],
      padding: EdgeInsets.zero,
      child: _notes.isEmpty
          ? const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('还没有笔记，点击右上角按钮添加。'),
            )
          : Column(
              children: _notes.map((AcademicNote note) {
                return ExpansionTile(
                  title: Text(
                    note.content.split('\n').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '创建于 ${_formatDateTime(note.createdAt)}'
                    '${note.updatedAt != note.createdAt ? ' · 更新于 ${_formatDateTime(note.updatedAt)}' : ''}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MarkdownBody(data: note.content),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: () => _showNoteEditor(note: note),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('编辑'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _deleteNote(note),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除'),
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('论文详情'),
        actions: <Widget>[
          IconButton(
            onPressed: _favoriteLoading ? null : _toggleFavorite,
            icon: _favoriteLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isFavorite ? Icons.star : Icons.star_border_outlined),
            tooltip: _isFavorite ? '取消收藏' : '加入收藏',
          ),
          IconButton(
            onPressed: _exporting ? null : _exportCurrentPaperPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: '导出 PDF',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _bibtex.trim().isEmpty ? null : _copyBibtex,
            icon: const Icon(Icons.content_copy_outlined),
            label: const Text('复制引用'),
          ),
        ),
      ),
      body: _loading && !_paper.hasDetailData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: <Widget>[
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _paper.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            Chip(label: Text(_paper.source.displayName)),
                            Chip(
                              label: Text(
                                '引用 ${_paper.citationCount?.toString() ?? '--'}',
                              ),
                            ),
                            if (_isFavorite) const Chip(label: Text('已收藏')),
                          ],
                        ),
                        if (_paper.source == AcademicSource.arxiv &&
                            (_paper.pdfUrl ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _openOriginalPdf,
                            icon: const Icon(Icons.open_in_new_outlined),
                            label: const Text('打开原文 PDF'),
                          ),
                        ],
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            '部分详情加载失败: $_error',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildSection(title: '基本信息', child: _buildMetadata()),
                if ((_paper.abstractText ?? '').trim().isNotEmpty)
                  _buildSection(
                    title: '摘要',
                    child: SelectableText(_paper.abstractText!.trim()),
                  ),
                _buildSection(
                  title: 'BibTeX',
                  child: SelectableText(
                    _bibtex.trim().isEmpty ? '暂无 BibTeX' : _bibtex,
                  ),
                ),
                _buildReferenceList(),
                _buildNotesSection(),
              ],
            ),
    );
  }
}
