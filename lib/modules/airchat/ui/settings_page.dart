import 'package:flutter/material.dart';

import '../controller/airchat_controller.dart';
import '../utility/snackbar_util.dart';

class AirChatSettingsPage extends StatefulWidget {
  const AirChatSettingsPage({super.key});

  @override
  State<AirChatSettingsPage> createState() => _AirChatSettingsPageState();
}

class _AirChatSettingsPageState extends State<AirChatSettingsPage> {
  final AirChatController _controller = AirChatController.instance;
  late final TextEditingController _nameController;
  late final TextEditingController _hotspotSsidController;
  late final TextEditingController _hotspotPasswordController;
  late final TextEditingController _hotspotNoteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _controller.displayName);
    _hotspotSsidController = TextEditingController(
      text: _controller.hotspotSsid,
    );
    _hotspotPasswordController = TextEditingController(
      text: _controller.hotspotPassword,
    );
    _hotspotNoteController = TextEditingController(
      text: _controller.hotspotNote,
    );
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _nameController.dispose();
    _hotspotSsidController.dispose();
    _hotspotPasswordController.dispose();
    _hotspotNoteController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) {
      return;
    }
    if (_nameController.text != _controller.displayName) {
      _nameController.text = _controller.displayName;
    }
    if (_hotspotSsidController.text != _controller.hotspotSsid) {
      _hotspotSsidController.text = _controller.hotspotSsid;
    }
    if (_hotspotPasswordController.text != _controller.hotspotPassword) {
      _hotspotPasswordController.text = _controller.hotspotPassword;
    }
    if (_hotspotNoteController.text != _controller.hotspotNote) {
      _hotspotNoteController.text = _controller.hotspotNote;
    }
    setState(() {});
  }

  Future<void> _saveDisplayName() async {
    final value = _nameController.text.trim();
    if (value.isEmpty) {
      return;
    }
    await _controller.setDisplayName(value);
    if (!mounted) {
      return;
    }
    SnackbarUtil.show(context, message: '名称已保存');
  }

  Future<void> _saveHotspotProfile() async {
    await _controller.saveHotspotProfile(
      ssid: _hotspotSsidController.text,
      password: _hotspotPasswordController.text,
      note: _hotspotNoteController.text,
    );
    if (!mounted) {
      return;
    }
    SnackbarUtil.show(context, message: '热点资料已保存');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('附近房间设置')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '本机显示名称',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('该名称会用于附近房间发现、连接和房间广播展示。'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: '输入名称',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => _saveDisplayName(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saveDisplayName,
                    child: const Text('保存名称'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'BLE + 热点资料',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '无 GMS 设备会把这里保存的热点名称和密码通过 BLE 同步给加入方。请填写你准备广播的热点资料。',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hotspotSsidController,
                    decoration: const InputDecoration(
                      hintText: '热点名称',
                      prefixIcon: Icon(Icons.wifi_tethering_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hotspotPasswordController,
                    decoration: const InputDecoration(
                      hintText: '热点密码',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hotspotNoteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '备注（可选，例如宿舍 305 / 仅签到时开启）',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton(
                        onPressed: _saveHotspotProfile,
                        child: const Text('保存热点资料'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _controller.openHotspotSettings,
                        icon: const Icon(Icons.settings_suggest_outlined),
                        label: const Text('打开热点设置'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '系统能力',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _controller.requestPermissions,
                        icon: const Icon(Icons.security_outlined),
                        label: const Text('请求权限'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _controller.openSystemSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('系统设置'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _controller.openWifiSettings,
                        icon: const Icon(Icons.wifi_rounded),
                        label: const Text('Wi-Fi 设置'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _controller.openPermissionSettings,
                        icon: const Icon(Icons.app_settings_alt_outlined),
                        label: const Text('应用权限'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
