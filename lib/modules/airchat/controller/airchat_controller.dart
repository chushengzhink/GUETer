import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/nearby_room_models.dart';
import '../services/airchat_storage_service.dart';
import '../services/airchat_transport_adapter.dart';
import '../services/connection_service.dart';

class AirChatController extends ChangeNotifier {
  AirChatController._();

  static final AirChatController instance = AirChatController._();

  final AirChatStorageService _storage = AirChatStorageService.instance;
  final Map<String, NearbyRoomEndpoint> _roomEndpoints =
      <String, NearbyRoomEndpoint>{};
  final Set<String> _connectedUserIds = <String>{};
  final Set<String> _connectingUserIds = <String>{};
  final List<String> _logs = <String>[];
  final StreamController<NearbyJoinResult> _joinResultController =
      StreamController<NearbyJoinResult>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _deviceSubscription;
  StreamSubscription<Map<String, dynamic>>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  List<AirChatPermissionSnapshot> _permissionStatuses =
      const <AirChatPermissionSnapshot>[];
  NearbyEnvironmentStatus? _environmentStatus;
  AirChatStartupResult? _lastDiscoveryResult;
  AirChatStartupResult? _lastAdvertisingResult;
  NearbyRoomEndpoint? _pendingJoinRoom;
  NearbyRoomEndpoint? _currentJoinedRoom;

  bool _initialized = false;
  bool _subscriptionsBound = false;
  bool _discovering = false;
  bool _advertising = false;
  bool _isPreparing = false;
  String? _error;

  bool get initialized => _initialized;
  bool get discovering => _discovering;
  bool get advertising => _advertising;
  bool get nearbyRunning => _discovering || _advertising;
  bool get isPreparing => _isPreparing;
  String? get error => _error;
  String get userId => _storage.userId;
  String get displayName => _storage.displayName;
  String get hotspotSsid => _storage.hotspotSsid;
  String get hotspotPassword => _storage.hotspotPassword;
  String get hotspotNote => _storage.hotspotNote;
  NearbyEnvironmentStatus? get environmentStatus => _environmentStatus;
  AirChatStartupResult? get lastDiscoveryResult => _lastDiscoveryResult;
  AirChatStartupResult? get lastAdvertisingResult => _lastAdvertisingResult;
  NearbyRoomEndpoint? get pendingJoinRoom => _pendingJoinRoom;
  NearbyRoomEndpoint? get currentJoinedRoom => _currentJoinedRoom;
  Stream<NearbyJoinResult> get joinResults => _joinResultController.stream;

  List<String> get logs => List<String>.unmodifiable(_logs);
  List<AirChatPermissionSnapshot> get permissionStatuses =>
      List<AirChatPermissionSnapshot>.unmodifiable(_permissionStatuses);
  NearbyTransportMode get activeTransportMode =>
      _environmentStatus?.transportMode ?? NearbyTransportMode.unsupported;

  List<NearbyRoomEndpoint> get roomEndpoints {
    final rooms = _roomEndpoints.values.toList()
      ..sort((NearbyRoomEndpoint a, NearbyRoomEndpoint b) {
        if (a.isConnected != b.isConnected) {
          return a.isConnected ? -1 : 1;
        }
        return a.roomName.toLowerCase().compareTo(b.roomName.toLowerCase());
      });
    return List<NearbyRoomEndpoint>.unmodifiable(rooms);
  }

  List<String> get blockingIssues {
    final issues = <String>[];
    if (_permissionStatuses.isEmpty) {
      issues.add('尚未完成权限检查');
    } else {
      for (final AirChatPermissionSnapshot item in _permissionStatuses) {
        if (!item.isGranted) {
          issues.add('缺少权限：${item.label}');
        }
      }
    }

    final environment = _environmentStatus;
    if (environment == null) {
      issues.add('尚未读取系统环境');
      return issues;
    }
    switch (environment.transportMode) {
      case NearbyTransportMode.nearbyConnections:
        if (!environment.playServicesAvailable) {
          issues.add('Google Play 服务不可用');
        }
        break;
      case NearbyTransportMode.bleHotspot:
        if (!environment.bleAvailable) {
          issues.add('设备不支持 BLE 发现');
        }
        if (!environment.hotspotCapable) {
          issues.add('当前设备无法使用热点接力模式');
        }
        break;
      case NearbyTransportMode.unsupported:
        issues.add('当前设备不支持附近房间');
        break;
    }
    if (!environment.bluetoothEnabled) {
      issues.add('蓝牙未开启');
    }
    if (!environment.locationServicesEnabled) {
      issues.add('定位服务未开启');
    }
    return issues;
  }

  List<String> get advisoryMessages {
    final environment = _environmentStatus;
    if (environment == null) {
      return const <String>[];
    }
    final messages = <String>[];
    if (!environment.wifiEnabled) {
      messages.add('Wi-Fi 关闭不会阻止使用，但开启后通常能提高发现成功率。');
    }
    if (environment.transportMode == NearbyTransportMode.bleHotspot) {
      messages.add('当前设备无需 Google Play 服务，将使用 BLE 发现和手动热点接力；进房后请按提示加入房主热点。');
      if (hotspotSsid.trim().isEmpty || hotspotPassword.trim().isEmpty) {
        messages.add('你还没有填写热点名称和密码；仍可扫描别人房间，但广播自己的房间时对方可能拿不到热点资料。');
      }
    }
    return messages;
  }

  bool get hasAllPermissions =>
      _permissionStatuses.isNotEmpty &&
      _permissionStatuses.every(
        (AirChatPermissionSnapshot item) => item.isGranted,
      );

  bool get canStartNearby => blockingIssues.isEmpty;

  NearbyRoomEndpoint get localRoom {
    final name = displayName.trim().isEmpty
        ? 'Nearby User'
        : displayName.trim();
    final transportMode = activeTransportMode == NearbyTransportMode.unsupported
        ? NearbyTransportMode.nearbyConnections
        : activeTransportMode;
    return NearbyRoomEndpoint(
      userId: userId,
      name: name,
      roomId: 'nearby-room-$userId',
      roomName: '$name 的附近房间',
      roomType: transportMode == NearbyTransportMode.bleHotspot
          ? 'ble_hotspot_pairing'
          : 'nearby_pairing',
      hostUserId: userId,
      transportMode: transportMode,
      discoveryMethod: transportMode == NearbyTransportMode.bleHotspot
          ? 'ble'
          : 'nearby',
      hotspotSsid: hotspotSsid.trim().isEmpty ? null : hotspotSsid.trim(),
      hotspotPassword: hotspotPassword.trim().isEmpty
          ? null
          : hotspotPassword.trim(),
      hotspotNote: hotspotNote.trim().isEmpty ? null : hotspotNote.trim(),
      requiresManualHotspotStep: transportMode.usesManualHotspotStep,
      isConnected: false,
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _isPreparing = true;
    notifyListeners();
    await _storage.initialize();
    _bindStreams();
    _initialized = true;
    _isPreparing = false;
    if (!kIsWeb && Platform.isAndroid) {
      await refreshDiagnostics(notify: false);
      await refreshConnectionState(notify: false);
    }
    notifyListeners();
  }

  void _bindStreams() {
    if (_subscriptionsBound) {
      return;
    }
    _subscriptionsBound = true;
    _deviceSubscription = ConnectionService.discoveredDevicesStream.listen(
      _handleDiscoveryEvent,
      onError: (Object error) => _setError(error.toString()),
    );
    _connectionSubscription = ConnectionService.connectionEventsStream.listen(
      _handleConnectionEvent,
      onError: (Object error) => _setError(error.toString()),
    );
    _messageSubscription = ConnectionService.messageEventsStream.listen(
      _handleMessageEvent,
      onError: (Object error) => _setError(error.toString()),
    );
  }

  Future<void> prepareSession() async {
    await initialize();
    _clearError();
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _isPreparing = true;
    notifyListeners();
    try {
      await refreshDiagnostics(notify: false);
      await refreshConnectionState(notify: false);
    } finally {
      _isPreparing = false;
      notifyListeners();
    }
  }

  Future<void> teardownSession() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await stopNearby();
  }

  Future<void> handleAppResumed() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await refreshDiagnostics(notify: false);
    await refreshConnectionState(notify: false);
    notifyListeners();
  }

  Future<void> refreshConnectionState({bool notify = true}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      final connectedUsers = await ConnectionService.getConnectedUsers();
      final discoveredUsers = await ConnectionService.getDiscoveredUsers();

      _connectedUserIds
        ..clear()
        ..addAll(
          connectedUsers
              .map((Map<String, dynamic> item) => item['id'] as String?)
              .whereType<String>(),
        );
      _connectingUserIds.removeWhere(
        (String id) =>
            !_connectedUserIds.contains(id) && _pendingJoinRoom?.userId != id,
      );

      final merged = <String, NearbyRoomEndpoint>{};
      for (final Map<String, dynamic> item in discoveredUsers) {
        final endpoint = NearbyRoomEndpoint.fromMap(
          item,
        ).copyWith(isConnected: _connectedUserIds.contains(item['id']));
        if (endpoint.userId == userId) {
          continue;
        }
        merged[endpoint.userId] = endpoint;
      }
      for (final Map<String, dynamic> item in connectedUsers) {
        final endpoint = NearbyRoomEndpoint.fromMap(
          item,
        ).copyWith(isConnected: true);
        if (endpoint.userId == userId) {
          continue;
        }
        merged[endpoint.userId] = endpoint;
      }
      _roomEndpoints
        ..clear()
        ..addAll(merged);
      _log('Connection state refreshed.');
      if (notify) {
        notifyListeners();
      }
    } catch (error) {
      _setError('刷新连接状态失败：$error');
    }
  }

  Future<void> refreshDiagnostics({bool notify = true}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await refreshPermissionStatuses(notify: false);
    await refreshEnvironmentStatus(notify: false);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> refreshPermissionStatuses({bool notify = true}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      _permissionStatuses = await ConnectionService.getPermissionStatuses();
      _log(
        'Permissions: ${_permissionStatuses.map((item) => '${item.label}=${item.status.name}').join(', ')}',
      );
      if (notify) {
        notifyListeners();
      }
    } catch (error) {
      _setError('刷新权限状态失败：$error');
    }
  }

  Future<void> refreshEnvironmentStatus({bool notify = true}) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      _environmentStatus = await ConnectionService.getEnvironmentStatus();
      _discovering = _environmentStatus?.discoveryRunning ?? _discovering;
      _advertising = _environmentStatus?.advertisingRunning ?? _advertising;
      _log(
        'Environment: mode=${_environmentStatus?.transportMode.wireName}, '
        'bluetooth=${_environmentStatus?.bluetoothEnabled}, '
        'location=${_environmentStatus?.locationServicesEnabled}, '
        'wifi=${_environmentStatus?.wifiEnabled}, '
        'playServices=${_environmentStatus?.playServicesAvailable}, '
        'discovering=$_discovering, advertising=$_advertising',
      );
      if (notify) {
        notifyListeners();
      }
    } catch (error) {
      _setError('读取系统环境失败：$error');
    }
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await ConnectionService.ensurePermissions();
      _log('Permissions requested successfully.');
      await refreshDiagnostics();
    } catch (error) {
      await refreshDiagnostics();
      _setError('权限请求失败：$error');
    }
  }

  Future<void> recheckEnvironment() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _clearError();
    await refreshDiagnostics();
    await refreshConnectionState();
  }

  Future<void> openPermissionSettings() async {
    await ConnectionService.openPermissionSettings();
  }

  Future<void> openSystemSettings() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await ConnectionService.openSystemSettings();
  }

  Future<void> openHotspotSettings() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await ConnectionService.openHotspotSettings();
  }

  Future<void> openWifiSettings() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await ConnectionService.openWifiSettings();
  }

  Future<void> saveHotspotProfile({
    required String ssid,
    required String password,
    required String note,
  }) async {
    await _storage.saveHotspotProfile(
      ssid: ssid,
      password: password,
      note: note,
    );
    _log('Hotspot profile updated.');
    notifyListeners();
  }

  Future<void> startNearby() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _clearError();
    await initialize();
    await refreshDiagnostics(notify: false);
    if (!hasAllPermissions) {
      await requestPermissions();
      await refreshDiagnostics(notify: false);
    }
    if (!canStartNearby) {
      _setError('无法开始附近房间：${blockingIssues.join('；')}');
      return;
    }

    final mode = activeTransportMode;
    final adapter = _adapterForMode(mode);
    final discoveryResult = await _startDiscoveryInternal(adapter);
    final advertisingResult = await _startAdvertisingInternal(adapter);
    if (!discoveryResult.ok || !advertisingResult.ok) {
      final failures = <String>[
        if (!discoveryResult.ok) '发现失败：${discoveryResult.message}',
        if (!advertisingResult.ok) '广播失败：${advertisingResult.message}',
      ];
      _setError(failures.join('?'));
    }
    await refreshEnvironmentStatus(notify: false);
    await refreshConnectionState(notify: false);
    notifyListeners();
  }

  Future<void> stopNearby() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      final adapter = _adapterForMode(activeTransportMode);
      await adapter.stopDiscovery();
      await adapter.stopAdvertising();
    } catch (error) {
      _log('Stop nearby error: $error');
    }
    _discovering = false;
    _advertising = false;
    await refreshEnvironmentStatus(notify: false);
    notifyListeners();
  }

  Future<void> connectToRoom(NearbyRoomEndpoint endpoint) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _clearError();
    _pendingJoinRoom = endpoint;
    _connectingUserIds.add(endpoint.userId);
    notifyListeners();

    if (_connectedUserIds.contains(endpoint.userId) &&
        endpoint.transportMode == NearbyTransportMode.bleHotspot) {
      _emitFallbackJoinSuccess(
        endpoint.copyWith(isConnected: true),
        message: _buildHotspotReadyMessage(endpoint),
        action: 'transport_ready',
      );
      return;
    }

    if (_connectedUserIds.contains(endpoint.userId)) {
      await _sendJoinRoomRequest(endpoint);
      return;
    }

    try {
      await _adapterForMode(
        endpoint.transportMode,
      ).connectToDevice(endpoint.userId);
      _log('Connection requested for ${endpoint.userId}');
    } catch (error) {
      _connectingUserIds.remove(endpoint.userId);
      _pendingJoinRoom = null;
      _setError('连接附近房间失败：$error');
    }
  }

  Future<void> setDisplayName(String value) async {
    await _storage.setDisplayName(value);
    _log('Display name updated.');
    notifyListeners();
  }

  Future<AirChatStartupResult> _startDiscoveryInternal(
    AirChatTransportAdapter adapter,
  ) async {
    final result = await adapter.startDiscovery();
    _lastDiscoveryResult = result;
    _discovering = result.ok || result.alreadyRunning;
    _log(
      result.ok
          ? 'Discovery ready: ${result.message}'
          : 'Discovery failed: ${result.message}',
    );
    return result;
  }

  Future<AirChatStartupResult> _startAdvertisingInternal(
    AirChatTransportAdapter adapter,
  ) async {
    final room = localRoom.copyWith(transportMode: adapter.mode);
    final result = await adapter.startAdvertising(
      room: NearbyRoomAdvertisement(
        userId: room.userId,
        name: room.name,
        roomId: room.roomId,
        roomName: room.roomName,
        roomType: room.roomType,
        hostUserId: room.hostUserId,
        courseId: room.courseId,
        platform: room.platform,
        transportMode: room.transportMode,
        hotspotSsid: room.hotspotSsid,
        hotspotPassword: room.hotspotPassword,
        hotspotNote: room.hotspotNote,
      ),
    );
    _lastAdvertisingResult = result;
    _advertising = result.ok || result.alreadyRunning;
    _log(
      result.ok
          ? 'Advertising ready: ${result.message}'
          : 'Advertising failed: ${result.message}',
    );
    return result;
  }

  Future<void> _sendJoinRoomRequest(NearbyRoomEndpoint endpoint) async {
    if (endpoint.transportMode != NearbyTransportMode.nearbyConnections) {
      _emitFallbackJoinSuccess(
        endpoint.copyWith(isConnected: true),
        message: _buildHotspotReadyMessage(endpoint),
        action: 'transport_ready',
      );
      return;
    }

    _pendingJoinRoom = endpoint;
    try {
      await ConnectionService.sendControlMessage(
        userId: endpoint.userId,
        action: 'join_room',
        payload: <String, dynamic>{
          'roomId': endpoint.roomId,
          'roomName': endpoint.roomName,
          'roomType': endpoint.roomType,
          'hostUserId': endpoint.hostUserId,
          'courseId': endpoint.courseId,
          'platform': endpoint.platform,
          'transportMode': endpoint.transportMode.wireName,
          'message': 'Request to join nearby room.',
        },
      );
      _log('Join request sent for room ${endpoint.roomId}.');
      notifyListeners();
    } catch (error) {
      _connectingUserIds.remove(endpoint.userId);
      _pendingJoinRoom = null;
      _setError('发送入房请求失败：$error');
    }
  }

  void _handleDiscoveryEvent(Map<String, dynamic> event) {
    final type = event['type'] as String? ?? '';
    final endpoint = NearbyRoomEndpoint.fromMap(
      event,
    ).copyWith(isConnected: _connectedUserIds.contains(event['id']));
    if (endpoint.userId.isEmpty || endpoint.userId == userId) {
      return;
    }
    if (type == 'found') {
      _roomEndpoints[endpoint.userId] = endpoint;
      _log(
        'Found room: ${endpoint.roomName} (${endpoint.userId}) via ${endpoint.transportMode.label}',
      );
    } else if (type == 'lost') {
      _roomEndpoints.remove(endpoint.userId);
      _connectingUserIds.remove(endpoint.userId);
      if (_pendingJoinRoom?.userId == endpoint.userId) {
        _pendingJoinRoom = null;
      }
      _log('Lost room host: ${endpoint.userId}');
    }
    notifyListeners();
  }

  void _handleConnectionEvent(Map<String, dynamic> event) {
    final userId = event['id'] as String? ?? '';
    final type = event['type'] as String? ?? '';
    if (userId.isEmpty) {
      return;
    }

    final endpoint = NearbyRoomEndpoint.fromMap(event).copyWith(
      isConnected: type == 'connected' || _connectedUserIds.contains(userId),
    );
    if (endpoint.userId != this.userId) {
      _roomEndpoints[userId] = endpoint;
    }

    switch (type) {
      case 'connected':
        _connectedUserIds.add(userId);
        _connectingUserIds.remove(userId);
        _roomEndpoints[userId] = endpoint.copyWith(isConnected: true);
        if (_pendingJoinRoom?.userId == userId) {
          if (endpoint.transportMode == NearbyTransportMode.bleHotspot) {
            _emitFallbackJoinSuccess(
              endpoint.copyWith(isConnected: true),
              message:
                  event['statusText'] as String? ??
                  _buildHotspotReadyMessage(endpoint),
              action: 'transport_ready',
            );
          } else {
            unawaited(_sendJoinRoomRequest(_pendingJoinRoom!));
          }
        }
        break;
      case 'failed':
        _connectedUserIds.remove(userId);
        _connectingUserIds.remove(userId);
        if (_pendingJoinRoom?.userId == userId) {
          _joinResultController.add(
            NearbyJoinResult(
              ok: false,
              action: 'join_failed',
              endpoint: endpoint,
              message: event['statusText'] as String? ?? '连接失败',
            ),
          );
          _pendingJoinRoom = null;
        }
        break;
      case 'disconnected':
        _connectedUserIds.remove(userId);
        _connectingUserIds.remove(userId);
        _roomEndpoints[userId] = endpoint.copyWith(isConnected: false);
        if (_currentJoinedRoom?.userId == userId) {
          _joinResultController.add(
            NearbyJoinResult(
              ok: false,
              action: 'room_closed',
              endpoint: endpoint,
              message: '房主连接已断开',
            ),
          );
          _currentJoinedRoom = null;
        }
        break;
      case 'connecting':
        _connectingUserIds.add(userId);
        break;
    }

    final statusText = event['statusText'] as String?;
    _log(
      statusText == null
          ? 'Connection event: $type for $userId'
          : 'Connection event: $type for $userId - $statusText',
    );
    notifyListeners();
  }

  void _handleMessageEvent(Map<String, dynamic> event) {
    if (event['type'] == 'control') {
      _handleControlMessage(NearbyControlMessage.fromMap(event));
      return;
    }
    _log('Ignored legacy chat payload from ${event['from'] ?? 'unknown'}');
  }

  void _handleControlMessage(NearbyControlMessage control) {
    if (control.action.isEmpty) {
      return;
    }
    _log('Control message: ${control.action} from ${control.fromUserId}');
    switch (control.action) {
      case 'join_room':
        if (control.roomId == localRoom.roomId) {
          unawaited(
            ConnectionService.sendControlMessage(
              userId: control.fromUserId,
              action: 'join_ack',
              payload: <String, dynamic>{
                'roomId': localRoom.roomId,
                'roomName': localRoom.roomName,
                'roomType': localRoom.roomType,
                'hostUserId': localRoom.hostUserId,
                'courseId': localRoom.courseId,
                'platform': localRoom.platform,
                'transportMode': localRoom.transportMode.wireName,
                'message': 'Join request accepted.',
              },
            ),
          );
        }
        break;
      case 'join_ack':
        final endpoint = NearbyRoomEndpoint(
          userId: _pendingJoinRoom?.userId ?? control.fromUserId,
          name: control.fromName,
          roomId: control.roomId,
          roomName: control.roomName?.isNotEmpty == true
              ? control.roomName!
              : '附近房间',
          roomType: control.roomType?.isNotEmpty == true
              ? control.roomType!
              : 'nearby_pairing',
          hostUserId: control.hostUserId?.isNotEmpty == true
              ? control.hostUserId!
              : control.fromUserId,
          courseId: control.courseId,
          platform: control.platform,
          transportMode:
              control.transportMode ?? NearbyTransportMode.nearbyConnections,
          hotspotSsid: control.hotspotSsid,
          hotspotPassword: control.hotspotPassword,
          hotspotNote: control.hotspotNote,
          requiresManualHotspotStep:
              (control.transportMode ?? NearbyTransportMode.nearbyConnections)
                  .usesManualHotspotStep,
          isConnected: true,
        );
        _currentJoinedRoom = endpoint;
        _pendingJoinRoom = null;
        _connectingUserIds.remove(endpoint.userId);
        _joinResultController.add(
          NearbyJoinResult(
            ok: true,
            action: 'join_ack',
            endpoint: endpoint,
            message: control.message ?? '已加入附近房间',
          ),
        );
        break;
      case 'hotspot_credentials':
      case 'transport_ready':
        final fallbackEndpoint = NearbyRoomEndpoint(
          userId: _pendingJoinRoom?.userId ?? control.fromUserId,
          name: control.fromName,
          roomId: control.roomId.isEmpty
              ? (_pendingJoinRoom?.roomId ?? 'room-${control.fromUserId}')
              : control.roomId,
          roomName: control.roomName?.isNotEmpty == true
              ? control.roomName!
              : (_pendingJoinRoom?.roomName ?? '附近房间'),
          roomType: control.roomType?.isNotEmpty == true
              ? control.roomType!
              : 'ble_hotspot_pairing',
          hostUserId: control.hostUserId?.isNotEmpty == true
              ? control.hostUserId!
              : control.fromUserId,
          courseId: control.courseId,
          platform: control.platform,
          transportMode: NearbyTransportMode.bleHotspot,
          hotspotSsid: control.hotspotSsid,
          hotspotPassword: control.hotspotPassword,
          hotspotNote: control.hotspotNote,
          requiresManualHotspotStep: true,
          isConnected: true,
        );
        _emitFallbackJoinSuccess(
          fallbackEndpoint,
          message:
              control.message ?? _buildHotspotReadyMessage(fallbackEndpoint),
          action: control.action,
        );
        break;
      case 'room_closed':
        if (_currentJoinedRoom?.roomId == control.roomId) {
          final endpoint = _currentJoinedRoom!;
          _currentJoinedRoom = null;
          _joinResultController.add(
            NearbyJoinResult(
              ok: false,
              action: 'room_closed',
              endpoint: endpoint,
              message: control.message ?? '房主已关闭附近房间',
            ),
          );
        }
        break;
      case 'sync_sign_context':
        _log('sync_sign_context received for room ${control.roomId}');
        break;
    }
    notifyListeners();
  }

  void _emitFallbackJoinSuccess(
    NearbyRoomEndpoint endpoint, {
    required String message,
    required String action,
  }) {
    _currentJoinedRoom = endpoint;
    _pendingJoinRoom = null;
    _connectingUserIds.remove(endpoint.userId);
    _joinResultController.add(
      NearbyJoinResult(
        ok: true,
        action: action,
        endpoint: endpoint,
        message: message,
      ),
    );
  }

  String _buildHotspotReadyMessage(
    NearbyRoomEndpoint endpoint, {
    String? statusText,
  }) {
    final buffer = StringBuffer();
    if (statusText != null && statusText.trim().isNotEmpty) {
      buffer.writeln(statusText.trim());
    } else {
      buffer.writeln('已同步房主热点信息，下一步请加入房主热点。');
    }
    if (endpoint.hotspotSsid?.trim().isNotEmpty == true) {
      buffer.writeln('热点名称：${endpoint.hotspotSsid}');
    }
    if (endpoint.hotspotPassword?.trim().isNotEmpty == true) {
      buffer.writeln('热点密码：${endpoint.hotspotPassword}');
    }
    if (endpoint.hotspotNote?.trim().isNotEmpty == true) {
      buffer.writeln('备注：${endpoint.hotspotNote}');
    }
    return buffer.toString().trim();
  }

  AirChatTransportAdapter _adapterForMode(NearbyTransportMode mode) {
    switch (mode) {
      case NearbyTransportMode.bleHotspot:
        return const BleHotspotAdapter();
      case NearbyTransportMode.nearbyConnections:
      case NearbyTransportMode.unsupported:
        return const NearbyConnectionsAdapter();
    }
  }

  void _setError(String value) {
    _error = value;
    _log(value);
    notifyListeners();
  }

  void _clearError() {
    if (_error == null) {
      return;
    }
    _error = null;
    notifyListeners();
  }

  void _log(String line) {
    final timestamp = DateTime.now().toIso8601String();
    _logs.insert(0, '[$timestamp] $line');
    if (_logs.length > 120) {
      _logs.removeRange(120, _logs.length);
    }
  }

  @override
  void dispose() {
    unawaited(_deviceSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    unawaited(_joinResultController.close());
    super.dispose();
  }
}
