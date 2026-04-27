import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../session/tronclass_sign_log_store.dart';

class TronclassSignLogItem {
  final DateTime time;
  final String activityId;
  final String activityTitle;
  final String mode;
  final String message;
  final bool success;

  const TronclassSignLogItem({
    required this.time,
    required this.activityId,
    required this.activityTitle,
    required this.mode,
    required this.message,
    required this.success,
  });

  factory TronclassSignLogItem.fromMap(Map<String, dynamic> map) {
    final millis = map['time'];
    return TronclassSignLogItem(
      time: DateTime.fromMillisecondsSinceEpoch(
        millis is int ? millis : int.tryParse(millis?.toString() ?? '') ?? 0,
      ),
      activityId: map['activityId']?.toString() ?? '',
      activityTitle: map['activityTitle']?.toString() ?? '',
      mode: map['mode']?.toString() ?? '未知模式',
      message: map['message']?.toString() ?? '',
      success: map['success'] == true || map['success']?.toString() == 'true',
    );
  }
}

class TronclassSignLogsPage extends StatefulWidget {
  final List<TronclassSignLogItem> logs;

  const TronclassSignLogsPage({super.key, this.logs = const []});

  @override
  State<TronclassSignLogsPage> createState() => _TronclassSignLogsPageState();
}

class _TronclassSignLogsPageState extends State<TronclassSignLogsPage> {
  final TronclassSignLogStore _store = TronclassSignLogStore();
  final TextEditingController _queryController = TextEditingController();
  List<TronclassSignLogItem> _logs = [];
  bool _loading = true;
  String _statusFilter = 'all';
  String _modeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final raw = await _store.loadRaw();
    final loaded = raw.map(TronclassSignLogItem.fromMap).toList();
    if (!mounted) return;
    setState(() {
      _logs = loaded.isNotEmpty ? loaded : widget.logs;
      _loading = false;
    });
  }

  List<MapEntry<int, TronclassSignLogItem>> _filteredEntries() {
    final query = _queryController.text.trim().toLowerCase();
    return _logs.asMap().entries.where((entry) {
      final log = entry.value;
      if (_statusFilter == 'success' && !log.success) return false;
      if (_statusFilter == 'failure' && log.success) return false;
      if (_modeFilter != 'all' && log.mode.toLowerCase() != _modeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return log.activityTitle.toLowerCase().contains(query) ||
          log.activityId.toLowerCase().contains(query) ||
          log.mode.toLowerCase().contains(query) ||
          log.message.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _deleteLog(int index) async {
    await _store.deleteAt(index);
    await _loadLogs();
  }

  Future<void> _clearAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空签到记录'),
        content: const Text('确认删除所有本地签到记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.clear();
    await _loadLogs();
  }

  String _buildShareText(List<MapEntry<int, TronclassSignLogItem>> entries) {
    final buffer = StringBuffer()..writeln('GUETer 畅课签到记录');
    for (final entry in entries) {
      final log = entry.value;
      buffer
        ..writeln('----------------')
        ..writeln('时间: ${_formatTime(log.time)}')
        ..writeln('状态: ${log.success ? '成功' : '失败'}')
        ..writeln('活动: ${log.activityTitle}')
        ..writeln('活动ID: ${log.activityId}')
        ..writeln('模式: ${log.mode}')
        ..writeln('消息: ${log.message}');
    }
    return buffer.toString().trim();
  }

  Future<void> _shareLogs(List<MapEntry<int, TronclassSignLogItem>> entries) async {
    if (entries.isEmpty) return;
    await Share.share(_buildShareText(entries));
  }

  String _formatTime(DateTime time) {
    final mm = time.month.toString().padLeft(2, '0');
    final dd = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mi = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries();

    return Scaffold(
      appBar: AppBar(
        title: const Text('签到日志'),
        actions: [
          IconButton(
            tooltip: '分享当前筛选结果',
            icon: const Icon(Icons.share_outlined),
            onPressed: filtered.isEmpty ? null : () => _shareLogs(filtered),
          ),
          IconButton(
            tooltip: '清空全部记录',
            icon: const Icon(Icons.delete_outline),
            onPressed: _logs.isEmpty ? null : _clearAllLogs,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _queryController,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: '搜索活动名称、模式、消息或活动ID',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _statusFilter,
                                  decoration: const InputDecoration(
                                    labelText: '状态',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('全部')),
                                    DropdownMenuItem(value: 'success', child: Text('成功')),
                                    DropdownMenuItem(value: 'failure', child: Text('失败')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _statusFilter = value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _modeFilter,
                                  decoration: const InputDecoration(
                                    labelText: '模式',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('全部模式')),
                                    DropdownMenuItem(value: '二维码签到', child: Text('二维码')),
                                    DropdownMenuItem(value: '雷达签到', child: Text('雷达')),
                                    DropdownMenuItem(value: '数字签到', child: Text('数字')),
                                    DropdownMenuItem(value: '未知模式', child: Text('未知')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _modeFilter = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('暂无签到日志'))
                      : RefreshIndicator(
                          onRefresh: _loadLogs,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              final actualIndex = entry.key;
                              final log = entry.value;
                              return Dismissible(
                                key: ValueKey('${log.activityId}-${log.time.millisecondsSinceEpoch}-$index'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red.shade300,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  alignment: Alignment.centerRight,
                                  child: const Icon(Icons.delete_outline, color: Colors.white),
                                ),
                                onDismissed: (_) => _deleteLog(actualIndex),
                                child: Card(
                                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                                  child: ListTile(
                                    leading: Icon(
                                      log.success ? Icons.check_circle : Icons.error,
                                      color: log.success ? Colors.green : Colors.red,
                                    ),
                                    title: Text(log.activityTitle),
                                    subtitle: Text(
                                      '${_formatTime(log.time)}\n模式: ${log.mode}\n活动ID: ${log.activityId}\n${log.message}',
                                    ),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      tooltip: '分享',
                                      icon: const Icon(Icons.share_outlined),
                                      onPressed: () => _shareLogs([entry]),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
