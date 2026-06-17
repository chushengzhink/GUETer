import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controller/airchat_controller.dart';
import '../models/nearby_room_models.dart';
import '../utility/display_name_prompt.dart';
import '../utility/snackbar_util.dart';
import 'nearby_room_session_page.dart';
import 'settings_page.dart';
import 'unsupported_page.dart';

class NearbyRoomPage extends StatefulWidget {
  const NearbyRoomPage({super.key});

  @override
  State<NearbyRoomPage> createState() => _NearbyRoomPageState();
}

class _NearbyRoomPageState extends State<NearbyRoomPage>
    with WidgetsBindingObserver {
  final AirChatController _controller = AirChatController.instance;
  StreamSubscription<NearbyJoinResult>? _joinSubscription;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_handleControllerChanged);
    _joinSubscription = _controller.joinResults.listen(_handleJoinResult);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _controller.initialize();
      if (!mounted || !_supported) {
        return;
      }
      await showDisplayNamePrompt(context);
      await _controller.prepareSession();
      if (!mounted) {
        return;
      }
      final error = _controller.error;
      if (error != null) {
        SnackbarUtil.show(context, message: error);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleControllerChanged);
    unawaited(_joinSubscription?.cancel());
    if (_supported) {
      unawaited(_controller.teardownSession());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_supported && state == AppLifecycleState.resumed) {
      unawaited(_controller.handleAppResumed());
    }
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleJoinResult(NearbyJoinResult result) async {
    if (!mounted) {
      return;
    }
    SnackbarUtil.show(context, message: result.message);
    if (!result.ok) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NearbyRoomSessionPage(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const AirChatUnsupportedPage();
    }

    final mode = _controller.activeTransportMode;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('附近房间'),
        actions: <Widget>[
          IconButton(
            tooltip: '附近房间设置',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AirChatSettingsPage(),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _controller.recheckEnvironment,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            _buildHero(mode, theme),
            if (_controller.isPreparing) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 16),
            _buildModeOverview(mode),
            const SizedBox(height: 16),
            _buildEnvironmentPanel(mode),
            const SizedBox(height: 16),
            if (mode == NearbyTransportMode.bleHotspot) ...<Widget>[
              _buildHotspotGuideCard(),
              const SizedBox(height: 16),
            ],
            _buildPrimaryActionCard(mode),
            const SizedBox(height: 16),
            _buildRoomSection(mode),
            const SizedBox(height: 16),
            _buildLogSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(NearbyTransportMode mode, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final room = _controller.localRoom;
    final usingFallback = mode == NearbyTransportMode.bleHotspot;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: usingFallback
              ? <Color>[const Color(0xFF0F766E), const Color(0xFF134E4A)]
              : <Color>[colorScheme.primary, colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildChip(
                mode.label,
                background: Colors.white.withValues(alpha: 0.16),
              ),
              _buildChip(
                _controller.discovering ? '正在发现' : '未发现',
                background: _controller.discovering
                    ? Colors.greenAccent.shade400
                    : Colors.white24,
                foreground: _controller.discovering
                    ? Colors.black87
                    : Colors.white,
              ),
              _buildChip(
                _controller.advertising ? '正在广播' : '未广播',
                background: _controller.advertising
                    ? Colors.lightBlueAccent.shade100
                    : Colors.white24,
                foreground: _controller.advertising
                    ? Colors.black87
                    : Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            usingFallback ? '无 Play 服务也能进房' : '近场发现与房间配对',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            usingFallback
                ? '当前设备无需 Google Play 服务，将通过 BLE 发现附近房间并同步房主热点资料；进房后需要手动切换到房主热点。'
                : '当前设备将优先使用 Google Nearby Connections 完成发现、配对和进房；如果 Play 服务不可用，会自动降级到 BLE + 热点模式。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.meeting_room_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    room.roomName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOverview(NearbyTransportMode mode) {
    final theme = Theme.of(context);
    final steps = mode == NearbyTransportMode.bleHotspot
        ? const <String>[
            '1. 打开附近房间并开始扫描',
            '2. 发现房主后点击加入',
            '3. 同步热点名称、密码和备注',
            '4. 跳转系统 Wi-Fi，手动加入房主热点',
          ]
        : const <String>[
            '1. 打开附近房间并开始扫描',
            '2. 发现房主后点击加入',
            '3. Nearby 自动完成连接与进房确认',
          ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '当前模式',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              switch (mode) {
                NearbyTransportMode.bleHotspot => 'BLE 发现 + 热点接力',
                NearbyTransportMode.nearbyConnections => 'Google Nearby',
                NearbyTransportMode.unsupported => '不支持',
              },
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(step),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentPanel(NearbyTransportMode mode) {
    final theme = Theme.of(context);
    final statuses = _controller.permissionStatuses;
    final environment = _controller.environmentStatus;
    final hasPermanentDeny = statuses.any((item) => item.isPermanentlyDenied);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _controller.canStartNearby
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: _controller.canStartNearby
                      ? Colors.green
                      : Colors.orange.shade800,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _controller.canStartNearby ? '环境检查通过' : '环境未满足',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _envPill('定位服务', environment?.locationServicesEnabled == true),
                _envPill('蓝牙', environment?.bluetoothEnabled == true),
                _envPill(
                  'Play 服务',
                  environment?.playServicesAvailable == true,
                  neutral: mode != NearbyTransportMode.nearbyConnections,
                ),
                _envPill(
                  'BLE',
                  environment?.bleAvailable == true,
                  neutral: mode != NearbyTransportMode.bleHotspot,
                ),
                _envPill(
                  '热点能力',
                  environment?.hotspotCapable == true,
                  neutral: mode != NearbyTransportMode.bleHotspot,
                ),
                _envPill(
                  'Wi-Fi',
                  environment?.wifiEnabled == true,
                  neutral: true,
                ),
              ],
            ),
            if (statuses.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              for (final item in statuses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        item.isGranted
                            ? Icons.check_circle
                            : item.isPermanentlyDenied
                            ? Icons.block
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: item.isGranted
                            ? Colors.green
                            : item.isPermanentlyDenied
                            ? Colors.red
                            : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.label)),
                      Text(
                        item.isGranted
                            ? '已授权'
                            : item.isPermanentlyDenied
                            ? '永久拒绝'
                            : '未授权',
                      ),
                    ],
                  ),
                ),
            ],
            if (_controller.blockingIssues.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (final issue in _controller.blockingIssues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('- $issue'),
                ),
            ],
            if (_controller.advisoryMessages.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              for (final message in _controller.advisoryMessages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '- $message',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _controller.requestPermissions,
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('请求权限'),
                ),
                OutlinedButton.icon(
                  onPressed: _controller.recheckEnvironment,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重新检查'),
                ),
                OutlinedButton.icon(
                  onPressed: _controller.openSystemSettings,
                  icon: const Icon(Icons.settings_suggest_rounded),
                  label: const Text('系统设置'),
                ),
                if (hasPermanentDeny)
                  OutlinedButton.icon(
                    onPressed: _controller.openPermissionSettings,
                    icon: const Icon(Icons.app_settings_alt_rounded),
                    label: const Text('应用权限'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotspotGuideCard() {
    final hasConfig =
        _controller.hotspotSsid.trim().isNotEmpty &&
        _controller.hotspotPassword.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.wifi_tethering_rounded,
                  color: hasConfig ? Colors.teal : Colors.orange.shade800,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasConfig ? '热点资料已准备' : '建议先准备热点资料',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasConfig
                  ? '广播时会附带你保存的热点名称和密码，对方读取后可按提示加入你的热点。'
                  : '第一次使用 BLE + 热点模式，建议先到设置页填写热点名称和密码，再广播自己的房间。',
            ),
            if (_controller.hotspotSsid.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('热点名称：${_controller.hotspotSsid}'),
            ],
            if (_controller.hotspotNote.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text('备注：${_controller.hotspotNote}'),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _controller.openHotspotSettings,
                  icon: const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('打开热点设置'),
                ),
                OutlinedButton.icon(
                  onPressed: _controller.openWifiSettings,
                  icon: const Icon(Icons.wifi_rounded),
                  label: const Text('打开 Wi-Fi 设置'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryActionCard(NearbyTransportMode mode) {
    final scanning = _controller.nearbyRunning;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '发现与广播',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              mode == NearbyTransportMode.bleHotspot
                  ? '开始后会通过 BLE 扫描并广播房间。加入别人房间时，只同步热点资料并引导你进入系统 Wi-Fi。'
                  : '开始后会检查权限，并通过 Google Nearby 发现附近设备、广播本机房间。',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: scanning
                    ? _controller.stopNearby
                    : _controller.startNearby,
                icon: Icon(
                  scanning ? Icons.stop_circle_outlined : Icons.radar_rounded,
                ),
                label: Text(scanning ? '停止附近房间' : '开始附近房间'),
              ),
            ),
            if (_controller.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSection(NearbyTransportMode mode) {
    final rooms = _controller.roomEndpoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          mode == NearbyTransportMode.bleHotspot ? '附近热点房间' : '附近可加入房间',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (rooms.isEmpty)
          _buildEmptyState(mode)
        else
          for (final room in rooms) _buildRoomTile(room, mode),
      ],
    );
  }

  Widget _buildRoomTile(
    NearbyRoomEndpoint room,
    NearbyTransportMode currentMode,
  ) {
    final theme = Theme.of(context);
    final connecting = _controller.pendingJoinRoom?.userId == room.userId;
    final usingFallback = room.transportMode == NearbyTransportMode.bleHotspot;
    final accent = usingFallback ? Colors.teal : theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: room.isConnected
                      ? Colors.green
                      : accent.withValues(alpha: 0.14),
                  child: Icon(
                    usingFallback
                        ? Icons.wifi_tethering_rounded
                        : Icons.meeting_room_outlined,
                    color: room.isConnected ? Colors.white : accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        room.roomName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        room.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: connecting
                      ? null
                      : () => _controller.connectToRoom(room),
                  child: Text(connecting ? '连接中' : '加入'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildChip(
                  room.transportMode.label,
                  background: accent.withValues(alpha: 0.12),
                  foreground: accent,
                ),
                if ((room.discoveryMethod ?? '').isNotEmpty)
                  _buildChip(
                    room.discoveryMethod!,
                    background: theme.colorScheme.surfaceContainerHighest,
                    foreground: theme.colorScheme.onSurfaceVariant,
                  ),
                if (room.requiresManualHotspotStep)
                  _buildChip(
                    '需要手动切换热点',
                    background: Colors.orange.withValues(alpha: 0.12),
                    foreground: Colors.orange.shade900,
                  ),
                if (room.hasHotspotCredentials)
                  _buildChip(
                    '已带热点资料',
                    background: Colors.green.withValues(alpha: 0.12),
                    foreground: Colors.green.shade800,
                  ),
              ],
            ),
            if ((room.hotspotSsid ?? '').isNotEmpty ||
                (room.hotspotNote ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  [
                    if ((room.hotspotSsid ?? '').isNotEmpty)
                      '热点：${room.hotspotSsid}',
                    if ((room.hotspotNote ?? '').isNotEmpty)
                      '备注：${room.hotspotNote}',
                  ].join('  ·  '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (currentMode == NearbyTransportMode.bleHotspot && !usingFallback)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '当前设备处于 BLE + 热点模式；该房间来自 Google Nearby 通道，可能无法直接加入。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(NearbyTransportMode mode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Icon(
              mode == NearbyTransportMode.bleHotspot
                  ? Icons.bluetooth_searching_rounded
                  : Icons.radar_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              mode == NearbyTransportMode.bleHotspot
                  ? '还没有发现可接力的热点房间'
                  : '还没有发现附近房间',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              mode == NearbyTransportMode.bleHotspot
                  ? '确认双方都已开启蓝牙、定位，并让房主先进入附近房间开始广播。'
                  : '确认双方都已开启定位、蓝牙，并在此页点击“开始附近房间”。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    final logs = _controller.logs.take(30).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.terminal_rounded),
        title: const Text('调试日志'),
        subtitle: const Text('用于排查发现、配对和热点切换问题'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: <Widget>[
          if (logs.isEmpty)
            const Align(alignment: Alignment.centerLeft, child: Text('暂无日志'))
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF10151F),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: logs
                    .map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _envPill(String label, bool ok, {bool neutral = false}) {
    final background = ok
        ? Colors.green.withValues(alpha: 0.12)
        : neutral
        ? Colors.blue.withValues(alpha: 0.08)
        : Colors.red.withValues(alpha: 0.08);
    final foreground = ok
        ? Colors.green.shade700
        : neutral
        ? Colors.blue.shade700
        : Colors.red.shade700;
    final state = ok
        ? '已开启'
        : neutral
        ? '可选'
        : '未开启';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label：$state',
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildChip(
    String label, {
    required Color background,
    Color foreground = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
