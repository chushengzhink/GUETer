import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/components/app_card.dart';
import '../controller/zerotier_controller.dart';
import '../models/zerotier_snapshot.dart';
import 'unsupported_page.dart';

class ZeroTierPage extends StatefulWidget {
  const ZeroTierPage({super.key, this.controller});

  final ZeroTierController? controller;

  @override
  State<ZeroTierPage> createState() => _ZeroTierPageState();
}

class _ZeroTierPageState extends State<ZeroTierPage> {
  late final ZeroTierController _controller;
  late final bool _ownsController;
  late final TextEditingController _networkIdController;
  bool _promptHandled = false;

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _tr(String zh, String en) => _isEnglish ? en : zh;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ZeroTierController();
    _ownsController = widget.controller == null;
    _networkIdController = TextEditingController();
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.initialize();
      if (!mounted || !_controller.isSupported) {
        return;
      }
      _networkIdController.text = _controller.networkId;
      await _maybePromptForNetworkId();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _networkIdController.dispose();
    if (_ownsController) {
      unawaited(_controller.close());
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    final normalized = ZeroTierController.normalizeNetworkId(
      _networkIdController.text,
    );
    if (normalized != _controller.networkId) {
      _networkIdController.value = TextEditingValue(
        text: _controller.networkId,
        selection: TextSelection.collapsed(
          offset: _controller.networkId.length,
        ),
      );
    }
    setState(() {});
  }

  Future<void> _maybePromptForNetworkId() async {
    if (_promptHandled || !_controller.requiresInitialNetworkIdPrompt) {
      return;
    }
    _promptHandled = true;
    final result = await _showNetworkIdDialog(
      initialValue: _controller.networkId,
      barrierDismissible: false,
    );
    if (!mounted || result == null || result.isEmpty) {
      return;
    }
    _networkIdController.text = result;
    await _controller.saveNetworkId(result);
  }

  Future<String?> _showNetworkIdDialog({
    required String initialValue,
    bool barrierDismissible = true,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? validationMessage;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                _tr('输入 ZeroTier 网络 ID', 'Enter ZeroTier Network ID'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Network ID',
                      hintText: _tr('16 位十六进制', '16 hex characters'),
                      errorText: validationMessage,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tr(
                      '该值会保存到本机，下次打开工具页时自动带出。',
                      'The value is stored locally and reused next time.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: barrierDismissible
                      ? () => Navigator.of(context).pop()
                      : null,
                  child: Text(_tr('取消', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final value = ZeroTierController.normalizeNetworkId(
                      controller.text,
                    );
                    if (!ZeroTierController.isValidNetworkId(value)) {
                      setDialogState(() {
                        validationMessage = _tr(
                          '请输入 16 位十六进制网络 ID',
                          'Enter a 16-character hex network ID',
                        );
                      });
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  child: Text(_tr('保存', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _handleJoin() async {
    await _controller.connect(_networkIdController.text);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isSupported) {
      return const ZeroTierUnsupportedPage();
    }

    final snapshot = _controller.snapshot;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('虚拟局域网')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          AppCard(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tr('ZeroTier 虚拟局域网', 'ZeroTier Virtual LAN'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _tr(
                    '加入指定网络后，GUETer 会在应用内持有一个 ZeroTier 节点，并显示当前分配到的虚拟 IP。',
                    'Join a network to run an in-app ZeroTier node and show the assigned virtual IP.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _StatusChip(
                      label: _buildStatusLabel(snapshot),
                      icon: _buildStatusIcon(snapshot),
                    ),
                    if (snapshot.networkStatus?.isNotEmpty == true)
                      _StatusChip(
                        label: snapshot.networkStatus!,
                        icon: Icons.info_outline_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tr('网络配置', 'Network Configuration'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _networkIdController,
                  enabled: !_controller.isBusy,
                  decoration: InputDecoration(
                    labelText: 'Network ID',
                    hintText: _tr(
                      '16 位十六进制网络 ID',
                      '16-character hex network ID',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _tr(
                    '支持修改网络 ID 后重新加入。若留空，首次进入会要求输入。',
                    'You can change the network ID and reconnect at any time.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tr('连接结果', 'Connection Result'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  label: 'Network ID',
                  value: snapshot.networkId.isEmpty
                      ? _tr('未设置', 'Not set')
                      : snapshot.networkId,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: _tr('虚拟 IP', 'Virtual IP'),
                  value: snapshot.virtualIp ?? _tr('尚未分配', 'Not assigned yet'),
                ),
                if (snapshot.networkName?.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: _tr('网络名称', 'Network Name'),
                    value: snapshot.networkName!,
                  ),
                ],
                const SizedBox(height: 8),
                _InfoRow(
                  label: _tr('最近更新', 'Last Update'),
                  value: _formatTime(snapshot.updatedAt),
                ),
                if (snapshot.errorMessage?.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      snapshot.errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _controller.isBusy ? null : _handleJoin,
                  icon: _controller.isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.vpn_lock_outlined),
                  label: Text(_tr('加入网络', 'Join Network')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _controller.isBusy
                      ? null
                      : _controller.refreshStatus,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_tr('刷新状态', 'Refresh Status')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _buildStatusIcon(ZeroTierSnapshot snapshot) {
    return switch (snapshot.connectionState) {
      ZeroTierConnectionState.uninitialized =>
        Icons.power_settings_new_outlined,
      ZeroTierConnectionState.connecting => Icons.sync_rounded,
      ZeroTierConnectionState.joined => Icons.check_circle_outline_rounded,
      ZeroTierConnectionState.failed => Icons.error_outline_rounded,
    };
  }

  String _buildStatusLabel(ZeroTierSnapshot snapshot) {
    return switch (snapshot.connectionState) {
      ZeroTierConnectionState.uninitialized => _tr('未初始化', 'Uninitialized'),
      ZeroTierConnectionState.connecting => _tr('连接中', 'Connecting'),
      ZeroTierConnectionState.joined => _tr('已加入', 'Joined'),
      ZeroTierConnectionState.failed => _tr('失败', 'Failed'),
    };
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} $hour:$minute:$second';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
