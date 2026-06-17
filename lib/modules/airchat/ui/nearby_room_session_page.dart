import 'package:flutter/material.dart';

import '../models/nearby_room_models.dart';
import '../services/connection_service.dart';

class NearbyRoomSessionPage extends StatelessWidget {
  const NearbyRoomSessionPage({super.key, required this.result});

  final NearbyJoinResult result;

  @override
  Widget build(BuildContext context) {
    final room = result.endpoint;
    final theme = Theme.of(context);
    final usingFallback = room.transportMode == NearbyTransportMode.bleHotspot;
    return Scaffold(
      appBar: AppBar(title: const Text('附近房间')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    room.roomName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _chip(context, room.transportMode.label),
                      if ((room.discoveryMethod ?? '').isNotEmpty)
                        _chip(context, room.discoveryMethod!),
                      if (room.requiresManualHotspotStep)
                        _chip(context, '需要切换热点'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('房主：${room.name}'),
                  const SizedBox(height: 4),
                  Text('房间类型：${room.roomType}'),
                  if ((room.platform ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text('平台：${room.platform}'),
                  ],
                  if ((room.courseId ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text('课程 ID：${room.courseId}'),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    result.message,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (usingFallback)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '热点接力',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (room.hotspotSsid ?? '').isNotEmpty
                          ? '热点名称：${room.hotspotSsid}'
                          : '热点名称暂未同步',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (room.hotspotPassword ?? '').isNotEmpty
                          ? '热点密码：${room.hotspotPassword}'
                          : '热点密码暂未同步',
                    ),
                    if ((room.hotspotNote ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text('备注：${room.hotspotNote}'),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      '此模式不依赖 Google Play 服务。当前已完成附近发现和房间资料同步，下一步需要在系统 Wi-Fi 中手动加入房主热点。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: ConnectionService.openWifiSettings,
                          icon: const Icon(Icons.wifi_rounded),
                          label: const Text('打开 Wi-Fi 设置'),
                        ),
                        OutlinedButton.icon(
                          onPressed: ConnectionService.openHotspotSettings,
                          icon: const Icon(Icons.wifi_tethering_rounded),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '当前状态',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    usingFallback
                        ? '这一版在无 Play 服务设备上提供发现房间、同步热点资料和进房确认；聊天或文件传输仍需要后续扩展局域网通道。'
                        : '当前已通过 Google Nearby 完成附近发现、连接和进房确认。',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
