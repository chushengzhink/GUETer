import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/file_tool_models.dart';
import '../materials/material_index_models.dart';
import '../materials/material_library_store.dart';
import '../materials/material_review_service.dart';
import '../materials/material_search_context.dart';
import '../plugins/plugin_runtime.dart';
import '../services/file_preview_service.dart';
import '../services/file_tool_service.dart';
import '../session/app_settings.dart';
import '../study/study_card_models.dart';
import '../study/study_card_store.dart';
import '../widgets/material_context_search.dart';

class FilePreviewPage extends StatefulWidget {
  const FilePreviewPage({
    super.key,
    required this.path,
    this.title,
    this.previewService,
    this.studyCardStore,
    this.reviewService,
  });

  final String path;
  final String? title;
  final FilePreviewService? previewService;
  final StudyCardStore? studyCardStore;
  final MaterialReviewService? reviewService;

  static Future<void> open(BuildContext context, String path, {String? title}) {
    MaterialLibraryStore()
        .recordOpened(
          path: path,
          name: title,
          sourceType: MaterialSourceType.fileToolOutput,
          sourceLabel: '本地资料',
        )
        .ignore();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FilePreviewPage(path: path, title: title),
      ),
    );
  }

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  late final FilePreviewService _service =
      widget.previewService ?? const FilePreviewService();
  final FileToolService _fileToolService = FileToolService();
  late final StudyCardStore _studyCardStore =
      widget.studyCardStore ?? StudyCardStore();
  late final MaterialReviewService _reviewService =
      widget.reviewService ?? const MaterialReviewService();
  late final Future<FilePreviewDescriptor> _descriptorFuture = _service
      .describe(widget.path);

  Future<void> _openExternal() async {
    final result = await OpenFilex.open(widget.path);
    if (!mounted || result.type == ResultType.done) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message.isEmpty ? '无法打开文件' : result.message),
      ),
    );
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.path));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('文件路径已复制')));
  }

  Future<void> _shareFile() async {
    await Share.shareXFiles([XFile(widget.path)], text: widget.title);
  }

  Future<void> _createStudyCardFromText(
    FilePreviewDescriptor descriptor,
    String text,
  ) async {
    final draft = _reviewService
        .draftsFromText(
          sourcePath: descriptor.path,
          sourceName: descriptor.name,
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
        title: const Text('转为复习卡片'),
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

  Future<void> _createStudyCardsFromText(
    FilePreviewDescriptor descriptor,
    String text,
  ) async {
    final drafts = _reviewService.draftsFromText(
      sourcePath: descriptor.path,
      sourceName: descriptor.name,
      text: text,
    );
    if (drafts.isEmpty) return;
    final decks = await _studyCardStore.loadDecks();
    if (!mounted) return;
    final confirmed = await showDialog<List<MaterialReviewCardDraft>>(
      context: context,
      builder: (_) => _TextDraftDialog(drafts: drafts, decks: decks),
    );
    if (confirmed == null || confirmed.isEmpty) return;
    final result = await _reviewService.createCards(confirmed, _studyCardStore);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已生成 ${result.successCount} 张复习卡')));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FilePreviewDescriptor>(
      future: _descriptorFuture,
      builder: (context, snapshot) {
        final descriptor = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title ?? descriptor?.name ?? '文件预览'),
            actions: [
              IconButton(
                tooltip: '复制路径',
                onPressed: descriptor == null ? null : _copyPath,
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                tooltip: '分享',
                onPressed: descriptor == null ? null : _shareFile,
                icon: const Icon(Icons.ios_share_outlined),
              ),
              IconButton(
                tooltip: '外部打开',
                onPressed: descriptor == null ? null : _openExternal,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
          body: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
              ? _PreviewError(
                  message: '读取文件失败：${snapshot.error}',
                  onExternalOpen: _openExternal,
                )
              : descriptor == null
              ? _PreviewError(message: '文件不存在', onExternalOpen: _openExternal)
              : _buildPreview(descriptor),
        );
      },
    );
  }

  Widget _buildPreview(FilePreviewDescriptor descriptor) {
    if (!descriptor.canPreview) {
      return _PreviewUnsupported(
        descriptor: descriptor,
        onExternalOpen: _openExternal,
      );
    }
    return Column(
      children: [
        _PreviewInfoStrip(descriptor: descriptor),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: MaterialRelatedPanel(
            title: '相似资料',
            contextData: MaterialSearchContext.filePreview(
              path: descriptor.path,
              title: descriptor.name,
              limit: 3,
            ),
            maxItems: 3,
          ),
        ),
        Expanded(
          child: switch (descriptor.kind) {
            FilePreviewKind.pdf => SfPdfViewer.file(File(descriptor.path)),
            FilePreviewKind.image => InteractiveViewer(
              child: Center(
                child: Image.file(File(descriptor.path), fit: BoxFit.contain),
              ),
            ),
            FilePreviewKind.markdown => _TextPreview(
              path: descriptor.path,
              kind: descriptor.kind,
              service: _service,
              markdown: true,
              onCreateStudyCard: (text) =>
                  _createStudyCardFromText(descriptor, text),
              onCreateStudyCards: (text) =>
                  _createStudyCardsFromText(descriptor, text),
            ),
            FilePreviewKind.text ||
            FilePreviewKind.json ||
            FilePreviewKind.csv => _TextPreview(
              path: descriptor.path,
              kind: descriptor.kind,
              service: _service,
              onCreateStudyCard: (text) =>
                  _createStudyCardFromText(descriptor, text),
              onCreateStudyCards: (text) =>
                  _createStudyCardsFromText(descriptor, text),
            ),
            FilePreviewKind.zip => _ZipPreview(
              path: descriptor.path,
              service: _fileToolService,
            ),
            FilePreviewKind.unsupported => _PreviewUnsupported(
              descriptor: descriptor,
              onExternalOpen: _openExternal,
            ),
          },
        ),
        _PluginFileActions(path: descriptor.path),
      ],
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({
    required this.path,
    required this.kind,
    required this.service,
    this.markdown = false,
    this.onCreateStudyCard,
    this.onCreateStudyCards,
  });

  final String path;
  final FilePreviewKind kind;
  final FilePreviewService service;
  final bool markdown;
  final ValueChanged<String>? onCreateStudyCard;
  final ValueChanged<String>? onCreateStudyCards;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: service.readTextPreview(path, kind),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('文本读取失败：${snapshot.error}'));
        }
        final text = snapshot.data ?? '';
        return Column(
          children: [
            if (onCreateStudyCard != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: text.trim().isEmpty
                            ? null
                            : () => onCreateStudyCard!(text),
                        icon: const Icon(Icons.style_outlined, size: 18),
                        label: const Text('转复习卡片'),
                      ),
                      if (onCreateStudyCards != null)
                        FilledButton.tonalIcon(
                          onPressed: text.trim().isEmpty
                              ? null
                              : () => onCreateStudyCards!(text),
                          icon: const Icon(
                            Icons.splitscreen_outlined,
                            size: 18,
                          ),
                          label: const Text('拆分成复习卡'),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: markdown
                  ? Markdown(data: text, padding: const EdgeInsets.all(16))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        text,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          height: 1.35,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TextDraftDialog extends StatefulWidget {
  const _TextDraftDialog({required this.drafts, required this.decks});

  final List<MaterialReviewCardDraft> drafts;
  final List<StudyDeck> decks;

  @override
  State<_TextDraftDialog> createState() => _TextDraftDialogState();
}

class _TextDraftDialogState extends State<_TextDraftDialog> {
  late String _deckId = widget.decks.isEmpty
      ? StudyCardStore.defaultDeckId
      : widget.decks.first.id;
  late final List<_SelectableTextDraft> _drafts = widget.drafts
      .map((draft) => _SelectableTextDraft(draft: draft))
      .toList();

  @override
  Widget build(BuildContext context) {
    final selectedCount = _drafts.where((item) => item.selected).length;
    return AlertDialog(
      title: const Text('拆分成复习卡'),
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

class _SelectableTextDraft {
  _SelectableTextDraft({required this.draft}) : selected = true;

  final MaterialReviewCardDraft draft;
  bool selected;
}

class _ZipPreview extends StatelessWidget {
  const _ZipPreview({required this.path, required this.service});

  final String path;
  final FileToolService service;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ZipPreview>(
      future: service.previewZip(zipFile: File(path)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('ZIP 预览失败：${snapshot.error}'));
        }
        final preview = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
            if (preview.hasUnsafeEntries)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const Text('检测到危险路径'),
                  subtitle: Text('${preview.skippedUnsafeCount} 个条目不会被自动解压。'),
                ),
              ),
            ...preview.entries.take(300).map((entry) {
              return ListTile(
                leading: Icon(
                  entry.isDirectory
                      ? Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
                ),
                title: Text(
                  entry.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  entry.isDirectory
                      ? '文件夹'
                      : FilePreviewService.formatBytes(entry.sizeBytes),
                ),
                trailing: entry.isSafe
                    ? const Icon(Icons.verified_outlined)
                    : const Icon(Icons.block, color: Colors.red),
              );
            }),
            if (preview.entries.length > 300)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('仅显示前 300 个条目。'),
              ),
          ],
        );
      },
    );
  }
}

class _PreviewInfoStrip extends StatelessWidget {
  const _PreviewInfoStrip({required this.descriptor});

  final FilePreviewDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Text(
        '${descriptor.extension.isEmpty ? '未知类型' : descriptor.extension} · '
        '${FilePreviewService.formatBytes(descriptor.sizeBytes)} · ${descriptor.path}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _PreviewUnsupported extends StatelessWidget {
  const _PreviewUnsupported({
    required this.descriptor,
    required this.onExternalOpen,
  });

  final FilePreviewDescriptor descriptor;
  final VoidCallback onExternalOpen;

  @override
  Widget build(BuildContext context) {
    return _PreviewError(
      message: descriptor.reason,
      onExternalOpen: onExternalOpen,
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.message, required this.onExternalOpen});

  final String message;
  final VoidCallback onExternalOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onExternalOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('外部打开'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginFileActions extends StatelessWidget {
  const _PluginFileActions({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final actions = PluginRuntime.filePreviewActions(
      AppSettings.pluginStore.enabledPluginsNotifier.value,
      path,
    );
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions.map((action) {
          return OutlinedButton.icon(
            onPressed: () => PluginRuntime.runEntry(
              context,
              action.manifest,
              action.entry,
              filePath: path,
            ),
            icon: Icon(PluginRuntime.iconFromName(action.entry.icon), size: 18),
            label: Text(action.entry.name.zh),
          );
        }).toList(),
      ),
    );
  }
}
