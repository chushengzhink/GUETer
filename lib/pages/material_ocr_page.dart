import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../materials/material_index_models.dart';
import '../materials/material_index_service.dart';
import '../materials/material_ocr_service.dart';
import '../materials/material_review_service.dart';
import '../study/study_card_models.dart';
import '../study/study_card_store.dart';
import 'file_preview_page.dart';

class MaterialOcrPage extends StatefulWidget {
  const MaterialOcrPage({
    super.key,
    this.ocrService,
    this.indexService,
    this.studyCardStore,
    this.reviewService,
  });

  final MaterialOcrService? ocrService;
  final MaterialIndexService? indexService;
  final StudyCardStore? studyCardStore;
  final MaterialReviewService? reviewService;

  @override
  State<MaterialOcrPage> createState() => _MaterialOcrPageState();
}

class _MaterialOcrPageState extends State<MaterialOcrPage> {
  late final MaterialOcrService _ocrService =
      widget.ocrService ?? const MaterialOcrService();
  late final MaterialIndexService _indexService =
      widget.indexService ?? MaterialIndexService();
  late final StudyCardStore _studyCardStore =
      widget.studyCardStore ?? StudyCardStore();
  late final MaterialReviewService _reviewService =
      widget.reviewService ?? const MaterialReviewService();
  final ImagePicker _picker = ImagePicker();

  String? _imagePath;
  MaterialOcrResult? _result;
  bool _busy = false;
  String _status = '选择图片或拍照后开始识别。';

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.firstOrNull?.path;
    if (path == null || path.isEmpty) return;
    setState(() {
      _imagePath = path;
      _result = null;
      _status = '已选择 ${path.split(Platform.pathSeparator).last}';
    });
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    setState(() {
      _imagePath = file.path;
      _result = null;
      _status = '已拍照，准备识别。';
    });
  }

  Future<void> _recognize() async {
    final path = _imagePath;
    if (path == null || path.isEmpty) return;
    setState(() {
      _busy = true;
      _status = '正在识别...';
    });
    try {
      final result = await _ocrService.recognizeImage(path);
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = result.text.isEmpty ? '未识别到文字。' : '识别完成。';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'OCR 失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyText() async {
    final text = _result?.text ?? '';
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OCR 文本已复制')));
  }

  Future<void> _saveText() async {
    final result = _result;
    if (result == null || result.text.isEmpty) return;
    final file = await _ocrService.saveText(result);
    await _indexService.indexExternalFile(
      path: file.path,
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: 'OCR 文本',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已保存：${file.path}')));
    await FilePreviewPage.open(context, file.path, title: 'OCR 文本');
  }

  Future<void> _createCard() async {
    final result = _result;
    if (result == null || result.text.isEmpty) return;
    final fileName = p.basename(result.sourcePath);
    final drafts = _reviewService.draftsFromText(
      sourcePath: result.sourcePath,
      sourceName: fileName,
      text: result.text,
    );
    if (drafts.isEmpty) return;
    final decks = await _studyCardStore.loadDecks();
    if (!mounted) return;
    final confirmed = await showDialog<List<MaterialReviewCardDraft>>(
      context: context,
      builder: (_) => _OcrDraftDialog(drafts: drafts, decks: decks),
    );
    if (confirmed == null || confirmed.isEmpty) return;
    final createResult = await _reviewService.createCards(
      confirmed,
      _studyCardStore,
    );
    setState(() => _status = '已生成 ${createResult.successCount} 张复习卡');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已生成复习卡片')));
  }

  @override
  Widget build(BuildContext context) {
    final supported = _ocrService.isSupported;
    return Scaffold(
      appBar: AppBar(title: const Text('资料扫描 OCR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!supported)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('当前平台暂不支持本地 OCR。你仍可使用资料搜索和复习卡片功能。'),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('选择图片'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !supported ? null : _takePhoto,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('拍照'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || !supported || _imagePath == null
                            ? null
                            : _recognize,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('开始识别'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_imagePath!),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      if (_busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_busy) const SizedBox(width: 8),
                      Expanded(child: Text(_status)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('识别结果', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText(
                    _result?.text.isNotEmpty == true ? _result!.text : '暂无文本',
                    style: const TextStyle(height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _result?.text.isNotEmpty == true
                            ? _copyText
                            : null,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('复制'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _result?.text.isNotEmpty == true
                            ? _saveText
                            : null,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存 TXT'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _result?.text.isNotEmpty == true
                            ? _createCard
                            : null,
                        icon: const Icon(Icons.style_outlined),
                        label: const Text('生成卡片'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrDraftDialog extends StatefulWidget {
  const _OcrDraftDialog({required this.drafts, required this.decks});

  final List<MaterialReviewCardDraft> drafts;
  final List<StudyDeck> decks;

  @override
  State<_OcrDraftDialog> createState() => _OcrDraftDialogState();
}

class _OcrDraftDialogState extends State<_OcrDraftDialog> {
  late String _deckId = widget.decks.isEmpty
      ? StudyCardStore.defaultDeckId
      : widget.decks.first.id;
  late final List<_SelectableOcrDraft> _drafts = widget.drafts
      .map((draft) => _SelectableOcrDraft(draft: draft))
      .toList();

  @override
  Widget build(BuildContext context) {
    final selectedCount = _drafts.where((item) => item.selected).length;
    return AlertDialog(
      title: const Text('生成 OCR 复习卡'),
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

class _SelectableOcrDraft {
  _SelectableOcrDraft({required this.draft}) : selected = true;

  final MaterialReviewCardDraft draft;
  bool selected;
}
