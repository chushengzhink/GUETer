import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../materials/material_index_service.dart';
import '../materials/material_sync_status_service.dart';
import '../services/duplicate_file_scanner.dart';
import 'duplicate_cleanup_page.dart';
import 'material_search_page.dart';

class MaterialSyncStatusPage extends StatefulWidget {
  const MaterialSyncStatusPage({super.key, this.service, this.indexService});

  final MaterialSyncStatusService? service;
  final MaterialIndexService? indexService;

  @override
  State<MaterialSyncStatusPage> createState() => _MaterialSyncStatusPageState();
}

class _MaterialSyncStatusPageState extends State<MaterialSyncStatusPage> {
  late final MaterialSyncStatusService _service =
      widget.service ?? MaterialSyncStatusService();
  late final MaterialIndexService _indexService =
      widget.indexService ?? MaterialIndexService();
  MaterialSyncStatusSnapshot? _snapshot;
  bool _busy = false;
  String _status = '点击刷新查看资料状态。';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _status = '正在扫描资料状态...';
    });
    try {
      final snapshot = await _service.loadSnapshot(
        onProgress: (message) {
          if (mounted) setState(() => _status = message);
        },
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _status = '状态已更新：${_formatTime(snapshot.generatedAt)}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '状态扫描失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rebuildIndex() async {
    setState(() {
      _busy = true;
      _status = '正在重建索引...';
    });
    try {
      await _indexService.rebuildIndex(
        onProgress: (message) {
          if (mounted) setState(() => _status = message);
        },
      );
      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '重建索引失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDuplicateCleanup() async {
    final roots = await _service.defaultDuplicateRoots();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DuplicateCleanupPage(roots: roots, title: '资料查重清理'),
      ),
    );
    await _refresh();
  }

  Future<void> _checkOfflinePackages() async {
    setState(() {
      _busy = true;
      _status = '正在校验离线包...';
    });
    try {
      await _service.checkOfflinePackages(
        onProgress: (message) {
          if (mounted) setState(() => _status = message);
        },
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '离线包校验失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDirectory(String path) async {
    await OpenFilex.open(path);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('资料状态'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(status: _status, busy: _busy),
            const SizedBox(height: 12),
            if (snapshot == null)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('正在准备资料状态。'),
                ),
              )
            else ...[
              _DirectoryCard(
                status: snapshot.downloads,
                icon: Icons.cloud_done_outlined,
                onOpen: () => _openDirectory(snapshot.downloads.path),
              ),
              _DirectoryCard(
                status: snapshot.offlineRoot,
                icon: Icons.inventory_2_outlined,
                onOpen: () => _openDirectory(snapshot.offlineRoot.path),
              ),
              _DirectoryCard(
                status: snapshot.fileToolOutput,
                icon: Icons.folder_copy_outlined,
                onOpen: () => _openDirectory(snapshot.fileToolOutput.path),
              ),
              const SizedBox(height: 8),
              _MetricGrid(snapshot: snapshot),
              const SizedBox(height: 12),
              _ActionPanel(
                busy: _busy,
                onSearch: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MaterialSearchPage()),
                ),
                onReindex: _rebuildIndex,
                onDuplicateCleanup: _openDuplicateCleanup,
                onCheckOffline: _checkOfflinePackages,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.busy});

  final String status;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.sync_alt_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(status)),
          ],
        ),
      ),
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  const _DirectoryCard({
    required this.status,
    required this.icon,
    required this.onOpen,
  });

  final MaterialDirectoryStatus status;
  final IconData icon;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(status.label),
        subtitle: Text(
          '${status.fileCount} 个文件 · ${duplicateFormatBytes(status.totalBytes)}\n${status.path}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: '打开目录',
          onPressed: status.exists ? onOpen : null,
          icon: const Icon(Icons.folder_open_outlined),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snapshot});

  final MaterialSyncStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width >= 720 ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.55,
      children: [
        _MetricCard(
          label: '离线包',
          value:
              '${snapshot.offlinePackageCount} 包 / ${snapshot.offlineFileCount} 文件',
          icon: Icons.inventory_2_outlined,
          warning: snapshot.hasOfflineIssues,
        ),
        _MetricCard(
          label: '缺失/变更',
          value:
              '${snapshot.offlineMissingCount} 缺失 / ${snapshot.offlineChangedCount} 变更',
          icon: Icons.report_problem_outlined,
          warning: snapshot.hasOfflineIssues,
        ),
        _MetricCard(
          label: '搜索索引',
          value:
              '${snapshot.indexSummary.indexed}/${snapshot.indexSummary.total} 可搜',
          icon: Icons.manage_search_outlined,
          warning: snapshot.hasIndexIssues,
        ),
        _MetricCard(
          label: '重复文件',
          value:
              '${snapshot.duplicateGroupCount} 组 / ${duplicateFormatBytes(snapshot.duplicateBytes)}',
          icon: Icons.content_copy_outlined,
          warning: snapshot.hasDuplicates,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.warning,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = warning ? colorScheme.error : colorScheme.primary;
    return Card(
      color: Color.alphaBlend(
        color.withValues(alpha: 0.08),
        colorScheme.surface,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.busy,
    required this.onSearch,
    required this.onReindex,
    required this.onDuplicateCleanup,
    required this.onCheckOffline,
  });

  final bool busy;
  final VoidCallback onSearch;
  final VoidCallback onReindex;
  final VoidCallback onDuplicateCleanup;
  final VoidCallback onCheckOffline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('进入资料搜索'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onReindex,
              icon: const Icon(Icons.manage_search_outlined),
              label: const Text('重新索引'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onDuplicateCleanup,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('查重清理'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onCheckOffline,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('校验离线包'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}
