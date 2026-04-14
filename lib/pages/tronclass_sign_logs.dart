import 'package:flutter/material.dart';

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
}

class TronclassSignLogsPage extends StatelessWidget {
  final List<TronclassSignLogItem> logs;

  const TronclassSignLogsPage({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('签到日志'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text(
                '暂无签到日志',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  leading: Icon(
                    log.success ? Icons.check_circle : Icons.error,
                    color: log.success ? Colors.green : Colors.red,
                  ),
                  title: Text(log.activityTitle),
                  subtitle: Text(
                    '${_formatTime(log.time)}\n模式: ${log.mode}\n活动ID: ${log.activityId}\n${log.message}',
                  ),
                  isThreeLine: false,
                );
              },
            ),
    );
  }

  String _formatTime(DateTime time) {
    final mm = time.month.toString().padLeft(2, '0');
    final dd = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mi = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi:$ss';
  }
}
