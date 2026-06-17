enum NearbyTransportMode { nearbyConnections, bleHotspot, unsupported }

extension NearbyTransportModeX on NearbyTransportMode {
  String get wireName => switch (this) {
    NearbyTransportMode.nearbyConnections => 'nearby_connections',
    NearbyTransportMode.bleHotspot => 'ble_hotspot',
    NearbyTransportMode.unsupported => 'unsupported',
  };

  String get label => switch (this) {
    NearbyTransportMode.nearbyConnections => 'Google Nearby',
    NearbyTransportMode.bleHotspot => 'BLE + Hotspot',
    NearbyTransportMode.unsupported => 'Unsupported',
  };

  bool get usesManualHotspotStep => this == NearbyTransportMode.bleHotspot;

  static NearbyTransportMode fromWireName(String? raw) {
    switch (raw?.trim()) {
      case 'nearby_connections':
        return NearbyTransportMode.nearbyConnections;
      case 'ble_hotspot':
        return NearbyTransportMode.bleHotspot;
      default:
        return NearbyTransportMode.unsupported;
    }
  }
}

class NearbyRoomEndpoint {
  const NearbyRoomEndpoint({
    required this.userId,
    required this.name,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.hostUserId,
    this.courseId,
    this.platform,
    this.transportMode = NearbyTransportMode.nearbyConnections,
    this.discoveryMethod,
    this.hotspotSsid,
    this.hotspotPassword,
    this.hotspotNote,
    this.requiresManualHotspotStep = false,
    this.isConnected = false,
  });

  final String userId;
  final String name;
  final String roomId;
  final String roomName;
  final String roomType;
  final String hostUserId;
  final String? courseId;
  final String? platform;
  final NearbyTransportMode transportMode;
  final String? discoveryMethod;
  final String? hotspotSsid;
  final String? hotspotPassword;
  final String? hotspotNote;
  final bool requiresManualHotspotStep;
  final bool isConnected;

  bool get hasRoom => roomId.trim().isNotEmpty;
  bool get hasHotspotCredentials =>
      (hotspotSsid?.trim().isNotEmpty == true) &&
      (hotspotPassword?.trim().isNotEmpty == true);

  NearbyRoomEndpoint copyWith({
    String? userId,
    String? name,
    String? roomId,
    String? roomName,
    String? roomType,
    String? hostUserId,
    String? courseId,
    String? platform,
    NearbyTransportMode? transportMode,
    String? discoveryMethod,
    String? hotspotSsid,
    String? hotspotPassword,
    String? hotspotNote,
    bool? requiresManualHotspotStep,
    bool? isConnected,
  }) {
    return NearbyRoomEndpoint(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      roomType: roomType ?? this.roomType,
      hostUserId: hostUserId ?? this.hostUserId,
      courseId: courseId ?? this.courseId,
      platform: platform ?? this.platform,
      transportMode: transportMode ?? this.transportMode,
      discoveryMethod: discoveryMethod ?? this.discoveryMethod,
      hotspotSsid: hotspotSsid ?? this.hotspotSsid,
      hotspotPassword: hotspotPassword ?? this.hotspotPassword,
      hotspotNote: hotspotNote ?? this.hotspotNote,
      requiresManualHotspotStep:
          requiresManualHotspotStep ?? this.requiresManualHotspotStep,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'name': name,
      'roomId': roomId,
      'roomName': roomName,
      'roomType': roomType,
      'hostUserId': hostUserId,
      'courseId': courseId,
      'platform': platform,
      'transportMode': transportMode.wireName,
      'discoveryMethod': discoveryMethod,
      'hotspotSsid': hotspotSsid,
      'hotspotPassword': hotspotPassword,
      'hotspotNote': hotspotNote,
      'requiresManualHotspotStep': requiresManualHotspotStep,
      'isConnected': isConnected,
    };
  }

  factory NearbyRoomEndpoint.fromMap(Map<String, dynamic> map) {
    final userId = (map['id'] as String?)?.trim().isNotEmpty == true
        ? (map['id'] as String).trim()
        : (map['userId'] as String?)?.trim() ?? '';
    final roomId = (map['roomId'] as String?)?.trim().isNotEmpty == true
        ? (map['roomId'] as String).trim()
        : 'room-$userId';
    final hostUserId = (map['hostUserId'] as String?)?.trim().isNotEmpty == true
        ? (map['hostUserId'] as String).trim()
        : userId;
    final resolvedName = (map['name'] as String?)?.trim().isNotEmpty == true
        ? (map['name'] as String).trim()
        : 'Nearby User';
    final transportMode = NearbyTransportModeX.fromWireName(
      map['transportMode'] as String?,
    );
    final roomName = (map['roomName'] as String?)?.trim().isNotEmpty == true
        ? (map['roomName'] as String).trim()
        : '$resolvedName 的附近房间';
    return NearbyRoomEndpoint(
      userId: userId,
      name: resolvedName,
      roomId: roomId,
      roomName: roomName,
      roomType: (map['roomType'] as String?)?.trim().isNotEmpty == true
          ? (map['roomType'] as String).trim()
          : 'nearby_pairing',
      hostUserId: hostUserId,
      courseId: (map['courseId'] as String?)?.trim(),
      platform: (map['platform'] as String?)?.trim(),
      transportMode: transportMode,
      discoveryMethod: (map['discoveryMethod'] as String?)?.trim(),
      hotspotSsid: (map['hotspotSsid'] as String?)?.trim(),
      hotspotPassword: (map['hotspotPassword'] as String?)?.trim(),
      hotspotNote: (map['hotspotNote'] as String?)?.trim(),
      requiresManualHotspotStep:
          map['requiresManualHotspotStep'] == true ||
          transportMode.usesManualHotspotStep,
      isConnected: map['isConnected'] == true,
    );
  }
}

class NearbyEnvironmentStatus {
  const NearbyEnvironmentStatus({
    required this.sdkInt,
    required this.locationServicesEnabled,
    required this.bluetoothEnabled,
    required this.wifiEnabled,
    required this.playServicesAvailable,
    required this.nearbySupported,
    required this.discoveryRunning,
    required this.advertisingRunning,
    required this.transportMode,
    required this.bleAvailable,
    required this.hotspotCapable,
    required this.requiresManualHotspotStep,
    this.lastNearbyOk,
    this.lastNearbyOperation,
    this.lastNearbyCode,
    this.lastNearbyMessage,
    this.serviceId,
  });

  final int sdkInt;
  final bool locationServicesEnabled;
  final bool bluetoothEnabled;
  final bool wifiEnabled;
  final bool playServicesAvailable;
  final bool nearbySupported;
  final bool discoveryRunning;
  final bool advertisingRunning;
  final NearbyTransportMode transportMode;
  final bool bleAvailable;
  final bool hotspotCapable;
  final bool requiresManualHotspotStep;
  final bool? lastNearbyOk;
  final String? lastNearbyOperation;
  final String? lastNearbyCode;
  final String? lastNearbyMessage;
  final String? serviceId;

  bool get hasFallbackPath =>
      transportMode == NearbyTransportMode.bleHotspot &&
      bleAvailable &&
      hotspotCapable;

  factory NearbyEnvironmentStatus.fromMap(Map<String, dynamic> map) {
    return NearbyEnvironmentStatus(
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      locationServicesEnabled: map['locationServicesEnabled'] == true,
      bluetoothEnabled: map['bluetoothEnabled'] == true,
      wifiEnabled: map['wifiEnabled'] == true,
      playServicesAvailable: map['playServicesAvailable'] == true,
      nearbySupported: map['nearbySupported'] != false,
      discoveryRunning: map['discoveryRunning'] == true,
      advertisingRunning: map['advertisingRunning'] == true,
      transportMode: NearbyTransportModeX.fromWireName(
        map['transportMode'] as String?,
      ),
      bleAvailable: map['bleAvailable'] == true,
      hotspotCapable: map['hotspotCapable'] == true,
      requiresManualHotspotStep: map['requiresManualHotspotStep'] == true,
      lastNearbyOk: map['lastNearbyOk'] as bool?,
      lastNearbyOperation: map['lastNearbyOperation'] as String?,
      lastNearbyCode: map['lastNearbyCode'] as String?,
      lastNearbyMessage: map['lastNearbyMessage'] as String?,
      serviceId: map['serviceId'] as String?,
    );
  }
}

class NearbyJoinResult {
  const NearbyJoinResult({
    required this.ok,
    required this.action,
    required this.endpoint,
    required this.message,
  });

  final bool ok;
  final String action;
  final NearbyRoomEndpoint endpoint;
  final String message;
}

class NearbyRoomAdvertisement {
  const NearbyRoomAdvertisement({
    required this.userId,
    required this.name,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.hostUserId,
    this.courseId,
    this.platform,
    this.transportMode = NearbyTransportMode.nearbyConnections,
    this.hotspotSsid,
    this.hotspotPassword,
    this.hotspotNote,
  });

  final String userId;
  final String name;
  final String roomId;
  final String roomName;
  final String roomType;
  final String hostUserId;
  final String? courseId;
  final String? platform;
  final NearbyTransportMode transportMode;
  final String? hotspotSsid;
  final String? hotspotPassword;
  final String? hotspotNote;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'name': name,
      'roomId': roomId,
      'roomName': roomName,
      'roomType': roomType,
      'hostUserId': hostUserId,
      'courseId': courseId,
      'platform': platform,
      'transportMode': transportMode.wireName,
      'hotspotSsid': hotspotSsid,
      'hotspotPassword': hotspotPassword,
      'hotspotNote': hotspotNote,
    };
  }
}

class NearbyControlMessage {
  const NearbyControlMessage({
    required this.fromUserId,
    required this.fromName,
    required this.action,
    required this.roomId,
    this.roomName,
    this.roomType,
    this.hostUserId,
    this.courseId,
    this.platform,
    this.message,
    this.transportMode,
    this.hotspotSsid,
    this.hotspotPassword,
    this.hotspotNote,
  });

  final String fromUserId;
  final String fromName;
  final String action;
  final String roomId;
  final String? roomName;
  final String? roomType;
  final String? hostUserId;
  final String? courseId;
  final String? platform;
  final String? message;
  final NearbyTransportMode? transportMode;
  final String? hotspotSsid;
  final String? hotspotPassword;
  final String? hotspotNote;

  factory NearbyControlMessage.fromMap(Map<String, dynamic> map) {
    return NearbyControlMessage(
      fromUserId: (map['from'] as String?)?.trim().isNotEmpty == true
          ? (map['from'] as String).trim()
          : (map['userId'] as String?)?.trim() ?? '',
      fromName: (map['name'] as String?)?.trim().isNotEmpty == true
          ? (map['name'] as String).trim()
          : 'Nearby User',
      action: (map['action'] as String?)?.trim() ?? '',
      roomId: (map['roomId'] as String?)?.trim() ?? '',
      roomName: (map['roomName'] as String?)?.trim(),
      roomType: (map['roomType'] as String?)?.trim(),
      hostUserId: (map['hostUserId'] as String?)?.trim(),
      courseId: (map['courseId'] as String?)?.trim(),
      platform: (map['platform'] as String?)?.trim(),
      message: (map['message'] as String?)?.trim(),
      transportMode: NearbyTransportModeX.fromWireName(
        map['transportMode'] as String?,
      ),
      hotspotSsid: (map['hotspotSsid'] as String?)?.trim(),
      hotspotPassword: (map['hotspotPassword'] as String?)?.trim(),
      hotspotNote: (map['hotspotNote'] as String?)?.trim(),
    );
  }
}
