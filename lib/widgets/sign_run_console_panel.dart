import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sign_run_console.dart';

class SignRunConsolePanel extends StatelessWidget {
  const SignRunConsolePanel({
    super.key,
    required this.controller,
    this.maxHeight = 260,
  });

  final SignRunConsoleController controller;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final events = controller.events.reversed.toList(growable: false);
        final theme = Theme.of(context);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '本次签到控制台',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '成功 ${controller.successCount} 失败 ${controller.failureCount} 跳过 ${controller.skippedCount}',
                      style: theme.textTheme.labelSmall,
                    ),
                    IconButton(
                      tooltip: '复制日志',
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      onPressed: events.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: controller.copyText()),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('本次签到日志已复制')),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (events.isEmpty)
                  Text(
                    '开始签到后会显示每个账号的换网与签到结果。',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const Divider(height: 10),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final color = event.isSuccess
                            ? Colors.green
                            : event.isFailure
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 8, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                event.toLine(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
