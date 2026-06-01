import '../models/nearby_room_models.dart';
import 'connection_service.dart';

abstract class AirChatTransportAdapter {
  const AirChatTransportAdapter(this.mode);

  final NearbyTransportMode mode;

  Future<AirChatStartupResult> startDiscovery();

  Future<AirChatStartupResult> startAdvertising({
    required NearbyRoomAdvertisement room,
  });

  Future<void> stopDiscovery();

  Future<void> stopAdvertising();

  Future<void> connectToDevice(String userId);
}

class NearbyConnectionsAdapter extends AirChatTransportAdapter {
  const NearbyConnectionsAdapter()
    : super(NearbyTransportMode.nearbyConnections);

  @override
  Future<AirChatStartupResult> startDiscovery() {
    return ConnectionService.startDiscovery(transportMode: mode);
  }

  @override
  Future<AirChatStartupResult> startAdvertising({
    required NearbyRoomAdvertisement room,
  }) {
    return ConnectionService.startAdvertising(room: room, transportMode: mode);
  }

  @override
  Future<void> stopDiscovery() {
    return ConnectionService.stopDiscovery(transportMode: mode);
  }

  @override
  Future<void> stopAdvertising() {
    return ConnectionService.stopAdvertising(transportMode: mode);
  }

  @override
  Future<void> connectToDevice(String userId) {
    return ConnectionService.connectToDevice(userId, transportMode: mode);
  }
}

class BleHotspotAdapter extends AirChatTransportAdapter {
  const BleHotspotAdapter() : super(NearbyTransportMode.bleHotspot);

  @override
  Future<AirChatStartupResult> startDiscovery() {
    return ConnectionService.startDiscovery(transportMode: mode);
  }

  @override
  Future<AirChatStartupResult> startAdvertising({
    required NearbyRoomAdvertisement room,
  }) {
    return ConnectionService.startAdvertising(room: room, transportMode: mode);
  }

  @override
  Future<void> stopDiscovery() {
    return ConnectionService.stopDiscovery(transportMode: mode);
  }

  @override
  Future<void> stopAdvertising() {
    return ConnectionService.stopAdvertising(transportMode: mode);
  }

  @override
  Future<void> connectToDevice(String userId) {
    return ConnectionService.connectToDevice(userId, transportMode: mode);
  }
}
