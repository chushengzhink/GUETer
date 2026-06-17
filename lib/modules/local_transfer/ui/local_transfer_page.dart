// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/local_transfer_controller.dart';
import '../model/transfer_device.dart';
import '../model/transfer_source_file.dart';
import 'widgets/device_name_dialog.dart';
import 'widgets/device_tile.dart';
import 'widgets/progress_panel.dart';
import 'widgets/send_panel.dart';
import '../../../pages/file_preview_page.dart';

class LocalTransferPage extends StatefulWidget {
  const LocalTransferPage({super.key});

  @override
  State<LocalTransferPage> createState() => _LocalTransferPageState();
}

class _LocalTransferPageState extends State<LocalTransferPage> {
  final LocalTransferController _controller = LocalTransferController.instance;
  final TextEditingController _textController = TextEditingController();
  List<TransferSourceFile> _pickedFiles = <TransferSourceFile>[];
  TransferDevice? _selectedDevice;
  bool _preparingPage = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_preparePage());
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    final devices = _controller.devices;
    if (_selectedDevice != null) {
      _selectedDevice = devices.cast<TransferDevice?>().firstWhere(
        (TransferDevice? item) => item?.stableId == _selectedDevice!.stableId,
        orElse: () => null,
      );
    }
    setState(() {});
  }

  Future<void> _preparePage() async {
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
    if (!mounted) {
      return;
    }
    setState(() {
      _preparingPage = false;
    });
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

  Future<void> _pickFiles() async {
    final files = await _controller.pickFiles();
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedFiles = files;
    });
  }

  Future<void> _sendFiles() async {
    final device = _selectedDevice;
    if (device == null || _pickedFiles.isEmpty) {
      return;
    }
    final files = _pickedFiles;
    setState(() {
      _pickedFiles = <TransferSourceFile>[];
    });
    await _controller.sendFiles(files, device);
  }

  Future<void> _sendText() async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }
    final text = _textController.text;
    _textController.clear();
    await _controller.sendText(text, device);
  }

  Future<void> _sendClipboard() async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      return;
    }
    await _controller.sendText(text, device);
  }

  Future<void> _previewReceivedFile(String path) {
    return FilePreviewPage.open(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('局域网快传'),
        actions: <Widget>[
          IconButton(
            onPressed: _controller.discoveryRunning
                ? _controller.stopDiscovery
                : _controller.startDiscovery,
            icon: Icon(
              _controller.discoveryRunning
                  ? Icons.radar_rounded
                  : Icons.radar_outlined,
            ),
            tooltip: _controller.discoveryRunning ? '停止发现' : '开始发现',
          ),
          IconButton(
            onPressed: _controller.refreshDiscoveryWithFallback,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新扫描',
          ),
        ],
      ),
      body: _preparingPage
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.perm_device_information_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '本机名称：${_controller.localDeviceName}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '该名称会广播给局域网内其他设备。',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _editLocalDeviceName,
                        icon: const Icon(Icons.edit_rounded),
                        tooltip: '编辑本机名称',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '附近设备',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '默认端口 ${_controller.serverPort} · ${_controller.protocol.toUpperCase()} · 广播优先，单播补充',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_controller.unicastScanning) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(
                          '正在扫描附近子网...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_controller.devices.isEmpty)
                        Text(
                          '当前无可用设备，请确保在同一 WiFi 下',
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        ..._controller.devices.map((TransferDevice device) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DeviceTile(
                              device: device,
                              selected:
                                  _selectedDevice?.stableId == device.stableId,
                              onTap: () {
                                setState(() {
                                  _selectedDevice = device;
                                });
                              },
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SendPanel(
                  selectedDevice: _selectedDevice,
                  textController: _textController,
                  pickedFiles: _pickedFiles,
                  onPickFiles: _pickFiles,
                  onClearFiles: () {
                    setState(() {
                      _pickedFiles = <TransferSourceFile>[];
                    });
                  },
                  onSendFiles: _sendFiles,
                  onSendText: _sendText,
                  onSendClipboard: _sendClipboard,
                ),
                const SizedBox(height: 16),
                ProgressPanel(
                  sessions: _controller.sessions,
                  onRetry: _controller.retrySession,
                  onCancel: _controller.cancelSession,
                  onOpenFile: _previewReceivedFile,
                  onCopyMessage: _controller.copyMessageToClipboard,
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('校园网排障建议'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: const <Widget>[
                    _TipLine('1. 防火墙需放行入站 TCP/UDP 53317。'),
                    _TipLine('2. 路由器或 AP 需关闭 AP/client/guest isolation。'),
                    _TipLine('3. 双频合一或漫游到不同 VLAN 时，自动发现可能失败。'),
                    _TipLine('4. 部分热点会屏蔽组播，此时依赖单播子网扫描补充发现。'),
                  ],
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('调试日志'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: _controller.logs.isEmpty
                      ? const <Widget>[_TipLine('暂无日志')]
                      : _controller.logs.take(40).map((String line) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          );
                        }).toList(),
                ),
              ],
            ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text),
      ),
    );
  }
}
