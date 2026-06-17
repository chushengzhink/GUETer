import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../materials/material_index_models.dart';
import '../materials/material_library_store.dart';
import '../models/file_tool_models.dart';
import '../plugins/plugin_action_menu.dart';
import '../plugins/plugin_context.dart';
import '../plugins/plugin_manifest.dart';
import '../services/file_output_share_service.dart';
import '../services/file_tool_history_store.dart';
import '../services/file_tool_service.dart';
import '../services/duplicate_file_scanner.dart';
import '../theme/components/app_card.dart';
import '../theme/components/app_text_field.dart';
import 'duplicate_cleanup_page.dart';
import 'file_preview_page.dart';

class FileToolsPage extends StatefulWidget {
  const FileToolsPage({super.key});

  @override
  State<FileToolsPage> createState() => _FileToolsPageState();
}

class _FileToolsPageState extends State<FileToolsPage> {
  final FileToolService _service = FileToolService();
  final FileToolHistoryStore _historyStore = FileToolHistoryStore();
  final FileOutputShareService _shareService = FileOutputShareService();
  final MaterialLibraryStore _materialLibraryStore = MaterialLibraryStore();
  final TextEditingController _fileNameController = TextEditingController();
  final TextEditingController _extensionController = TextEditingController();
  final TextEditingController _archiveNameController = TextEditingController();

  bool _busy = false;
  String _status = '';
  String? _customOutputDir;
  String? _defaultOutputDir;
  String? _lastOutputPath;
  String? _fileNameError;
  String? _extensionError;
  int _compressionLevel = 6;

  SelectedFileItem? _selectedZipFile;
  SelectedFileItem? _selectedRenameFile;
  ZipPreview? _zipPreview;
  Set<String> _selectedZipEntries = <String>{};
  List<SelectedFileItem> _archiveInputs = <SelectedFileItem>[];
  final List<FileToolTaskRecord> _recentTasks = <FileToolTaskRecord>[];

  @override
  void initState() {
    super.initState();
    _fileNameController.addListener(_updateRenamePreviewErrors);
    _extensionController.addListener(_updateRenamePreviewErrors);
    _refreshDefaultOutputDirectory();
    _loadHistory();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _extensionController.dispose();
    _archiveNameController.dispose();
    super.dispose();
  }

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _tr(String zh, String en) => _isEnglish ? en : zh;

  RenamePreview get _renamePreview => _service.buildRenamePreview(
    _fileNameController.text,
    _extensionController.text,
  );

  Future<void> _pickOutputDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: _tr('选择文件工具输出目录', 'Choose file tools output directory'),
    );
    if (path == null || path.trim().isEmpty) {
      return;
    }
    setState(() {
      _customOutputDir = path;
      _status = _tr('输出目录已切换：$path', 'Output directory updated: $path');
    });
  }

  void _resetOutputDirectory() {
    setState(() {
      _customOutputDir = null;
      _status = _tr('已恢复默认输出目录。', 'Output directory reset to default.');
    });
    _refreshDefaultOutputDirectory();
  }

  Future<Directory> _outputDirectory() {
    return _service.ensureOutputDirectory(customOutputPath: _customOutputDir);
  }

  Future<void> _refreshDefaultOutputDirectory() async {
    final dir = await _service.ensureOutputDirectory();
    if (!mounted) return;
    setState(() {
      _defaultOutputDir = dir.path;
    });
  }

  Future<void> _loadHistory() async {
    final records = await _historyStore.load(scope: FileToolHistoryScope.file);
    if (!mounted) return;
    setState(() {
      _recentTasks
        ..clear()
        ..addAll(records.map((record) => record.toTaskRecord()));
      if (_recentTasks.isNotEmpty && _recentTasks.first.outputPath.isNotEmpty) {
        _lastOutputPath = _recentTasks.first.outputPath;
      }
    });
  }

  Future<void> _pickZipFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: false,
    );
    final path = (result == null || result.files.isEmpty)
        ? null
        : result.files.first.path;
    if (path == null || path.isEmpty) {
      return;
    }
    final item = await SelectedFileItem.fromEntity(File(path));
    setState(() {
      _selectedZipFile = item;
      _zipPreview = null;
      _selectedZipEntries = <String>{};
      _status = _tr('已选择 ZIP：${item.name}', 'ZIP selected: ${item.name}');
    });
    await _loadZipPreview(File(path));
  }

  Future<void> _pickRenameFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    final path = (result == null || result.files.isEmpty)
        ? null
        : result.files.first.path;
    if (path == null || path.isEmpty) {
      return;
    }
    final item = await SelectedFileItem.fromEntity(File(path));
    setState(() {
      _selectedRenameFile = item;
      _fileNameController.text = p.basenameWithoutExtension(item.path);
      _extensionController.text = p.extension(item.path).replaceFirst('.', '');
      _status = _tr(
        '已选择待重命名文件：${item.name}',
        'Rename source selected: ${item.name}',
      );
    });
    _updateRenamePreviewErrors();
  }

  Future<void> _pickArchiveFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final items = <SelectedFileItem>[];
    for (final file in result.files) {
      final path = file.path;
      if (path == null || path.isEmpty) {
        continue;
      }
      items.add(await SelectedFileItem.fromEntity(File(path)));
    }
    if (items.isEmpty) {
      return;
    }
    setState(() {
      _archiveInputs = items;
      _archiveNameController.text = items.length == 1
          ? p.basenameWithoutExtension(items.first.path)
          : 'archive_${DateTime.now().millisecondsSinceEpoch}';
      _status = _tr(
        '已选择 ${items.length} 个文件用于打包。',
        'Selected ${items.length} files for ZIP creation.',
      );
    });
  }

  Future<void> _pickArchiveDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: _tr('选择要打包的文件夹', 'Choose a folder to archive'),
    );
    if (path == null || path.trim().isEmpty) {
      return;
    }
    final item = await SelectedFileItem.fromEntity(Directory(path));
    setState(() {
      _archiveInputs = <SelectedFileItem>[item];
      _archiveNameController.text = item.name;
      _status = _tr('已选择文件夹：${item.name}', 'Folder selected: ${item.name}');
    });
  }

  void _clearArchiveInputs() {
    setState(() {
      _archiveInputs = <SelectedFileItem>[];
      _archiveNameController.clear();
      _status = _tr('已清空打包输入。', 'Archive inputs cleared.');
    });
  }

  Future<void> _loadZipPreview(File file) async {
    try {
      final preview = await _service.previewZip(zipFile: file);
      if (!mounted) return;
      setState(() {
        _zipPreview = preview;
        _selectedZipEntries = preview.entries
            .where((entry) => entry.isSafe)
            .map((entry) => entry.path)
            .toSet();
        _status = _tr(
          'ZIP 预览完成：${preview.fileCount} 个文件，${preview.directoryCount} 个文件夹。',
          'ZIP preview ready: ${preview.fileCount} files, ${preview.directoryCount} folders.',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _zipPreview = null;
        _selectedZipEntries = <String>{};
        _status = error.toString();
      });
    }
  }

  void _toggleZipEntry(String path, bool selected) {
    setState(() {
      final next = Set<String>.from(_selectedZipEntries);
      if (selected) {
        next.add(path);
      } else {
        next.remove(path);
      }
      _selectedZipEntries = next;
    });
  }

  void _selectAllZipEntries() {
    final preview = _zipPreview;
    if (preview == null) return;
    setState(() {
      _selectedZipEntries = preview.entries
          .where((entry) => entry.isSafe)
          .map((entry) => entry.path)
          .toSet();
    });
  }

  void _clearZipEntrySelection() {
    setState(() {
      _selectedZipEntries = <String>{};
    });
  }

  void _trimRecentTasks() {
    if (_recentTasks.length > 30) {
      _recentTasks.removeRange(30, _recentTasks.length);
    }
  }

  void _updateRenamePreviewErrors() {
    String? fileNameError;
    String? extensionError;
    try {
      _service.validateBaseName(_fileNameController.text.trim());
    } on FileToolValidationException catch (error) {
      fileNameError = error.message;
    }
    try {
      _service.validateExtension(_renamePreview.normalizedExtension);
    } on FileToolValidationException catch (error) {
      extensionError = error.message;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _fileNameError = fileNameError;
      _extensionError = extensionError;
    });
  }

  Future<void> _executeTask({
    required String toolName,
    required String inputSummary,
    required String successMessage,
    required Future<String> Function() action,
  }) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final outputPath = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _lastOutputPath = outputPath;
        _status = successMessage;
      });
      await _recordHistory(
        toolName: toolName,
        inputSummary: inputSummary,
        outputPath: outputPath,
        success: true,
        message: successMessage,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString();
      setState(() {
        _busy = false;
        _status = message;
      });
      await _recordHistory(
        toolName: toolName,
        inputSummary: inputSummary,
        outputPath: '',
        success: false,
        message: message,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _recordHistory({
    required String toolName,
    required String inputSummary,
    required String outputPath,
    required bool success,
    required String message,
  }) async {
    final record = FileToolHistoryRecord(
      scope: FileToolHistoryScope.file,
      toolName: toolName,
      inputSummary: inputSummary,
      outputPath: outputPath,
      timestamp: DateTime.now(),
      success: success,
      message: message,
    );
    await _historyStore.append(record);
    if (success && outputPath.trim().isNotEmpty) {
      await _materialLibraryStore.upsertItem(
        path: outputPath,
        name: p.basename(outputPath),
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: toolName,
      );
    }
    if (!mounted) return;
    setState(() {
      _recentTasks.insert(0, record.toTaskRecord());
      _trimRecentTasks();
    });
  }

  Future<void> _extractZip() async {
    final zip = _selectedZipFile;
    if (zip == null) {
      setState(() {
        _status = _tr('请先选择 ZIP 文件。', 'Choose a ZIP file first.');
      });
      return;
    }

    await _executeTask(
      toolName: _tr('ZIP 解压', 'Extract ZIP'),
      inputSummary: zip.name,
      successMessage: _tr('ZIP 解压完成。', 'ZIP extracted successfully.'),
      action: () async {
        if (_zipPreview != null && _selectedZipEntries.isEmpty) {
          throw FileToolException(
            _tr(
              '请至少选择一个安全条目再解压。',
              'Choose at least one safe entry to extract.',
            ),
          );
        }
        final outputDirectory = await _outputDirectory();
        final directory = await _service.extractZip(
          zipFile: File(zip.path),
          outputDirectory: outputDirectory,
          selectedEntryPaths: _zipPreview == null ? null : _selectedZipEntries,
        );
        return directory.path;
      },
    );
  }

  Future<void> _createZip() async {
    if (_archiveInputs.isEmpty) {
      setState(() {
        _status = _tr(
          '请先选择要打包的文件或文件夹。',
          'Choose files or a folder to archive first.',
        );
      });
      return;
    }

    await _executeTask(
      toolName: _tr('ZIP 打包', 'Create ZIP'),
      inputSummary: _archiveInputs.map((item) => item.name).join(', '),
      successMessage: _tr('ZIP 打包完成。', 'ZIP created successfully.'),
      action: () async {
        final outputDirectory = await _outputDirectory();
        final entities = _archiveInputs
            .map<FileSystemEntity>(
              (item) =>
                  item.isDirectory ? Directory(item.path) : File(item.path),
            )
            .toList();
        final file = await _service.createZip(
          sources: entities,
          outputDirectory: outputDirectory,
          preferredName: _archiveNameController.text,
          compressionLevel: _compressionLevel,
        );
        return file.path;
      },
    );
  }

  Future<void> _renameFile() async {
    final file = _selectedRenameFile;
    if (file == null) {
      setState(() {
        _status = _tr('请先选择要重命名的文件。', 'Choose a file to rename first.');
      });
      return;
    }

    _updateRenamePreviewErrors();
    if (_fileNameError != null || _extensionError != null) {
      setState(() {
        _status = _tr('请先修正文件名或扩展名。', 'Fix the file name or extension first.');
      });
      return;
    }

    await _executeTask(
      toolName: _tr('重命名文件', 'Rename file'),
      inputSummary: file.name,
      successMessage: _tr('文件重命名完成。', 'File renamed successfully.'),
      action: () async {
        final renamed = await _service.renameFile(
          source: File(file.path),
          baseName: _fileNameController.text,
          extension: _extensionController.text,
        );
        final updated = await SelectedFileItem.fromEntity(renamed);
        if (mounted) {
          setState(() {
            _selectedRenameFile = updated;
          });
        }
        return renamed.path;
      },
    );
  }

  Future<void> _openLastOutput() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) {
      return;
    }
    await FilePreviewPage.open(context, path);
  }

  Future<void> _openContainingDirectory() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) {
      return;
    }
    final type = await FileSystemEntity.type(path);
    final targetPath = type == FileSystemEntityType.directory
        ? path
        : p.dirname(path);
    await OpenFilex.open(targetPath);
  }

  Future<void> _shareLastOutput() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) {
      return;
    }
    await _shareOutputPath(path);
  }

  Future<void> _openDuplicateCleanup() async {
    final outputDir = await _outputDirectory();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuplicateCleanupPage(
          title: _tr('文件工具查重清理', 'File tools duplicate cleanup'),
          roots: [
            DuplicateScanRoot(
              label: _tr('文件工具输出', 'File outputs'),
              path: outputDir.path,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareOutputPath(String path) async {
    try {
      await _shareService.shareOutput(
        path,
        text: _tr('文件工具输出', 'File tool output'),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      setState(() => _status = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _clearHistory() async {
    await _historyStore.clear(scope: FileToolHistoryScope.file);
    if (!mounted) return;
    setState(() {
      _recentTasks.clear();
      _status = _tr('文件工具历史已清空。', 'File tool history cleared.');
    });
  }

  void _copyLastOutputPath() {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) {
      return;
    }
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.outputPathCopied)));
  }

  Future<void> _runFileOutputMod(
    String path,
    PluginActionMenuItem action,
  ) async {
    try {
      final stat = await File(path).stat();
      if (!mounted) return;
      await PluginActionMenu.run(
        context,
        action,
        PluginActionContext(
          type: PluginContextType.file,
          filePath: path,
          fileName: p.basename(path),
          fileSize: stat.size,
          isDirectory: stat.type == FileSystemEntityType.directory,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mod 执行失败：$error')));
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${time.month}/${time.day} $hour:$minute';
  }

  Widget _buildSelectionInfo({
    required String title,
    required SelectedFileItem? item,
    required VoidCallback onPick,
    required String actionLabel,
  }) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : onPick,
                icon: const Icon(Icons.attach_file),
                label: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (item == null)
            Text(
              _tr('尚未选择文件。', 'No file selected.'),
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: _tr('名称', 'Name'), value: item.name),
                _InfoLine(
                  label: _tr('扩展名', 'Extension'),
                  value: item.displayExtension,
                ),
                _InfoLine(
                  label: _tr('大小', 'Size'),
                  value: item.isDirectory ? '-' : _formatBytes(item.sizeBytes),
                ),
                _InfoLine(label: _tr('路径', 'Path'), value: item.path),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildArchiveInputsCard() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      gradient: LinearGradient(
        colors: [
          Colors.indigo.withValues(alpha: 0.12),
          Colors.blue.withValues(alpha: 0.05),
        ],
      ),
      border: Border.all(color: Colors.indigo.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tr('打包输入', 'Archive inputs'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _archiveInputs.isEmpty || _busy
                    ? null
                    : _clearArchiveInputs,
                child: Text(_tr('清空', 'Clear')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickArchiveFiles,
                icon: const Icon(Icons.note_add_outlined),
                label: Text(_tr('选择文件', 'Pick files')),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickArchiveDirectory,
                icon: const Icon(Icons.folder_zip_outlined),
                label: Text(_tr('选择文件夹', 'Pick folder')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_archiveInputs.isNotEmpty) ...[
            AppTextField(
              controller: _archiveNameController,
              labelText: _tr('压缩包名称', 'Archive name'),
              hintText: _tr('不需要填写 .zip', 'Do not include .zip'),
              prefixIcon: Icons.drive_file_rename_outline,
            ),
            const SizedBox(height: 12),
            Text(
              _tr('压缩级别', 'Compression level'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(_tr('存储', 'Store')),
                  icon: const Icon(Icons.speed_outlined),
                ),
                ButtonSegment(
                  value: 6,
                  label: Text(_tr('均衡', 'Balanced')),
                  icon: const Icon(Icons.tune_outlined),
                ),
                ButtonSegment(
                  value: 9,
                  label: Text(_tr('最小', 'Smallest')),
                  icon: const Icon(Icons.compress_outlined),
                ),
              ],
              selected: <int>{_compressionLevel},
              onSelectionChanged: _busy
                  ? null
                  : (selection) {
                      setState(() => _compressionLevel = selection.first);
                    },
            ),
            const SizedBox(height: 12),
          ],
          if (_archiveInputs.isEmpty)
            Text(
              _tr('还没有要打包的内容。', 'No files or folders selected yet.'),
              style: TextStyle(color: Colors.grey[700]),
            )
          else
            ..._archiveInputs
                .take(4)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isDirectory
                              ? Icons.folder_copy_outlined
                              : Icons.insert_drive_file_outlined,
                          size: 18,
                          color: Colors.indigo,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                item.path,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildZipPreviewCard() {
    final preview = _zipPreview;
    final selectedCount = _selectedZipEntries.length;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      border: Border.all(color: Colors.blue.withValues(alpha: 0.18)),
      gradient: LinearGradient(
        colors: [
          Colors.blue.withValues(alpha: 0.10),
          Colors.cyan.withValues(alpha: 0.04),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tr('ZIP 内容预览', 'ZIP preview'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (preview != null)
                Text(
                  _tr('$selectedCount 已选', '$selectedCount selected'),
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_selectedZipFile == null)
            Text(
              _tr('选择 ZIP 后会显示内容列表。', 'Choose a ZIP file to preview entries.'),
              style: TextStyle(color: Colors.grey[700]),
            )
          else if (preview == null)
            Text(
              _tr('正在等待 ZIP 预览。', 'Waiting for ZIP preview.'),
              style: TextStyle(color: Colors.grey[700]),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat(
                  label: _tr('文件', 'Files'),
                  value: preview.fileCount.toString(),
                ),
                _MiniStat(
                  label: _tr('文件夹', 'Folders'),
                  value: preview.directoryCount.toString(),
                ),
                _MiniStat(
                  label: _tr('总大小', 'Total'),
                  value: _formatBytes(preview.totalSizeBytes),
                ),
                if (preview.hasUnsafeEntries)
                  _MiniStat(
                    label: _tr('已拦截', 'Blocked'),
                    value: preview.skippedUnsafeCount.toString(),
                    color: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preview.hasUnsafeEntries
                  ? _tr(
                      '检测到不安全路径，已禁止选择，解压时会跳过。',
                      'Unsafe paths were blocked and will be skipped.',
                    )
                  : _tr(
                      '路径安全校验通过，可选择需要解压的条目。',
                      'Path safety check passed. Pick entries to extract.',
                    ),
              style: TextStyle(
                color: preview.hasUnsafeEntries
                    ? Colors.red[700]
                    : Colors.grey[700],
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _selectAllZipEntries,
                  icon: const Icon(Icons.select_all_outlined),
                  label: Text(_tr('全选', 'Select all')),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _clearZipEntrySelection,
                  icon: const Icon(Icons.deselect_outlined),
                  label: Text(_tr('清空选择', 'Clear selection')),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...preview.entries
                .take(8)
                .map(
                  (entry) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value:
                        entry.isSafe &&
                        _selectedZipEntries.contains(entry.path),
                    onChanged: !entry.isSafe || _busy
                        ? null
                        : (value) =>
                              _toggleZipEntry(entry.path, value ?? false),
                    secondary: Icon(
                      entry.isDirectory
                          ? Icons.folder_outlined
                          : Icons.insert_drive_file_outlined,
                      color: entry.isSafe ? Colors.blue : Colors.red,
                    ),
                    title: Text(
                      entry.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      entry.isDirectory
                          ? _tr('文件夹', 'Folder')
                          : _formatBytes(entry.sizeBytes),
                    ),
                  ),
                ),
            if (preview.entries.length > 8)
              Text(
                _tr(
                  '仅显示前 8 项，解压选择仍按当前勾选状态执行。',
                  'Showing first 8 entries. Extraction uses current selection.',
                ),
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRenameCard() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      gradient: LinearGradient(
        colors: [
          Colors.orange.withValues(alpha: 0.12),
          Colors.deepOrange.withValues(alpha: 0.05),
        ],
      ),
      border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tr('重命名预览', 'Rename preview'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _renamePreview.fullName.isEmpty ? '-' : _renamePreview.fullName,
                style: TextStyle(
                  color: Colors.orange[900],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _fileNameController,
            labelText: _tr('文件名', 'File name'),
            hintText: _tr('只填主体名', 'Base name only'),
            prefixIcon: Icons.drive_file_rename_outline,
            errorText: _fileNameError,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _extensionController,
            labelText: _tr('扩展名', 'Extension'),
            hintText: _tr('例如 pdf / zip / 留空', 'For example pdf / zip / empty'),
            prefixIcon: Icons.extension_outlined,
            errorText: _extensionError,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final outputDirectory = _customOutputDir ?? _defaultOutputDir ?? '-';
    final outputType = _lastOutputPath == null
        ? FileSystemEntityType.notFound
        : FileSystemEntity.typeSync(_lastOutputPath!);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      gradient: LinearGradient(
        colors: [
          Colors.teal.withValues(alpha: 0.12),
          Colors.cyan.withValues(alpha: 0.05),
        ],
      ),
      border: Border.all(color: Colors.teal.withValues(alpha: 0.18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tr('文件工具状态', 'File tools status'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _status.isEmpty
                ? _tr('选择文件后即可开始操作。', 'Choose files to start.')
                : _status,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 10),
          _InfoLine(
            label: _tr('输出目录', 'Output directory'),
            value: outputDirectory,
          ),
          if (_lastOutputPath != null)
            _InfoLine(
              label: _tr('最近输出', 'Last output'),
              value: _lastOutputPath!,
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickOutputDirectory,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(_tr('改输出目录', 'Change output')),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _resetOutputDirectory,
                icon: const Icon(Icons.restart_alt_outlined),
                label: Text(_tr('恢复默认', 'Reset')),
              ),
              OutlinedButton.icon(
                onPressed: (_lastOutputPath == null || _busy)
                    ? null
                    : _openLastOutput,
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(
                  outputType == FileSystemEntityType.directory
                      ? _tr('打开目录', 'Open folder')
                      : _tr('打开输出', 'Open output'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: (_lastOutputPath == null || _busy)
                    ? null
                    : _openContainingDirectory,
                icon: const Icon(Icons.folder_outlined),
                label: Text(_tr('所在目录', 'Containing folder')),
              ),
              OutlinedButton.icon(
                onPressed: (_lastOutputPath == null || _busy)
                    ? null
                    : _shareLastOutput,
                icon: const Icon(Icons.share_outlined),
                label: Text(_tr('分享', 'Share')),
              ),
              OutlinedButton.icon(
                onPressed: (_lastOutputPath == null || _busy)
                    ? null
                    : _copyLastOutputPath,
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.copyOutputPath),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _openDuplicateCleanup,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: Text(_tr('查重清理', 'Deduplicate')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.08,
      children: [
        _ActionCard(
          color: Colors.blue,
          icon: Icons.unarchive_outlined,
          title: _tr('解压 ZIP', 'Extract ZIP'),
          subtitle: _tr('可按预览勾选条目解压', 'Extract selected preview entries'),
          onTap: _busy ? null : _extractZip,
        ),
        _ActionCard(
          color: Colors.indigo,
          icon: Icons.archive_outlined,
          title: _tr('创建 ZIP', 'Create ZIP'),
          subtitle: _tr('打包选中文件或文件夹', 'Archive selected files or folders'),
          onTap: _busy ? null : _createZip,
        ),
        _ActionCard(
          color: Colors.orange,
          icon: Icons.drive_file_rename_outline,
          title: _tr('重命名文件', 'Rename file'),
          subtitle: _tr(
            '文件名与扩展名分开编辑',
            'Edit file name and extension separately',
          ),
          onTap: _busy ? null : _renameFile,
        ),
      ],
    );
  }

  Widget _buildRecentTasksCard() {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 24),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history),
        title: Row(
          children: [
            Expanded(child: Text(l10n.recentTasksTitle)),
            TextButton(
              onPressed: _recentTasks.isEmpty || _busy ? null : _clearHistory,
              child: Text(_tr('清空', 'Clear')),
            ),
          ],
        ),
        subtitle: Text(l10n.recentTasksCount(_recentTasks.length)),
        children: [
          if (_recentTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _tr('还没有文件工具记录。', 'No file tool tasks yet.'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ..._recentTasks
                .take(6)
                .map(
                  (task) => ListTile(
                    dense: true,
                    leading: Icon(
                      task.success ? Icons.check_circle : Icons.error_outline,
                      color: task.success ? Colors.green : Colors.red,
                    ),
                    title: Text(task.toolName),
                    subtitle: Text(
                      '${_formatTime(task.timestamp)}\n${task.inputSummary}\n${task.message}',
                      style: const TextStyle(height: 1.35),
                    ),
                    trailing: task.outputPath.isEmpty
                        ? null
                        : Wrap(
                            spacing: 2,
                            children: [
                              IconButton(
                                tooltip: _tr('预览', 'Preview'),
                                onPressed: () => FilePreviewPage.open(
                                  context,
                                  task.outputPath,
                                ),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              IconButton(
                                tooltip: _tr('分享输出', 'Share output'),
                                onPressed: () =>
                                    _shareOutputPath(task.outputPath),
                                icon: const Icon(Icons.share_outlined),
                              ),
                              IconButton(
                                tooltip: l10n.copyOutputPath,
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: task.outputPath),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.outputPathCopied),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_outlined),
                              ),
                              PopupMenuButton<PluginActionMenuItem>(
                                tooltip: 'Mod 动作',
                                icon: const Icon(Icons.extension_outlined),
                                onSelected: (action) =>
                                    _runFileOutputMod(task.outputPath, action),
                                itemBuilder: (context) {
                                  final items = PluginActionMenu.popupItems(
                                    context,
                                    PluginActionContext(
                                      type: PluginContextType.file,
                                      filePath: task.outputPath,
                                      fileName: p.basename(task.outputPath),
                                    ),
                                  );
                                  if (items.isEmpty) {
                                    return const [
                                      PopupMenuItem(
                                        enabled: false,
                                        child: Text('没有可用 Mod 动作'),
                                      ),
                                    ];
                                  }
                                  return items;
                                },
                              ),
                            ],
                          ),
                  ),
                ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    const floatingNavBarHeight = 80.0;
    final totalBottomPadding = bottomSafeArea + floatingNavBarHeight;

    return Scaffold(
      appBar: AppBar(title: Text(_tr('文件工具', 'File Tools'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, totalBottomPadding + 16),
        children: [
          _buildStatusCard(),
          _buildSelectionInfo(
            title: _tr('ZIP 输入', 'ZIP input'),
            item: _selectedZipFile,
            onPick: _pickZipFile,
            actionLabel: _tr('选 ZIP', 'Pick ZIP'),
          ),
          _buildZipPreviewCard(),
          _buildArchiveInputsCard(),
          _buildSelectionInfo(
            title: _tr('重命名源文件', 'Rename source'),
            item: _selectedRenameFile,
            onPick: _pickRenameFile,
            actionLabel: _tr('选文件', 'Pick file'),
          ),
          _buildRenameCard(),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _tr('操作', 'Actions'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          _buildActionsGrid(),
          const SizedBox(height: 16),
          _buildRecentTasksCard(),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: color.withValues(alpha: 0.24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(height: 1.4),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.color = Colors.blue,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
