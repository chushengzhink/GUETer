import 'package:flutter/material.dart';

import '../api/course.dart';

class KetangpaiSignStatusPage extends StatefulWidget {
  final String courseId;

  const KetangpaiSignStatusPage({super.key, required this.courseId});

  @override
  State<KetangpaiSignStatusPage> createState() =>
      _KetangpaiSignStatusPageState();
}

class _KetangpaiSignStatusPageState extends State<KetangpaiSignStatusPage> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final data = await KTCourseApi.getSignStatus(widget.courseId);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
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
            Text(label, style: TextStyle(color: color, fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    final data = _data?['data'] is Map<String, dynamic>
        ? _data!['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('考勤详情'), centerTitle: true),
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
                  Row(
                    children: [
                      _countCard('出勤', data['attenceCount'], Colors.green),
                      _countCard('迟到', data['lateCount'], Colors.orange),
                      _countCard('缺勤', data['absentCount'], Colors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _countCard('早退', data['leaveEarlyCount'], Colors.blue),
                      _countCard('请假', data['pleaseCount'], Colors.purple),
                      _countCard('总计', data['total'], Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '签到记录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...((data['lists'] as List?) ?? const []).map((item) {
                    final map = item is Map<String, dynamic>
                        ? item
                        : <String, dynamic>{};
                    return Card(
                      child: ListTile(
                        title: Text(map['title']?.toString() ?? '签到'),
                        subtitle: Text(map.toString()),
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }
}
