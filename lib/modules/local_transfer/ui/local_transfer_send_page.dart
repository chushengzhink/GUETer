import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/local_transfer_controller.dart';
import '../model/transfer_device.dart';
import '../model/transfer_source_file.dart';
import '../../../pages/file_preview_page.dart';
import 'widgets/device_name_dialog.dart';
import 'widgets/device_tile.dart';
import 'widgets/progress_panel.dart';

class LocalTransferSendPage extends StatefulWidget {
  const LocalTransferSendPage({
    super.key,
    required this.files,
    required this.sourceLabel,
  });

  final List<TransferSourceFile> files;
  final String sourceLabel;

  @override
  State<LocalTransferSendPage> createState() => _LocalTransferSendPageState();
}

class _LocalTransferSendPageState extends State<LocalTransferSendPage> {
  final LocalTransferController _controller = LocalTransferController.instance;
  TransferDevice? _selectedDevice;
  bool _preparing = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepare());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    final devices = _controller.devices;
    if (_selectedDevice != null) {
      _selectedDevice = devices.cast<TransferDevice?>().firstWhere(
        (item) => item?.stableId == _selectedDevice!.stableId,
        orElse: () => null,
      );
    }
    setState(() {});
  }

  Future<void> _prepare() async {
    await _controller.ensurePickerPermissions();
    if (!mounted) {
      return;
    }
    final ready = await _controller.ensureLocalDeviceName(context);
    if (!mounted) {
      return;
    }
    if (!ready) {
      Navigator.of(context).maybePop();
      return;
    }
    if (_controller.initialized && !_controller.discoveryRunning) {
      await _controller.startDiscovery();
    }
    if (mounted) {
      setState(() => _preparing = false);
    }
  }

  Future<void> _editLocalDeviceName() async {
    final result = await showDeviceNameDialog(
      context,
      initialValue: _controller.localDeviceName,
      allowCancel: true,
    );
    if (result == null) {
      return;
    }
    await _controller.saveLocalDeviceName(result);
  }

  Future<void> _send() async {
    final device = _selectedDevice;
    if (device == null || widget.files.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await _controller.sendFilesWithSource(
        widget.files,
        device,
        sourceLabel: widget.sourceLabel,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalSize = widget.files.fold<int>(0, (sum, file) => sum + file.size);
    return Scaffold(
      appBar: AppBar(
        title: const Text('发送到局域网'),
        actions: [
          IconButton(
            onPressed: _controller.refreshDiscoveryWithFallback,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新扫描',
          ),
        ],
      ),
      body: _preparing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_sync_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${widget.sourceLabel} · ${widget.files.length} 个文件 · ${_formatSize(totalSize)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '本机名称：${_controller.localDeviceName}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _editLocalDeviceName,
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: '编辑本机名称',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '附近设备',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (_controller.devices.isEmpty)
                  const Text('当前无可用设备，请确保在同一 WiFi 或虚拟局域网下。')
                else
                  ..._controller.devices.map((device) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DeviceTile(
                        device: device,
                        selected: _selectedDevice?.stableId == device.stableId,
                        onTap: () => setState(() => _selectedDevice = device),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      _selectedDevice == null ||
                          widget.files.isEmpty ||
                          _sending
                      ? null
                      : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_sending ? '正在发送' : '发送'),
                ),
                const SizedBox(height: 16),
                ProgressPanel(
                  sessions: _controller.sessions,
                  onRetry: _controller.retrySession,
                  onCancel: _controller.cancelSession,
                  onOpenFile: (path) => FilePreviewPage.open(context, path),
                  onCopyMessage: _controller.copyMessageToClipboard,
                ),
              ],
            ),
    );
  }
}

String _formatSize(int size) {
  if (size < 1024) {
    return '$size B';
  }
  final kb = size / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}
