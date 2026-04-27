import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../session/sign_record_store.dart';

class SignRecordsPage extends StatefulWidget {
  const SignRecordsPage({super.key});

  @override
  State<SignRecordsPage> createState() => _SignRecordsPageState();
}

class _SignRecordsPageState extends State<SignRecordsPage> {
  final SignRecordStore _store = SignRecordStore();
  final TextEditingController _courseFilterController = TextEditingController();

  List<Map<String, dynamic>> _allRecords = <Map<String, dynamic>>[];
  String _platformFilter = '全部';
  DateTimeRange? _dateRange;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _courseFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _loading = true;
    });
    final records = await _store.loadRaw();
    if (!mounted) {
      return;
    }
    setState(() {
      _allRecords = records;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredRecords {
    final courseKeyword = _courseFilterController.text.trim().toLowerCase();
    return _allRecords.where((record) {
      final platform = (record['platform'] ?? '').toString();
      final courseName = (record['courseName'] ?? '').toString();
      final ts = int.tryParse((record['timestamp'] ?? '0').toString()) ?? 0;
      final signAt = DateTime.fromMillisecondsSinceEpoch(ts);

      if (_platformFilter != '全部' && platform != _platformFilter) {
        return false;
      }
      if (courseKeyword.isNotEmpty &&
          !courseName.toLowerCase().contains(courseKeyword)) {
        return false;
      }
      if (_dateRange != null) {
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );
        if (signAt.isBefore(start) || signAt.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _recordLine(Map<String, dynamic> record) {
    final platform = (record['platform'] ?? '未知平台').toString();
    final courseName = (record['courseName'] ?? '未知课程').toString();
    final account = (record['account'] ?? '未知账号').toString();
    final status = (record['status'] ?? '未知状态').toString();
    final detail = (record['detail'] ?? '').toString();
    final ts = int.tryParse((record['timestamp'] ?? '0').toString()) ?? 0;
    final signAt = DateTime.fromMillisecondsSinceEpoch(ts);
    final signTime = _fmt(signAt);

    if (detail.isEmpty) {
      return '[$platform] $courseName | $signTime | $account | $status';
    }
    return '[$platform] $courseName | $signTime | $account | $status | $detail';
  }

  String _fmt(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    final ss = dateTime.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  Future<void> _copyAllFiltered() async {
    final lines = _filteredRecords.map(_recordLine).join('\n');
    if (lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前筛选结果为空')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: lines));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制筛选日志')));
  }

  Future<void> _shareAllFiltered() async {
    final lines = _filteredRecords.map(_recordLine).join('\n');
    if (lines.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前筛选结果为空')));
      return;
    }
    await Share.share(lines, subject: 'GUETer 签到记录');
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
    );
    if (result == null) return;
    setState(() {
      _dateRange = result;
    });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空签到记录'),
        content: const Text('将删除本地所有签到日志，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }
    await _store.clear();
    await _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('签到记录查询'),
        actions: [
          IconButton(
            tooltip: '复制筛选结果',
            onPressed: _copyAllFiltered,
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            tooltip: '分享筛选结果',
            onPressed: _shareAllFiltered,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: '清空全部',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _courseFilterController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '按课程筛选',
                    hintText: '输入课程名关键字',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _platformFilter,
                        decoration: const InputDecoration(
                          labelText: '平台',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: '全部', child: Text('全部')),
                          DropdownMenuItem(value: '雨课堂', child: Text('雨课堂')),
                          DropdownMenuItem(value: '课堂派', child: Text('课堂派')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _platformFilter = v;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          _dateRange == null
                              ? '按时间筛选'
                              : '${_fmt(_dateRange!.start).substring(0, 10)} ~ ${_fmt(_dateRange!.end).substring(0, 10)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_dateRange != null)
                      IconButton(
                        tooltip: '清除时间筛选',
                        onPressed: () {
                          setState(() {
                            _dateRange = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? const Center(
                    child: Text(
                      '暂无签到记录',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = filtered[index];
                      final platform = (record['platform'] ?? '未知平台')
                          .toString();
                      final courseName = (record['courseName'] ?? '未知课程')
                          .toString();
                      final account = (record['account'] ?? '未知账号').toString();
                      final status = (record['status'] ?? '未知状态').toString();
                      final detail = (record['detail'] ?? '').toString();
                      final ts =
                          int.tryParse(
                            (record['timestamp'] ?? '0').toString(),
                          ) ??
                          0;
                      final signAt = DateTime.fromMillisecondsSinceEpoch(ts);

                      return ListTile(
                        leading: Icon(
                          platform == '雨课堂'
                              ? Icons.cloud_outlined
                              : Icons.class_outlined,
                        ),
                        title: Text(courseName),
                        subtitle: Text(
                          '${_fmt(signAt)}\n账号: $account\n状态: $status${detail.isEmpty ? '' : '\n备注: $detail'}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: '复制该条日志',
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _recordLine(record)),
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制该条日志')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
