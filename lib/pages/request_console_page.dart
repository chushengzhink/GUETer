import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_service.dart';

class RequestConsolePage extends StatefulWidget {
  const RequestConsolePage({super.key});

  @override
  State<RequestConsolePage> createState() => _RequestConsolePageState();
}

class _RequestConsolePageState extends State<RequestConsolePage> {
  String _selectedPlatform = '全部';
  bool _isExporting = false;

  final List<String> _platforms = ['全部', '学习通', '雨课堂', '畅课', '课堂派', '通用'];

  @override
  void initState() {
    super.initState();
    ApiService.consoleLogVersion.addListener(_onLogChanged);
  }

  @override
  void dispose() {
    ApiService.consoleLogVersion.removeListener(_onLogChanged);
    super.dispose();
  }

  void _onLogChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _copyAllLogs() async {
    final logs = ApiService.getConsoleLogs(platform: _selectedPlatform);
    final text = logs.map((log) => log['message']).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(logs.isEmpty ? '当前没有可复制的日志' : '请求日志已复制')),
    );
  }

  Future<void> _clearLogs() async {
    ApiService.clearConsoleLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请求日志已清空')),
    );
  }

  Future<void> _exportLogs() async {
    final logs = ApiService.getConsoleLogs(platform: _selectedPlatform);
    if (logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有可导出的日志')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出日志'),
        content: Text('确认导出 ${logs.length} 条日志到文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isExporting = true);

    try {
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final platformStr = _selectedPlatform == '全部' ? '全部' : _selectedPlatform;
      final fileName = 'GUETer_logs_${platformStr}_${dateStr}_$timeStr.txt';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      final buffer = StringBuffer();
      buffer.writeln('GUETer 请求控制台日志');
      buffer.writeln('导出时间：${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}');
      buffer.writeln('筛选平台：$platformStr');
      buffer.writeln('共 ${logs.length} 条日志');
      buffer.writeln('================================');

      for (final log in logs) {
        final timestamp = DateTime.parse(log['timestamp']!);
        final dateTimeStr = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
        buffer.writeln('[$dateTimeStr] [${log['platform']}] ${log['message']}');
      }

      await file.writeAsString(buffer.toString());

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'GUETer 请求日志',
      );

      if (!mounted) return;

      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ApiService.getConsoleLogs(platform: _selectedPlatform);
    final displayLogs = logs.reversed.toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('请求控制台'),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: '导出',
              icon: const Icon(Icons.share_outlined),
              onPressed: _exportLogs,
            ),
          IconButton(
            tooltip: '复制全部',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: _copyAllLogs,
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // 平台筛选标签
          Container(
            height: 50,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _platforms.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final platform = _platforms[index];
                final isSelected = platform == _selectedPlatform;
                return FilterChip(
                  label: Text(platform),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedPlatform = platform);
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                );
              },
            ),
          ),

          // 日志统计信息
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              logs.isEmpty
                  ? '暂无请求日志。触发一次登录、拉课或扫码后再回来查看。'
                  : '共 ${logs.length} 条日志（最新在上方）',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // 日志列表
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      '还没有请求日志',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: displayLogs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = displayLogs[index];
                      final message = log['message'] ?? '';
                      final platform = log['platform'] ?? '通用';

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedPlatform == '全部')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '[$platform]',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            SelectableText(
                              message,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
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
