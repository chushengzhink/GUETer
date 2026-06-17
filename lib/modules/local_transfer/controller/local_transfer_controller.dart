// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/gueter_storage_service.dart';
import '../local_transfer_config.dart';
import '../local_transfer_module.dart';
import '../model/transfer_device.dart';
import '../model/transfer_file_models.dart';
import '../model/transfer_protocol_dto.dart';
import '../model/transfer_session.dart';
import '../model/transfer_source_file.dart';
import '../services/certificate_service.dart';
import '../services/discovery_service.dart';
import '../services/permission_service.dart';
import '../services/transfer_client.dart';
import '../services/transfer_server.dart';
import '../ui/receive_request_dialog.dart';
import '../ui/widgets/device_name_dialog.dart';

const List<String> guetCommonUnicastCidrs = <String>[
  '10.33.0.0/22',
  '10.38.0.0/22',
  '10.39.0.0/22',
];

String buildSuggestedLocalDeviceName({
  required String fallbackAlias,
  String? brand,
  String? model,
}) {
  final normalizedFallback = fallbackAlias.trim().isEmpty
      ? 'GUETer'
      : fallbackAlias.trim();
  final normalizedBrand = (brand ?? '').trim();
  final normalizedModel = (model ?? '').trim();
  if (normalizedModel.isEmpty ||
      _isGenericDeviceLabel(normalizedModel.toLowerCase())) {
    return normalizedFallback;
  }
  if (normalizedBrand.isEmpty ||
      _isGenericDeviceLabel(normalizedBrand.toLowerCase())) {
    return normalizedModel;
  }
  if (normalizedModel.toLowerCase().startsWith(normalizedBrand.toLowerCase())) {
    return normalizedModel;
  }
  return '$normalizedBrand $normalizedModel';
}

bool _isGenericDeviceLabel(String value) {
  return value == 'android' ||
      value == 'ios' ||
      value == 'windows' ||
      value == 'linux' ||
      value == 'macos';
}

String inferLocalUnicastCidr(
  String ip, {
  List<String> preferredCidrs = guetCommonUnicastCidrs,
}) {
  for (final String cidr in preferredCidrs) {
    if (cidrContainsIp(cidr, ip)) {
      return cidr;
    }
  }
  final segments = ip.split('.');
  if (segments.length != 4) {
    throw ArgumentError.value(ip, 'ip', 'Invalid IPv4 address.');
  }
  return '${segments[0]}.${segments[1]}.${segments[2]}.0/24';
}

List<String> buildUnicastCandidateIps({
  required List<String> localIps,
  List<String> staticCidrs = guetCommonUnicastCidrs,
}) {
  final excludedIps = localIps.toSet();
  final candidates = <String>{};
  for (final String localIp in localIps) {
    candidates.addAll(
      expandCidrHosts(
        inferLocalUnicastCidr(localIp, preferredCidrs: staticCidrs),
        excludedIps: excludedIps,
      ),
    );
  }
  for (final String cidr in staticCidrs) {
    candidates.addAll(expandCidrHosts(cidr, excludedIps: excludedIps));
  }
  final sorted = candidates.toList()..sort(compareIpv4Strings);
  return sorted;
}

List<String> expandCidrHosts(
  String cidr, {
  Set<String> excludedIps = const <String>{},
}) {
  final parts = cidr.split('/');
  if (parts.length != 2) {
    throw ArgumentError.value(cidr, 'cidr', 'Invalid CIDR notation.');
  }
  final prefix = int.parse(parts[1]);
  final network = ipv4ToInt(parts[0]);
  final hostBits = 32 - prefix;
  if (hostBits <= 0) {
    return excludedIps.contains(parts[0]) ? <String>[] : <String>[parts[0]];
  }
  final networkAddress = network & _prefixMask(prefix);
  final broadcastAddress = networkAddress | ((1 << hostBits) - 1);
  if (broadcastAddress - networkAddress <= 1) {
    return <String>[];
  }
  final hosts = <String>[];
  for (
    int current = networkAddress + 1;
    current < broadcastAddress;
    current++
  ) {
    final ip = intToIpv4(current);
    if (!excludedIps.contains(ip)) {
      hosts.add(ip);
    }
  }
  return hosts;
}

bool cidrContainsIp(String cidr, String ip) {
  final parts = cidr.split('/');
  if (parts.length != 2) {
    return false;
  }
  final prefix = int.tryParse(parts[1]);
  if (prefix == null) {
    return false;
  }
  final mask = _prefixMask(prefix);
  return (ipv4ToInt(parts[0]) & mask) == (ipv4ToInt(ip) & mask);
}

int compareIpv4Strings(String left, String right) {
  return ipv4ToInt(left).compareTo(ipv4ToInt(right));
}

int ipv4ToInt(String ip) {
  final segments = ip.split('.');
  if (segments.length != 4) {
    throw ArgumentError.value(ip, 'ip', 'Invalid IPv4 address.');
  }
  var value = 0;
  for (final String segment in segments) {
    final parsed = int.parse(segment);
    value = (value << 8) | parsed;
  }
  return value;
}

String intToIpv4(int value) {
  return '${(value >> 24) & 0xFF}.'
      '${(value >> 16) & 0xFF}.'
      '${(value >> 8) & 0xFF}.'
      '${value & 0xFF}';
}

int _prefixMask(int prefix) {
  if (prefix <= 0) {
    return 0;
  }
  if (prefix >= 32) {
    return 0xFFFFFFFF;
  }
  return (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
}

class LocalTransferController extends ChangeNotifier {
  LocalTransferController._();

  static final LocalTransferController instance = LocalTransferController._();
  static const String localDeviceNamePreferenceKey =
      'local_transfer_device_name';

  final PermissionService _permissionService = PermissionService();
  final CertificateService _certificateService = CertificateService();
  final Connectivity _connectivity = Connectivity();
  late final TransferClient _transferClient = TransferClient(
    certificateService: _certificateService,
  );

  DiscoveryService? _discoveryService;
  TransferServer? _transferServer;
  LocalTransferConfig? _config;
  LocalTransferSecurityContext? _securityContext;
  bool _initialized = false;
  bool _initializing = false;
  bool _discoveryRunning = false;
  String? _saveDirectoryPath;
  int _serverPort = 53317;
  String? _localDeviceName;
  String? _suggestedLocalDeviceName;
  String? _resolvedDeviceModel;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ConnectivityResult> _lastConnectivityResults = <ConnectivityResult>[];
  String? _lastWifiSignature;
  bool _refreshingDiscovery = false;
  bool _unicastScanning = false;

  final Map<String, TransferDevice> _devicesById = <String, TransferDevice>{};
  final List<TransferSession> _sessions = <TransferSession>[];
  final List<String> _logs = <String>[];

  List<TransferDevice> get devices {
    final list = _devicesById.values.toList()
      ..sort((TransferDevice a, TransferDevice b) {
        return b.lastSeen.compareTo(a.lastSeen);
      });
    return list;
  }

  List<TransferSession> get sessions =>
      List<TransferSession>.unmodifiable(_sessions.reversed);

  List<String> get logs => List<String>.unmodifiable(_logs.reversed);

  bool get initialized => _initialized;
  bool get initializing => _initializing;
  bool get discoveryRunning => _discoveryRunning;
  String get protocol => (_config?.enableHttps ?? true) ? 'https' : 'http';
  int get serverPort => _serverPort;
  String? get saveDirectoryPath => _saveDirectoryPath;
  String get fingerprint => _securityContext?.certificateHash ?? '';
  String get localDeviceName => _localDeviceName?.trim().isNotEmpty == true
      ? _localDeviceName!.trim()
      : (_config?.appAlias ?? 'GUETer');
  String get suggestedLocalDeviceName =>
      _suggestedLocalDeviceName?.trim().isNotEmpty == true
      ? _suggestedLocalDeviceName!.trim()
      : (_config?.appAlias ?? 'GUETer');
  bool get hasConfiguredLocalDeviceName =>
      _localDeviceName?.trim().isNotEmpty == true;
  bool get unicastScanning => _unicastScanning;
  bool get isScanningNearbySubnets => _unicastScanning;

  Future<void> initialize(LocalTransferConfig config) async {
    if (_initialized || _initializing) {
      return;
    }
    _initializing = true;
    notifyListeners();

    try {
      _config = config;
      await loadLocalDeviceName();
      _resolvedDeviceModel = await _resolveDeviceModel();
      _suggestedLocalDeviceName = buildSuggestedLocalDeviceName(
        fallbackAlias: config.appAlias,
        brand: await _resolveDeviceBrand(),
        model: _resolvedDeviceModel,
      );
      _securityContext = await _certificateService.ensureSecurityContext();
      _saveDirectoryPath = await _resolveSaveDirectory(config);
      _transferServer = TransferServer(
        securityContext: _securityContext!,
        saveDirectoryPath: _saveDirectoryPath!,
        enableHttps: config.enableHttps,
        onDeviceDiscovered: _registerDevice,
        onIncomingSession: _handleIncomingSession,
        onSessionChanged: _upsertSession,
        onCancelSendingSession: _cancelSendingSessionFromRemote,
        onLog: log,
        selfInfoProvider: _buildSelfInfo,
      );
      _serverPort = await _transferServer!.start();
      _discoveryService = DiscoveryService(
        client: _transferClient,
        selfInfoProvider: _buildSelfInfo,
        onDeviceDiscovered: _registerDevice,
        onLog: log,
      );
      await _startConnectivityMonitoring();
      _initialized = true;
      log('Local transfer initialized. Fingerprint: $fingerprint');
      if (config.autoStartDiscovery && hasConfiguredLocalDeviceName) {
        await startDiscovery();
      } else if (!hasConfiguredLocalDeviceName) {
        log('Waiting for local device name before discovery starts.');
      }
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> startDiscovery() async {
    final discovery = _discoveryService;
    if (!_initialized || discovery == null || _discoveryRunning) {
      return;
    }
    if (!hasConfiguredLocalDeviceName) {
      log('Discovery skipped because local device name is not configured yet.');
      return;
    }
    await discovery.start();
    _discoveryRunning = true;
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    final discovery = _discoveryService;
    if (discovery == null || !_discoveryRunning) {
      return;
    }
    await discovery.stop();
    _discoveryRunning = false;
    notifyListeners();
  }

  Future<void> refreshDiscovery() async {
    if (!hasConfiguredLocalDeviceName) {
      return;
    }
    await _discoveryService?.sendAnnouncement();
  }

  Future<void> refreshDiscoveryWithFallback() async {
    if (!hasConfiguredLocalDeviceName || _refreshingDiscovery) {
      return;
    }

    _refreshingDiscovery = true;
    notifyListeners();

    final initialDeviceCount = _devicesById.length;
    try {
      if (_discoveryRunning) {
        await refreshDiscovery();
      } else {
        await startDiscovery();
      }

      await Future<void>.delayed(const Duration(seconds: 3));
      if (_devicesById.isNotEmpty || _devicesById.length > initialDeviceCount) {
        return;
      }
      if (_config?.enableHttpSubnetFallback != true) {
        return;
      }

      _unicastScanning = true;
      notifyListeners();
      log('No devices found via UDP in 3 seconds. Starting unicast scan.');
      await unicastScan();
    } finally {
      _unicastScanning = false;
      _refreshingDiscovery = false;
      notifyListeners();
    }
  }

  Future<void> unicastScan() async {
    if (!hasConfiguredLocalDeviceName) {
      return;
    }
    final localIps = await _localPrivateIpv4s();
    if (localIps.isEmpty) {
      log('No private IPv4 address available for unicast scan.');
      return;
    }

    final candidates = buildUnicastCandidateIps(localIps: localIps);
    if (candidates.isEmpty) {
      log('No candidate IPs generated for unicast scan.');
      return;
    }

    log('Scanning ${candidates.length} nearby IPs via unicast.');
    final selfInfo = _buildSelfInfo();
    const int concurrency = 50;
    final batch = <Future<void>>[];
    for (final String candidateIp in candidates) {
      batch.add(_probeUnicastCandidate(candidateIp, selfInfo));
      if (batch.length >= concurrency) {
        await Future.wait(batch);
        batch.clear();
      }
    }
    if (batch.isNotEmpty) {
      await Future.wait(batch);
    }
  }

  Future<void> loadLocalDeviceName() async {
    final preferences = await SharedPreferences.getInstance();
    final savedName =
        preferences.getString(localDeviceNamePreferenceKey)?.trim() ?? '';
    _localDeviceName = savedName.isEmpty ? null : savedName;
    notifyListeners();
  }

  Future<void> saveLocalDeviceName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Device name cannot be empty.');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(localDeviceNamePreferenceKey, trimmed);
    _localDeviceName = trimmed;
    notifyListeners();
    log('Local device name updated to "$trimmed".');
    if (_discoveryRunning) {
      await refreshDiscovery();
    }
  }

  Future<bool> ensureLocalDeviceName(BuildContext context) async {
    if (hasConfiguredLocalDeviceName) {
      return true;
    }
    final result = await showDeviceNameDialog(
      context,
      initialValue: suggestedLocalDeviceName,
      allowCancel: false,
    );
    if (result == null) {
      return false;
    }
    await saveLocalDeviceName(result);
    return true;
  }

  Future<void> ensurePickerPermissions() {
    return _permissionService.ensurePickerPermissions();
  }

  Future<List<TransferSourceFile>> pickFiles() async {
    await ensurePickerPermissions();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return <TransferSourceFile>[];
    }
    final files = <TransferSourceFile>[];
    for (final PlatformFile file in result.files) {
      files.add(await TransferSourceFile.fromPlatformFile(file));
    }
    return files;
  }

  Future<void> sendFiles(
    List<TransferSourceFile> files,
    TransferDevice target,
  ) {
    return sendFilesWithSource(files, target);
  }

  Future<void> sendFilesWithSource(
    List<TransferSourceFile> files,
    TransferDevice target, {
    String? sourceLabel,
  }) async {
    if (files.isEmpty) {
      return;
    }
    final sessionId = _newId();
    final descriptors = <String, TransferFileDescriptor>{};
    final entries = <String, TransferSessionEntry>{};
    for (final TransferSourceFile sourceFile in files) {
      final fileId = _newId();
      final descriptor = await sourceFile.toDescriptor(fileId);
      descriptors[fileId] = descriptor;
      entries[fileId] = TransferSessionEntry(
        descriptor: descriptor,
        sourceFile: sourceFile,
        status: TransferFileStatus.queued,
        token: null,
        bytesTransferred: 0,
        outputPath: null,
        errorMessage: null,
      );
    }

    final session = TransferSession(
      localSessionId: sessionId,
      remoteSessionId: null,
      direction: TransferSessionDirection.sending,
      device: target,
      status: TransferSessionStatus.waiting,
      entries: entries,
      message: null,
      errorMessage: null,
      createdAt: DateTime.now(),
      startedAt: null,
      finishedAt: null,
      sourceLabel: sourceLabel,
    );
    _upsertSession(session);

    final request = TransferPrepareUploadRequestDto(
      info: _buildSelfInfo(),
      files: descriptors,
    );

    try {
      final prepareResult = await _transferClient.prepareUpload(
        target: target,
        request: request,
      );
      if (prepareResult.statusCode == 204) {
        _upsertSession(
          session.copyWith(
            status: TransferSessionStatus.finished,
            startedAt: DateTime.now(),
            finishedAt: DateTime.now(),
          ),
        );
        return;
      }

      final response = prepareResult.response!;
      var working = session.copyWith(
        remoteSessionId: response.sessionId,
        status: TransferSessionStatus.sending,
        startedAt: DateTime.now(),
        entries: <String, TransferSessionEntry>{
          for (final MapEntry<String, TransferSessionEntry> entry
              in session.entries.entries)
            entry.key: response.files.containsKey(entry.key)
                ? entry.value.copyWith(token: response.files[entry.key])
                : entry.value.copyWith(status: TransferFileStatus.skipped),
        },
      );
      _upsertSession(working);

      for (final MapEntry<String, TransferSessionEntry> item
          in working.entries.entries) {
        final entry = item.value;
        final token = entry.token;
        final sourceFile = entry.sourceFile;
        if (token == null || sourceFile == null) {
          continue;
        }
        working = _sessionWithFileStatus(
          working,
          item.key,
          TransferFileStatus.sending,
        );
        _upsertSession(working);
        try {
          await _transferClient.uploadFile(
            target: target,
            remoteSessionId: response.sessionId,
            fileId: item.key,
            token: token,
            sourceFile: sourceFile,
            onProgress: (int sentBytes) {
              final latest = _findSession(sessionId);
              if (latest == null) {
                return;
              }
              final updated = latest.copyWith(
                entries: <String, TransferSessionEntry>{
                  ...latest.entries,
                  item.key: latest.entries[item.key]!.copyWith(
                    bytesTransferred: sentBytes,
                    status: TransferFileStatus.sending,
                  ),
                },
              );
              _upsertSession(updated);
            },
          );
          working = _sessionWithCompletedFile(
            _findSession(sessionId) ?? working,
            item.key,
          );
          _upsertSession(working);
        } catch (error) {
          log('Failed to upload ${entry.descriptor.fileName}: $error');
          working = (_findSession(sessionId) ?? working).copyWith(
            status: TransferSessionStatus.finishedWithErrors,
            entries: <String, TransferSessionEntry>{
              ...(_findSession(sessionId) ?? working).entries,
              item.key: (_findSession(sessionId) ?? working).entries[item.key]!
                  .copyWith(
                    status: TransferFileStatus.failed,
                    errorMessage: error.toString(),
                  ),
            },
          );
          _upsertSession(working);
        }
      }

      final latest = _findSession(sessionId) ?? working;
      _upsertSession(
        latest.copyWith(
          status: latest.hasFailures
              ? TransferSessionStatus.finishedWithErrors
              : TransferSessionStatus.finished,
          finishedAt: DateTime.now(),
        ),
      );
    } on TransferHttpException catch (error) {
      _upsertSession(
        session.copyWith(
          status: switch (error.statusCode) {
            403 => TransferSessionStatus.rejected,
            409 => TransferSessionStatus.error,
            _ => TransferSessionStatus.error,
          },
          errorMessage: error.toString(),
          finishedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      _upsertSession(
        session.copyWith(
          status: TransferSessionStatus.error,
          errorMessage: error.toString(),
          finishedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> sendText(String text, TransferDevice target) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await sendFiles(<TransferSourceFile>[
      TransferSourceFile.text(trimmed),
    ], target);
  }

  Future<void> cancelSession(String sessionId) async {
    final session = _findSession(sessionId);
    if (session == null) {
      return;
    }
    if (session.direction == TransferSessionDirection.sending &&
        session.remoteSessionId != null) {
      try {
        await _transferClient.cancel(
          target: session.device,
          sessionId: session.remoteSessionId!,
        );
      } catch (error) {
        log('Failed to cancel remote session: $error');
      }
    }
    _upsertSession(
      session.copyWith(
        status: session.direction == TransferSessionDirection.sending
            ? TransferSessionStatus.canceledBySender
            : TransferSessionStatus.canceledByReceiver,
        finishedAt: DateTime.now(),
      ),
    );
  }

  Future<void> retrySession(String sessionId) async {
    final session = _findSession(sessionId);
    if (session == null ||
        session.direction != TransferSessionDirection.sending ||
        !session.hasFailures) {
      return;
    }
    final sourceFiles = session.entries.values
        .where(
          (TransferSessionEntry entry) =>
              entry.sourceFile != null &&
              entry.status == TransferFileStatus.failed,
        )
        .map((TransferSessionEntry entry) => entry.sourceFile!)
        .toList();
    if (sourceFiles.isEmpty) {
      return;
    }
    await sendFilesWithSource(
      sourceFiles,
      session.device,
      sourceLabel: session.sourceLabel,
    );
  }

  Future<void> copyMessageToClipboard(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
  }

  Future<void> openReceivedFile(String path) async {
    await OpenFilex.open(path);
  }

  void clearDevices({String? reason}) {
    if (_devicesById.isEmpty) {
      if (reason != null && reason.trim().isNotEmpty) {
        log(reason);
      }
      return;
    }
    _devicesById.clear();
    if (reason != null && reason.trim().isNotEmpty) {
      log(reason);
    }
    notifyListeners();
  }

  Future<void> handleConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    final hadWifi = _containsWifi(_lastConnectivityResults);
    final hasWifi = _containsWifi(results);
    _lastConnectivityResults = List<ConnectivityResult>.from(results);

    if (!_initialized) {
      return;
    }

    if (!hasWifi) {
      _lastWifiSignature = null;
      clearDevices(reason: 'Wi-Fi disconnected. Nearby devices cleared.');
      return;
    }

    final newSignature = await _currentWifiSignature();
    final networkChanged = !hadWifi || newSignature != _lastWifiSignature;
    _lastWifiSignature = newSignature;
    if (!networkChanged) {
      return;
    }

    clearDevices(reason: 'Wi-Fi changed. Refreshing nearby devices.');
    if (!hasConfiguredLocalDeviceName) {
      return;
    }
    await refreshDiscoveryWithFallback();
  }

  void log(String message) {
    _logs.add('[${DateTime.now().toIso8601String()}] $message');
    if (_logs.length > 200) {
      _logs.removeRange(0, _logs.length - 200);
    }
    notifyListeners();
  }

  TransferRegisterDto _buildSelfInfo() {
    return TransferRegisterDto(
      alias: localDeviceName,
      version: '2.0',
      deviceModel: _deviceModel(),
      deviceType: 'mobile',
      fingerprint: _securityContext?.certificateHash ?? '',
      port: _serverPort,
      protocol: protocol,
      download: false,
    );
  }

  String? _deviceModel() {
    return _resolvedDeviceModel ?? Platform.operatingSystem;
  }

  Future<void> _registerDevice(TransferDevice device) async {
    final existing = _devicesById[device.stableId];
    _devicesById[device.stableId] =
        existing?.copyWith(
          alias: device.alias,
          port: device.port,
          protocol: device.protocol,
          download: device.download,
          discoveryMethod: device.discoveryMethod,
          deviceModel: device.deviceModel,
          deviceType: device.deviceType,
          lastSeen: DateTime.now(),
        ) ??
        device;
    notifyListeners();
  }

  Future<void> _probeUnicastCandidate(
    String candidateIp,
    TransferRegisterDto selfInfo,
  ) async {
    try {
      final device = await _transferClient.ping(
        ip: candidateIp,
        port: 53317,
        protocol: protocol,
        selfInfo: selfInfo,
        discoveryMethod: 'unicast',
      );
      if (device == null || device.fingerprint == fingerprint) {
        return;
      }
      await _registerDevice(device);
    } catch (_) {
      // Ignore unreachable hosts during unicast scanning.
    }
  }

  Future<Map<String, String>?> _handleIncomingSession(
    TransferSession session,
  ) async {
    final context = LocalTransferModule.navigatorKey.currentContext;
    if (context == null) {
      log('Incoming request rejected because no navigator context is ready.');
      return null;
    }
    return showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ReceiveRequestDialog(session: session);
      },
    );
  }

  void _upsertSession(TransferSession session) {
    final index = _sessions.indexWhere(
      (TransferSession current) =>
          current.localSessionId == session.localSessionId,
    );
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
    notifyListeners();
  }

  bool _cancelSendingSessionFromRemote(String sessionId, String senderIp) {
    final session = _sessions.cast<TransferSession?>().firstWhere(
      (TransferSession? item) =>
          item?.remoteSessionId == sessionId &&
          item?.device.ip == senderIp &&
          item?.direction == TransferSessionDirection.sending,
      orElse: () => null,
    );
    if (session == null) {
      return false;
    }
    _upsertSession(
      session.copyWith(
        status: TransferSessionStatus.canceledByReceiver,
        finishedAt: DateTime.now(),
      ),
    );
    return true;
  }

  TransferSession? _findSession(String sessionId) {
    for (final TransferSession session in _sessions) {
      if (session.localSessionId == sessionId) {
        return session;
      }
    }
    return null;
  }

  TransferSession _sessionWithFileStatus(
    TransferSession session,
    String fileId,
    TransferFileStatus status,
  ) {
    return session.copyWith(
      entries: <String, TransferSessionEntry>{
        ...session.entries,
        fileId: session.entries[fileId]!.copyWith(
          status: status,
          clearErrorMessage: true,
        ),
      },
    );
  }

  TransferSession _sessionWithCompletedFile(
    TransferSession session,
    String fileId,
  ) {
    final entry = session.entries[fileId]!;
    return session.copyWith(
      entries: <String, TransferSessionEntry>{
        ...session.entries,
        fileId: entry.copyWith(
          status: TransferFileStatus.finished,
          bytesTransferred: entry.descriptor.size,
        ),
      },
    );
  }

  Future<String> _resolveSaveDirectory(LocalTransferConfig config) async {
    if (config.defaultSaveDirPath != null &&
        config.defaultSaveDirPath!.trim().isNotEmpty) {
      final directory = Directory(config.defaultSaveDirPath!);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      return directory.path;
    }

    final directory = await GueterStorageService.instance.publicDirectory(
      GueterPublicDirectory.localTransfer,
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory.path;
  }

  Future<void> _startConnectivityMonitoring() async {
    _lastConnectivityResults = await _connectivity.checkConnectivity();
    _lastWifiSignature = _containsWifi(_lastConnectivityResults)
        ? await _currentWifiSignature()
        : null;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      unawaited(handleConnectivityChanged(results));
    });
  }

  bool _containsWifi(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.wifi);
  }

  Future<String?> _currentWifiSignature() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = <String>[];
    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress address in interface.addresses) {
        if (_isPrivateIpv4(address)) {
          addresses.add(address.address);
        }
      }
    }
    if (addresses.isEmpty) {
      return null;
    }
    addresses.sort();
    return addresses.join('|');
  }

  Future<List<String>> _localPrivateIpv4s() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = <String>{};
    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress address in interface.addresses) {
        if (_isPrivateIpv4(address)) {
          addresses.add(address.address);
        }
      }
    }
    final sorted = addresses.toList()..sort(compareIpv4Strings);
    return sorted;
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

  String _newId() {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$micros$random';
  }

  Future<String?> _resolveDeviceBrand() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return info.brand.trim().isEmpty ? info.manufacturer : info.brand;
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.name;
      }
    } catch (error) {
      log('Failed to resolve device brand: $error');
    }
    return null;
  }

  Future<String?> _resolveDeviceModel() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return info.model;
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.utsname.machine;
      }
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return info.computerName;
      }
    } catch (error) {
      log('Failed to resolve device model: $error');
    }
    if (Platform.isAndroid) {
      return 'Android';
    }
    if (Platform.isWindows) {
      return 'Windows';
    }
    return Platform.operatingSystem;
  }
}
