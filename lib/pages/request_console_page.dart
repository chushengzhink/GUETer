import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../api/api_service.dart';
import '../features/openlist/openlist_repository.dart';
import '../modules/local_transfer/controller/local_transfer_controller.dart';
import '../plugins/plugin_action_menu.dart';
import '../plugins/plugin_context.dart';
import '../plugins/plugin_manifest.dart';
import '../features/openlist/openlist_cloud_page.dart';
import '../modules/local_transfer/ui/local_transfer_page.dart';
import '../pages/login.dart';
import '../services/diagnostics_service.dart';
import '../services/gueter_storage_service.dart';
import '../services/notification_service.dart';
import '../services/permission_repair_service.dart';
import '../session/account.dart';

class RequestConsolePage extends StatefulWidget {
  const RequestConsolePage({super.key});

  @override
  State<RequestConsolePage> createState() => _RequestConsolePageState();
}

class _RequestConsolePageState extends State<RequestConsolePage> {
  String _selectedPlatform = '全部';
  bool _isExporting = false;
  bool? _notificationAllowed;
  List<ConnectivityResult> _connectivity = const <ConnectivityResult>[];
  final PermissionRepairService _permissionRepairService =
      PermissionRepairService();
  final DiagnosticsService _diagnosticsService = const DiagnosticsService();
  List<PermissionRepairItem> _permissionItems = const <PermissionRepairItem>[];

  final List<String> _platforms = [
    '全部',
    '学习通',
    '雨课堂',
    '畅课',
    '课堂派',
    'OpenList',
    '通用',
  ];

  @override
  void initState() {
    super.initState();
    ApiService.consoleLogVersion.addListener(_onLogChanged);
    _loadHealthSignals();
  }

  @override
  void dispose() {
    ApiService.consoleLogVersion.removeListener(_onLogChanged);
    super.dispose();
  }

  void _onLogChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _copyAllLogs() async {
    final logs = ApiService.getConsoleLogs(platform: _selectedPlatform);
    final text = logs
        .map((log) => ApiService.sanitizeConsoleLogText(log['message'] ?? ''))
        .join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(logs.isEmpty ? '当前没有可复制的日志' : '请求日志已复制')),
    );
  }

  Future<void> _clearLogs() async {
    ApiService.clearConsoleLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('请求日志已清空')));
  }

  Future<void> _exportLogs() async {
    final logs = ApiService.getConsoleLogs(platform: _selectedPlatform);
    if (logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可导出的日志')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出日志'),
        content: Text('确认导出 ${logs.length} 条日志到文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isExporting = true);

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final platformStr = _selectedPlatform == '全部' ? '全部' : _selectedPlatform;
      final fileName = 'GUETer_logs_${platformStr}_${dateStr}_$timeStr.txt';

      final exportDir = await GueterStorageService.instance.publicDirectory(
        GueterPublicDirectory.exports,
      );
      final file = File(p.join(exportDir.path, fileName));

      final buffer = StringBuffer();
      buffer.writeln('GUETer 请求控制台日志');
      buffer.writeln(
        '导出时间：${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      );
      buffer.writeln('筛选平台：$platformStr');
      buffer.writeln('共 ${logs.length} 条日志');
      buffer.writeln('================================');

      for (final log in logs) {
        final timestamp = DateTime.parse(log['timestamp']!);
        final dateTimeStr =
            '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
        buffer.writeln(
          '[$dateTimeStr] [${log['platform']}] '
          '${ApiService.sanitizeConsoleLogText(log['message'] ?? '')}',
        );
      }

      await file.writeAsString(buffer.toString());

      final result = await Share.shareXFiles([
        XFile(file.path),
      ], text: 'GUETer 请求日志');

      if (!mounted) return;

      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('导出成功')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _loadHealthSignals() async {
    final notificationAllowed = await NotificationService()
        .checkPermissionStatus()
        .catchError((_) => false);
    final connectivity = await Connectivity().checkConnectivity();
    final permissions = await _permissionRepairService.inspect();
    if (!mounted) {
      return;
    }
    setState(() {
      _notificationAllowed = notificationAllowed;
      _connectivity = connectivity;
      _permissionItems = permissions;
    });
  }

  Future<void> _requestPermission(String id) async {
    await _permissionRepairService.request(id);
    await _loadHealthSignals();
  }

  Future<void> _openAppSettings() async {
    await _permissionRepairService.openSettings();
  }

  Future<void> _runHealthMod(PluginActionMenuItem action) async {
    try {
      await PluginActionMenu.run(
        context,
        action,
        PluginActionContext(
          type: PluginContextType.healthIssue,
          healthIssueId: _selectedPlatform,
          values: <String, Object?>{
            'platform': _selectedPlatform,
            'notificationAllowed': _notificationAllowed,
            'permissionIssues': _permissionItems
                .where((item) => item.needsAttention)
                .length,
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mod 执行失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ApiService.getConsoleLogs(platform: _selectedPlatform);
    final displayLogs = logs.reversed.toList(growable: false);
    final summary = ApiService.getConsoleHealthSummary(
      platform: _selectedPlatform,
    );
    final issues = _diagnosticsService.buildIssues(
      logs: logs,
      notificationAllowed: _notificationAllowed,
      hasNetwork:
          _connectivity.isNotEmpty &&
          !_connectivity.contains(ConnectivityResult.none),
      hasCurrentAccount: AccountManager.currentSessionId?.isNotEmpty == true,
      localTransferRunning: LocalTransferController.instance.discoveryRunning,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('诊断修复中心'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.receipt_long_outlined), text: '日志'),
              Tab(icon: Icon(Icons.health_and_safety_outlined), text: '诊断'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '刷新状态',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadHealthSignals,
            ),
            PopupMenuButton<PluginActionMenuItem>(
              tooltip: 'Mod 动作',
              icon: const Icon(Icons.extension_outlined),
              onSelected: _runHealthMod,
              itemBuilder: (context) {
                final items = PluginActionMenu.popupItems(
                  context,
                  PluginActionContext(
                    type: PluginContextType.healthIssue,
                    healthIssueId: _selectedPlatform,
                    values: <String, Object?>{'platform': _selectedPlatform},
                  ),
                );
                if (items.isEmpty) {
                  return const [
                    PopupMenuItem(enabled: false, child: Text('没有可用 Mod 动作')),
                  ];
                }
                return items;
              },
            ),
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: '导出',
                icon: const Icon(Icons.share_outlined),
                onPressed: _exportLogs,
              ),
            IconButton(
              tooltip: '复制全部',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: _copyAllLogs,
            ),
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clearLogs,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _ConsoleLogsTab(
              platforms: _platforms,
              selectedPlatform: _selectedPlatform,
              logs: logs,
              displayLogs: displayLogs,
              summary: summary,
              onPlatformChanged: (platform) {
                setState(() => _selectedPlatform = platform);
              },
              onOpenLog: _showLogDetail,
            ),
            _DiagnosticsTab(
              summary: summary,
              notificationAllowed: _notificationAllowed,
              connectivity: _connectivity,
              permissionItems: _permissionItems,
              issues: issues,
              onRequestPermission: _requestPermission,
              onOpenSettings: _openAppSettings,
              onRefreshSignals: _loadHealthSignals,
              onIssueAction: _handleDiagnosticAction,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogDetail(Map<String, String> log) async {
    final sanitizedMessage = ApiService.sanitizeConsoleLogText(
      log['message'] ?? '',
    );
    final timestamp = _formatLogTimestamp(log['timestamp']);
    final platform = log['platform'] ?? '通用';
    final operation = log['operation'] ?? 'request';
    final level = log['level'] ?? 'info';
    final retryable = log['retryable'] == 'true';
    final detail = [
      '时间：$timestamp',
      '平台：$platform',
      '级别：${_levelLabel(level)}',
      '操作：$operation',
      '可重试：${retryable ? "是" : "否"}',
      '',
      sanitizedMessage,
    ].join('\n');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.article_outlined),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '日志详情',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LevelPill(level: level),
                      _TextPill(label: platform),
                      _TextPill(label: operation),
                      if (retryable) const _TextPill(label: '可重试'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          detail,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: detail),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('本条日志已复制')),
                            );
                          },
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('复制本条'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('关闭'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDiagnosticAction(DiagnosticIssue issue) async {
    switch (issue.id) {
      case 'notification':
        await _openAppSettings();
        return;
      case 'account':
      case 'credential':
        if (!mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      case 'openlist':
        if (!mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OpenListCloudPage()));
        return;
      case 'local-transfer':
        if (!mounted) return;
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LocalTransferPage()));
        return;
      default:
        await _loadHealthSignals();
    }
  }
}

class _ConsoleLogsTab extends StatelessWidget {
  const _ConsoleLogsTab({
    required this.platforms,
    required this.selectedPlatform,
    required this.logs,
    required this.displayLogs,
    required this.summary,
    required this.onPlatformChanged,
    required this.onOpenLog,
  });

  final List<String> platforms;
  final String selectedPlatform;
  final List<Map<String, String>> logs;
  final List<Map<String, String>> displayLogs;
  final Map<String, int> summary;
  final ValueChanged<String> onPlatformChanged;
  final ValueChanged<Map<String, String>> onOpenLog;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlatformFilterStrip(
          platforms: platforms,
          selectedPlatform: selectedPlatform,
          onChanged: onPlatformChanged,
        ),
        _LogSummaryStrip(summary: summary),
        _PlatformRequestSummaryStrip(summary: summary),
        Expanded(
          child: logs.isEmpty
              ? const _LogEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: displayLogs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final log = displayLogs[index];
                    return _ConsoleLogTile(
                      log: log,
                      showPlatform: selectedPlatform == '全部',
                      onTap: () => onOpenLog(log),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DiagnosticsTab extends StatelessWidget {
  const _DiagnosticsTab({
    required this.summary,
    required this.notificationAllowed,
    required this.connectivity,
    required this.permissionItems,
    required this.issues,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onRefreshSignals,
    required this.onIssueAction,
  });

  final Map<String, int> summary;
  final bool? notificationAllowed;
  final List<ConnectivityResult> connectivity;
  final List<PermissionRepairItem> permissionItems;
  final List<DiagnosticIssue> issues;
  final Future<void> Function(String id) onRequestPermission;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onRefreshSignals;
  final Future<void> Function(DiagnosticIssue issue) onIssueAction;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefreshSignals,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _HealthOverview(
            summary: summary,
            notificationAllowed: notificationAllowed,
            connectivity: connectivity,
          ),
          _PermissionRepairPanel(
            items: permissionItems,
            onRequest: onRequestPermission,
            onOpenSettings: onOpenSettings,
          ),
          _HealthSuggestions(
            issues: issues,
            onRefreshSignals: onRefreshSignals,
            onIssueAction: onIssueAction,
          ),
          if (issues.isEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('暂无需要处理的诊断建议。'),
            ),
        ],
      ),
    );
  }
}

class _PlatformFilterStrip extends StatelessWidget {
  const _PlatformFilterStrip({
    required this.platforms,
    required this.selectedPlatform,
    required this.onChanged,
  });

  final List<String> platforms;
  final String selectedPlatform;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: platforms.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final platform = platforms[index];
          final isSelected = platform == selectedPlatform;
          return FilterChip(
            label: Text(platform),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                onChanged(platform);
              }
            },
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
          );
        },
      ),
    );
  }
}

class _LogSummaryStrip extends StatelessWidget {
  const _LogSummaryStrip({required this.summary});

  final Map<String, int> summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _TextPill(label: '共 ${summary['total'] ?? 0} 条'),
          _TextPill(label: '失败 ${summary['failures'] ?? 0}'),
          _TextPill(label: '警告 ${summary['warnings'] ?? 0}'),
          _TextPill(label: '可重试 ${summary['retryable'] ?? 0}'),
        ],
      ),
    );
  }
}

class _PlatformRequestSummaryStrip extends StatelessWidget {
  const _PlatformRequestSummaryStrip({required this.summary});

  final Map<String, int> summary;

  @override
  Widget build(BuildContext context) {
    final cacheHits = summary['cacheHits'] ?? 0;
    final dedupeHits = summary['dedupeHits'] ?? 0;
    final staleFallbacks = summary['staleFallbacks'] ?? 0;
    if (cacheHits == 0 && dedupeHits == 0 && staleFallbacks == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.cached_outlined,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          _TextPill(label: '\u7f13\u5b58\u547d\u4e2d $cacheHits'),
          _TextPill(label: '\u8bf7\u6c42\u5408\u5e76 $dedupeHits'),
          _TextPill(label: '\u65e7\u7f13\u5b58\u515c\u5e95 $staleFallbacks'),
        ],
      ),
    );
  }
}

class _ConsoleLogTile extends StatelessWidget {
  const _ConsoleLogTile({
    required this.log,
    required this.showPlatform,
    required this.onTap,
  });

  final Map<String, String> log;
  final bool showPlatform;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = ApiService.sanitizeConsoleLogText(log['message'] ?? '');
    final platform = log['platform'] ?? '通用';
    final level = log['level'] ?? 'info';
    final operation = log['operation'] ?? 'request';
    final retryable = log['retryable'] == 'true';
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LevelPill(level: level),
                  const SizedBox(width: 8),
                  _TextPill(label: operation),
                  if (retryable) ...[
                    const SizedBox(width: 8),
                    const _TextPill(label: '可重试'),
                  ],
                  const Spacer(),
                  Text(
                    _formatLogTimestamp(log['timestamp']),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (showPlatform) ...[
                const SizedBox(height: 6),
                Text(
                  platform,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogEmptyState extends StatelessWidget {
  const _LogEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text('还没有请求日志'),
          const SizedBox(height: 4),
          Text(
            '发生请求后会显示在这里。',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _TextPill extends StatelessWidget {
  const _TextPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PermissionRepairPanel extends StatelessWidget {
  const _PermissionRepairPanel({
    required this.items,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final List<PermissionRepairItem> items;
  final Future<void> Function(String id) onRequest;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final visibleItems = items.where((item) => item.needsAttention).toList();
    if (visibleItems.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('关键权限状态正常。'),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('权限修复', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...visibleItems.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.status == PermissionRepairStatus.permanentlyDenied
                        ? Icons.settings_outlined
                        : Icons.privacy_tip_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.title} · ${_permissionLabel(item.status)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(item.description),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: item.canRequest
                        ? () => onRequest(item.id)
                        : onOpenSettings,
                    child: Text(item.canRequest ? '请求' : '设置'),
                  ),
                ],
              ),
            );
          }),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('打开应用设置'),
            ),
          ),
        ],
      ),
    );
  }

  static String _permissionLabel(PermissionRepairStatus status) {
    return switch (status) {
      PermissionRepairStatus.granted => '可用',
      PermissionRepairStatus.denied => '未授权',
      PermissionRepairStatus.permanentlyDenied => '需到系统设置处理',
      PermissionRepairStatus.unsupported => '不支持检测',
    };
  }
}

class _HealthOverview extends StatelessWidget {
  const _HealthOverview({
    required this.summary,
    required this.notificationAllowed,
    required this.connectivity,
  });

  final Map<String, int> summary;
  final bool? notificationAllowed;
  final List<ConnectivityResult> connectivity;

  @override
  Widget build(BuildContext context) {
    final localTransfer = LocalTransferController.instance;
    final tronclassCurrent =
        AccountManager.currentSessionId?.isNotEmpty == true;
    final networkLabel = connectivity.isEmpty
        ? '未知'
        : connectivity.map((item) => item.name).join(' / ');
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MetricCard(
            icon: Icons.receipt_long_outlined,
            label: '日志',
            value: '${summary['total'] ?? 0}',
            detail:
                '失败 ${summary['failures'] ?? 0} · 可重试 ${summary['retryable'] ?? 0}',
          ),
          _MetricCard(
            icon: Icons.notifications_active_outlined,
            label: '通知',
            value: notificationAllowed == true ? '可用' : '需检查',
            detail: notificationAllowed == null ? '检测中' : '系统权限',
          ),
          _MetricCard(
            icon: Icons.network_check_outlined,
            label: '网络',
            value: networkLabel,
            detail: '当前连接',
          ),
          _MetricCard(
            icon: Icons.cloud_queue,
            label: 'OpenList',
            value: OpenListRepository().currentSession?.username ?? '按需连接',
            detail: '云盘会话',
          ),
          _MetricCard(
            icon: Icons.lan_outlined,
            label: '局域网',
            value: localTransfer.discoveryRunning ? '发现中' : '待启动',
            detail: '${localTransfer.devices.length} 台设备',
          ),
          _MetricCard(
            icon: Icons.person_outline,
            label: '畅课',
            value: tronclassCurrent ? '已选择' : '未选择',
            detail: '当前账号状态',
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelMedium),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthSuggestions extends StatelessWidget {
  const _HealthSuggestions({
    required this.issues,
    required this.onRefreshSignals,
    required this.onIssueAction,
  });

  final List<DiagnosticIssue> issues;
  final Future<void> Function() onRefreshSignals;
  final Future<void> Function(DiagnosticIssue issue) onIssueAction;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('处理建议', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ...issues
              .take(4)
              .map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_iconFor(issue.severity), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(issue.description),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => onIssueAction(issue),
                        child: Text(issue.actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRefreshSignals,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新检测'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(DiagnosticSeverity severity) {
    return switch (severity) {
      DiagnosticSeverity.error => Icons.error_outline,
      DiagnosticSeverity.warning => Icons.warning_amber_outlined,
      DiagnosticSeverity.info => Icons.info_outline,
    };
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (level) {
      'error' => scheme.error,
      'warning' => const Color(0xFFB45309),
      _ => scheme.primary,
    };
    final label = switch (level) {
      'error' => '失败',
      'warning' => '警告',
      _ => '信息',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatLogTimestamp(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) {
    return '--:--:--';
  }
  final local = parsed.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  final ss = local.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

String _levelLabel(String level) {
  return switch (level) {
    'error' => '失败',
    'warning' => '警告',
    _ => '信息',
  };
}
