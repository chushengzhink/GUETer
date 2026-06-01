// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'package:flutter/material.dart';

import '../../model/transfer_device.dart';
import '../../model/transfer_source_file.dart';

class SendPanel extends StatelessWidget {
  const SendPanel({
    super.key,
    required this.selectedDevice,
    required this.textController,
    required this.pickedFiles,
    required this.onPickFiles,
    required this.onClearFiles,
    required this.onSendFiles,
    required this.onSendText,
    required this.onSendClipboard,
  });

  final TransferDevice? selectedDevice;
  final TextEditingController textController;
  final List<TransferSourceFile> pickedFiles;
  final VoidCallback onPickFiles;
  final VoidCallback onClearFiles;
  final VoidCallback onSendFiles;
  final VoidCallback onSendText;
  final VoidCallback onSendClipboard;

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
            '发送内容',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedDevice == null
                ? '请先在上方选择一个设备。'
                : '目标设备：${selectedDevice!.displayName}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: textController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '发送文本',
              hintText: '输入消息，或直接发送当前剪贴板内容',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onPickFiles,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('选择文件'),
              ),
              OutlinedButton.icon(
                onPressed: pickedFiles.isEmpty ? null : onClearFiles,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('清空文件'),
              ),
              FilledButton.icon(
                onPressed: selectedDevice == null || pickedFiles.isEmpty
                    ? null
                    : onSendFiles,
                icon: const Icon(Icons.send_rounded),
                label: const Text('发送文件'),
              ),
              FilledButton.tonalIcon(
                onPressed: selectedDevice == null ? null : onSendText,
                icon: const Icon(Icons.message_outlined),
                label: const Text('发送文本'),
              ),
              FilledButton.tonalIcon(
                onPressed: selectedDevice == null ? null : onSendClipboard,
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('发送剪贴板'),
              ),
            ],
          ),
          if (pickedFiles.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '已选文件 (${pickedFiles.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...pickedFiles.map((TransferSourceFile file) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.insert_drive_file_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatBytes(file.size),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
