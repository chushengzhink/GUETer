import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';

class UpdateAnnouncementsPage extends StatefulWidget {
  const UpdateAnnouncementsPage({
    super.key,
    UpdateAnnouncementStore? store,
    UpdateService? updateService,
  }) : _store = store,
       _updateService = updateService;

  final UpdateAnnouncementStore? _store;
  final UpdateService? _updateService;

  @override
  State<UpdateAnnouncementsPage> createState() =>
      _UpdateAnnouncementsPageState();
}

class _UpdateAnnouncementsPageState extends State<UpdateAnnouncementsPage> {
  late final UpdateAnnouncementStore _store;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _downloadUrl;
  List<UpdateAnnouncement> _announcements = const <UpdateAnnouncement>[];

  @override
  void initState() {
    super.initState();
    _store = widget._store ?? UpdateAnnouncementStore();
    _load();
  }

  Future<void> _load() async {
    final cached = await _store.loadCached();
    if (mounted) {
      setState(() {
        _announcements = cached;
        _loading = false;
      });
    }
    await _refresh(showSnackBar: false);
  }

  Future<void> _refresh({bool showSnackBar = true}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final service = widget._updateService ?? UpdateService();
      final info = await service.fetchLatest();
      final metadataWarning = info.metadataWarning;
      final hasFullMetadata = metadataWarning == null;
      if (hasFullMetadata) {
        await _store.save(info.announcements);
      }
      if (!mounted) return;
      setState(() {
        if (hasFullMetadata || _announcements.isEmpty) {
          _announcements = info.announcements;
        }
        _downloadUrl = info.apk.downloadUrl;
        _refreshing = false;
        _error = metadataWarning;
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新公告已刷新')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = _announcements.isEmpty
            ? '暂时无法获取更新公告，请稍后重试。'
            : '刷新失败，当前显示本地缓存公告。';
      });
    }
  }

  Future<void> _openDownload() async {
    final url = _downloadUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可用下载链接')));
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('更新公告'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshing ? null : () => _refresh(),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refresh(showSnackBar: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _buildHeader(context),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _buildNotice(context, _error!),
                  ],
                  const SizedBox(height: 12),
                  if (_announcements.isEmpty)
                    _buildEmpty(context)
                  else
                    ..._announcements.map(_buildAnnouncementCard),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_outlined, color: colors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '这里会显示远端 update.txt 发布的历史更新公告。',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(onPressed: _openDownload, child: const Text('下载页')),
        ],
      ),
    );
  }

  Widget _buildNotice(BuildContext context, String text) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: colors.onErrorContainer, fontSize: 13),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 46,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('暂无更新公告'),
            const SizedBox(height: 8),
            const Text('下拉或点击右上角刷新。', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(UpdateAnnouncement announcement) {
    final date = announcement.publishedAt == null
        ? '发布时间未知'
        : _formatDateTime(announcement.publishedAt!.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(announcement.tag),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...announcement.notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(note)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
