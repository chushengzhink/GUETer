import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../api/course.dart';
import '../api/ketangpai_content_utils.dart';
import '../materials/material_index_models.dart';
import '../materials/material_library_store.dart';
import '../models/course.dart';
import '../services/gueter_storage_service.dart';

enum KetangpaiContentKind {
  announcement,
  answerQuestion,
  courseWare,
  source,
  topic,
}

class KetangpaiContentBrowser extends StatefulWidget {
  const KetangpaiContentBrowser({
    super.key,
    required this.course,
    required this.kind,
    required this.title,
  });

  final Course course;
  final KetangpaiContentKind kind;
  final String title;

  @override
  State<KetangpaiContentBrowser> createState() =>
      _KetangpaiContentBrowserState();
}

class _KetangpaiContentBrowserState extends State<KetangpaiContentBrowser> {
  bool _loading = true;
  bool _downloading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final items = await _loadItemsForKind();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadItemsForKind() {
    switch (widget.kind) {
      case KetangpaiContentKind.announcement:
        return KTCourseApi.getAnnouncementList(widget.course.courseId);
      case KetangpaiContentKind.answerQuestion:
        return KTCourseApi.getAnswerQuestionList(widget.course.courseId);
      case KetangpaiContentKind.courseWare:
        return KTCourseApi.getCourseWareList(widget.course.courseId);
      case KetangpaiContentKind.source:
        return KTCourseApi.getSourceList(widget.course.courseId);
      case KetangpaiContentKind.topic:
        return KTCourseApi.getTopicList(widget.course.courseId);
    }
  }

  int _contentTypeOf(Map<String, dynamic> item) {
    return ketangpaiContentTypeOf(item);
  }

  String _titleOf(Map<String, dynamic> item) {
    return ketangpaiTitleOf(item, fallback: widget.title);
  }

  String _subtitleOf(Map<String, dynamic> item) {
    final subtitle = ketangpaiSubtitleOf(item);
    if (subtitle.isEmpty) {
      return '内容类型 ${_contentTypeOf(item)}';
    }
    return subtitle;
  }

  String _sizeLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  String _linkSummary(List<KetangpaiResourceLink> links) {
    if (links.isEmpty) return '无附件';
    final first = links.first;
    final size = _sizeLabel(first.sizeBytes);
    final suffix = links.length > 1 ? '，另有 ${links.length - 1} 个附件' : '';
    return '${first.name}${size.isEmpty ? '' : ' · $size'}$suffix';
  }

  Future<void> _openResource(KetangpaiResourceLink link) async {
    final uri = Uri.tryParse(link.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadResource(KetangpaiResourceLink link) async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
    });
    try {
      final dir = await GueterStorageService.instance.publicDirectory(
        GueterPublicDirectory.cloudDownloads,
      );
      final safeName = _sanitizeFileName(link.name);
      final savePath = p.join(dir.path, safeName);
      await Dio().download(link.url, savePath);
      await MaterialLibraryStore().upsertItem(
        path: savePath,
        name: safeName,
        sourceType: MaterialSourceType.openListDownload,
        sourceLabel: '课堂派资料',
        tags: const <String>['ketangpai'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已下载到 $savePath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return cleaned.isEmpty ? 'ketangpai_file' : cleaned;
  }

  Future<void> _showDetail(Map<String, dynamic> item) async {
    final links = extractKetangpaiResourceLinks(item);
    final prettyJson = const JsonEncoder.withIndent('  ').convert(item);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_titleOf(item)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_subtitleOf(item)),
                  if (links.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '附件和链接',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final link in links)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file),
                        title: Text(link.name),
                        subtitle: Text(
                          [
                            link.url,
                            _sizeLabel(link.sizeBytes),
                          ].where((item) => item.isNotEmpty).join(' · '),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: '打开',
                              onPressed: () => _openResource(link),
                              icon: const Icon(Icons.open_in_new),
                            ),
                            IconButton(
                              tooltip: '下载',
                              onPressed: _downloading
                                  ? null
                                  : () => _downloadResource(link),
                              icon: const Icon(Icons.download),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('原始数据'),
                    children: [SelectableText(prettyJson)],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              color: Theme.of(context).colorScheme.outline,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              '暂无${widget.title}内容',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '当前课程暂未返回内容，或当前账号没有访问权限。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final links = extractKetangpaiResourceLinks(item);
    final subtitle = _subtitleOf(item);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  '${_contentTypeOf(item) == -1 ? '?' : _contentTypeOf(item)}',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleOf(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            links.isEmpty
                                ? Icons.link_off_outlined
                                : Icons.attach_file,
                            size: 16,
                          ),
                          label: Text(_linkSummary(links)),
                        ),
                        if (links.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(
                              Icons.download_outlined,
                              size: 16,
                            ),
                            label: Text('${links.length} 个可处理附件'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    if (_items.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildItem(_items[index]),
        separatorBuilder: (context, index) => const SizedBox(height: 2),
      ),
    );
  }
}
