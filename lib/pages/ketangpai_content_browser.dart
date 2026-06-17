import 'dart:convert';
import 'dart:io';

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
      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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
      return '???? ${_contentTypeOf(item)}';
    }
    return subtitle;
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
        sourceLabel: '?????',
        tags: const <String>['ketangpai'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('???? $savePath')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('????: $e')));
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
                      '?????',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final link in links)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.attach_file),
                        title: Text(link.name),
                        subtitle: Text(link.url),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: '??',
                              onPressed: () => _openResource(link),
                              icon: const Icon(Icons.open_in_new),
                            ),
                            IconButton(
                              tooltip: '??',
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
                    title: const Text('????'),
                    children: [SelectableText(prettyJson)],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('??'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '当前课程暂无${widget.title}内容，或当前账号对该课程没有可访问权限。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '${_contentTypeOf(item) == -1 ? '?' : _contentTypeOf(item)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Text(_titleOf(item)),
              subtitle: Text(_subtitleOf(item)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDetail(item),
            ),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(height: 2),
      ),
    );
  }
}
