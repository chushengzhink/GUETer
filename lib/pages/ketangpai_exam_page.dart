import 'package:flutter/material.dart';

import '../api/course.dart';
import '../models/course.dart';
import 'ketangpai_prepare_exam_page.dart';
import 'ketangpai_exam_execute_page.dart';

class KetangpaiExamPage extends StatefulWidget {
  final Course course;

  const KetangpaiExamPage({super.key, required this.course});

  @override
  State<KetangpaiExamPage> createState() => _KetangpaiExamPageState();
}

class _KetangpaiExamPageState extends State<KetangpaiExamPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final items = await KTCourseApi.getCourseContentList(
      widget.course.courseId,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _total = items.length;
      _loading = false;
    });
  }

  String _titleOf(Map<String, dynamic> item) {
    return item['title']?.toString() ?? item['name']?.toString() ?? '未命名活动';
  }

  String _activityLabelOf(Map<String, dynamic> item) {
    final label = item['activitylabel']?.toString() ?? '';
    if (label.trim().isNotEmpty) {
      return label;
    }
    return _activityTypeTag(item);
  }

  String _activityTypeTag(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    if (type == '0') {
      return '测试';
    }
    if (type == '1') {
      return '考试';
    }
    return '测试';
  }

  Color _activityTagColor(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? '';
    if (type == '1') {
      return Colors.orange.shade100;
    }
    return Colors.yellow.shade100;
  }

  bool _isFinished(Map<String, dynamic> item) {
    final over = item['over'];
    return over == 1 || over?.toString() == '1';
  }

  int _submitStateOf(Map<String, dynamic> item) {
    return int.tryParse(item['submit_state']?.toString() ?? '') ?? 0;
  }

  Widget _checkedIcon() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline_outlined, color: Colors.greenAccent),
        SizedBox(width: 4),
        Text('已批改', style: TextStyle(color: Colors.greenAccent)),
      ],
    );
  }

  Widget _failedSubmitIcon() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_outlined, color: Colors.blueAccent),
        SizedBox(width: 4),
        Text('未提交', style: TextStyle(color: Colors.blueAccent)),
      ],
    );
  }

  Widget _toReviewIcon() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_outlined, color: Colors.blueAccent),
        SizedBox(width: 4),
        Text('待批改', style: TextStyle(color: Colors.blueAccent)),
      ],
    );
  }

  Widget _overIcon() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_alarm_outlined, color: Colors.grey),
        SizedBox(width: 4),
        Text('已结束', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _statusWidget(Map<String, dynamic> item) {
    if (_isFinished(item)) {
      return _overIcon();
    }
    final submitState = _submitStateOf(item);
    if (submitState == 4) {
      return _toReviewIcon();
    }
    if (submitState < 3) {
      return _failedSubmitIcon();
    }
    if (submitState >= 6) {
      return _checkedIcon();
    }
    return const SizedBox.shrink();
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
              const Text(
                '课程内容',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                '$_total个活动',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _activityTagColor(item),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _activityTypeTag(item),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          _titleOf(item),
                          style: const TextStyle(fontSize: 16),
                        ),
                        subtitle: Text(
                          _activityLabelOf(item),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: _statusWidget(item),
                        onTap: () {
                          final testPaperId =
                              item['testpaperid']?.toString() ?? '';
                          if (testPaperId.isEmpty) {
                            _showActivityDetail(item);
                            return;
                          }

                          final type = item['type']?.toString() ?? '';
                          if (type == '0') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KetangpaiExamExecutePage(
                                  courseId: widget.course.courseId,
                                  testPaperId: testPaperId,
                                  readOnly: _isFinished(item),
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KetangpaiPrepareExamPage(
                                  courseId: widget.course.courseId,
                                  testPaperId: testPaperId,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActivityDetail(Map<String, dynamic> item) async {
    final detailLines = <String>[
      '标题: ${_titleOf(item)}',
      '类型: ${_activityTypeTag(item)}',
      '状态: ${_isFinished(item) ? '已结束' : '进行中'}',
      if (_activityLabelOf(item).trim().isNotEmpty)
        '标签: ${_activityLabelOf(item)}',
      if ((item['begintime']?.toString() ?? '').isNotEmpty)
        '开始时间: ${item['begintime']}',
      if ((item['endtime']?.toString() ?? '').isNotEmpty)
        '结束时间: ${item['endtime']}',
      if ((item['testpaperid']?.toString() ?? '').isNotEmpty)
        '试卷ID: ${item['testpaperid']}',
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(_titleOf(item)),
          content: SingleChildScrollView(
            child: SelectableText(detailLines.join('\n')),
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
}
