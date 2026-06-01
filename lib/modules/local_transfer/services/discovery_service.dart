// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../model/transfer_device.dart';
import '../model/transfer_protocol_dto.dart';
import 'transfer_client.dart';

typedef LocalDeviceInfoProvider = TransferRegisterDto Function();
typedef DiscoveryDeviceCallback = Future<void> Function(TransferDevice device);
typedef DiscoveryLogCallback = void Function(String message);

class DiscoveryService {
  DiscoveryService({
    required TransferClient client,
    required LocalDeviceInfoProvider selfInfoProvider,
    required DiscoveryDeviceCallback onDeviceDiscovered,
    required DiscoveryLogCallback onLog,
  }) : _client = client,
       _selfInfoProvider = selfInfoProvider,
       _onDeviceDiscovered = onDeviceDiscovered,
       _onLog = onLog;

  static const int defaultPort = 53317;
  static const String multicastAddress = '224.0.0.167';
  static const MethodChannel _channel = MethodChannel(
    'course_helper/local_transfer/multicast',
  );

  final TransferClient _client;
  final LocalDeviceInfoProvider _selfInfoProvider;
  final DiscoveryDeviceCallback _onDeviceDiscovered;
  final DiscoveryLogCallback _onLog;

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  Timer? _announceTimer;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      await _channel.invokeMethod<void>('acquire');
    } catch (_) {
      _onLog('MulticastLock unavailable, continuing without it.');
    }

    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        defaultPort,
        reuseAddress: true,
        reusePort: true,
      );
      socket.multicastHops = 1;
      socket.broadcastEnabled = true;
      final interfaces = await _getIpv4Interfaces();
      final group = InternetAddress(multicastAddress);
      for (final NetworkInterface interface in interfaces) {
        try {
          socket.joinMulticast(group, interface);
        } catch (_) {
          // Continue on devices that reject one particular interface.
        }
      }
      _socket = socket;
      _socketSubscription = socket.listen(_handleSocketEvent);
      _announceTimer = Timer.periodic(
        const Duration(seconds: 18),
        (_) => sendAnnouncement(),
      );
      await sendAnnouncement();
      _onLog('Discovery started on UDP $multicastAddress:$defaultPort');
    } catch (error) {
      _running = false;
      _onLog('Failed to start discovery: $error');
      rethrow;
    }
  }

  Future<void> stop() async {
    _running = false;
    _announceTimer?.cancel();
    await _socketSubscription?.cancel();
    _socket?.close();
    _socket = null;
    try {
      await _channel.invokeMethod<void>('release');
    } catch (_) {
      // no-op
    }
  }

  Future<void> sendAnnouncement() async {
    final socket = _socket;
    if (!_running || socket == null) {
      return;
    }
    final payload = jsonEncode(
      _selfInfoProvider().toJson()..['announce'] = true,
    );
    socket.send(
      utf8.encode(payload),
      InternetAddress(multicastAddress),
      defaultPort,
    );
    _onLog('Sent UDP announcement.');
  }

  Future<void> scanLocalSubnets() async {
    final interfaces = await _getIpv4Interfaces();
    final self = _selfInfoProvider();
    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress address in interface.addresses) {
        if (!_isPrivateIpv4(address)) {
          continue;
        }
        final segments = address.address.split('.');
        if (segments.length != 4) {
          continue;
        }
        final base = '${segments[0]}.${segments[1]}.${segments[2]}';
        const int batchSize = 24;
        final futures = <Future<void>>[];
        for (int host = 1; host <= 254; host++) {
          final candidateIp = '$base.$host';
          if (candidateIp == address.address) {
            continue;
          }
          futures.add(_probeCandidate(candidateIp, self));
          if (futures.length >= batchSize) {
            await Future.wait(futures);
            futures.clear();
          }
        }
        if (futures.isNotEmpty) {
          await Future.wait(futures);
        }
      }
    }
  }

  Future<void> _probeCandidate(
    String candidateIp,
    TransferRegisterDto self,
  ) async {
    try {
      final device = await _client.register(
        ip: candidateIp,
        port: defaultPort,
        protocol: 'https',
        expectedFingerprint: null,
        request: self,
        discoveryMethod: 'http-scan',
      );
      if (device != null) {
        await _onDeviceDiscovered(device);
      }
      return;
    } catch (_) {
      // Fallback to plain HTTP probe.
    }

    try {
      final device = await _client.register(
        ip: candidateIp,
        port: defaultPort,
        protocol: 'http',
        expectedFingerprint: null,
        request: self,
        discoveryMethod: 'http-scan',
      );
      if (device != null) {
        await _onDeviceDiscovered(device);
      }
    } catch (_) {
      // Ignore dead hosts.
    }
  }

  Future<void> _handleSocketEvent(RawSocketEvent event) async {
    if (event != RawSocketEvent.read) {
      return;
    }
    final datagram = _socket?.receive();
    if (datagram == null) {
      return;
    }
    try {
      final payload = jsonDecode(utf8.decode(datagram.data));
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final dto = TransferRegisterDto.fromJson(payload);
      final self = _selfInfoProvider();
      if (dto.fingerprint.isEmpty || dto.fingerprint == self.fingerprint) {
        return;
      }

      final device = dto.toDevice(
        ip: datagram.address.address,
        discoveryMethod: 'udp',
      );
      await _onDeviceDiscovered(device);
      _onLog(
        'Discovered ${device.displayName} via UDP (${device.ip}:${device.port}).',
      );

      if (dto.announce == true) {
        try {
          final registered = await _client.register(
            ip: datagram.address.address,
            port: dto.port,
            protocol: dto.protocol,
            expectedFingerprint: dto.fingerprint,
            request: self,
            discoveryMethod: 'register',
          );
          if (registered != null) {
            await _onDeviceDiscovered(registered);
          }
        } catch (error) {
          _onLog('Register callback failed for ${device.ip}: $error');
        }
      }
    } catch (error) {
      _onLog('Failed to parse UDP payload: $error');
    }
  }

  Future<List<NetworkInterface>> _getIpv4Interfaces() async {
    return NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
  }

  bool _isPrivateIpv4(InternetAddress address) {
    final segments = address.address.split('.');
    if (segments.length != 4) {
      return false;
    }
    final first = int.tryParse(segments[0]) ?? -1;
    final second = int.tryParse(segments[1]) ?? -1;
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
}
