import 'package:flutter/material.dart';

import '../api/course.dart';
import 'widget/ketangpai_sign_task_panel.dart';

class KetangpaiSignStatusPage extends StatefulWidget {
  final String courseId;

  const KetangpaiSignStatusPage({super.key, required this.courseId});

  @override
  State<KetangpaiSignStatusPage> createState() =>
      _KetangpaiSignStatusPageState();
}

class _KetangpaiSignStatusPageState extends State<KetangpaiSignStatusPage> {
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;
  List<dynamic> _pendingSigns = const <dynamic>[];

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
      final results = await Future.wait<dynamic>([
        KTCourseApi.getSignStatus(widget.courseId),
        KTCourseApi.getNotFinishSign(widget.courseId),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as Map<String, dynamic>?;
        _pendingSigns = results[1] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _pendingSigns = const <dynamic>[];
        _errorMessage = '考勤信息加载失败: $e';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _statsData() {
    final root = _data;
    if (root?['data'] is Map<String, dynamic>) {
      return root!['data'] as Map<String, dynamic>;
    }
    return root ?? <String, dynamic>{};
  }

  Widget _countCard(String label, dynamic value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              value?.toString() ?? '0',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
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
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildStats(Map<String, dynamic> data) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('考勤统计', '当前课程签到历史汇总'),
            Row(
              children: [
                _countCard('出勤', data['attenceCount'], Colors.green),
                _countCard('迟到', data['lateCount'], Colors.orange),
                _countCard('缺勤', data['absentCount'], Colors.red),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _countCard('早退', data['leaveEarlyCount'], Colors.blue),
                _countCard('请假', data['pleaseCount'], Colors.purple),
                _countCard('总计', data['total'], Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _titleOf(Map<String, dynamic> item) {
    return (item['title'] ?? item['name'] ?? '签到记录').toString();
  }

  String _subtitleOf(Map<String, dynamic> item) {
    final parts = <String>[
      if ((item['studentattence_createtime'] ?? '').toString().isNotEmpty)
        '签到时间: ${item['studentattence_createtime']}',
      if ((item['attence_time'] ?? '').toString().isNotEmpty)
        '发起时间: ${item['attence_time']}',
      if ((item['status'] ?? '').toString().isNotEmpty) '状态: ${item['status']}',
    ];
    if (parts.isEmpty) {
      return item.toString();
    }
    return parts.join(' · ');
  }

  Widget _buildHistory(Map<String, dynamic> data) {
    final list = (data['lists'] as List?) ?? const <dynamic>[];
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('签到记录', '已结束或已完成的课堂派考勤记录'),
            if (list.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('暂无签到记录'),
              )
            else
              for (final item in list)
                if (item is Map)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(_titleOf(Map<String, dynamic>.from(item))),
                    subtitle: Text(
                      _subtitleOf(Map<String, dynamic>.from(item)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _statsData();
    return Scaffold(
      appBar: AppBar(
        title: const Text('课堂派签到中心'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_errorMessage != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  KetangpaiSignTaskPanel(
                    courseId: widget.courseId,
                    initialTasks: _pendingSigns,
                    compact: true,
                  ),
                  const SizedBox(height: 12),
                  _buildStats(data),
                  const SizedBox(height: 12),
                  _buildHistory(data),
                ],
              ),
      ),
    );
  }
}
