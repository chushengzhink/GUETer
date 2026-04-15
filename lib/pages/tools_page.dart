import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'reading.dart';

class _ToolTaskRecord {
  final String toolName;
  final String inputSummary;
  final String outputPath;
  final DateTime timestamp;
  final bool success;
  final String message;

  const _ToolTaskRecord({
    required this.toolName,
    required this.inputSummary,
    required this.outputPath,
    required this.timestamp,
    required this.success,
    required this.message,
  });
}

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  bool _busy = false;
  String _status = '请选择一个工具开始';
  String? _customOutputDir;
  String? _lastOutputPath;
  final List<_ToolTaskRecord> _recentTasks = <_ToolTaskRecord>[];

  static final List<Map<String, dynamic>> _watermarkColorOptions = [
    {'name': '深红', 'color': PdfColor(170, 30, 30)},
    {'name': '深蓝', 'color': PdfColor(30, 60, 170)},
    {'name': '深灰', 'color': PdfColor(70, 70, 70)},
    {'name': '黑色', 'color': PdfColor(25, 25, 25)},
  ];

  Future<void> _pickOutputDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 PDF 工具输出目录',
    );
    if (path == null || path.trim().isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _customOutputDir = path;
      _status = '输出目录已切换为: $path';
    });
  }

  void _resetOutputDirectory() {
    setState(() {
      _customOutputDir = null;
      _status = '输出目录已恢复为默认临时目录';
    });
  }

  Future<Directory> _outputDir() async {
    if (_customOutputDir != null && _customOutputDir!.trim().isNotEmpty) {
      final out = Directory(_customOutputDir!);
      if (!out.existsSync()) {
        out.createSync(recursive: true);
      }
      return out;
    }

    final dir = await getTemporaryDirectory();
    final out = Directory(p.join(dir.path, 'pdf_tools_output'));
    if (!out.existsSync()) {
      out.createSync(recursive: true);
    }
    return out;
  }

  Future<File?> _pickSinglePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final path = result.files.first.path;
    if (path == null || path.isEmpty) {
      return null;
    }
    return File(path);
  }

  Future<List<File>> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );
    if (result == null) {
      return <File>[];
    }
    return result.files
        .map((item) => item.path)
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .map(File.new)
        .toList();
  }

  Future<void> _runTool(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      await task();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = '执行失败: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('执行失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _recordTask({
    required String toolName,
    required String inputSummary,
    required String outputPath,
    required bool success,
    required String message,
  }) {
    _recentTasks.insert(
      0,
      _ToolTaskRecord(
        toolName: toolName,
        inputSummary: inputSummary,
        outputPath: outputPath,
        timestamp: DateTime.now(),
        success: success,
        message: message,
      ),
    );
    if (_recentTasks.length > 30) {
      _recentTasks.removeRange(30, _recentTasks.length);
    }
  }

  String _formatTime(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  Future<void> _openOutputFile() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;

    final result = await OpenFilex.open(path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败: ${result.message}')),
      );
    }
  }

  Future<void> _shareOutputFile() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;

    await Share.shareXFiles([XFile(path)], text: 'PDF 工具输出文件');
  }

  Future<void> _pdfToImages() async {
    final file = await _pickSinglePdf();
    if (file == null) return;

    final outDir = await _outputDir();
    final bytes = await file.readAsBytes();
    final stream = Printing.raster(bytes, dpi: 160);

    int index = 0;
    await for (final page in stream) {
      index += 1;
      final png = await page.toPng();
      final out = File(
        p.join(
          outDir.path,
          '${p.basenameWithoutExtension(file.path)}_p$index.png',
        ),
      );
      await out.writeAsBytes(png, flush: true);
    }

    if (!mounted) return;
    setState(() {
      _status = 'PDF 转图片完成，共导出 $index 张\n输出目录: ${outDir.path}';
      _lastOutputPath = outDir.path;
      _recordTask(
        toolName: 'PDF 转图片',
        inputSummary: p.basename(file.path),
        outputPath: outDir.path,
        success: true,
        message: '导出 $index 张 PNG',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF 转图片完成，共导出 $index 张')),
    );
  }

  Future<void> _imagesToPdf() async {
    final images = await _pickImages();
    if (images.isEmpty) return;

    final document = PdfDocument();
    for (final imageFile in images) {
      final imageBytes = await imageFile.readAsBytes();
      final bitmap = PdfBitmap(imageBytes);
      final page = document.pages.add();
      final size = page.getClientSize();
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    }

    final outDir = await _outputDir();
    final outFile = File(
      p.join(outDir.path, 'images_merged_${DateTime.now().millisecondsSinceEpoch}.pdf'),
    );
    await outFile.writeAsBytes(document.saveSync(), flush: true);
    document.dispose();

    if (!mounted) return;
    setState(() {
      _status = '图片合并 PDF 完成\n输出文件: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: '图片合并 PDF',
        inputSummary: '${images.length} 张图片',
        outputPath: outFile.path,
        success: true,
        message: '合并完成',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片合并 PDF 完成')),
    );
  }

  Future<void> _compressPdf() async {
    final file = await _pickSinglePdf();
    if (file == null) return;

    final inputBytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: inputBytes);
    document.compressionLevel = PdfCompressionLevel.best;

    final outDir = await _outputDir();
    final outFile = File(
      p.join(
        outDir.path,
        '${p.basenameWithoutExtension(file.path)}_compressed.pdf',
      ),
    );
    await outFile.writeAsBytes(document.saveSync(), flush: true);
    document.dispose();

    if (!mounted) return;
    setState(() {
      _status = 'PDF 压缩完成\n输出文件: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: 'PDF 压缩',
        inputSummary: p.basename(file.path),
        outputPath: outFile.path,
        success: true,
        message: '压缩完成',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF 压缩完成')),
    );
  }

  Future<List<int>?> _askPagesToExtract(int maxPage) async {
    final controller = TextEditingController();
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('输入提取页码'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '示例: 1,3,5-8 (总页数 $maxPage)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parsePageExpression(controller.text, maxPage);
                Navigator.pop(context, parsed);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  List<int> _parsePageExpression(String text, int maxPage) {
    final set = <int>{};
    for (final piece in text.split(',')) {
      final token = piece.trim();
      if (token.isEmpty) continue;
      if (token.contains('-')) {
        final parts = token.split('-');
        if (parts.length != 2) continue;
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        if (start == null || end == null) continue;
        final lo = start < end ? start : end;
        final hi = start < end ? end : start;
        for (int i = lo; i <= hi; i++) {
          if (i >= 1 && i <= maxPage) set.add(i);
        }
      } else {
        final page = int.tryParse(token);
        if (page != null && page >= 1 && page <= maxPage) {
          set.add(page);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> _extractPages() async {
    final file = await _pickSinglePdf();
    if (file == null) return;

    final srcBytes = await file.readAsBytes();
    final source = PdfDocument(inputBytes: srcBytes);
    final pages = await _askPagesToExtract(source.pages.count);
    if (pages == null || pages.isEmpty) {
      source.dispose();
      return;
    }

    final target = PdfDocument();
    for (final pageNumber in pages) {
      final template = source.pages[pageNumber - 1].createTemplate();
      final page = target.pages.add();
      final size = page.getClientSize();
      page.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        Size(size.width, size.height),
      );
    }

    final outDir = await _outputDir();
    final outFile = File(
      p.join(
        outDir.path,
        '${p.basenameWithoutExtension(file.path)}_extract.pdf',
      ),
    );
    await outFile.writeAsBytes(target.saveSync(), flush: true);
    source.dispose();
    target.dispose();

    if (!mounted) return;
    setState(() {
      _status = 'PDF 提取页面完成（${pages.length} 页）\n输出文件: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: 'PDF 提取页面',
        inputSummary: '${p.basename(file.path)} | 页码: ${pages.join(',')}',
        outputPath: outFile.path,
        success: true,
        message: '提取 ${pages.length} 页',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF 提取页面完成（${pages.length} 页）')),
    );
  }

  Future<Map<String, dynamic>?> _askWatermarkOptions() async {
    final controller = TextEditingController(text: '仅供学习交流');
    double opacity = 0.20;
    double angle = -35;
    double fontSize = 34;
    int colorIndex = 0;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('水印参数'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: '水印文字',
                        hintText: '例如：防篡改-姓名-日期',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('透明度: ${opacity.toStringAsFixed(2)}'),
                    Slider(
                      min: 0.05,
                      max: 0.60,
                      value: opacity,
                      onChanged: (v) => setDialogState(() => opacity = v),
                    ),
                    Text('旋转角度: ${angle.toStringAsFixed(0)}°'),
                    Slider(
                      min: -80,
                      max: 80,
                      value: angle,
                      onChanged: (v) => setDialogState(() => angle = v),
                    ),
                    Text('字号: ${fontSize.toStringAsFixed(0)}'),
                    Slider(
                      min: 18,
                      max: 72,
                      value: fontSize,
                      onChanged: (v) => setDialogState(() => fontSize = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: colorIndex,
                      decoration: const InputDecoration(
                        labelText: '颜色',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(_watermarkColorOptions.length, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(_watermarkColorOptions[index]['name'] as String),
                        );
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() => colorIndex = v);
                      },
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
                    Navigator.pop(context, {
                      'text': controller.text.trim(),
                      'opacity': opacity,
                      'angle': angle,
                      'fontSize': fontSize,
                      'color': _watermarkColorOptions[colorIndex]['color'] as PdfColor,
                    });
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _addWatermark() async {
    final file = await _pickSinglePdf();
    if (file == null) return;

    final options = await _askWatermarkOptions();
    if (options == null) return;
    final text = (options['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) return;

    final opacity = (options['opacity'] as double?) ?? 0.20;
    final angle = (options['angle'] as double?) ?? -35;
    final fontSize = (options['fontSize'] as double?) ?? 34;
    final color = (options['color'] as PdfColor?) ?? PdfColor(170, 30, 30);

    final srcBytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: srcBytes);
    final font = PdfStandardFont(
      PdfFontFamily.helvetica,
      fontSize,
      style: PdfFontStyle.bold,
    );
    final brush = PdfSolidBrush(color);

    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.getClientSize();
      page.graphics.save();
      page.graphics.setTransparency(opacity);
      page.graphics.translateTransform(size.width / 2, size.height / 2);
      page.graphics.rotateTransform(angle);
      page.graphics.drawString(
        text,
        font,
        brush: brush,
        bounds: Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 1.1,
          height: 120,
        ),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      page.graphics.restore();
    }

    final outDir = await _outputDir();
    final outFile = File(
      p.join(
        outDir.path,
        '${p.basenameWithoutExtension(file.path)}_watermark.pdf',
      ),
    );
    await outFile.writeAsBytes(document.saveSync(), flush: true);
    document.dispose();

    if (!mounted) return;
    setState(() {
      _status = 'PDF 加水印完成\n输出文件: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: '加水印（防篡改）',
        inputSummary: '${p.basename(file.path)} | "$text"',
        outputPath: outFile.path,
        success: true,
        message: '透明度 ${opacity.toStringAsFixed(2)}，角度 ${angle.toStringAsFixed(0)}°',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF 加水印完成')),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('工具'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.menu_book_outlined), text: '阅读'),
              Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF 工具'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('阅读'),
                    subtitle: const Text('阅读功能已并入工具分区，点击进入阅读页。'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReadingPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _busy ? '正在处理，请稍候...' : _status,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pickOutputDirectory,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('选择输出目录'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _resetOutputDirectory,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('恢复默认目录'),
                          ),
                          OutlinedButton.icon(
                            onPressed: (_busy || _lastOutputPath == null)
                                ? null
                                : _openOutputFile,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('打开输出'),
                          ),
                          OutlinedButton.icon(
                            onPressed: (_busy || _lastOutputPath == null)
                                ? null
                                : _shareOutputFile,
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('分享输出'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前目录: ${_customOutputDir ?? '系统临时目录/pdf_tools_output'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'PDF 小工具合集',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  '包含转换、合并、压缩、提取和防篡改水印。',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                _buildToolButton(
                  icon: Icons.image_outlined,
                  title: 'PDF 转图片',
                  subtitle: '将 PDF 页面导出为 PNG 图片',
                  onTap: () => _runTool(_pdfToImages),
                ),
                _buildToolButton(
                  icon: Icons.collections_outlined,
                  title: '图片合并 PDF',
                  subtitle: '多张图片合并为一个 PDF 文件',
                  onTap: () => _runTool(_imagesToPdf),
                ),
                _buildToolButton(
                  icon: Icons.compress_outlined,
                  title: 'PDF 压缩',
                  subtitle: '压缩 PDF 体积（取决于文档内容）',
                  onTap: () => _runTool(_compressPdf),
                ),
                _buildToolButton(
                  icon: Icons.snippet_folder_outlined,
                  title: 'PDF 提取页面',
                  subtitle: '按页码范围提取指定页面',
                  onTap: () => _runTool(_extractPages),
                ),
                _buildToolButton(
                  icon: Icons.verified_user_outlined,
                  title: '加水印（防篡改）',
                  subtitle: '支持透明度、角度、字号、颜色配置',
                  onTap: () => _runTool(_addWatermark),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.history),
                    title: const Text('最近任务记录'),
                    subtitle: Text('已记录 ${_recentTasks.length} 条'),
                    initiallyExpanded: true,
                    children: [
                      if (_recentTasks.isEmpty)
                        const ListTile(
                          title: Text('暂无记录'),
                          subtitle: Text('执行一次 PDF 工具后会显示记录。'),
                        )
                      else
                        ..._recentTasks.map((task) {
                          return ListTile(
                            leading: Icon(
                              task.success ? Icons.check_circle : Icons.error,
                              color: task.success ? Colors.green : Colors.red,
                            ),
                            title: Text(task.toolName),
                            subtitle: Text(
                              '${_formatTime(task.timestamp)}\n输入: ${task.inputSummary}\n输出: ${task.outputPath}\n${task.message}',
                              style: const TextStyle(height: 1.35),
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: '复制输出路径',
                              icon: const Icon(Icons.copy_outlined),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: task.outputPath));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已复制输出路径')),
                                );
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
