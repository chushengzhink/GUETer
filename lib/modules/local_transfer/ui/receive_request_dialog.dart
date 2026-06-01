// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'package:flutter/material.dart';

import '../model/transfer_session.dart';

class ReceiveRequestDialog extends StatelessWidget {
  const ReceiveRequestDialog({super.key, required this.session});

  final TransferSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = session.entries.values.toList();
    return AlertDialog(
      title: const Text('接收请求'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${session.device.displayName} 想向你发送内容',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${session.device.ip}:${session.device.port} · ${session.device.protocol.toUpperCase()}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (session.message != null) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(session.message!),
              ),
            ] else ...<Widget>[
              Text('文件数：${files.length}', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final item = files[index];
                    return Row(
                      children: <Widget>[
                        const Icon(Icons.insert_drive_file_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                item.descriptor.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${_formatBytes(item.descriptor.size)} · ${item.descriptor.fileType}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('拒绝'),
        ),
        FilledButton(
          onPressed: () {
            if (session.message != null) {
              Navigator.of(context).pop(<String, String>{});
              return;
            }
            Navigator.of(context).pop(<String, String>{
              for (final entry in session.entries.entries)
                entry.key: entry.value.descriptor.fileName,
            });
          },
          child: Text(session.message != null ? '接收文本' : '接受全部'),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
