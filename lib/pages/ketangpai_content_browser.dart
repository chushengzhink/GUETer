import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';

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
    return int.tryParse(
          item['contenttype']?.toString() ??
              item['contentType']?.toString() ??
              '',
        ) ??
        -1;
  }

  String _titleOf(Map<String, dynamic> item) {
    return item['title']?.toString().trim().isNotEmpty == true
        ? item['title'].toString().trim()
        : (item['name']?.toString().trim().isNotEmpty == true
              ? item['name'].toString().trim()
              : widget.title);
  }

  String _subtitleOf(Map<String, dynamic> item) {
    final fields = <String>[
      item['activitylabel']?.toString() ?? '',
      item['begintime']?.toString() ?? '',
      item['endtime']?.toString() ?? '',
      item['createtime']?.toString() ?? '',
      item['updatetime']?.toString() ?? '',
    ].where((value) => value.trim().isNotEmpty).toList();

    if (fields.isEmpty) {
      return '内容类型 ${_contentTypeOf(item)}';
    }

    return fields.take(2).join('  |  ');
  }

  Future<void> _showDetail(Map<String, dynamic> item) async {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(item);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_titleOf(item)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(child: SelectableText(prettyJson)),
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
