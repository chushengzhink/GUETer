// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/performance/app_performance.dart';
import '../features/tools/tool_catalog.dart';
import '../modules/local_transfer/ui/local_transfer_page.dart';
import '../app_entries/app_entry.dart';
import '../l10n/app_localizations.dart';
import '../layout/layout_preferences.dart';
import '../models/file_output_manager_models.dart';
import '../models/file_tool_models.dart';
import '../models/tool_workflow_models.dart';
import '../features/openlist/openlist_cloud_page.dart';
import '../features/unipus/unipus_assist_page.dart';
import '../plugins/plugin_runtime.dart';
import '../services/file_output_share_service.dart';
import '../services/file_tool_history_store.dart';
import '../services/gueter_storage_service.dart';
import '../services/lightweight_pdf_conversion_service.dart';
import '../session/app_settings.dart';
import '../theme/components/app_card.dart';
import '../theme/components/dashboard_components.dart';
import 'academic_search_page.dart';
import 'file_output_manager_page.dart';
import 'file_tools_page.dart';
import 'material_ocr_page.dart';
import 'material_search_page.dart';
import 'material_sync_status_page.dart';
import 'computer_help_manual_page.dart';
import 'guet_email_apply_page.dart';
import 'pdf_arrange_page.dart';
import 'reading.dart';
import 'smart_organizer_page.dart';
import 'study_center_page.dart';
import 'user_manual_page.dart';
import 'web_archive_page.dart';

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

  factory _ToolTaskRecord.fromHistory(FileToolHistoryRecord record) {
    return _ToolTaskRecord(
      toolName: record.toolName,
      inputSummary: record.inputSummary,
      outputPath: record.outputPath,
      timestamp: record.timestamp,
      success: record.success,
      message: record.message,
    );
  }
}

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key, this.initializeServices = true});

  /// Disable external services when rendering the real page in widget tests.
  final bool initializeServices;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  bool _busy = false;
  String _status = '';
  String? _customOutputDir;
  String? _defaultOutputDirPath;
  String? _lastOutputPath;
  int _selectedToolCategory = 1;
  final List<_ToolTaskRecord> _recentTasks = <_ToolTaskRecord>[];
  final ScrollController _dashboardScrollController = ScrollController();

  final FileToolHistoryStore _historyStore = FileToolHistoryStore();
  final List<FileToolHistoryRecord> _recentFiles = [];
  final FileOutputShareService _shareService = FileOutputShareService();
  final LightweightPdfConversionService _pdfConversionService =
      LightweightPdfConversionService();

  static final List<Map<String, dynamic>> _watermarkColorOptions = [
    {'name': 'deep-red', 'color': PdfColor(170, 30, 30)},
    {'name': 'deep-blue', 'color': PdfColor(30, 60, 170)},
    {'name': 'deep-gray', 'color': PdfColor(70, 70, 70)},
    {'name': 'black', 'color': PdfColor(25, 25, 25)},
  ];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _tr(String zh, String en) => _isEnglish ? en : zh;

  AppPerformanceMode get _performanceMode => AppSettings.performanceMode;

  CooperativeYield _toolYielder() {
    return CooperativeYield(
      batchSize: _performanceMode == AppPerformanceMode.lowPower ? 2 : 8,
    );
  }

  String get _effectivePdfOutputDirectory =>
      _customOutputDir?.trim().isNotEmpty == true
      ? _customOutputDir!
      : (_defaultOutputDirPath ??
            _tr('正在读取默认输出目录', 'Loading default output directory'));

  ToolActionSpec _fromToolEntry(ToolEntry entry) {
    final locale = Localizations.localeOf(context);
    return ToolActionSpec(
      id: entry.id,
      title: entry.titleFor(locale),
      subtitle: entry.subtitleFor(locale),
      icon: entry.icon,
      color: entry.color,
      onTap: entry.onTap,
      tags: entry.tags,
      badge: entry.badge,
      priority: entry.priority,
    );
  }

  List<ToolCategorySpec> _withToolLayout(List<ToolCategorySpec> categories) {
    final pluginEntries = PluginRuntime.buildToolEntries(
      AppSettings.pluginStore.enabledPluginsNotifier.value,
      context,
    );
    if (pluginEntries.isNotEmpty) {
      final locale = Localizations.localeOf(context);
      final groupedPluginEntries = <String, List<ToolEntry>>{};
      for (final entry in pluginEntries) {
        groupedPluginEntries
            .putIfAbsent(entry.categoryId, () => <ToolEntry>[])
            .add(entry);
      }
      categories = <ToolCategorySpec>[
        ...categories,
        ...groupedPluginEntries.entries.map((group) {
          final first = group.value.first;
          return ToolCategorySpec(
            id: first.categoryId,
            label: first.categoryFor(locale),
            subtitle: first.categorySubtitleFor(locale),
            icon: first.categoryIcon,
            color: first.categoryColor,
            actions: group.value.map(_fromToolEntry).toList()
              ..sort((a, b) => b.priority.compareTo(a.priority)),
          );
        }),
      ];
    }

    final preferences = AppSettings.layoutPreferencesStore.notifier.value;
    final categoryIds = categories.map((category) => category.id).toList();
    final actionIds = categories
        .expand((category) => category.actions)
        .map((action) => action.id)
        .toList();
    final normalized = preferences.normalized(
      navIds: LayoutPreferences.defaultNavOrder,
      toolCategoryIds: categoryIds,
      toolActionIds: actionIds,
    );
    final orderedCategoryIds = normalized.toolCategoryOrder.isEmpty
        ? categoryIds
        : normalized.toolCategoryOrder;
    final actionOrder = normalized.visibleToolActionOrder(actionIds);
    final actionIndex = <String, int>{
      for (var i = 0; i < actionOrder.length; i++) actionOrder[i]: i,
    };
    final categoryById = {
      for (final category in categories) category.id: category,
    };

    return orderedCategoryIds
        .map((id) => categoryById[id])
        .whereType<ToolCategorySpec>()
        .map((category) {
          final actions =
              category.actions
                  .where(
                    (action) =>
                        !normalized.hiddenToolActionIds.contains(action.id),
                  )
                  .toList()
                ..sort(
                  (a, b) => (actionIndex[a.id] ?? 9999).compareTo(
                    actionIndex[b.id] ?? 9999,
                  ),
                );
          return ToolCategorySpec(
            id: category.id,
            label: category.label,
            subtitle: category.subtitle,
            icon: category.icon,
            color: category.color,
            actions: actions,
          );
        })
        .where((category) => category.actions.isNotEmpty)
        .toList();
  }

  List<ToolCategorySpec> _toolCategories() {
    return _withToolLayout([
      ToolCategorySpec(
        id: 'transfer',
        label: _tr('传输', 'Transfer'),
        subtitle: _tr('近场配对、局域网互传', 'Nearby pairing and LAN transfer'),
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF06B6D4),
        actions: [
          ToolActionSpec(
            id: 'nearby-room',
            title: _tr('附近房间', 'Nearby Room'),
            subtitle: _tr('发现附近房间，进入面对面配对。', 'Discover nearby rooms.'),
            icon: Icons.meeting_room_outlined,
            color: const Color(0xFF06B6D4),
            onTap: () => Navigator.pushNamed(context, '/nearby-room'),
            badge: _tr('近场', 'Nearby'),
          ),
          ToolActionSpec(
            id: 'local-transfer',
            title: l10n.localTransferTitle,
            subtitle: l10n.localTransferSubtitle,
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF14B8A6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocalTransferPage()),
              );
            },
            badge: 'LAN',
          ),
        ],
      ),
      ToolCategorySpec(
        id: 'pdf',
        label: 'PDF',
        subtitle: _tr('转换、压缩、提取、水印', 'Convert, compress, extract, watermark'),
        icon: Icons.picture_as_pdf_outlined,
        color: const Color(0xFFF97316),
        actions: [
          ToolActionSpec(
            id: 'arrange-pdf',
            title: _tr('PDF 页面编排', 'PDF Arrange'),
            subtitle: _tr(
              '拖拽排序、删除恢复、旋转页面并导出',
              'Reorder, remove, rotate, and export pages',
            ),
            icon: Icons.dashboard_customize_outlined,
            color: const Color(0xFFF97316),
            onTap: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PdfArrangePage()),
                    );
                  },
            badge: _tr('编排', 'Arrange'),
          ),
          ToolActionSpec(
            id: 'lightweight-to-pdf',
            title: _tr('轻量转 PDF', 'Files to PDF'),
            subtitle: _tr(
              '图片、TXT、Markdown、HTML、CSV 转 PDF',
              'Images, TXT, Markdown, HTML, and CSV',
            ),
            icon: Icons.post_add_outlined,
            color: const Color(0xFFEA580C),
            onTap: _busy ? null : () => _runTool(_lightweightFilesToPdf),
            badge: _tr('本地', 'Local'),
          ),
          ToolActionSpec(
            id: 'pdf-to-images',
            title: l10n.pdfToImagesTitle,
            subtitle: l10n.pdfToImagesSubtitle,
            icon: Icons.image_outlined,
            color: const Color(0xFFF97316),
            onTap: _busy ? null : () => _runTool(_pdfToImages),
            badge: 'PNG',
          ),
          ToolActionSpec(
            id: 'images-to-pdf',
            title: l10n.imagesToPdfTitle,
            subtitle: l10n.imagesToPdfSubtitle,
            icon: Icons.collections_outlined,
            color: const Color(0xFFEF4444),
            onTap: _busy ? null : () => _runTool(_imagesToPdf),
            badge: 'PDF',
          ),
          ToolActionSpec(
            id: 'compress-pdf',
            title: l10n.compressPdfTitle,
            subtitle: l10n.compressPdfSubtitle,
            icon: Icons.compress_outlined,
            color: const Color(0xFFF59E0B),
            onTap: _busy ? null : () => _runTool(_compressPdf),
            badge: _tr('压缩', 'Zip'),
          ),
          ToolActionSpec(
            id: 'extract-pages',
            title: l10n.extractPagesTitle,
            subtitle: l10n.extractPagesSubtitle,
            icon: Icons.snippet_folder_outlined,
            color: const Color(0xFFFB7185),
            onTap: _busy ? null : () => _runTool(_extractPages),
            badge: _tr('页码', 'Pages'),
          ),
          ToolActionSpec(
            id: 'watermark-pdf',
            title: l10n.watermarkTitle,
            subtitle: l10n.watermarkSubtitle,
            icon: Icons.verified_user_outlined,
            color: const Color(0xFFF97316),
            onTap: _busy ? null : () => _runTool(_addWatermark),
            badge: _tr('水印', 'Mark'),
          ),
        ],
      ),
      ToolCategorySpec(
        id: 'files',
        label: _tr('文件', 'Files'),
        subtitle: _tr('压缩包、批量整理', 'Archive and batch cleanup'),
        icon: Icons.folder_zip_outlined,
        color: const Color(0xFF22C55E),
        actions: [
          ToolActionSpec(
            id: 'file-tools',
            title: _tr('文件工具', 'File Tools'),
            subtitle: _tr(
              'ZIP、批量重命名和扩展名修整。',
              'ZIP, rename, and extension cleanup.',
            ),
            icon: Icons.folder_zip_outlined,
            color: const Color(0xFF22C55E),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FileToolsPage()),
              );
            },
            badge: 'ZIP',
          ),
          ToolActionSpec(
            id: 'file-output-manager',
            title: _tr('输出文件管家', 'Output Manager'),
            subtitle: _tr(
              '集中管理 PDF、文件、OCR、下载和分享输出。',
              'Manage PDF, file, OCR, download, and share outputs.',
            ),
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF0F766E),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FileOutputManagerPage(),
                ),
              );
            },
            tags: const ['output', 'history', 'cleanup', 'share', 'files'],
            badge: _tr('输出', 'Output'),
          ),
          ToolActionSpec(
            id: 'material-ocr',
            title: _tr('资料扫描 OCR', 'Material OCR'),
            subtitle: _tr(
              '图片识别文字，保存 TXT 或生成复习卡片。',
              'Recognize image text, save TXT, or create study cards.',
            ),
            icon: Icons.document_scanner_outlined,
            color: const Color(0xFF16A34A),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MaterialOcrPage()),
              );
            },
            tags: const ['ocr', 'scan', 'text', 'study card'],
            badge: 'OCR',
          ),
          ToolActionSpec(
            id: 'web-archive',
            title: _tr('网页归档箱', 'Web Archive'),
            subtitle: _tr(
              '保存链接、网页摘要和文本快照，并接入资料搜索。',
              'Save links, page summaries, and searchable text snapshots.',
            ),
            icon: Icons.bookmark_add_outlined,
            color: const Color(0xFF0891B2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebArchivePage()),
              );
            },
            tags: const ['web', 'archive', 'bookmark', 'materials', 'search'],
            badge: _tr('归档', 'Archive'),
          ),
        ],
      ),
      ToolCategorySpec(
        id: 'network',
        label: _tr('网络', 'Network'),
        subtitle: _tr('虚拟局域网与连接状态', 'Virtual LAN and connection state'),
        icon: Icons.vpn_lock_outlined,
        color: const Color(0xFF6366F1),
        actions: [
          ToolActionSpec(
            id: 'virtual-lan',
            title: _tr('虚拟局域网', 'Virtual LAN'),
            subtitle: _tr(
              '加入 ZeroTier 网络，查看虚拟 IP。',
              'Join ZeroTier and inspect virtual IP.',
            ),
            icon: Icons.vpn_lock_outlined,
            color: const Color(0xFF6366F1),
            onTap: () => Navigator.pushNamed(context, '/virtual-lan'),
            badge: 'ZT',
          ),
        ],
      ),
      ToolCategorySpec(
        id: 'study',
        label: _tr('学习', 'Study'),
        subtitle: _tr('阅读、资料与复习', 'Reading, materials and review'),
        icon: Icons.auto_stories_outlined,
        color: const Color(0xFF8B5CF6),
        actions: [
          ToolActionSpec(
            id: 'smart-organizer',
            title: _tr('智能整理', 'Smart Organizer'),
            subtitle: _tr(
              '本地规则汇总待办、资料、复习、输出和诊断建议。',
              'Local suggestions for todos, materials, reviews, outputs, and diagnostics.',
            ),
            icon: Icons.tips_and_updates_outlined,
            color: const Color(0xFF0D9488),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SmartOrganizerPage()),
              );
            },
            tags: const [
              'smart',
              'organizer',
              'insight',
              'materials',
              'review',
              'todo',
              '智能',
              '整理',
            ],
            badge: _tr('本地', 'Local'),
          ),
          ToolActionSpec(
            id: 'material-search',
            title: _tr('资料搜索', 'Material Search'),
            subtitle: _tr(
              '搜索本地资料、网页归档和索引片段，并生成复习卡。',
              'Search local materials and web archives, then create study cards.',
            ),
            icon: Icons.manage_search_outlined,
            color: const Color(0xFF2563EB),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MaterialSearchPage()),
              );
            },
            tags: const [
              'materials',
              'search',
              'index',
              'study card',
              '资料',
              '搜索',
            ],
            badge: _tr('资料', 'Materials'),
          ),
          ToolActionSpec(
            id: 'user-manual',
            title: _tr('使用说明书', 'User Manual'),
            subtitle: _tr(
              '查看应用使用说明、资料流程、复习卡和排障入口。',
              'Read app usage, material workflow, review cards, and troubleshooting.',
            ),
            icon: Icons.menu_book_outlined,
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManualPage()),
              );
            },
            tags: const ['manual', 'help', 'guide', '说明书', '帮助'],
            badge: _tr('说明', 'Manual'),
          ),
          ToolActionSpec(
            id: 'study-cards',
            title: _tr('复习中心', 'Review Center'),
            subtitle: _tr(
              '本地复习卡片、今日待复习和间隔重复。',
              'Local study cards, due review, and spaced repetition.',
            ),
            icon: Icons.style_outlined,
            color: const Color(0xFFDB2777),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudyCenterPage()),
              );
            },
            badge: _tr('复习', 'Review'),
          ),
          ToolActionSpec(
            id: 'reading',
            title: l10n.readingTitle,
            subtitle: l10n.readingSubtitle,
            icon: Icons.menu_book_outlined,
            color: const Color(0xFF8B5CF6),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadingPage()),
              );
            },
            badge: _tr('阅读', 'Read'),
          ),
          ToolActionSpec(
            id: 'academic-search',
            title: l10n.academicSearchTitle,
            subtitle: l10n.academicSearchSubtitle,
            icon: Icons.auto_stories_outlined,
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AcademicSearchPage()),
              );
            },
            badge: _tr('检索', 'Search'),
          ),
        ],
      ),
      ToolCategorySpec(
        id: 'cloud',
        label: _tr('云盘', 'Cloud'),
        subtitle: _tr(
          'OpenList 共享文件、上传与下载',
          'OpenList shared files, uploads, and downloads',
        ),
        icon: Icons.cloud_queue_outlined,
        color: const Color(0xFF2563EB),
        actions: [
          ToolActionSpec(
            id: 'openlist-cloud',
            title: _tr('云盘共享', 'Cloud Share'),
            subtitle: _tr(
              '浏览 OpenList 共享文件，登录畅课后可上传。',
              'Browse OpenList shares and upload after Tronclass login.',
            ),
            icon: Icons.cloud_queue_outlined,
            color: const Color(0xFF2563EB),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OpenListCloudPage()),
              );
            },
            tags: const ['OpenList', 'cloud', 'share', 'upload', 'download'],
            badge: _tr('云盘', 'Cloud'),
          ),
          ToolActionSpec(
            id: 'material-sync-status',
            title: _tr('资料状态', 'Material Status'),
            subtitle: _tr(
              '查看下载、离线包、索引、重复文件和本地缺失。',
              'Inspect downloads, offline packages, index, duplicates, and missing files.',
            ),
            icon: Icons.sync_alt_outlined,
            color: const Color(0xFF0F766E),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaterialSyncStatusPage(),
                ),
              );
            },
            tags: const ['sync', 'offline', 'duplicate', 'index', 'status'],
            badge: _tr('状态', 'Status'),
          ),
        ],
      ),
      ToolCategorySpec(
        id: 'campus',
        label: _tr('校园', 'Campus'),
        subtitle: _tr('桂电入口与支持', 'GUET entries and support'),
        icon: Icons.school_outlined,
        color: const Color(0xFF10B981),
        actions: [
          ToolActionSpec(
            id: 'unipus-assist',
            title: 'U 校园辅助',
            subtitle: '自动扫描课程树，生成确认式学习辅助队列。',
            icon: Icons.assistant_direction_outlined,
            color: const Color(0xFF2563EB),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnipusAssistPage()),
              );
            },
            tags: const ['unipus', 'u-campus', 'assist', 'accessibility'],
            badge: 'Unipus',
          ),
          ToolActionSpec(
            id: 'guet-email',
            title: l10n.guetEmailTitle,
            subtitle: l10n.guetEmailSubtitle,
            icon: Icons.email_outlined,
            color: const Color(0xFF10B981),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GuetEmailApplyPage()),
              );
            },
            badge: _tr('邮箱', 'Mail'),
          ),
          ToolActionSpec(
            id: 'guet-official',
            title: l10n.guetOfficialTitle,
            subtitle: l10n.guetOfficialSubtitle,
            icon: Icons.public_outlined,
            color: const Color(0xFF059669),
            onTap: () => _openExternalUrl('https://www.guet.edu.cn/'),
            badge: _tr('官网', 'Web'),
          ),
          ToolActionSpec(
            id: 'computer-help',
            title: l10n.computerHelpTitle,
            subtitle: l10n.computerHelpSubtitle,
            icon: Icons.computer_outlined,
            color: const Color(0xFF0F766E),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ComputerHelpManualPage(),
                ),
              );
            },
            badge: _tr('帮助', 'Help'),
          ),
        ],
      ),
    ]);
  }

  void _selectToolCategory(int index) {
    setState(() => _selectedToolCategory = index);
  }

  Future<void> _openToolCategory(ToolCategorySpec category) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _selectedToolCategory = _toolCategories().indexWhere(
      (item) => item.id == category.id,
    );
    await _openSelectedToolCategory();
  }

  Future<void> _openSelectedToolCategory() async {
    final categories = _toolCategories();
    final selectedCategory = categories[_selectedToolCategory];
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ToolCategoryDetailPage(
          category: selectedCategory,
          pdfOutputDirectory: selectedCategory.id == 'pdf'
              ? _effectivePdfOutputDirectory
              : null,
          pdfLastOutputPath: selectedCategory.id == 'pdf'
              ? _lastOutputPath
              : null,
          onOpenPdfOutput:
              selectedCategory.id == 'pdf' &&
                  _lastOutputPath != null &&
                  _lastOutputPath!.isNotEmpty
              ? _openOutputFile
              : null,
          onSharePdfOutput:
              selectedCategory.id == 'pdf' &&
                  _lastOutputPath != null &&
                  _lastOutputPath!.isNotEmpty
              ? _shareOutputFile
              : null,
          onCopyPdfOutput:
              selectedCategory.id == 'pdf' &&
                  _lastOutputPath != null &&
                  _lastOutputPath!.isNotEmpty
              ? () => _copyOutputPath(_lastOutputPath!)
              : null,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.initializeServices) return;
      _loadPdfHistory();
      _refreshDefaultOutputDirectory();
    });
    FileToolHistoryStore.revision.addListener(_loadPdfHistory);
    AppSettings.layoutPreferencesStore.notifier.addListener(_onRegistryChanged);
    AppSettings.pluginStore.enabledPluginsNotifier.addListener(
      _onRegistryChanged,
    );
  }

  void _onRegistryChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadPdfHistory() async {
    final allRecords = await _historyStore.load();
    final records = allRecords
        .where((record) => record.scope == FileToolHistoryScope.pdf)
        .toList();
    if (!mounted) return;
    setState(() {
      _recentFiles
        ..clear()
        ..addAll(
          allRecords
              .where((record) => record.success && record.outputPath.isNotEmpty)
              .take(3),
        );
      _recentTasks
        ..clear()
        ..addAll(records.map(_ToolTaskRecord.fromHistory));
      if (_recentTasks.isNotEmpty && _recentTasks.first.outputPath.isNotEmpty) {
        _lastOutputPath = _recentTasks.first.outputPath;
      }
    });
  }

  Future<void> _openRecentOutput(String path) async {
    if (!await File(path).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                '文件已移动或删除，请到输出管理查看',
                'File moved or deleted. Check output manager.',
              ),
            ),
          ),
        );
      }
      return;
    }
    await OpenFilex.open(path);
  }

  Future<void> _shareRecentOutput(String path) async {
    if (!await File(path).exists()) {
      await _openRecentOutput(path);
      return;
    }
    await _shareOutputPath(path);
  }

  Future<void> _refreshDefaultOutputDirectory() async {
    if (_customOutputDir != null && _customOutputDir!.trim().isNotEmpty) {
      return;
    }
    final dir = await _outputDir();
    if (!mounted) return;
    setState(() {
      _defaultOutputDirPath = dir.path;
    });
  }

  Widget _buildDashboard(double totalBottomPadding) {
    final categories = _toolCategories();
    if (categories.isEmpty) {
      return CustomScrollView(
        controller: _dashboardScrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: DashboardEmptyState(
                title: _tr('暂无可见工具', '暂无可见工具'),
                subtitle: _tr('请在设置的界面布局中恢复工具卡片。', '请在设置的界面布局中恢复工具卡片。'),
                icon: Icons.visibility_off_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: totalBottomPadding + 20)),
        ],
      );
    }
    if (_selectedToolCategory >= categories.length) {
      _selectedToolCategory = categories.isEmpty ? 0 : categories.length - 1;
    }
    return CustomScrollView(
      key: const PageStorageKey('tools-dashboard'),
      controller: _dashboardScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: ToolCatalog(
              categories: categories,
              pinnedIds: AppSettings
                  .layoutPreferencesStore
                  .notifier
                  .value
                  .pinnedToolActionIds,
              onOpenCategory: _openToolCategory,
            ),
          ),
        ),
        if (_busy || _status.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(_status.isEmpty ? l10n.statusSelectTool : _status),
                  ],
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_recentFiles.isNotEmpty) ...[
                  Text(
                    _tr('最近文件', 'Recent files'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final record in _recentFiles)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(
                        p.basename(record.outputPath),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(record.toolName),
                      onTap: () => _openRecentOutput(record.outputPath),
                      trailing: IconButton(
                        tooltip: _tr('分享', 'Share'),
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => _shareRecentOutput(record.outputPath),
                      ),
                    ),
                ],
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tr('文件记录与输出管理', 'File history & outputs')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openOutputManager,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_tr('工作流', 'Workflows')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _RecommendedWorkflowPanel(
                        recipes: _recommendedRecipes(categories),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: totalBottomPadding + 20)),
      ],
    );
  }

  Widget _buildCategoryShortcutGrid(List<ToolCategorySpec> categories) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent - 32;
        final columns = width >= 720 ? 3 : 2;
        return SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            return _ToolCategoryShortcutCard(
              category: categories[index],
              selected: index == _selectedToolCategory,
              onTap: () => _selectToolCategory(index),
            );
          }, childCount: categories.length),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: width < 380 ? 1.78 : 2.28,
          ),
        );
      },
    );
  }

  Widget _buildFeaturedToolActions(List<ToolCategorySpec> categories) {
    final featured = <ToolActionSpec>[];
    for (final category in categories) {
      if (category.actions.isNotEmpty) {
        featured.add(category.actions.first);
      }
      if (featured.length >= 4) break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final cards = featured
            .map(
              (action) => DashboardActionCard(
                title: action.title,
                subtitle: action.subtitle,
                icon: action.icon,
                color: action.color,
                onTap: action.onTap,
                trailing: action.badge == null
                    ? null
                    : _DashboardPill(label: action.badge!, color: action.color),
              ),
            )
            .toList();

        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: cards[i]),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              cards[i],
            ],
          ],
        );
      },
    );
  }

  List<ToolWorkflowRecipe> _recommendedRecipes(
    List<ToolCategorySpec> categories,
  ) {
    final byId = <String, ToolActionSpec>{
      for (final category in categories)
        for (final action in category.actions) action.id: action,
    };
    final recipes = <ToolWorkflowRecipe>[
      ToolWorkflowRecipe(
        id: 'pdf-inbox',
        name: _tr('PDF 收件箱整理', 'PDF inbox cleanup'),
        description: _tr(
          '转换、压缩或编排 PDF 后，集中进入输出管家再加入资料库。',
          'Convert or arrange PDFs, then review outputs and add them to materials.',
        ),
        steps: const <ToolWorkflowStep>[
          ToolWorkflowStep(id: 'lightweight-to-pdf', label: 'Files to PDF'),
          ToolWorkflowStep(id: 'compress-pdf', label: 'Compress'),
          ToolWorkflowStep(id: 'file-output-manager', label: 'Inbox'),
        ],
        inputKinds: const <String>['image', 'text', 'pdf'],
        outputPolicy: _tr('确认后写入资料库', 'Confirm before adding to library'),
        enabled:
            byId.containsKey('lightweight-to-pdf') &&
            byId.containsKey('file-output-manager'),
      ),
      ToolWorkflowRecipe(
        id: 'transfer-package',
        name: _tr('局域网资料交付', 'LAN handoff package'),
        description: _tr(
          '先整理输出文件，再用本地传输发送给同学或另一台设备。',
          'Prepare output files, then send them over local transfer.',
        ),
        steps: const <ToolWorkflowStep>[
          ToolWorkflowStep(id: 'file-output-manager', label: 'Output'),
          ToolWorkflowStep(id: 'local-transfer', label: 'Transfer'),
        ],
        inputKinds: const <String>['file', 'folder'],
        outputPolicy: _tr('仅本地与局域网', 'Local and LAN only'),
        enabled:
            byId.containsKey('file-output-manager') &&
            byId.containsKey('local-transfer'),
      ),
      ToolWorkflowRecipe(
        id: 'archive-search',
        name: _tr('资料快照检索', 'Material snapshot search'),
        description: _tr(
          '网页归档或 OCR 后进入资料搜索，适合整理课程资料线索。',
          'Archive pages or OCR text, then search them as course materials.',
        ),
        steps: const <ToolWorkflowStep>[
          ToolWorkflowStep(id: 'web-archive', label: 'Archive'),
          ToolWorkflowStep(id: 'material-ocr', label: 'OCR'),
          ToolWorkflowStep(id: 'material-search', label: 'Search'),
        ],
        inputKinds: const <String>['url', 'image', 'text'],
        outputPolicy: _tr('本地索引优先', 'Local index first'),
        enabled:
            byId.containsKey('web-archive') &&
            byId.containsKey('material-search'),
      ),
    ];
    return recipes.where((recipe) => recipe.enabled).toList(growable: false);
  }

  void _openOutputManager() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FileOutputManagerPage()),
    );
  }

  Widget _buildToolActionGrid(List<ToolActionSpec> actions) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent - 32;
        final columns = width >= 720
            ? 3
            : width >= 430
            ? 2
            : 1;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ToolActionCard(action: actions[index]),
              childCount: actions.length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 2.55 : 1.42,
            ),
          ),
        );
      },
    );
  }

  String _shortPathLabel(String? path, {required String emptyLabel}) {
    if (path == null || path.trim().isEmpty) {
      return emptyLabel;
    }
    final name = p.basename(path.trim());
    return name.isEmpty ? path.trim() : name;
  }

  @override
  void dispose() {
    FileToolHistoryStore.revision.removeListener(_loadPdfHistory);
    AppSettings.layoutPreferencesStore.notifier.removeListener(
      _onRegistryChanged,
    );
    AppSettings.pluginStore.enabledPluginsNotifier.removeListener(
      _onRegistryChanged,
    );
    _dashboardScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickOutputDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: l10n.pickPdfOutputDirectory,
    );
    if (path == null || path.trim().isEmpty) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _customOutputDir = path;
      _status = l10n.statusOutputDirChanged(path);
    });
  }

  void _resetOutputDirectory() {
    setState(() {
      _customOutputDir = null;
      _status = l10n.statusOutputDirReset;
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

    return GueterStorageService.instance.publicDirectory(
      GueterPublicDirectory.pdfTools,
    );
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

  Future<List<File>> _pickLightweightPdfSources() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      withData: false,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'bmp',
        'gif',
        'txt',
        'md',
        'markdown',
        'html',
        'htm',
        'csv',
      ],
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
        _status = l10n.toolRunFailed(e.toString());
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.toolRunFailed(e.toString()))));
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
    final timestamp = DateTime.now();
    _recentTasks.insert(
      0,
      _ToolTaskRecord(
        toolName: toolName,
        inputSummary: inputSummary,
        outputPath: outputPath,
        timestamp: timestamp,
        success: success,
        message: message,
      ),
    );
    if (_recentTasks.length > 30) {
      _recentTasks.removeRange(30, _recentTasks.length);
    }
    unawaited(
      _historyStore.append(
        FileToolHistoryRecord(
          scope: FileToolHistoryScope.pdf,
          toolName: toolName,
          inputSummary: inputSummary,
          outputPath: outputPath,
          timestamp: timestamp,
          success: success,
          message: message,
        ),
      ),
    );
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
        SnackBar(content: Text(l10n.openFailedMessage(result.message))),
      );
    }
  }

  Future<void> _shareOutputFile() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;

    await _shareOutputPath(path);
  }

  Future<void> _shareOutputPath(String path) async {
    try {
      await _shareService.shareOutput(path, text: l10n.pdfOutputShareText);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.openFailedMessage(error.toString()))),
      );
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.openFailedMessage(url))));
    }
  }

  Future<void> _pdfToImages() async {
    final file = await _pickSinglePdf();
    if (file == null) return;

    final outDir = await _outputDir();
    final bytes = await file.readAsBytes();
    final stream = Printing.raster(bytes, dpi: 160);
    final yielder = _toolYielder();

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
      await yielder.tick();
    }

    if (!mounted) return;
    setState(() {
      _status =
          '${l10n.pdfToImagesComplete(index)}\n\u8f93\u51fa\u76ee\u5f55: ${outDir.path}';
      _lastOutputPath = outDir.path;
      _recordTask(
        toolName: l10n.pdfToImagesTitle,
        inputSummary: p.basename(file.path),
        outputPath: outDir.path,
        success: true,
        message: '\u5bfc\u51fa $index \u5f20 PNG',
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pdfToImagesComplete(index))));
  }

  Future<void> _lightweightFilesToPdf() async {
    final files = await _pickLightweightPdfSources();
    if (files.isEmpty) return;

    final outDir = await _outputDir();
    final result = await _pdfConversionService.convertFilesToPdf(
      files: files,
      outputDirectory: outDir,
      performanceMode: _performanceMode,
    );

    if (!mounted) return;
    final outputPath = result.primaryOutputPath;
    setState(() {
      _status =
          '${_tr('轻量格式转 PDF 完成', 'Files converted to PDF')}\n${_tr('输出', 'Output')}: $outputPath';
      _lastOutputPath = outputPath;
      _recordTask(
        toolName: _tr('轻量转 PDF', 'Files to PDF'),
        inputSummary: files.map((file) => p.basename(file.path)).join(', '),
        outputPath: outputPath,
        success: true,
        message: _tr(
          '已转换 ${result.outputPaths.length} 个文件',
          'Converted ${result.outputPaths.length} files',
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr('轻量格式转 PDF 完成', 'Files converted to PDF'))),
    );
  }

  Future<void> _imagesToPdf() async {
    final images = await _pickImages();
    if (images.isEmpty) return;

    final document = PdfDocument();
    final yielder = _toolYielder();
    for (final imageFile in images) {
      final imageBytes = await imageFile.readAsBytes();
      final bitmap = PdfBitmap(imageBytes);
      final page = document.pages.add();
      final size = page.getClientSize();
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
      await yielder.tick();
    }

    final outDir = await _outputDir();
    final outFile = File(
      p.join(
        outDir.path,
        'images_merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
      ),
    );
    await outFile.writeAsBytes(document.saveSync(), flush: true);
    document.dispose();

    if (!mounted) return;
    setState(() {
      _status =
          '\u56fe\u7247\u5408\u5e76 PDF \u5b8c\u6210\n\u8f93\u51fa\u6587\u4ef6: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: l10n.imagesToPdfTitle,
        inputSummary: '${images.length} \u5f20\u56fe\u7247',
        outputPath: outFile.path,
        success: true,
        message: '\u5408\u5e76\u4e3a PDF',
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.imagesToPdfComplete)));
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
      _status =
          'PDF \u538b\u7f29\u5b8c\u6210\n\u8f93\u51fa\u6587\u4ef6: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: l10n.compressPdfTitle,
        inputSummary: p.basename(file.path),
        outputPath: outFile.path,
        success: true,
        message: '\u538b\u7f29\u5b8c\u6210',
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.compressPdfComplete)));
  }

  Future<List<int>?> _askPagesToExtract(int maxPage) async {
    final controller = TextEditingController();
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.extractPagesDialogTitle),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: l10n.extractPagesHint(maxPage),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parsePageExpression(controller.text, maxPage);
                Navigator.pop(context, parsed);
              },
              child: Text(l10n.confirmButton),
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
    final yielder = _toolYielder();
    for (final pageNumber in pages) {
      final template = source.pages[pageNumber - 1].createTemplate();
      final page = target.pages.add();
      final size = page.getClientSize();
      page.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        Size(size.width, size.height),
      );
      await yielder.tick();
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
      _status =
          'PDF \u63d0\u53d6\u9875\u9762\u5b8c\u6210\uff08${pages.length} \u9875\uff09\n\u8f93\u51fa\u6587\u4ef6: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: l10n.extractPagesTitle,
        inputSummary:
            '${p.basename(file.path)} | \u9875\u9762 ${pages.join(',')}',
        outputPath: outFile.path,
        success: true,
        message: '\u63d0\u53d6 ${pages.length} \u9875',
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.extractPagesComplete(pages.length))),
    );
  }

  Future<Map<String, dynamic>?> _askWatermarkOptions() async {
    final controller = TextEditingController(
      text: '\u4ec5\u4f9b\u5185\u90e8\u4f7f\u7528',
    );
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
              title: Text(l10n.watermarkDialogTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: l10n.watermarkTextLabel,
                        hintText: l10n.watermarkTextHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.watermarkOpacityLabel(opacity.toStringAsFixed(2)),
                    ),
                    Slider(
                      min: 0.05,
                      max: 0.60,
                      value: opacity,
                      onChanged: (v) => setDialogState(() => opacity = v),
                    ),
                    Text(l10n.watermarkAngleLabel(angle.toStringAsFixed(0))),
                    Slider(
                      min: -80,
                      max: 80,
                      value: angle,
                      onChanged: (v) => setDialogState(() => angle = v),
                    ),
                    Text(
                      l10n.watermarkFontSizeLabel(fontSize.toStringAsFixed(0)),
                    ),
                    Slider(
                      min: 18,
                      max: 72,
                      value: fontSize,
                      onChanged: (v) => setDialogState(() => fontSize = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: colorIndex,
                      decoration: InputDecoration(
                        labelText: l10n.watermarkColorLabel,
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(_watermarkColorOptions.length, (
                        index,
                      ) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(_watermarkColorName(index)),
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
                  child: Text(l10n.cancelButton),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'text': controller.text.trim(),
                      'opacity': opacity,
                      'angle': angle,
                      'fontSize': fontSize,
                      'color':
                          _watermarkColorOptions[colorIndex]['color']
                              as PdfColor,
                    });
                  },
                  child: Text(l10n.confirmButton),
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
    final yielder = _toolYielder();

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
      await yielder.tick();
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
      _status =
          'PDF \u6c34\u5370\u5b8c\u6210\n\u8f93\u51fa\u6587\u4ef6: ${outFile.path}';
      _lastOutputPath = outFile.path;
      _recordTask(
        toolName: l10n.watermarkTitle,
        inputSummary: '${p.basename(file.path)} | "$text"',
        outputPath: outFile.path,
        success: true,
        message:
            '\u900f\u660e\u5ea6 ${opacity.toStringAsFixed(2)}\uff0c\u89d2\u5ea6 ${angle.toStringAsFixed(0)}\u00b0',
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.watermarkComplete)));
  }

  String _watermarkColorName(int index) {
    switch (index) {
      case 0:
        return l10n.watermarkColorDeepRed;
      case 1:
        return l10n.watermarkColorDeepBlue;
      case 2:
        return l10n.watermarkColorDeepGray;
      default:
        return l10n.watermarkColorBlack;
    }
  }

  void _copyOutputPath(String path) {
    Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.outputPathCopied)));
  }

  Widget _buildTabScrollView({
    required double totalBottomPadding,
    required List<Widget> children,
    ScrollController? controller,
  }) {
    return CustomScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, totalBottomPadding + 20),
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
      ],
    );
  }

  Widget _buildEditorialActionGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1120
            ? 3
            : width >= 700
            ? 2
            : 1;
        final childAspectRatio = switch (crossAxisCount) {
          1 => 1.58,
          2 => 1.22,
          _ => 1.08,
        };

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  Widget _buildReadingTab(double totalBottomPadding) {
    return _buildTabScrollView(
      totalBottomPadding: totalBottomPadding,
      children: [
        const SizedBox(height: 28),
        _SectionHeader(
          eyebrow: _tr('第一组', 'Group 01'),
          title: _tr('近场与传输', 'Nearby and Transfer'),
          subtitle: _tr(
            '把线下配对和局域网传输放在同一屏，先处理离你最近的连接动作。',
            'Keep nearby pairing and local transfer together for the fastest offline flow.',
          ),
        ),
        _PrimaryEntryCard(
          onTap: () => Navigator.pushNamed(context, '/nearby-room'),
          icon: Icons.meeting_room_outlined,
          title: _tr('附近房间', 'Nearby Room'),
          subtitle: _tr(
            '发现附近房间并进行本地近场配对，不再依赖旧的共享签到链路。',
            'Discover nearby rooms for local pairing without relying on the retired shared sign-in flow.',
          ),
          color: Colors.teal,
        ),
        const SizedBox(height: 12),
        _PrimaryEntryCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LocalTransferPage()),
            );
          },
          icon: Icons.swap_horiz_rounded,
          title: l10n.localTransferTitle,
          subtitle: l10n.localTransferSubtitle,
          color: Colors.blue,
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          eyebrow: _tr('第二组', 'Group 02'),
          title: _tr('阅读与检索', 'Reading and Search'),
          subtitle: _tr(
            '内容阅读和论文检索收拢成一个区块，减少在多个页面之间切换。',
            'Place reading and paper search in one focused block instead of scattering them across the page.',
          ),
        ),
        _PrimaryEntryCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReadingPage()),
            );
          },
          icon: Icons.menu_book_outlined,
          title: l10n.readingTitle,
          subtitle: l10n.readingSubtitle,
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _PrimaryEntryCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AcademicSearchPage()),
            );
          },
          icon: Icons.auto_stories_outlined,
          title: l10n.academicSearchTitle,
          subtitle: l10n.academicSearchSubtitle,
          color: Colors.cyan,
        ),
        const SizedBox(height: 28),
        _SectionHeader(
          eyebrow: _tr('第三组', 'Group 03'),
          title: _tr('帮助', 'Help'),
          subtitle: _tr(
            '需要电脑速查时，直接进入独立卡片，不和阅读入口混在一起。',
            'Keep the quick computer manual separate so it reads like a supporting module, not another list item.',
          ),
        ),
        _FeaturedToolCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComputerHelpManualPage()),
            );
          },
          accentColor: Colors.amber.shade800,
          eyebrow: _tr('离线手册', 'Offline Manual'),
          icon: Icons.computer_outlined,
          title: l10n.computerHelpTitle,
          subtitle: l10n.computerHelpSubtitle,
          details: [
            _tr('网络问题', 'Network'),
            _tr('系统设置', 'System'),
            _tr('常见排错', 'Troubleshooting'),
          ],
        ),
      ],
    );
  }

  Widget _buildPdfTab(double totalBottomPadding) {
    final outputWorkspace = _effectivePdfOutputDirectory;
    final statusText = _status.isEmpty ? l10n.statusSelectTool : _status;

    return _buildTabScrollView(
      totalBottomPadding: totalBottomPadding,
      children: [
        _TabHeroHeader(
          eyebrow: '${l10n.toolsTabPdf} / ${l10n.pdfToolsTitle}',
          title: _tr('PDF 工作台', 'PDF Workbench'),
          subtitle: _tr(
            '把文件入口、输出目录、处理动作和最近结果重新组织成一个连续的工作面板。',
            'Reframe file entry, output directory, processing actions, and recent results as one continuous workbench.',
          ),
          accentColor: Colors.orange,
          icon: Icons.picture_as_pdf_outlined,
          footnotes: [
            _busy
                ? _tr('当前正在处理任务', 'A task is currently running')
                : _tr('当前空闲，可开始新任务', 'Idle and ready for the next task'),
            l10n.recentTasksCount(_recentTasks.length),
          ],
        ),
        const SizedBox(height: 24),
        _WorkbenchStatusPanel(
          title: _tr('工作区状态', 'Workbench Status'),
          subtitle: _tr(
            '上半区显示当前进度，下半区管理输出目录和最近一次结果，避免操作链路断开。',
            'Keep progress, output controls, and the latest result in one panel so the workflow stays continuous.',
          ),
          statusLabel: _tr('当前状态', 'Current Status'),
          statusValue: statusText,
          outputLabel: _tr('输出目录', 'Output Directory'),
          outputValue: outputWorkspace,
          lastOutputValue: _lastOutputPath,
          pickOutputLabel: _tr('选择输出目录', 'Choose Output Directory'),
          resetOutputLabel: _tr('恢复默认目录', 'Reset Directory'),
          openOutputLabel: _tr('打开输出', '打开输出'),
          shareOutputLabel: _tr('分享输出', 'Share Output'),
          busy: _busy,
          onPickOutputDirectory: _busy ? null : _pickOutputDirectory,
          onResetOutputDirectory: _busy ? null : _resetOutputDirectory,
          onOpenOutput:
              (_busy || _lastOutputPath == null || _lastOutputPath!.isEmpty)
              ? null
              : _openOutputFile,
          onShareOutput:
              (_busy || _lastOutputPath == null || _lastOutputPath!.isEmpty)
              ? null
              : _shareOutputFile,
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          eyebrow: _tr('入口', 'Entry'),
          title: _tr('文件工具', 'File Tools'),
          subtitle: _tr(
            '先处理 ZIP、重命名和扩展名，再进入 PDF 细分动作，结构更符合真实工作顺序。',
            'Handle ZIP, rename, and extension cleanup first, then move into PDF-specific operations.',
          ),
        ),
        _FeaturedToolCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FileToolsPage()),
            );
          },
          accentColor: Colors.indigo,
          eyebrow: _tr('Featured', 'Featured'),
          icon: Icons.folder_zip_outlined,
          title: _tr('文件工具', 'File Tools'),
          subtitle: _tr(
            'ZIP 解压/打包、文件重命名和扩展名编辑。',
            'ZIP extract/create, file rename, and extension editing.',
          ),
          details: ['ZIP', _tr('重命名', 'Rename'), _tr('扩展名', 'Extensions')],
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          eyebrow: _tr('动作区', 'Actions'),
          title: _tr('PDF 操作', 'PDF 操作'),
          subtitle: _tr(
            '转换、压缩、提取和加水印统一为一组动作卡，窄屏会自动退化成更舒适的单列。',
            'Conversion, compression, extraction, and watermarking share one responsive action grid.',
          ),
        ),
        _buildEditorialActionGrid([
          _ActionToolCard(
            onTap: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PdfArrangePage()),
                    );
                  },
            icon: Icons.dashboard_customize_outlined,
            title: _tr('PDF 页面编排', 'PDF Arrange'),
            subtitle: _tr(
              '拖拽排序、删除恢复、旋转页面并导出',
              'Reorder, remove, rotate, and export pages',
            ),
            color: Colors.deepOrange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_lightweightFilesToPdf),
            icon: Icons.post_add_outlined,
            title: _tr('轻量转 PDF', 'Files to PDF'),
            subtitle: _tr(
              '图片、TXT、Markdown、HTML、CSV 转 PDF',
              'Images, TXT, Markdown, HTML, and CSV',
            ),
            color: Colors.deepOrange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_pdfToImages),
            icon: Icons.image_outlined,
            title: l10n.pdfToImagesTitle,
            subtitle: l10n.pdfToImagesSubtitle,
            color: Colors.orange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_imagesToPdf),
            icon: Icons.collections_outlined,
            title: l10n.imagesToPdfTitle,
            subtitle: l10n.imagesToPdfSubtitle,
            color: Colors.deepOrange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_compressPdf),
            icon: Icons.compress_outlined,
            title: l10n.compressPdfTitle,
            subtitle: l10n.compressPdfSubtitle,
            color: Colors.amber,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_extractPages),
            icon: Icons.snippet_folder_outlined,
            title: l10n.extractPagesTitle,
            subtitle: l10n.extractPagesSubtitle,
            color: Colors.orange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_addWatermark),
            icon: Icons.verified_user_outlined,
            title: l10n.watermarkTitle,
            subtitle: l10n.watermarkSubtitle,
            color: Colors.deepOrange,
          ),
        ]),
        const SizedBox(height: 24),
        _RecentTasksPanel(
          title: l10n.recentTasksTitle,
          subtitle: l10n.recentTasksCount(_recentTasks.length),
          emptyText: _tr('还没有 PDF 任务记录。', 'No PDF task has been recorded yet.'),
          copyTooltip: l10n.copyOutputPath,
          tasks: _recentTasks,
          onCopyPath: _copyOutputPath,
          onSharePath: _shareOutputPath,
          formatTime: _formatTime,
        ),
        const SizedBox(height: 12),
        _WorkbenchInfoBlock(
          title: _tr('技术说明', 'Tech Note'),
          body: _tr(
            '底层依赖 printing、syncfusion_flutter_pdf、file_picker、share_plus 和 open_filex；这里只弱化成说明，不再抢主视觉。',
            'This workbench is powered by printing, syncfusion_flutter_pdf, file_picker, share_plus, and open_filex.',
          ),
          icon: Icons.info_outline,
          accentColor: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildGueterTab(double totalBottomPadding) {
    return _buildTabScrollView(
      totalBottomPadding: totalBottomPadding,
      children: [
        _TabHeroHeader(
          eyebrow: '${l10n.toolsTabGueter} / Campus',
          title: l10n.gueterToolsTitle,
          subtitle: _tr(
            '校园常用入口收成一个简洁的页面头部和动作区，减少杂散信息。',
            'Campus essentials live in one concise header and action field without extra noise.',
          ),
          accentColor: Colors.green,
          icon: Icons.hub_outlined,
          footnotes: [
            l10n.gueterToolsSubtitle,
            _tr('3 个常用入口', '3 essential links'),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          eyebrow: _tr('快捷入口', 'Quick Access'),
          title: _tr('校园常用入口', 'Campus Essentials'),
          subtitle: _tr(
            '用和 PDF 页一致的动作卡语法承载桂电邮箱、官网和 AI 配图入口。',
            'Use the same action-card grammar as the PDF tab for mail, official site, and AI figure generation.',
          ),
        ),
        _buildEditorialActionGrid([
          _ActionToolCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GuetEmailApplyPage()),
              );
            },
            icon: Icons.email_outlined,
            title: l10n.guetEmailTitle,
            subtitle: l10n.guetEmailSubtitle,
            color: Colors.green,
          ),
          _ActionToolCard(
            onTap: () => _openExternalUrl('https://www.guet.edu.cn/'),
            icon: Icons.public_outlined,
            title: l10n.guetOfficialTitle,
            subtitle: l10n.guetOfficialSubtitle,
            color: Colors.teal,
          ),
          _ActionToolCard(
            onTap: () => _openExternalUrl('https://deepscientist.cc'),
            icon: Icons.science_outlined,
            title: l10n.aiFigureTitle,
            subtitle: l10n.aiFigureSubtitle,
            color: Colors.green,
          ),
        ]),
      ],
    );
  }

  Widget _buildDashboardLegacy(double totalBottomPadding) {
    final outputWorkspace = _effectivePdfOutputDirectory;
    final statusText = _status.isEmpty ? l10n.statusSelectTool : _status;
    return _buildTabScrollView(
      totalBottomPadding: totalBottomPadding,
      children: [
        _TabHeroHeader(
          eyebrow: _tr('Tool Dashboard', 'Tool Dashboard'),
          title: _tr('把高频工具放回一页首页', 'One-page tool dashboard'),
          subtitle: _tr(
            '取消原来的阅读 / PDF / GUETer 三标签，把高频入口、PDF 工作台、校园工具和帮助信息重新编排成一个连续工作流。',
            'Replace the old Reading / PDF / GUETer tabs with one continuous dashboard for quick entries, the PDF workbench, campus tools, and help.',
          ),
          accentColor: Colors.deepPurple,
          icon: Icons.dashboard_customize_outlined,
          footnotes: [
            _busy
                ? _tr('当前有任务进行中', 'A task is running')
                : _tr('当前空闲', 'Idle now'),
            l10n.recentTasksCount(_recentTasks.length),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          eyebrow: _tr('Quick Access', 'Quick Access'),
          title: _tr('高频入口', '高频入口'),
          subtitle: _tr(
            '把最常用的入口直接放在第一屏，减少跨标签切换。',
            'Put the most-used actions on the first screen and remove tab hopping.',
          ),
        ),
        _buildEditorialActionGrid([
          _ActionToolCard(
            onTap: () => Navigator.pushNamed(context, '/nearby-room'),
            icon: Icons.meeting_room_outlined,
            title: _tr('附近房间', 'Nearby Room'),
            subtitle: _tr(
              '近场发现、配对与热点接力',
              'Nearby discovery, pairing, and hotspot relay',
            ),
            color: Colors.teal,
          ),
          _ActionToolCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LocalTransferPage()),
              );
            },
            icon: Icons.swap_horiz_rounded,
            title: l10n.localTransferTitle,
            subtitle: l10n.localTransferSubtitle,
            color: Colors.blue,
          ),
          _ActionToolCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadingPage()),
              );
            },
            icon: Icons.menu_book_outlined,
            title: l10n.readingTitle,
            subtitle: l10n.readingSubtitle,
            color: Colors.indigo,
          ),
          _ActionToolCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AcademicSearchPage()),
              );
            },
            icon: Icons.auto_stories_outlined,
            title: l10n.academicSearchTitle,
            subtitle: l10n.academicSearchSubtitle,
            color: Colors.cyan,
          ),
        ]),
        const SizedBox(height: 28),
        const SizedBox(height: 28),
        _SectionHeader(
          eyebrow: _tr('Workbench', 'Workbench'),
          title: _tr('PDF 工作台', 'PDF Workbench'),
          subtitle: _tr(
            '保留输出目录、状态、最近任务和操作网格，但从标签页里提到主流程中间。',
            'Keep output controls, status, recent tasks, and the action grid, but bring them into the main flow.',
          ),
        ),
        _WorkbenchStatusPanel(
          title: _tr('工作区状态', 'Workbench Status'),
          subtitle: _tr(
            '集中查看当前进度、输出目录和最近一次结果。',
            'Track progress, output location, and the latest result in one place.',
          ),
          statusLabel: _tr('当前状态', 'Current Status'),
          statusValue: statusText,
          outputLabel: _tr('输出目录', 'Output Directory'),
          outputValue: outputWorkspace,
          lastOutputValue: _lastOutputPath,
          pickOutputLabel: _tr('选择输出目录', 'Choose Output Directory'),
          resetOutputLabel: _tr('恢复默认目录', 'Reset Directory'),
          openOutputLabel: _tr('打开输出', '打开输出'),
          shareOutputLabel: _tr('分享输出', 'Share Output'),
          busy: _busy,
          onPickOutputDirectory: _busy ? null : _pickOutputDirectory,
          onResetOutputDirectory: _busy ? null : _resetOutputDirectory,
          onOpenOutput:
              (_busy || _lastOutputPath == null || _lastOutputPath!.isEmpty)
              ? null
              : _openOutputFile,
          onShareOutput:
              (_busy || _lastOutputPath == null || _lastOutputPath!.isEmpty)
              ? null
              : _shareOutputFile,
        ),
        const SizedBox(height: 24),
        _FeaturedToolCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FileToolsPage()),
            );
          },
          accentColor: Colors.indigo,
          eyebrow: _tr('File Entry', 'File Entry'),
          icon: Icons.folder_zip_outlined,
          title: _tr('文件工具', 'File Tools'),
          subtitle: _tr(
            'ZIP 解压/打包、重命名和扩展名编辑，作为 PDF 工作前的入口。',
            'ZIP extract/create, rename, and extension editing before PDF tasks.',
          ),
          details: ['ZIP', _tr('重命名', 'Rename'), _tr('扩展名', 'Extensions')],
        ),
        const SizedBox(height: 24),
        _buildEditorialActionGrid([
          _ActionToolCard(
            onTap: _busy
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PdfArrangePage()),
                    );
                  },
            icon: Icons.dashboard_customize_outlined,
            title: _tr('PDF 页面编排', 'PDF Arrange'),
            subtitle: _tr(
              '拖拽排序、删除恢复、旋转页面并导出',
              'Reorder, remove, rotate, and export pages',
            ),
            color: Colors.deepOrange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_lightweightFilesToPdf),
            icon: Icons.post_add_outlined,
            title: _tr('轻量转 PDF', 'Files to PDF'),
            subtitle: _tr(
              '图片、TXT、Markdown、HTML、CSV 转 PDF',
              'Images, TXT, Markdown, HTML, and CSV',
            ),
            color: Colors.deepOrange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_pdfToImages),
            icon: Icons.image_outlined,
            title: l10n.pdfToImagesTitle,
            subtitle: l10n.pdfToImagesSubtitle,
            color: Colors.orange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_imagesToPdf),
            icon: Icons.collections_outlined,
            title: l10n.imagesToPdfTitle,
            subtitle: l10n.imagesToPdfSubtitle,
            color: Colors.deepOrange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_compressPdf),
            icon: Icons.compress_outlined,
            title: l10n.compressPdfTitle,
            subtitle: l10n.compressPdfSubtitle,
            color: Colors.amber,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_extractPages),
            icon: Icons.snippet_folder_outlined,
            title: l10n.extractPagesTitle,
            subtitle: l10n.extractPagesSubtitle,
            color: Colors.orange,
          ),
          _ActionToolCard(
            onTap: _busy ? null : () => _runTool(_addWatermark),
            icon: Icons.verified_user_outlined,
            title: l10n.watermarkTitle,
            subtitle: l10n.watermarkSubtitle,
            color: Colors.deepOrange,
          ),
        ]),
        const SizedBox(height: 24),
        _RecentTasksPanel(
          title: l10n.recentTasksTitle,
          subtitle: l10n.recentTasksCount(_recentTasks.length),
          emptyText: _tr('还没有 PDF 任务记录。', 'No PDF task has been recorded yet.'),
          copyTooltip: l10n.copyOutputPath,
          tasks: _recentTasks,
          onCopyPath: _copyOutputPath,
          onSharePath: _shareOutputPath,
          formatTime: _formatTime,
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          eyebrow: _tr('Campus & Help', 'Campus & Help'),
          title: _tr('校园入口与帮助', 'Campus and Help'),
          subtitle: _tr(
            '把校园常用入口和离线帮助作为底部支撑区域，不再单独占一个标签。',
            'Move campus links and offline help into a supporting lower section instead of a full tab.',
          ),
        ),
        _buildEditorialActionGrid([
          _ActionToolCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GuetEmailApplyPage()),
              );
            },
            icon: Icons.email_outlined,
            title: l10n.guetEmailTitle,
            subtitle: l10n.guetEmailSubtitle,
            color: Colors.green,
          ),
          _ActionToolCard(
            onTap: () => _openExternalUrl('https://www.guet.edu.cn/'),
            icon: Icons.public_outlined,
            title: l10n.guetOfficialTitle,
            subtitle: l10n.guetOfficialSubtitle,
            color: Colors.teal,
          ),
          _ActionToolCard(
            onTap: () => _openExternalUrl('https://deepscientist.cc'),
            icon: Icons.science_outlined,
            title: l10n.aiFigureTitle,
            subtitle: l10n.aiFigureSubtitle,
            color: Colors.green,
          ),
          _ActionToolCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ComputerHelpManualPage(),
                ),
              );
            },
            icon: Icons.computer_outlined,
            title: l10n.computerHelpTitle,
            subtitle: l10n.computerHelpSubtitle,
            color: Colors.amber.shade800,
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsPageTitle)),
      body: _buildDashboard(0),
    );
  }
}

Color _dashboardSurface(BuildContext context, Color accent) {
  final theme = Theme.of(context);
  final alpha = theme.brightness == Brightness.dark ? 0.16 : 0.055;
  return Color.alphaBlend(
    accent.withValues(alpha: alpha),
    theme.colorScheme.surface,
  );
}

class _ToolEfficiencyOverview extends StatelessWidget {
  const _ToolEfficiencyOverview({
    required this.busy,
    required this.outputSummary,
    required this.recentTasks,
    required this.lastOutputPath,
    required this.onOpenOutputManager,
    required this.onOpenLastOutput,
    required this.onShareLastOutput,
    required this.onRefresh,
  });

  final bool busy;
  final FileOutputManagerSummary? outputSummary;
  final List<_ToolTaskRecord> recentTasks;
  final String? lastOutputPath;
  final VoidCallback onOpenOutputManager;
  final VoidCallback? onOpenLastOutput;
  final VoidCallback? onShareLastOutput;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = outputSummary;
    final latestName = lastOutputPath == null || lastOutputPath!.trim().isEmpty
        ? _localizedLabel(context, '暂无输出', 'No output')
        : p.basename(lastOutputPath!);

    return AppCard(
      elevation: 0,
      radius: 22,
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
      ),
      color: _dashboardSurface(context, Theme.of(context).colorScheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ToolIconBox(
                icon: Icons.space_dashboard_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localizedLabel(context, '效率工作台', 'Efficiency workbench'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localizedLabel(
                        context,
                        '最近任务、输出收件箱和当前运行状态集中查看。',
                        'Recent tasks, output inbox, and current state in one place.',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _localizedLabel(context, '刷新', 'Refresh'),
                onPressed: onRefresh,
                icon: Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 680;
              final metrics = <Widget>[
                _EfficiencyMetricTile(
                  label: _localizedLabel(context, '运行状态', 'Running'),
                  value: busy
                      ? _localizedLabel(context, '处理中', 'Busy')
                      : _localizedLabel(context, '待命', 'Ready'),
                  icon: busy
                      ? Icons.hourglass_top_rounded
                      : Icons.check_circle_outline,
                  color: busy
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.primary,
                ),
                _EfficiencyMetricTile(
                  label: _localizedLabel(context, '输出收件箱', 'Output inbox'),
                  value: summary == null
                      ? _localizedLabel(context, '读取中', 'Loading')
                      : '${summary.availableCount}/${summary.totalCount}',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF0F766E),
                ),
                _EfficiencyMetricTile(
                  label: _localizedLabel(context, '待处理', 'Attention'),
                  value: summary == null
                      ? '-'
                      : '${summary.missingCount + summary.duplicateCandidateCount}',
                  icon: Icons.rule_folder_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                _EfficiencyMetricTile(
                  label: _localizedLabel(context, '最近任务', 'Recent tasks'),
                  value: '${recentTasks.length}',
                  icon: Icons.history_rounded,
                  color: const Color(0xFF2563EB),
                ),
              ];

              if (wide) {
                return Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: metrics[i]),
                    ],
                  ],
                );
              }

              return GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.25,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children: metrics,
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_localizedLabel(context, '最近输出', 'Latest output')}: $latestName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onOpenOutputManager,
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(_localizedLabel(context, '收件箱', 'Inbox')),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: _localizedLabel(context, '打开最近输出', 'Open latest'),
                onPressed: onOpenLastOutput,
                icon: Icon(Icons.open_in_new_rounded, size: 18),
              ),
              IconButton.outlined(
                tooltip: _localizedLabel(context, '分享最近输出', 'Share latest'),
                onPressed: onShareLastOutput,
                icon: Icon(Icons.share_outlined, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EfficiencyMetricTile extends StatelessWidget {
  const _EfficiencyMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedWorkflowPanel extends StatelessWidget {
  const _RecommendedWorkflowPanel({required this.recipes});

  final List<ToolWorkflowRecipe> recipes;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      elevation: 0,
      radius: 22,
      border: Border.all(
        color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.15),
      ),
      color: _dashboardSurface(context, Theme.of(context).colorScheme.tertiary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ToolIconBox(
                icon: Icons.account_tree_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _localizedLabel(context, '推荐工作流', 'Recommended flows'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _localizedLabel(
                        context,
                        '把常用工具组合成可确认的步骤，先做入口聚合，不自动执行危险操作。',
                        'Common tool combinations as confirmable steps, without risky automation.',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              final cards = recipes
                  .take(3)
                  .map((recipe) => _WorkflowRecipeCard(recipe: recipe))
                  .toList();
              if (wide) {
                return Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    cards[i],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkflowRecipeCard extends StatelessWidget {
  const _WorkflowRecipeCard({required this.recipe});

  final ToolWorkflowRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recipe.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recipe.steps
                .map(
                  (step) => _DashboardPill(
                    label: step.label,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            recipe.outputPolicy,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentCategoryPreview extends StatelessWidget {
  const _CurrentCategoryPreview({
    required this.category,
    required this.onOpenCategory,
  });

  final ToolCategorySpec category;
  final VoidCallback onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleActions = category.actions.take(6).toList();

    return AppCard(
      elevation: 0,
      radius: 22,
      border: Border.all(color: category.color.withValues(alpha: 0.16)),
      color: Color.alphaBlend(
        category.color.withValues(alpha: 0.052),
        colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${category.label} · ${category.actions.length} 个工具',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onOpenCategory,
                icon: Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visibleActions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final action = visibleActions[index];
                return _CompactPreviewToolTile(action: action);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactPreviewToolTile extends StatelessWidget {
  const _CompactPreviewToolTile({required this.action});

  final ToolActionSpec action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = action.onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Container(
          width: 116,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: action.color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: action.color.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, color: action.color, size: 25),
              const Spacer(),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolStatusStrip extends StatelessWidget {
  const _ToolStatusStrip({
    required this.recentTasksLabel,
    required this.recentTasksValue,
    required this.outputLabel,
    required this.outputValue,
    required this.lastOutputLabel,
    required this.lastOutputValue,
    this.onOpenOutput,
    this.onShareOutput,
  });

  final String recentTasksLabel;
  final String recentTasksValue;
  final String outputLabel;
  final String outputValue;
  final String lastOutputLabel;
  final String lastOutputValue;
  final VoidCallback? onOpenOutput;
  final VoidCallback? onShareOutput;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: 0,
      radius: 18,
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: recentTasksLabel,
                  value: recentTasksValue,
                  icon: Icons.history_rounded,
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: outputLabel,
                  value: outputValue,
                  icon: Icons.folder_outlined,
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: lastOutputLabel,
                  value: lastOutputValue,
                  icon: Icons.outbox_outlined,
                ),
              ),
            ],
          ),
          if (onOpenOutput != null || onShareOutput != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenOutput,
                    icon: Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('打开输出'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareOutput,
                    icon: Icon(Icons.share_outlined, size: 18),
                    label: const Text('分享输出'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolSectionTitle extends StatelessWidget {
  const _ToolSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ToolSearchResultsSection extends StatelessWidget {
  const _ToolSearchResultsSection({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.clearLabel,
    required this.query,
    required this.actions,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final String clearLabel;
  final String query;
  final List<ToolActionSpec> actions;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      elevation: 0,
      radius: 22,
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
      ),
      color: _dashboardSurface(context, Theme.of(context).colorScheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ToolIconBox(
                icon: Icons.manage_search_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title · ${actions.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$subtitle "$query"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: Icon(Icons.close_rounded, size: 18),
                label: Text(clearLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (actions.isEmpty)
            _ToolEmptySearchCard(text: emptyText)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760
                    ? 3
                    : constraints.maxWidth >= 460
                    ? 2
                    : 1;
                final spacing = columns == 1 ? 10.0 : 12.0;
                final tileHeight = columns == 1 ? 108.0 : 132.0;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: actions
                      .map(
                        (action) => SizedBox(
                          width:
                              (constraints.maxWidth - spacing * (columns - 1)) /
                              columns,
                          height: tileHeight,
                          child: _ToolActionCard(action: action),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ToolActionCard extends StatelessWidget {
  const _ToolActionCard({required this.action});

  final ToolActionSpec action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: AppCard(
        elevation: 0,
        radius: 18,
        onTap: action.onTap,
        border: Border.all(color: action.color.withValues(alpha: 0.14)),
        color: _dashboardSurface(context, action.color),
        child: Row(
          children: [
            _ToolIconBox(icon: action.icon, color: action.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          action.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (action.badge != null)
                        _DashboardPill(
                          label: action.badge!,
                          color: action.color,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolEmptySearchCard extends StatelessWidget {
  const _ToolEmptySearchCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: 0,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCategoryShortcutCard extends StatelessWidget {
  const _ToolCategoryShortcutCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ToolCategorySpec category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 176;
        return AppCard(
          elevation: 0,
          radius: 18,
          onTap: onTap,
          padding: EdgeInsets.all(compact ? 12 : 16),
          border: Border.all(
            color: category.color.withValues(alpha: selected ? 0.52 : 0.16),
            width: selected ? 1.6 : 1,
          ),
          color: Color.alphaBlend(
            category.color.withValues(alpha: selected ? 0.14 : 0.055),
            theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(compact ? 12 : 14),
                ),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: compact ? 20 : 23,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category.subtitle,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolCategoryDetailPage extends StatelessWidget {
  const _ToolCategoryDetailPage({
    required this.category,
    this.pdfOutputDirectory,
    this.pdfLastOutputPath,
    this.onOpenPdfOutput,
    this.onSharePdfOutput,
    this.onCopyPdfOutput,
  });

  final ToolCategorySpec category;
  final String? pdfOutputDirectory;
  final String? pdfLastOutputPath;
  final VoidCallback? onOpenPdfOutput;
  final VoidCallback? onSharePdfOutput;
  final VoidCallback? onCopyPdfOutput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            sliver: SliverToBoxAdapter(
              child: AppCard(
                elevation: 0,
                radius: 18,
                padding: const EdgeInsets.all(14),
                border: Border.all(
                  color: category.color.withValues(alpha: 0.16),
                ),
                color: Color.alphaBlend(
                  category.color.withValues(alpha: 0.07),
                  theme.colorScheme.surface,
                ),
                child: Row(
                  children: [
                    _ToolIconBox(
                      icon: category.icon,
                      color: category.color,
                      size: 44,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${category.actions.length} 个工具 · ${category.subtitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _DashboardPill(label: '可视化', color: category.color),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final columns = scale > 1.4
                    ? 1
                    : width >= 1100
                    ? 4
                    : width >= 720
                    ? 3
                    : 2;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _VisualToolTile(action: category.actions[index]);
                  }, childCount: category.actions.length),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 188 + (scale - 1).clamp(0, 3) * 110,
                  ),
                );
              },
            ),
          ),
          if (category.id == 'pdf')
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(
                child: _PdfOutputHelpPanel(
                  accentColor: category.color,
                  outputDirectory: pdfOutputDirectory,
                  lastOutputPath: pdfLastOutputPath,
                  onOpenOutput: onOpenPdfOutput,
                  onShareOutput: onSharePdfOutput,
                  onCopyOutput: onCopyPdfOutput,
                ),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _VisualToolTile extends StatelessWidget {
  const _VisualToolTile({required this.action});

  final ToolActionSpec action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = action.onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.54,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: '${action.title}, ${action.subtitle}',
        child: AppCard(
          elevation: 0,
          radius: 18,
          padding: const EdgeInsets.all(12),
          onTap: action.onTap,
          border: Border.all(color: action.color.withValues(alpha: 0.15)),
          color: _dashboardSurface(context, action.color),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ToolIconBox(
                    icon: action.icon,
                    color: action.color,
                    size: 46,
                    iconSize: 25,
                  ),
                  const Spacer(),
                  if (action.badge != null)
                    _DashboardPill(label: action.badge!, color: action.color)
                  else
                    Icon(
                      enabled ? Icons.arrow_outward_rounded : Icons.block,
                      size: 17,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              const Spacer(),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactPdfHelpPanel extends StatelessWidget {
  const _CompactPdfHelpPanel({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      elevation: 0,
      padding: EdgeInsets.zero,
      radius: 18,
      border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: _ToolIconBox(
          icon: Icons.tune_rounded,
          color: accentColor,
          size: 40,
          iconSize: 20,
        ),
        title: Text(
          '输出与最近任务',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '处理完成后可在工具页顶部状态和最近任务中打开、分享或复制输出路径',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Text(
            'PDF 操作现在优先显示功能按钮。输出目录、最近输出和历史记录仍保留在工具首页状态区，不再占用详情页第一屏。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfOutputHelpPanel extends StatelessWidget {
  const _PdfOutputHelpPanel({
    required this.accentColor,
    required this.outputDirectory,
    required this.lastOutputPath,
    required this.onOpenOutput,
    required this.onShareOutput,
    required this.onCopyOutput,
  });

  final Color accentColor;
  final String? outputDirectory;
  final String? lastOutputPath;
  final VoidCallback? onOpenOutput;
  final VoidCallback? onShareOutput;
  final VoidCallback? onCopyOutput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final directoryLabel =
        outputDirectory ??
        _localizedLabel(
          context,
          '正在读取默认输出目录',
          'Loading default output directory',
        );
    final latestOutput = lastOutputPath?.isNotEmpty == true
        ? lastOutputPath!
        : _localizedLabel(context, '暂无输出记录', 'No output yet');

    return AppCard(
      elevation: 0,
      padding: EdgeInsets.zero,
      radius: 18,
      border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: _ToolIconBox(
          icon: Icons.folder_open_rounded,
          color: accentColor,
          size: 40,
          iconSize: 20,
        ),
        title: Text(
          _localizedLabel(context, '输出目录与最近输出', 'Output and latest file'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          directoryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          _PathSummaryRow(
            icon: Icons.folder_outlined,
            label: _localizedLabel(
              context,
              '当前输出目录',
              'Current output directory',
            ),
            value: directoryLabel,
          ),
          const SizedBox(height: 10),
          _PathSummaryRow(
            icon: Icons.description_outlined,
            label: _localizedLabel(context, '最近输出', 'Latest output'),
            value: latestOutput,
          ),
          if (lastOutputPath?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onOpenOutput,
                    icon: Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(_localizedLabel(context, '打开输出', 'Open')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShareOutput,
                    icon: Icon(Icons.share_outlined, size: 18),
                    label: Text(_localizedLabel(context, '分享输出', 'Share')),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopyOutput,
                    icon: Icon(Icons.copy_outlined, size: 18),
                    label: Text(_localizedLabel(context, '复制路径', 'Copy path')),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PathSummaryRow extends StatelessWidget {
  const _PathSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolQuickControls extends StatelessWidget {
  const _ToolQuickControls({
    required this.title,
    required this.busy,
    required this.statusText,
    required this.outputWorkspace,
    required this.pickOutputLabel,
    required this.resetOutputLabel,
    required this.recentTasksTitle,
    required this.recentTasksSubtitle,
    required this.recentTasksEmpty,
    required this.copyTooltip,
    required this.tasks,
    required this.onPickOutputDirectory,
    required this.onResetOutputDirectory,
    required this.onCopyPath,
    required this.onSharePath,
    required this.formatTime,
  });

  final String title;
  final bool busy;
  final String statusText;
  final String outputWorkspace;
  final String pickOutputLabel;
  final String resetOutputLabel;
  final String recentTasksTitle;
  final String recentTasksSubtitle;
  final String recentTasksEmpty;
  final String copyTooltip;
  final List<_ToolTaskRecord> tasks;
  final VoidCallback? onPickOutputDirectory;
  final VoidCallback? onResetOutputDirectory;
  final ValueChanged<String> onCopyPath;
  final ValueChanged<String> onSharePath;
  final String Function(DateTime time) formatTime;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: 0,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ToolIconBox(
                icon: Icons.tune_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            outputWorkspace,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPickOutputDirectory,
                icon: Icon(Icons.folder_open_rounded, size: 18),
                label: Text(pickOutputLabel),
              ),
              OutlinedButton.icon(
                onPressed: onResetOutputDirectory,
                icon: Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(resetOutputLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DashboardTaskHistoryPanel(
            title: recentTasksTitle,
            subtitle: recentTasksSubtitle,
            emptyText: recentTasksEmpty,
            copyTooltip: copyTooltip,
            tasks: tasks,
            onCopyPath: onCopyPath,
            onSharePath: onSharePath,
            formatTime: formatTime,
          ),
        ],
      ),
    );
  }
}

class _DashboardTaskHistoryPanel extends StatelessWidget {
  const _DashboardTaskHistoryPanel({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.copyTooltip,
    required this.tasks,
    required this.onCopyPath,
    required this.onSharePath,
    required this.formatTime,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final String copyTooltip;
  final List<_ToolTaskRecord> tasks;
  final ValueChanged<String> onCopyPath;
  final ValueChanged<String> onSharePath;
  final String Function(DateTime time) formatTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      elevation: 0,
      padding: EdgeInsets.zero,
      radius: 20,
      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
      color: colorScheme.surface,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        leading: _ToolIconBox(
          icon: Icons.history_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 40,
          iconSize: 20,
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...tasks.map(
              (task) => ListTile(
                dense: true,
                isThreeLine: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 2,
                ),
                leading: Icon(
                  task.success ? Icons.check_circle : Icons.error_outline,
                  color: task.success
                      ? Theme.of(context).colorScheme.primary
                      : colorScheme.error,
                  size: 20,
                ),
                title: Text(
                  task.toolName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${formatTime(task.timestamp)}\n${task.inputSummary}\n${task.message}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                trailing: task.outputPath.isEmpty
                    ? null
                    : Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: _localizedLabel(
                              context,
                              '分享输出',
                              'Share output',
                            ),
                            icon: Icon(Icons.share_outlined, size: 18),
                            onPressed: () => onSharePath(task.outputPath),
                          ),
                          IconButton(
                            tooltip: copyTooltip,
                            icon: Icon(Icons.copy_outlined, size: 18),
                            onPressed: () => onCopyPath(task.outputPath),
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

class _DashboardPill extends StatelessWidget {
  const _DashboardPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.eyebrow, this.subtitle});

  final String title;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null && eyebrow!.isNotEmpty) ...[
            Text(
              eyebrow!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabHeroHeader extends StatelessWidget {
  const _TabHeroHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.icon,
    this.footnotes = const <String>[],
    this.media,
    this.onTap,
    this.trailing,
    this.height = 232,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accentColor;
  final IconData icon;
  final List<String> footnotes;
  final Widget? media;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleFootnotes = footnotes
        .where((note) => note.trim().isNotEmpty)
        .toList();
    final mediaWidgets = media == null ? const <Widget>[] : <Widget>[media!];
    final trailingWidgets = trailing == null
        ? const <Widget>[]
        : <Widget>[trailing!];

    return Semantics(
      button: onTap != null,
      label: '$eyebrow $title',
      child: AppCard(
        padding: EdgeInsets.zero,
        radius: 20,
        onTap: onTap,
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ...mediaWidgets,
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: media != null
                          ? [
                              Colors.black.withValues(alpha: 0.06),
                              Colors.black.withValues(alpha: 0.78),
                            ]
                          : [
                              Color.alphaBlend(
                                accentColor.withValues(alpha: 0.07),
                                colorScheme.surfaceContainerHighest,
                              ),
                              colorScheme.surface,
                            ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _HeroLabel(
                                  label: eyebrow,
                                  backgroundColor: media != null
                                      ? Colors.white.withValues(alpha: 0.14)
                                      : accentColor.withValues(alpha: 0.12),
                                  foregroundColor: media != null
                                      ? Colors.white
                                      : accentColor,
                                ),
                                _ToolIconBox(
                                  icon: icon,
                                  color: media != null
                                      ? Colors.white
                                      : accentColor,
                                  size: 40,
                                  iconSize: 20,
                                ),
                              ],
                            ),
                          ),
                          ...trailingWidgets,
                          if (trailing == null &&
                              media == null &&
                              onTap != null)
                            Icon(
                              Icons.arrow_outward_rounded,
                              color: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (media != null
                                    ? theme.textTheme.headlineSmall
                                    : theme.textTheme.headlineMedium)
                                ?.copyWith(
                                  color: media != null ? Colors.white : null,
                                  fontWeight: FontWeight.w800,
                                  height: 1.06,
                                ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: media != null
                              ? Colors.white.withValues(alpha: 0.88)
                              : colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      if (visibleFootnotes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visibleFootnotes
                              .map(
                                (note) => _HeroLabel(
                                  label: note,
                                  backgroundColor: media != null
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : colorScheme.surfaceContainerHighest,
                                  foregroundColor: media != null
                                      ? Colors.white
                                      : colorScheme.onSurfaceVariant,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
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

class _PrimaryEntryCard extends StatelessWidget {
  const _PrimaryEntryCard({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: AppCard(
        onTap: onTap,
        radius: 20,
        border: Border.all(color: color.withValues(alpha: 0.16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 14),
            _ToolIconBox(icon: icon, color: color, size: 54, iconSize: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_outward_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedToolCard extends StatelessWidget {
  const _FeaturedToolCard({
    required this.onTap,
    required this.accentColor,
    required this.eyebrow,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.details = const <String>[],
  });

  final VoidCallback onTap;
  final Color accentColor;
  final String eyebrow;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '$title, $subtitle',
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        radius: 20,
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 5, color: accentColor.withValues(alpha: 0.78)),
            Padding(
              padding: const EdgeInsets.all(18),
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
                            _HeroLabel(
                              label: eyebrow,
                              backgroundColor: accentColor.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: accentColor,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.06,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _ToolIconBox(
                            icon: icon,
                            color: accentColor,
                            size: 58,
                            iconSize: 28,
                          ),
                          const SizedBox(height: 18),
                          Icon(
                            Icons.arrow_outward_rounded,
                            color: colorScheme.onSurfaceVariant,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: details
                          .map(
                            (item) => _HeroLabel(
                              label: item,
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              foregroundColor: colorScheme.onSurfaceVariant,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionToolCard extends StatelessWidget {
  const _ActionToolCard({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title, $subtitle',
      child: Opacity(
        opacity: enabled ? 1 : 0.56,
        child: AppCard(
          onTap: onTap,
          radius: 18,
          border: Border.all(color: color.withValues(alpha: 0.14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ToolIconBox(
                    icon: icon,
                    color: color,
                    size: 46,
                    iconSize: 22,
                  ),
                  const Spacer(),
                  Icon(
                    enabled
                        ? Icons.arrow_outward_rounded
                        : Icons.block_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchStatusPanel extends StatelessWidget {
  const _WorkbenchStatusPanel({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusValue,
    required this.outputLabel,
    required this.outputValue,
    required this.lastOutputValue,
    required this.pickOutputLabel,
    required this.resetOutputLabel,
    required this.openOutputLabel,
    required this.shareOutputLabel,
    required this.busy,
    required this.onPickOutputDirectory,
    required this.onResetOutputDirectory,
    required this.onOpenOutput,
    required this.onShareOutput,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final String statusValue;
  final String outputLabel;
  final String outputValue;
  final String? lastOutputValue;
  final String pickOutputLabel;
  final String resetOutputLabel;
  final String openOutputLabel;
  final String shareOutputLabel;
  final bool busy;
  final VoidCallback? onPickOutputDirectory;
  final VoidCallback? onResetOutputDirectory;
  final VoidCallback? onOpenOutput;
  final VoidCallback? onShareOutput;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusCard = _WorkbenchInfoBlock(
      title: statusLabel,
      body: statusValue,
      icon: busy ? Icons.hourglass_top_rounded : Icons.check_circle_outline,
      accentColor: busy ? Colors.orange : Colors.green,
    );
    final outputBody = lastOutputValue == null || lastOutputValue!.isEmpty
        ? outputValue
        : '$outputValue\n\n${_localizedLabel(context, '最近输出', 'Latest output')}:\n$lastOutputValue';
    final outputCard = _WorkbenchInfoBlock(
      title: outputLabel,
      body: outputBody,
      icon: Icons.folder_outlined,
      accentColor: Colors.indigo,
    );

    return Semantics(
      container: true,
      label: title,
      child: AppCard(
        radius: 20,
        border: Border.all(color: Colors.orange.withValues(alpha: 0.14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ToolIconBox(
                  icon: Icons.space_dashboard_outlined,
                  color: Colors.orange,
                  size: 42,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _localizedLabel(context, '处理中', 'Running'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: statusCard),
                      const SizedBox(width: 12),
                      Expanded(child: outputCard),
                    ],
                  );
                }

                return Column(
                  children: [
                    statusCard,
                    const SizedBox(height: 12),
                    outputCard,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onPickOutputDirectory,
                  icon: Icon(Icons.folder_open, size: 18),
                  label: Text(pickOutputLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onResetOutputDirectory,
                  icon: Icon(Icons.restart_alt, size: 18),
                  label: Text(resetOutputLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenOutput,
                  icon: Icon(Icons.open_in_new, size: 18),
                  label: Text(openOutputLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onShareOutput,
                  icon: Icon(Icons.share_outlined, size: 18),
                  label: Text(shareOutputLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTasksPanel extends StatelessWidget {
  const _RecentTasksPanel({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.copyTooltip,
    required this.tasks,
    required this.onCopyPath,
    required this.onSharePath,
    required this.formatTime,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final String copyTooltip;
  final List<_ToolTaskRecord> tasks;
  final ValueChanged<String> onCopyPath;
  final ValueChanged<String> onSharePath;
  final String Function(DateTime time) formatTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.18)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        leading: Icon(Icons.history_rounded),
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...tasks.map(
              (task) => ListTile(
                dense: true,
                isThreeLine: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: Icon(
                  task.success ? Icons.check_circle : Icons.error_outline,
                  color: task.success ? Colors.green : colorScheme.error,
                  size: 20,
                ),
                title: Text(
                  task.toolName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${formatTime(task.timestamp)}\n${task.inputSummary}\n${task.message}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                trailing: task.outputPath.isEmpty
                    ? null
                    : Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: _localizedLabel(
                              context,
                              '分享输出',
                              'Share output',
                            ),
                            icon: Icon(Icons.share_outlined, size: 18),
                            onPressed: () => onSharePath(task.outputPath),
                          ),
                          IconButton(
                            tooltip: copyTooltip,
                            icon: Icon(Icons.copy_outlined, size: 18),
                            onPressed: () => onCopyPath(task.outputPath),
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

class _WorkbenchInfoBlock extends StatelessWidget {
  const _WorkbenchInfoBlock({
    required this.title,
    required this.body,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      radius: 18,
      border: Border.all(color: accentColor.withValues(alpha: 0.14)),
      color: Color.alphaBlend(
        accentColor.withValues(alpha: 0.055),
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolIconBox(icon: icon, color: accentColor, size: 40, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroLabel extends StatelessWidget {
  const _HeroLabel({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ToolIconBox extends StatelessWidget {
  const _ToolIconBox({
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

String _localizedLabel(BuildContext context, String zh, String en) {
  return Localizations.localeOf(context).languageCode == 'en' ? en : zh;
}
