import 'package:course_helper/modules/airchat/models/nearby_room_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NearbyRoomEndpoint', () {
    test('parses discovery payload with room metadata', () {
      final endpoint = NearbyRoomEndpoint.fromMap(<String, dynamic>{
        'id': 'user-1',
        'name': 'Alice',
        'roomId': 'room-1',
        'roomName': 'Alice 的附近配对房间',
        'roomType': 'nearby_pairing',
        'hostUserId': 'user-1',
        'courseId': 'course-9',
        'platform': 'ketangpai',
      });

      expect(endpoint.userId, 'user-1');
      expect(endpoint.name, 'Alice');
      expect(endpoint.roomId, 'room-1');
      expect(endpoint.roomType, 'nearby_pairing');
      expect(endpoint.platform, 'ketangpai');
      expect(endpoint.hasRoom, isTrue);
    });

    test('falls back to derived room fields when metadata is missing', () {
      final endpoint = NearbyRoomEndpoint.fromMap(<String, dynamic>{
        'id': 'user-2',
        'name': 'Bob',
      });

      expect(endpoint.hostUserId, 'user-2');
      expect(endpoint.roomType, 'nearby_pairing');
      expect(endpoint.roomName, 'Bob 的附近房间');
    });

    test('parses BLE hotspot fallback metadata', () {
      final endpoint = NearbyRoomEndpoint.fromMap(<String, dynamic>{
        'id': 'host-ble',
        'name': 'Host',
        'transportMode': 'ble_hotspot',
        'hotspotSsid': 'RoomHotspot',
        'hotspotPassword': '12345678',
        'requiresManualHotspotStep': true,
      });

      expect(endpoint.transportMode, NearbyTransportMode.bleHotspot);
      expect(endpoint.requiresManualHotspotStep, isTrue);
      expect(endpoint.hasHotspotCredentials, isTrue);
      expect(endpoint.roomName, 'Host 的附近房间');
    });
  });

  group('NearbyEnvironmentStatus', () {
    test('parses BLE hotspot fallback availability', () {
      final status = NearbyEnvironmentStatus.fromMap(<String, dynamic>{
        'sdkInt': 34,
        'locationServicesEnabled': true,
        'bluetoothEnabled': true,
        'wifiEnabled': true,
        'playServicesAvailable': false,
        'nearbySupported': true,
        'transportMode': 'ble_hotspot',
        'bleAvailable': true,
        'hotspotCapable': true,
        'requiresManualHotspotStep': true,
      });

      expect(status.transportMode, NearbyTransportMode.bleHotspot);
      expect(status.requiresManualHotspotStep, isTrue);
      expect(status.hasFallbackPath, isTrue);
      expect(status.playServicesAvailable, isFalse);
    });
  });

  group('NearbyControlMessage', () {
    test('parses join ack payload', () {
      final control = NearbyControlMessage.fromMap(<String, dynamic>{
        'type': 'control',
        'from': 'host-1',
        'name': 'Host',
        'action': 'join_ack',
        'roomId': 'room-ack',
        'roomName': 'Host 的附近配对房间',
        'roomType': 'nearby_pairing',
        'hostUserId': 'host-1',
        'message': 'Join request accepted.',
      });

      expect(control.fromUserId, 'host-1');
      expect(control.action, 'join_ack');
      expect(control.roomId, 'room-ack');
      expect(control.hostUserId, 'host-1');
      expect(control.message, 'Join request accepted.');
    });
  });
}
