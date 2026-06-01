// ignore_for_file: unused_element, unused_element_parameter

import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modules/local_transfer/ui/local_transfer_page.dart';
import '../l10n/app_localizations.dart';
import '../services/nasa_api.dart';
import '../theme/components/app_card.dart';
import '../theme/components/dashboard_components.dart';
import 'apod_detail_page.dart';
import 'academic_search_page.dart';
import 'file_tools_page.dart';
import 'computer_help_manual_page.dart';
import 'guet_email_apply_page.dart';
import 'reading.dart';

const Color _dashboardPrimary = Color(0xFF0D9488);
const Color _dashboardSecondary = Color(0xFF14B8A6);
const Color _dashboardAction = Color(0xFFF97316);
const Color _dashboardInk = Color(0xFF134E4A);

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

class _ToolActionSpec {
  const _ToolActionSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? badge;
}

class _ToolCategorySpec {
  const _ToolCategorySpec({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actions,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_ToolActionSpec> actions;
}

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  String _status = '';
  String? _customOutputDir;
  String? _lastOutputPath;
  int _selectedToolCategory = 1;
  String _toolSearchQuery = '';
  late final TextEditingController _toolSearchController;
  final List<_ToolTaskRecord> _recentTasks = <_ToolTaskRecord>[];
  final ScrollController _dashboardScrollController = ScrollController();
  late final AnimationController _wheelController;
  late Animation<double> _wheelAnimation;
  double _wheelRotation = 0;

  final NasaApiService _nasaApiService = NasaApiService();
  NasaApodData? _apodData;
  bool _apodLoading = false;
  String? _apodError;

  static final List<Map<String, dynamic>> _watermarkColorOptions = [
    {'name': 'deep-red', 'color': PdfColor(170, 30, 30)},
    {'name': 'deep-blue', 'color': PdfColor(30, 60, 170)},
    {'name': 'deep-gray', 'color': PdfColor(70, 70, 70)},
    {'name': 'black', 'color': PdfColor(25, 25, 25)},
  ];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _tr(String zh, String en) => _isEnglish ? en : zh;

  List<_ToolCategorySpec> _toolCategories() {
    return [
      _ToolCategorySpec(
        label: _tr('传输', 'Transfer'),
        subtitle: _tr('近场配对、局域网互传', 'Nearby pairing and LAN transfer'),
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF06B6D4),
        actions: [
          _ToolActionSpec(
            title: _tr('附近房间', 'Nearby Room'),
            subtitle: _tr('发现附近房间，进入面对面配对。', 'Discover nearby rooms.'),
            icon: Icons.meeting_room_outlined,
            color: const Color(0xFF06B6D4),
            onTap: () => Navigator.pushNamed(context, '/nearby-room'),
            badge: _tr('近场', 'Nearby'),
          ),
          _ToolActionSpec(
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
      _ToolCategorySpec(
        label: 'PDF',
        subtitle: _tr('转换、压缩、提取、水印', 'Convert, compress, extract, watermark'),
        icon: Icons.picture_as_pdf_outlined,
        color: const Color(0xFFF97316),
        actions: [
          _ToolActionSpec(
            title: l10n.pdfToImagesTitle,
            subtitle: l10n.pdfToImagesSubtitle,
            icon: Icons.image_outlined,
            color: const Color(0xFFF97316),
            onTap: _busy ? null : () => _runTool(_pdfToImages),
            badge: 'PNG',
          ),
          _ToolActionSpec(
            title: l10n.imagesToPdfTitle,
            subtitle: l10n.imagesToPdfSubtitle,
            icon: Icons.collections_outlined,
            color: const Color(0xFFEF4444),
            onTap: _busy ? null : () => _runTool(_imagesToPdf),
            badge: 'PDF',
          ),
          _ToolActionSpec(
            title: l10n.compressPdfTitle,
            subtitle: l10n.compressPdfSubtitle,
            icon: Icons.compress_outlined,
            color: const Color(0xFFF59E0B),
            onTap: _busy ? null : () => _runTool(_compressPdf),
            badge: _tr('压缩', 'Zip'),
          ),
          _ToolActionSpec(
            title: l10n.extractPagesTitle,
            subtitle: l10n.extractPagesSubtitle,
            icon: Icons.snippet_folder_outlined,
            color: const Color(0xFFFB7185),
            onTap: _busy ? null : () => _runTool(_extractPages),
            badge: _tr('页码', 'Pages'),
          ),
          _ToolActionSpec(
            title: l10n.watermarkTitle,
            subtitle: l10n.watermarkSubtitle,
            icon: Icons.verified_user_outlined,
            color: const Color(0xFFF97316),
            onTap: _busy ? null : () => _runTool(_addWatermark),
            badge: _tr('水印', 'Mark'),
          ),
        ],
      ),
      _ToolCategorySpec(
        label: _tr('文件', 'Files'),
        subtitle: _tr('压缩包、批量整理', 'Archive and batch cleanup'),
        icon: Icons.folder_zip_outlined,
        color: const Color(0xFF22C55E),
        actions: [
          _ToolActionSpec(
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
        ],
      ),
      _ToolCategorySpec(
        label: _tr('网络', 'Network'),
        subtitle: _tr('虚拟局域网与连接状态', 'Virtual LAN and connection state'),
        icon: Icons.vpn_lock_outlined,
        color: const Color(0xFF6366F1),
        actions: [
          _ToolActionSpec(
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
      _ToolCategorySpec(
        label: _tr('学习', 'Study'),
        subtitle: _tr('阅读、检索、天文图', 'Reading, search, APOD'),
        icon: Icons.auto_stories_outlined,
        color: const Color(0xFF8B5CF6),
        actions: [
          _ToolActionSpec(
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
          _ToolActionSpec(
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
          _ToolActionSpec(
            title: l10n.apodCardTitle,
            subtitle: _apodData?.title ?? l10n.apodLoadingSubtitle,
            icon: Icons.nights_stay_rounded,
            color: const Color(0xFF0EA5E9),
            onTap: _apodData == null
                ? (_apodLoading ? null : () => _refreshApod())
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ApodDetailPage(apod: _apodData!),
                      ),
                    );
                  },
            badge: 'APOD',
          ),
        ],
      ),
      _ToolCategorySpec(
        label: _tr('校园', 'Campus'),
        subtitle: _tr('桂电入口与支持', 'GUET entries and support'),
        icon: Icons.school_outlined,
        color: const Color(0xFF10B981),
        actions: [
          _ToolActionSpec(
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
          _ToolActionSpec(
            title: l10n.guetOfficialTitle,
            subtitle: l10n.guetOfficialSubtitle,
            icon: Icons.public_outlined,
            color: const Color(0xFF059669),
            onTap: () => _openExternalUrl('https://www.guet.edu.cn/'),
            badge: _tr('官网', 'Web'),
          ),
          _ToolActionSpec(
            title: l10n.aiFigureTitle,
            subtitle: l10n.aiFigureSubtitle,
            icon: Icons.science_outlined,
            color: const Color(0xFFF97316),
            onTap: () => _openExternalUrl('https://deepscientist.cc'),
            badge: 'AI',
          ),
          _ToolActionSpec(
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
    ];
  }

  void _selectToolCategory(int index) {
    final categories = _toolCategories();
    if (index < 0 || index >= categories.length) return;
    final targetRotation = -index * (math.pi * 2 / categories.length);
    _animateWheelTo(index, targetRotation);
  }

  void _selectToolCategoryByRotation(double rotation) {
    final categories = _toolCategories();
    final segment = math.pi * 2 / categories.length;
    final index = ((-rotation / segment).round() % categories.length);
    final normalizedIndex = index < 0 ? index + categories.length : index;
    _selectToolCategory(normalizedIndex);
  }

  void _setWheelDragRotation(double rotation) {
    _wheelController.stop();
    _wheelRotation = rotation;
    _wheelAnimation = AlwaysStoppedAnimation<double>(_wheelRotation);
    setState(() {});
  }

  void _animateWheelTo(int index, double targetRotation) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _selectedToolCategory = index);

    if (disableAnimations) {
      _wheelController.stop();
      _wheelRotation = targetRotation;
      _wheelAnimation = AlwaysStoppedAnimation<double>(_wheelRotation);
      setState(() {});
      return;
    }

    _wheelAnimation = Tween<double>(begin: _wheelRotation, end: targetRotation)
        .animate(
          CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic),
        );
    _wheelController
      ..stop()
      ..reset()
      ..forward().whenComplete(() {
        _wheelRotation = targetRotation;
      });
  }

  Future<void> _openSelectedToolCategory() async {
    final categories = _toolCategories();
    final selectedCategory = categories[_selectedToolCategory];
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ToolCategoryDetailPage(category: selectedCategory),
      ),
    );
  }

  Future<void> _openToolSearch() async {
    final categories = _toolCategories();
    final actions = categories.expand((category) => category.actions).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _ToolSearchSheet(
          title: _tr('搜索工具', 'Search tools'),
          emptyText: _tr('没有找到匹配工具', 'No matching tools'),
          initialQuery: _toolSearchQuery,
          actions: actions,
          onQueryChanged: (value) {
            setState(() => _toolSearchQuery = value);
          },
        );
      },
    );
  }

  List<_ToolActionSpec> _filteredActions(List<_ToolCategorySpec> categories) {
    final query = _toolSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return categories[_selectedToolCategory].actions;
    return categories
        .expand((category) => category.actions)
        .where(
          (action) =>
              action.title.toLowerCase().contains(query) ||
              action.subtitle.toLowerCase().contains(query) ||
              (action.badge ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _wheelAnimation = AlwaysStoppedAnimation<double>(_wheelRotation);
    _toolSearchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializeApod();
    });
  }

  Widget _buildDashboard(double totalBottomPadding) {
    final categories = _toolCategories();
    final selectedCategory = categories[_selectedToolCategory];
    final statusText = _status.isEmpty ? l10n.statusSelectTool : _status;

    return CustomScrollView(
      controller: _dashboardScrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _ToolCommandHeader(
              title: _tr('工具', 'Tools'),
              subtitle: _tr(
                '常用学习、文件和网络工具集中在这里。',
                'Study, file, and network tools in one workspace.',
              ),
              busy: _busy,
              statusText: statusText,
              searchHint: _tr(
                '搜索工具、PDF、传输、校园...',
                'Search tools, PDF, transfer, campus...',
              ),
              searchController: _toolSearchController,
              onSearchChanged: (value) {
                setState(() => _toolSearchQuery = value);
                _openToolSearch();
              },
              onSearchTap: _openToolSearch,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _buildFeaturedToolActions(categories),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: SliverToBoxAdapter(
            child: _ToolWheelPanel(
              categories: categories,
              selectedIndex: _selectedToolCategory,
              selectedCategory: selectedCategory,
              rotationAnimation: _wheelAnimation,
              onSelected: _selectToolCategory,
              onRotationChanged: _setWheelDragRotation,
              onRotationEnd: _selectToolCategoryByRotation,
              onCenterTap: _openSelectedToolCategory,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          sliver: _buildCategoryShortcutGrid(categories),
        ),
        SliverToBoxAdapter(child: SizedBox(height: totalBottomPadding + 20)),
      ],
    );
  }

  Widget _buildCategoryShortcutGrid(List<_ToolCategorySpec> categories) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        return _ToolCategoryShortcutCard(
          category: categories[index],
          selected: index == _selectedToolCategory,
          onTap: () => _selectToolCategory(index),
        );
      }, childCount: categories.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.35,
      ),
    );
  }

  Widget _buildFeaturedToolActions(List<_ToolCategorySpec> categories) {
    final featured = <_ToolActionSpec>[];
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

  Widget _buildToolActionGrid(List<_ToolActionSpec> actions) {
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

  Widget _buildApodCompactCard() {
    final title = _apodData?.title.isNotEmpty == true
        ? _apodData!.title
        : l10n.apodCardTitle;
    final subtitle = _apodData == null
        ? (_apodError ?? l10n.apodLoadingSubtitle)
        : (_apodData!.isImage
              ? _apodData!.explanation
              : l10n.apodUnavailableSubtitle);
    final canOpenDetail = _apodData != null;

    Widget image;
    if (_apodData?.isImage == true) {
      image = CachedNetworkImage(
        imageUrl: _apodData!.url,
        fit: BoxFit.cover,
        placeholder: (context, progress) => Container(
          color: _dashboardPrimary.withValues(alpha: 0.08),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) =>
            Image.asset('images/placeholder.png', fit: BoxFit.cover),
      );
    } else {
      image = Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('images/placeholder.png', fit: BoxFit.cover),
          Container(
            color: Colors.black.withValues(alpha: 0.12),
            alignment: Alignment.center,
            child: Icon(
              _apodLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.nights_stay_rounded,
              color: Colors.white.withValues(alpha: 0.92),
              size: 28,
            ),
          ),
        ],
      );
    }

    final theme = Theme.of(context);

    return AppCard(
      elevation: 0,
      radius: 20,
      border: Border.all(color: _dashboardPrimary.withValues(alpha: 0.12)),
      color: _dashboardSurface(context, _dashboardPrimary),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: 108, height: 108, child: image),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DashboardPill(
                      label: _tr('APOD', 'APOD'),
                      color: _dashboardPrimary,
                    ),
                    if (_apodData?.date.isNotEmpty == true)
                      _DashboardPill(
                        label: _apodData!.date,
                        color: _dashboardSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: canOpenDetail
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ApodDetailPage(apod: _apodData!),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(_tr('查看详情', 'Open detail')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _apodLoading ? null : _refreshApod,
                      icon: _apodLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(_tr('刷新', 'Refresh')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
    _toolSearchController.dispose();
    _wheelController.dispose();
    _dashboardScrollController.dispose();
    _nasaApiService.dispose();
    super.dispose();
  }

  Future<void> _initializeApod() async {
    final cached = await _nasaApiService.loadCachedApod();
    if (!mounted) return;

    if (cached != null) {
      setState(() {
        _apodData = cached;
      });
    }

    final shouldRefresh = await _nasaApiService.shouldAutoRefreshToday();
    if (!mounted) return;

    if (cached == null || shouldRefresh) {
      await _refreshApod(markDailyRefresh: shouldRefresh);
    }
  }

  Future<void> _refreshApod({bool markDailyRefresh = false}) async {
    setState(() {
      _apodLoading = true;
      _apodError = null;
    });

    final data = await _nasaApiService.fetchApod();
    if (!mounted) return;

    if (data != null) {
      if (markDailyRefresh) {
        await _nasaApiService.markAutoRefreshedToday();
      }
      setState(() {
        _apodData = data;
        _apodLoading = false;
        _apodError = null;
      });
      return;
    }

    setState(() {
      _apodLoading = false;
      _apodError = l10n.apodErrorSubtitle;
    });
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
        SnackBar(content: Text(l10n.openFailedMessage(result.message))),
      );
    }
  }

  Future<void> _shareOutputFile() async {
    final path = _lastOutputPath;
    if (path == null || path.isEmpty) return;

    await Share.shareXFiles([XFile(path)], text: l10n.pdfOutputShareText);
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

  Widget _buildApodHeroHeader() {
    final title = _apodData?.title.isNotEmpty == true
        ? _apodData!.title
        : l10n.apodCardTitle;
    final subtitle = _apodData == null
        ? (_apodError ?? l10n.apodLoadingSubtitle)
        : (_apodData!.isImage
              ? _apodData!.explanation
              : l10n.apodUnavailableSubtitle);

    return _TabHeroHeader(
      eyebrow: '${l10n.toolsTabReading} / ${l10n.apodCardTitle}',
      title: title,
      subtitle: subtitle,
      accentColor: Colors.indigo,
      icon: Icons.nights_stay_rounded,
      media: _buildApodHeroMedia(),
      height: 340,
      onTap: _apodData == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ApodDetailPage(apod: _apodData!),
                ),
              );
            },
      trailing: IconButton(
        tooltip: l10n.apodRefreshTooltip,
        onPressed: _apodLoading ? null : _refreshApod,
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.28),
          foregroundColor: Colors.white,
        ),
        icon: _apodLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh_rounded),
      ),
      footnotes: [
        if (_apodData?.date.isNotEmpty == true)
          '${l10n.apodDateLabel}: ${_apodData!.date}',
        if (_apodData == null && _apodLoading) l10n.apodLoadingSubtitle,
        if (_apodData != null && !_apodData!.isImage) l10n.apodNonImageNotice,
      ],
    );
  }

  Widget _buildApodHeroMedia() {
    if (_apodData?.isImage == true) {
      return CachedNetworkImage(
        imageUrl: _apodData!.url,
        fit: BoxFit.cover,
        placeholder: (context, progress) => Container(
          color: Colors.indigo.withValues(alpha: 0.15),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (context, url, error) =>
            Image.asset('images/placeholder.png', fit: BoxFit.cover),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('images/placeholder.png', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.18),
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _apodLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _apodError != null
                        ? Icons.error_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 34,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
          ),
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
        _buildApodHeroHeader(),
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
    final outputWorkspace = _customOutputDir?.trim().isNotEmpty == true
        ? _customOutputDir!
        : _tr('默认临时目录', 'Default temp directory');
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
          openOutputLabel: _tr('打开输出', 'Open Output'),
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
          title: _tr('PDF 操作', 'PDF Actions'),
          subtitle: _tr(
            '转换、压缩、提取和加水印统一为一组动作卡，窄屏会自动退化成更舒适的单列。',
            'Conversion, compression, extraction, and watermarking share one responsive action grid.',
          ),
        ),
        _buildEditorialActionGrid([
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
    final outputWorkspace = _customOutputDir?.trim().isNotEmpty == true
        ? _customOutputDir!
        : _tr('默认临时目录', 'Default temp directory');
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
          title: _tr('高频入口', 'Core Actions'),
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
        _buildApodHeroHeader(),
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
          openOutputLabel: _tr('打开输出', 'Open Output'),
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
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    const floatingNavBarHeight = 80.0;
    final totalBottomPadding = bottomSafeArea + floatingNavBarHeight;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.toolsPageTitle)),
      body: _buildDashboard(totalBottomPadding),
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

class _ToolCommandHeader extends StatelessWidget {
  const _ToolCommandHeader({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.statusText,
    required this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    this.onSearchTap,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final String statusText;
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onSearchTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      elevation: 0,
      radius: 24,
      border: Border.all(color: _dashboardPrimary.withValues(alpha: 0.14)),
      color: _dashboardSurface(context, _dashboardPrimary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _dashboardPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.blur_circular_rounded,
                  color: _dashboardPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.brightness == Brightness.dark
                            ? null
                            : _dashboardInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
              const SizedBox(width: 10),
              _DashboardPill(
                label: busy ? '处理中' : '待命',
                color: busy ? _dashboardAction : _dashboardPrimary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            onTap: onSearchTap,
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              filled: true,
              fillColor: colorScheme.surface.withValues(alpha: 0.86),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            statusText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolWheelPanel extends StatelessWidget {
  const _ToolWheelPanel({
    required this.categories,
    required this.selectedIndex,
    required this.selectedCategory,
    required this.rotationAnimation,
    required this.onSelected,
    required this.onRotationChanged,
    required this.onRotationEnd,
    required this.onCenterTap,
  });

  final List<_ToolCategorySpec> categories;
  final int selectedIndex;
  final _ToolCategorySpec selectedCategory;
  final Animation<double> rotationAnimation;
  final ValueChanged<int> onSelected;
  final ValueChanged<double> onRotationChanged;
  final ValueChanged<double> onRotationEnd;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      elevation: 0,
      radius: 28,
      border: Border.all(color: selectedCategory.color.withValues(alpha: 0.18)),
      color: Color.alphaBlend(
        selectedCategory.color.withValues(alpha: 0.055),
        colorScheme.surface,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth.clamp(260.0, 360.0);
          return Column(
            children: [
              SizedBox(
                width: size,
                height: size,
                child: RepaintBoundary(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      onRotationChanged(
                        rotationAnimation.value + details.delta.dx * 0.014,
                      );
                    },
                    onPanEnd: (_) => onRotationEnd(rotationAnimation.value),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: rotationAnimation,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size.square(size),
                              painter: _TechWheelPainter(
                                categories: categories,
                                selectedIndex: selectedIndex,
                                rotation: rotationAnimation.value,
                                surfaceColor: colorScheme.surface,
                                textColor: colorScheme.onSurface,
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: rotationAnimation.value,
                              child: child,
                            );
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < categories.length; i++)
                                _WheelNodeButton(
                                  index: i,
                                  total: categories.length,
                                  category: categories[i],
                                  selected: i == selectedIndex,
                                  radius: size * 0.38,
                                  wheelRotation: rotationAnimation.value,
                                  onSelected: onSelected,
                                ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onCenterTap,
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: size * 0.42,
                              height: size * 0.42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.surface.withValues(
                                  alpha: 0.94,
                                ),
                                border: Border.all(
                                  color: selectedCategory.color.withValues(
                                    alpha: 0.42,
                                  ),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: selectedCategory.color.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 26,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    selectedCategory.icon,
                                    color: selectedCategory.color,
                                    size: 34,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedCategory.label,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    '进入',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _WheelNodeButton extends StatelessWidget {
  const _WheelNodeButton({
    required this.index,
    required this.total,
    required this.category,
    required this.selected,
    required this.radius,
    required this.wheelRotation,
    required this.onSelected,
  });

  final int index;
  final int total;
  final _ToolCategorySpec category;
  final bool selected;
  final double radius;
  final double wheelRotation;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final angle = (math.pi * 2 / total) * index - math.pi / 2;
    final offset = Offset(math.cos(angle) * radius, math.sin(angle) * radius);

    return Transform.translate(
      offset: offset,
      child: GestureDetector(
        onTap: () => onSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 70 : 58,
          height: selected ? 70 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.alphaBlend(
              category.color.withValues(alpha: selected ? 0.20 : 0.10),
              Theme.of(context).colorScheme.surface,
            ),
            border: Border.all(
              color: category.color.withValues(alpha: selected ? 0.7 : 0.25),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: category.color.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Transform.rotate(
            angle: -wheelRotation,
            child: Icon(
              category.icon,
              color: category.color,
              size: selected ? 31 : 27,
            ),
          ),
        ),
      ),
    );
  }
}

class _TechWheelPainter extends CustomPainter {
  const _TechWheelPainter({
    required this.categories,
    required this.selectedIndex,
    required this.rotation,
    required this.surfaceColor,
    required this.textColor,
  });

  final List<_ToolCategorySpec> categories;
  final int selectedIndex;
  final double rotation;
  final Color surfaceColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = textColor.withValues(alpha: 0.08);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = categories[selectedIndex].color.withValues(alpha: 0.72);

    for (final factor in const [0.34, 0.58, 0.82]) {
      canvas.drawCircle(center, radius * factor, ringPaint);
    }

    final segment = math.pi * 2 / categories.length;
    for (var i = 0; i < categories.length; i++) {
      final angle = segment * i - math.pi / 2 + rotation;
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.22;
      final end =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.84;
      canvas.drawLine(start, end, ringPaint);
    }

    final activeStart =
        -math.pi / 2 + segment * selectedIndex + rotation - segment * 0.34;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.82),
      activeStart,
      segment * 0.68,
      false,
      activePaint,
    );

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = categories[selectedIndex].color.withValues(alpha: 0.42);
    for (var i = 0; i < categories.length; i++) {
      final angle = segment * i - math.pi / 2 + rotation;
      final dot =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.58;
      canvas.drawCircle(dot, i == selectedIndex ? 4 : 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TechWheelPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.rotation != rotation ||
        oldDelegate.categories != categories ||
        oldDelegate.textColor != textColor;
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
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('打开输出'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareOutput,
                    icon: const Icon(Icons.share_outlined, size: 18),
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
        Icon(icon, size: 18, color: _dashboardPrimary),
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

class _ToolActionCard extends StatelessWidget {
  const _ToolActionCard({required this.action});

  final _ToolActionSpec action;

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

  final _ToolCategorySpec category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      elevation: 0,
      radius: 18,
      onTap: onTap,
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(category.icon, color: category.color, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _ToolCategoryDetailPage extends StatelessWidget {
  const _ToolCategoryDetailPage({required this.category});

  final _ToolCategorySpec category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(category.label)),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            sliver: SliverToBoxAdapter(
              child: AppCard(
                elevation: 0,
                radius: 22,
                border: Border.all(
                  color: category.color.withValues(alpha: 0.16),
                ),
                color: Color.alphaBlend(
                  category.color.withValues(alpha: 0.07),
                  theme.colorScheme.surface,
                ),
                child: Row(
                  children: [
                    _ToolIconBox(icon: category.icon, color: category.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.label,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.crossAxisExtent >= 720 ? 3 : 1;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _ToolActionCard(action: category.actions[index]);
                  }, childCount: category.actions.length),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 2.45 : 1.35,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolSearchSheet extends StatefulWidget {
  const _ToolSearchSheet({
    required this.title,
    required this.emptyText,
    required this.initialQuery,
    required this.actions,
    required this.onQueryChanged,
  });

  final String title;
  final String emptyText;
  final String initialQuery;
  final List<_ToolActionSpec> actions;
  final ValueChanged<String> onQueryChanged;

  @override
  State<_ToolSearchSheet> createState() => _ToolSearchSheetState();
}

class _ToolSearchSheetState extends State<_ToolSearchSheet> {
  late final TextEditingController _controller;
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_ToolActionSpec> get _filteredActions {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.actions;
    return widget.actions
        .where(
          (action) =>
              action.title.toLowerCase().contains(query) ||
              action.subtitle.toLowerCase().contains(query) ||
              (action.badge ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _filteredActions;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: '输入工具名称',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _query = value);
              widget.onQueryChanged(value);
            },
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.52,
            ),
            child: actions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(widget.emptyText),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemBuilder: (context, index) {
                      final action = actions[index];
                      return ListTile(
                        leading: _ToolIconBox(
                          icon: action.icon,
                          color: action.color,
                        ),
                        title: Text(action.title),
                        subtitle: Text(
                          action.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: action.badge == null
                            ? null
                            : _DashboardPill(
                                label: action.badge!,
                                color: action.color,
                              ),
                        onTap: action.onTap == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                action.onTap!();
                              },
                      );
                    },
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemCount: actions.length,
                  ),
          ),
        ],
      ),
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
              const _ToolIconBox(
                icon: Icons.tune_rounded,
                color: _dashboardPrimary,
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
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: Text(pickOutputLabel),
              ),
              OutlinedButton.icon(
                onPressed: onResetOutputDirectory,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
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
    required this.formatTime,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final String copyTooltip;
  final List<_ToolTaskRecord> tasks;
  final ValueChanged<String> onCopyPath;
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
        leading: const _ToolIconBox(
          icon: Icons.history_rounded,
          color: _dashboardPrimary,
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
                  color: task.success ? _dashboardPrimary : colorScheme.error,
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
                    : IconButton(
                        tooltip: copyTooltip,
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        onPressed: () => onCopyPath(task.outputPath),
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
                const _ToolIconBox(
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
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(pickOutputLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onResetOutputDirectory,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(resetOutputLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenOutput,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(openOutputLabel),
                ),
                OutlinedButton.icon(
                  onPressed: onShareOutput,
                  icon: const Icon(Icons.share_outlined, size: 18),
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
    required this.formatTime,
  });

  final String title;
  final String subtitle;
  final String emptyText;
  final String copyTooltip;
  final List<_ToolTaskRecord> tasks;
  final ValueChanged<String> onCopyPath;
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
        leading: const Icon(Icons.history_rounded),
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
                    : IconButton(
                        tooltip: copyTooltip,
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        onPressed: () => onCopyPath(task.outputPath),
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
