import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';

class KetangpaiHomeworkPage extends StatefulWidget {
  final Course course;

  const KetangpaiHomeworkPage({super.key, required this.course});

  @override
  State<KetangpaiHomeworkPage> createState() => _KetangpaiHomeworkPageState();
}

class _KetangpaiHomeworkPageState extends State<KetangpaiHomeworkPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final items = await KTCourseApi.getHomeworkList(widget.course.courseId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  String _titleOf(Map<String, dynamic> item) {
    return item['title']?.toString() ?? item['name']?.toString() ?? '未命名作业';
  }

  String _homeworkTypeLabel(Map<String, dynamic> item) {
    final type = item['homeworktype']?.toString() ?? '';
    switch (type) {
      case '1':
        return '普通作业';
      case '2':
        return '实验报告';
      case '3':
        return '分组作业';
      default:
        return '作业';
    }
  }

  bool _isFinished(Map<String, dynamic> item) {
    final over = item['over'];
    return over == 1 || over?.toString() == '1';
  }

  int _submitState(Map<String, dynamic> item) {
    return int.tryParse(item['submit_state']?.toString() ?? '') ?? 0;
  }

  Widget _statusWidget(Map<String, dynamic> item) {
    if (_isFinished(item)) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_alarm_outlined, color: Colors.grey),
          SizedBox(width: 4),
          Text('已结束', style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    final state = _submitState(item);
    if (state >= 3) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_outlined, color: Colors.greenAccent),
          SizedBox(width: 4),
          Text('已提交', style: TextStyle(color: Colors.greenAccent)),
        ],
      );
    }

    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_outlined, color: Colors.blueAccent),
        SizedBox(width: 4),
        Text('未提交', style: TextStyle(color: Colors.blueAccent)),
      ],
    );
  }

  Future<void> _showHomeworkDetail(Map<String, dynamic> item) async {
    final homeworkId = item['id']?.toString() ?? item['homeworkid']?.toString() ?? '';
    if (homeworkId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作业ID为空，无法查看详情')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final detail = await KTCourseApi.getHomeworkDetail(widget.course.courseId, homeworkId);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('获取作业详情失败')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final homework = detail['data']?['homework'] as Map<String, dynamic>? ?? {};
        final title = homework['title']?.toString() ?? '作业详情';
        final description = homework['description']?.toString() ?? '';
        final beginTime = homework['begintime']?.toString() ?? '';
        final endTime = homework['endtime']?.toString() ?? '';
        final score = homework['score']?.toString() ?? '';
        final homeworkType = _homeworkTypeLabel(homework);

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('类型: $homeworkType', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                if (beginTime.isNotEmpty) Text('开始时间: $beginTime', style: const TextStyle(fontSize: 14)),
                if (endTime.isNotEmpty) Text('截止时间: $endTime', style: const TextStyle(fontSize: 14)),
                if (score.isNotEmpty) Text('分值: $score', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
                if (description.isNotEmpty) ...[
                  const Text('作业要求:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(description.replaceAll(RegExp(r'<[^>]+>'), '')),
                ],
              ],
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('作业列表', style: TextStyle(fontSize: 18, color: Colors.grey)),
              Text('${_items.length}个作业', style: const TextStyle(fontSize: 18, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('暂无作业'))
                    : ListView.separated(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_homeworkTypeLabel(item), style: const TextStyle(fontSize: 12)),
                            ),
                            title: Text(_titleOf(item), style: const TextStyle(fontSize: 16)),
                            subtitle: Text(
                              '截止: ${item['endtime']?.toString() ?? '无'}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            trailing: _statusWidget(item),
                            onTap: () => _showHomeworkDetail(item),
                          );
                        },
                        separatorBuilder: (context, index) => const Divider(height: 1),
                      ),
          ),
        ],
      ),
    );
  }
}
