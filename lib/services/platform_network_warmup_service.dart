import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../platform.dart';
import '../api/platform_dio_manager.dart';

class PlatformEndpointLatency {
  const PlatformEndpointLatency({
    required this.platform,
    required this.host,
    required this.checkedAt,
    required this.dnsElapsedMs,
    required this.tcpElapsedMs,
    required this.addresses,
    this.error,
  });

  final PlatformType platform;
  final String host;
  final DateTime checkedAt;
  final int dnsElapsedMs;
  final int tcpElapsedMs;
  final List<String> addresses;
  final String? error;

  bool get ok => error == null || error!.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': platform.name,
      'host': host,
      'checkedAt': checkedAt.toIso8601String(),
      'dnsElapsedMs': dnsElapsedMs,
      'tcpElapsedMs': tcpElapsedMs,
      'addresses': addresses,
      'error': error,
    };
  }

  static PlatformEndpointLatency? fromJson(Map<String, dynamic> json) {
    final platformName = json['platform']?.toString();
    PlatformType? platform;
    for (final item in PlatformType.values) {
      if (item.name == platformName) {
        platform = item;
        break;
      }
    }
    final checkedAt = DateTime.tryParse(json['checkedAt']?.toString() ?? '');
    if (platform == null || checkedAt == null) return null;
    final addressesRaw = json['addresses'];
    return PlatformEndpointLatency(
      platform: platform,
      host: json['host']?.toString() ?? '',
      checkedAt: checkedAt,
      dnsElapsedMs: (json['dnsElapsedMs'] as num?)?.toInt() ?? 0,
      tcpElapsedMs: (json['tcpElapsedMs'] as num?)?.toInt() ?? 0,
      addresses: addressesRaw is List
          ? addressesRaw.map((item) => item.toString()).toList()
          : const <String>[],
      error: json['error']?.toString(),
    );
  }
}

class PlatformEndpointLatencyStore {
  PlatformEndpointLatencyStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _key = 'platform_endpoint_latency_v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  Future<List<PlatformEndpointLatency>> load() async {
    final raw = (await _prefs).getStringList(_key) ?? const <String>[];
    final items = <PlatformEndpointLatency>[];
    for (final item in raw) {
      try {
        final decoded = Uri.splitQueryString(item);
        final addresses = decoded['addresses']?.split(',') ?? const <String>[];
        final latency = PlatformEndpointLatency.fromJson(<String, dynamic>{
          ...decoded,
          'dnsElapsedMs': int.tryParse(decoded['dnsElapsedMs'] ?? '') ?? 0,
          'tcpElapsedMs': int.tryParse(decoded['tcpElapsedMs'] ?? '') ?? 0,
          'addresses': addresses
              .where((address) => address.isNotEmpty)
              .toList(),
        });
        if (latency != null) items.add(latency);
      } catch (_) {
        // Ignore corrupted diagnostic entries.
      }
    }
    return items;
  }

  Future<void> upsert(PlatformEndpointLatency latency) async {
    final items = await load();
    final filtered = items
        .where(
          (item) =>
              item.platform != latency.platform || item.host != latency.host,
        )
        .toList();
    filtered.add(latency);
    final encoded = filtered.map((item) {
      final json = item.toJson();
      return Uri(
        queryParameters: <String, String>{
          'platform': json['platform'].toString(),
          'host': json['host'].toString(),
          'checkedAt': json['checkedAt'].toString(),
          'dnsElapsedMs': json['dnsElapsedMs'].toString(),
          'tcpElapsedMs': json['tcpElapsedMs'].toString(),
          'addresses': (json['addresses'] as List).join(','),
          if (json['error'] != null) 'error': json['error'].toString(),
        },
      ).query;
    }).toList();
    await (await _prefs).setStringList(_key, encoded);
  }
}

class PlatformNetworkWarmupService {
  PlatformNetworkWarmupService({
    PlatformEndpointLatencyStore? store,
    Duration timeout = const Duration(seconds: 2),
    Future<List<InternetAddress>> Function(String host)? lookup,
    Future<Socket> Function(String host, int port, {Duration? timeout})?
    socketConnect,
  }) : _store = store ?? PlatformEndpointLatencyStore(),
       _timeout = timeout,
       _lookup = lookup ?? InternetAddress.lookup,
       _socketConnect = socketConnect ?? Socket.connect;

  final PlatformEndpointLatencyStore _store;
  final Duration _timeout;
  final Future<List<InternetAddress>> Function(String host) _lookup;
  final Future<Socket> Function(String host, int port, {Duration? timeout})
  _socketConnect;

  Future<void> warmupDio({
    required PlatformType platform,
    required String userId,
  }) async {
    if (userId.isEmpty) return;
    await PlatformDioManager.getDioForUser(platform: platform, userId: userId);
  }

  Future<PlatformEndpointLatency> diagnoseEndpoint({
    required PlatformType platform,
    required String url,
  }) async {
    final uri = Uri.tryParse(url);
    final host = uri?.host;
    if (host == null || host.isEmpty) {
      final result = PlatformEndpointLatency(
        platform: platform,
        host: url,
        checkedAt: DateTime.now(),
        dnsElapsedMs: 0,
        tcpElapsedMs: 0,
        addresses: const <String>[],
        error: 'invalid url',
      );
      await _store.upsert(result);
      return result;
    }

    final dnsWatch = Stopwatch()..start();
    try {
      final addresses = await _lookup(host).timeout(_timeout);
      dnsWatch.stop();
      final tcpWatch = Stopwatch()..start();
      Socket? socket;
      try {
        socket = await _socketConnect(host, 443, timeout: _timeout);
        tcpWatch.stop();
      } finally {
        socket?.destroy();
      }
      final result = PlatformEndpointLatency(
        platform: platform,
        host: host,
        checkedAt: DateTime.now(),
        dnsElapsedMs: dnsWatch.elapsedMilliseconds,
        tcpElapsedMs: tcpWatch.elapsedMilliseconds,
        addresses: addresses.map((item) => item.address).toList(),
      );
      await _store.upsert(result);
      return result;
    } catch (error) {
      dnsWatch.stop();
      final result = PlatformEndpointLatency(
        platform: platform,
        host: host,
        checkedAt: DateTime.now(),
        dnsElapsedMs: dnsWatch.elapsedMilliseconds,
        tcpElapsedMs: 0,
        addresses: const <String>[],
        error: error.toString(),
      );
      await _store.upsert(result);
      return result;
    }
  }

  Future<List<PlatformEndpointLatency>> loadLastDiagnostics() {
    return _store.load();
  }
}
