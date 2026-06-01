// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'package:flutter/material.dart';

import '../../model/transfer_session.dart';

class ProgressPanel extends StatelessWidget {
  const ProgressPanel({
    super.key,
    required this.sessions,
    required this.onRetry,
    required this.onCancel,
    required this.onOpenFile,
    required this.onCopyMessage,
  });

  final List<TransferSession> sessions;
  final Future<void> Function(String sessionId) onRetry;
  final Future<void> Function(String sessionId) onCancel;
  final Future<void> Function(String path) onOpenFile;
  final Future<void> Function(String message) onCopyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '传输进度',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (sessions.isEmpty)
            Text('暂无传输任务。', style: theme.textTheme.bodyMedium)
          else
            ...sessions.take(8).map((TransferSession session) {
              final canRetry =
                  session.direction == TransferSessionDirection.sending &&
                  session.hasFailures;
              final canCancel =
                  session.status == TransferSessionStatus.sending ||
                  session.status == TransferSessionStatus.awaitingAcceptance ||
                  session.status == TransferSessionStatus.waiting;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          session.direction == TransferSessionDirection.sending
                              ? Icons.north_east_rounded
                              : Icons.south_west_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${session.direction == TransferSessionDirection.sending ? '发送到' : '接收自'} ${session.device.displayName}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _labelForStatus(session.status),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (session.message != null) ...<Widget>[
                      Text(
                        session.message!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ] else ...<Widget>[
                      LinearProgressIndicator(value: session.overallProgress),
                      const SizedBox(height: 8),
                      Text(
                        '${(session.overallProgress * 100).toStringAsFixed(0)}% · ${session.entries.length} 个文件',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (session.errorMessage != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        session.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if (session.message != null)
                          OutlinedButton.icon(
                            onPressed: () => onCopyMessage(session.message!),
                            icon: const Icon(Icons.copy_all_rounded),
                            label: const Text('复制文本'),
                          ),
                        if (session.entries.values.any(
                          (TransferSessionEntry item) =>
                              item.outputPath != null,
                        ))
                          OutlinedButton.icon(
                            onPressed: () {
                              final path = session.entries.values
                                  .firstWhere(
                                    (TransferSessionEntry item) =>
                                        item.outputPath != null,
                                  )
                                  .outputPath!;
                              onOpenFile(path);
                            },
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('打开文件'),
                          ),
                        if (canRetry)
                          OutlinedButton.icon(
                            onPressed: () => onRetry(session.localSessionId),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('重试失败项'),
                          ),
                        if (canCancel)
                          TextButton.icon(
                            onPressed: () => onCancel(session.localSessionId),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('取消'),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

String _labelForStatus(TransferSessionStatus status) {
  switch (status) {
    case TransferSessionStatus.waiting:
      return '等待中';
    case TransferSessionStatus.awaitingAcceptance:
      return '待确认';
    case TransferSessionStatus.sending:
      return '传输中';
    case TransferSessionStatus.finished:
      return '已完成';
    case TransferSessionStatus.finishedWithErrors:
      return '部分失败';
    case TransferSessionStatus.rejected:
      return '已拒绝';
    case TransferSessionStatus.canceledBySender:
      return '发送方取消';
    case TransferSessionStatus.canceledByReceiver:
      return '接收方取消';
    case TransferSessionStatus.error:
      return '错误';
  }
}
