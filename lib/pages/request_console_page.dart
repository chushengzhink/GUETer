import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_service.dart';

class RequestConsolePage extends StatefulWidget {
  const RequestConsolePage({super.key});

  @override
  State<RequestConsolePage> createState() => _RequestConsolePageState();
}

class _RequestConsolePageState extends State<RequestConsolePage> {
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
    final logs = ApiService.getConsoleLogs();
    final text = logs.join('\n');
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

  @override
  Widget build(BuildContext context) {
    final logs = ApiService.getConsoleLogs();
    final displayLogs = logs.reversed.toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('请求控制台'),
        actions: [
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
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final line = displayLogs[index];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: SelectableText(
                          line,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.35,
                          ),
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
