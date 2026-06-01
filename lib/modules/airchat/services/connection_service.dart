import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/nearby_room_models.dart';
import 'airchat_storage_service.dart';

class AirChatPermissionSnapshot {
  const AirChatPermissionSnapshot({
    required this.permission,
    required this.label,
    required this.status,
  });

  final Permission permission;
  final String label;
  final PermissionStatus status;

  bool get isGranted => status.isGranted;
  bool get isPermanentlyDenied => status.isPermanentlyDenied;
}

typedef AirChatEnvironmentStatus = NearbyEnvironmentStatus;

class AirChatStartupResult {
  const AirChatStartupResult({
    required this.ok,
    required this.operation,
    required this.code,
    required this.message,
    this.statusCode,
    this.alreadyRunning = false,
  });

  final bool ok;
  final String operation;
  final String code;
  final String message;
  final int? statusCode;
  final bool alreadyRunning;

  factory AirChatStartupResult.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const AirChatStartupResult(
        ok: false,
        operation: 'unknown',
        code: 'EMPTY_RESPONSE',
        message: 'Native layer returned an empty response.',
      );
    }
    return AirChatStartupResult(
      ok: map['ok'] == true,
      operation: map['operation'] as String? ?? 'unknown',
      code: map['code'] as String? ?? 'UNKNOWN',
      message: map['message'] as String? ?? 'Unknown Nearby result.',
      statusCode: (map['statusCode'] as num?)?.toInt(),
      alreadyRunning: map['alreadyRunning'] == true,
    );
  }
}

class ConnectionService {
  static const MethodChannel _channel = MethodChannel('airchat/connection');
  static const EventChannel _discoveryChannel = EventChannel(
    'airchat/discoveryEvents',
  );
  static const EventChannel _messageChannel = EventChannel(
    'airchat/messageEvents',
  );
  static const EventChannel _connectionChannel = EventChannel(
    'airchat/connectionEvents',
  );
  static const EventChannel _fileChannel = EventChannel('airchat/fileEvents');
  static const EventChannel _fileProgressChannel = EventChannel(
    'airchat/fileTransferProgressEvents',
  );

  static bool _requestingPermissions = false;

  static Stream<Map<String, dynamic>> get discoveredDevicesStream =>
      _discoveryChannel.receiveBroadcastStream().map(_castEvent);

  static Stream<Map<String, dynamic>> get messageEventsStream =>
      _messageChannel.receiveBroadcastStream().map(_castEvent);

  static Stream<Map<String, dynamic>> get connectionEventsStream =>
      _connectionChannel.receiveBroadcastStream().map(_castEvent);

  static Stream<Map<String, dynamic>> get fileEventsStream =>
      _fileChannel.receiveBroadcastStream().map(_castEvent);

  static Stream<Map<String, dynamic>> get fileTransferProgressStream =>
      _fileProgressChannel.receiveBroadcastStream().map(_castEvent);

  static Map<String, dynamic> _castEvent(dynamic event) {
    return Map<String, dynamic>.from(event as Map);
  }

  static Future<void> _ensureSupported() async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('AirChat Nearby is only supported on Android.');
    }
  }

  static List<(Permission, String)> _requiredPermissionsForSdk(int sdkInt) {
    if (sdkInt >= 33) {
      return const <(Permission, String)>[
        (Permission.locationWhenInUse, '位置'),
        (Permission.bluetoothScan, '蓝牙扫描'),
        (Permission.bluetoothAdvertise, '蓝牙广播'),
        (Permission.bluetoothConnect, '蓝牙连接'),
        (Permission.nearbyWifiDevices, 'Nearby Wi-Fi Devices'),
      ];
    }
    if (sdkInt >= 31) {
      return const <(Permission, String)>[
        (Permission.locationWhenInUse, '位置'),
        (Permission.bluetoothScan, '蓝牙扫描'),
        (Permission.bluetoothAdvertise, '蓝牙广播'),
        (Permission.bluetoothConnect, '蓝牙连接'),
      ];
    }
    return const <(Permission, String)>[(Permission.locationWhenInUse, '位置')];
  }

  static Future<NearbyEnvironmentStatus> getEnvironmentStatus() async {
    await _ensureSupported();
    final result = await _channel.invokeMethod<dynamic>('getEnvironmentStatus');
    final map = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return NearbyEnvironmentStatus.fromMap(map);
  }

  static Future<void> ensurePermissions() async {
    await _ensureSupported();
    if (_requestingPermissions) {
      return;
    }
    _requestingPermissions = true;
    try {
      final environment = await getEnvironmentStatus();
      for (final (Permission permission, String label)
          in _requiredPermissionsForSdk(environment.sdkInt)) {
        final status = await permission.status;
        if (status.isGranted) {
          continue;
        }
        final result = await permission.request();
        if (!result.isGranted) {
          throw Exception('Required permission denied: $label');
        }
      }
    } finally {
      _requestingPermissions = false;
    }
  }

  static Future<List<AirChatPermissionSnapshot>> getPermissionStatuses() async {
    await _ensureSupported();
    final environment = await getEnvironmentStatus();
    final result = <AirChatPermissionSnapshot>[];
    for (final (Permission permission, String label)
        in _requiredPermissionsForSdk(environment.sdkInt)) {
      result.add(
        AirChatPermissionSnapshot(
          permission: permission,
          label: label,
          status: await permission.status,
        ),
      );
    }
    return result;
  }

  static Future<void> openPermissionSettings() async {
    await openAppSettings();
  }

  static Future<void> openSystemSettings() async {
    await _ensureSupported();
    await _channel.invokeMethod<void>('openSystemSettings');
  }

  static Future<void> openHotspotSettings() async {
    await _ensureSupported();
    await _channel.invokeMethod<void>('openHotspotSettings');
  }

  static Future<void> openWifiSettings() async {
    await _ensureSupported();
    await _channel.invokeMethod<void>('openWifiSettings');
  }

  static Future<AirChatStartupResult> startDiscovery({
    required NearbyTransportMode transportMode,
  }) async {
    await _ensureSupported();
    final storage = AirChatStorageService.instance;
    final result = await _channel
        .invokeMethod<dynamic>('startDiscovery', <String, dynamic>{
          'userId': storage.userId,
          'name': storage.displayName,
          'transportMode': transportMode.wireName,
        });
    final map = result is Map ? Map<String, dynamic>.from(result) : null;
    return AirChatStartupResult.fromMap(map);
  }

  static Future<void> stopDiscovery({
    NearbyTransportMode? transportMode,
  }) async {
    await _ensureSupported();
    await _channel.invokeMethod<void>('stopDiscovery', <String, dynamic>{
      if (transportMode != null) 'transportMode': transportMode.wireName,
    });
  }

  static Future<AirChatStartupResult> startAdvertising({
    NearbyRoomAdvertisement? room,
    required NearbyTransportMode transportMode,
  }) async {
    await _ensureSupported();
    final storage = AirChatStorageService.instance;
    final payload = <String, dynamic>{
      'name': storage.displayName,
      'userId': storage.userId,
      'roomId': room?.roomId,
      'roomName': room?.roomName,
      'roomType': room?.roomType,
      'hostUserId': room?.hostUserId,
      'courseId': room?.courseId,
      'platform': room?.platform,
      'transportMode': room?.transportMode.wireName,
      'hotspotSsid': room?.hotspotSsid,
      'hotspotPassword': room?.hotspotPassword,
      'hotspotNote': room?.hotspotNote,
    }..removeWhere((Object key, Object? value) => value == null);
    final endpointInfo = jsonEncode(payload);
    final result = await _channel.invokeMethod<dynamic>(
      'startAdvertising',
      <String, dynamic>{
        'endpointInfo': endpointInfo,
        'transportMode': transportMode.wireName,
      },
    );
    final map = result is Map ? Map<String, dynamic>.from(result) : null;
    return AirChatStartupResult.fromMap(map);
  }

  static Future<void> stopAdvertising({
    NearbyTransportMode? transportMode,
  }) async {
    await _ensureSupported();
    await _channel.invokeMethod<void>('stopAdvertising', <String, dynamic>{
      if (transportMode != null) 'transportMode': transportMode.wireName,
    });
  }

  static Future<void> connectToDevice(
    String userId, {
    required NearbyTransportMode transportMode,
  }) async {
    await _ensureSupported();
    await _channel.invokeMethod<void>('connectToDevice', <String, dynamic>{
      'userId': userId,
      'transportMode': transportMode.wireName,
    });
  }

  static Future<int> sendMessage(String userId, String message) async {
    await _ensureSupported();
    final result = await _channel.invokeMethod<dynamic>(
      'sendMessage',
      <String, dynamic>{'userId': userId, 'message': message},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  static Future<int> sendControlMessage({
    required String userId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    await _ensureSupported();
    final result = await _channel.invokeMethod<dynamic>(
      'sendControlMessage',
      <String, dynamic>{'userId': userId, 'action': action, 'payload': payload},
    );
    return (result as num?)?.toInt() ?? 0;
  }

  static Future<int> sendFile(
    String userId,
    String filePath,
    String fileName,
  ) async {
    await _ensureSupported();
    final result = await _channel.invokeMethod<dynamic>(
      'sendFile',
      <String, dynamic>{
        'userId': userId,
        'filePath': filePath,
        'fileName': fileName,
      },
    );
    return (result as num?)?.toInt() ?? 0;
  }

  static Future<String?> getEndpointIdForUserId(String userId) async {
    await _ensureSupported();
    final result = await _channel.invokeMethod<dynamic>(
      'getEndpointIdForUserId',
      <String, dynamic>{'userId': userId},
    );
    return result as String?;
  }

  static Future<List<Map<String, dynamic>>> getConnectedUsers() async {
    await _ensureSupported();
    final result = await _channel.invokeMethod<dynamic>('getConnectedUsers');
    if (result is! List) {
      return <Map<String, dynamic>>[];
    }
    return result
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getDiscoveredUsers() async {
    await _ensureSupported();
    final result = await _channel.invokeMethod<dynamic>('getDiscoveredUsers');
    if (result is! List) {
      return <Map<String, dynamic>>[];
    }
    return result
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
