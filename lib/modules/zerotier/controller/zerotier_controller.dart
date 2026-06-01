import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/zerotier_snapshot.dart';
import '../services/zerotier_client.dart';
import '../services/zerotier_plugin_client.dart';
import '../services/zerotier_storage_service.dart';
import '../zerotier_constants.dart';

class ZeroTierController extends ChangeNotifier {
  ZeroTierController({
    ZeroTierClient Function()? clientFactory,
    ZeroTierStorageService? storageService,
    bool? supportedOverride,
  }) : _customClientFactory = clientFactory,
       _storageService = storageService ?? ZeroTierStorageService(),
       _supportedOverride = supportedOverride;

  final ZeroTierClient Function()? _customClientFactory;
  final ZeroTierStorageService _storageService;
  final bool? _supportedOverride;

  ZeroTierClient? _client;
  bool _initialized = false;
  String _networkId = '';
  ZeroTierSnapshot _snapshot = ZeroTierSnapshot.initial();

  bool get initialized => _initialized;
  bool get isSupported => _supportedOverride ?? (!kIsWeb && Platform.isAndroid);
  String get networkId => _networkId;
  ZeroTierSnapshot get snapshot => _snapshot;
  bool get isBusy => _snapshot.isBusy;
  bool get requiresInitialNetworkIdPrompt =>
      _initialized && _networkId.trim().isEmpty;

  static final RegExp _networkIdPattern = RegExp(r'^[0-9a-f]{16}$');

  static bool isValidNetworkId(String value) {
    return _networkIdPattern.hasMatch(value.trim().toLowerCase());
  }

  static String normalizeNetworkId(String value) {
    return value.trim().toLowerCase();
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final storedNetworkId = await _storageService.loadNetworkId();
    _networkId = normalizeNetworkId(
      storedNetworkId ?? kDefaultZeroTierNetworkId,
    );
    _snapshot = ZeroTierSnapshot.initial(networkId: _networkId);
    _initialized = true;
    notifyListeners();
  }

  Future<void> saveNetworkId(String value) async {
    final normalized = normalizeNetworkId(value);
    await _storageService.saveNetworkId(normalized);
    if (_networkId != normalized) {
      _networkId = normalized.isNotEmpty
          ? normalized
          : normalizeNetworkId(kDefaultZeroTierNetworkId);
      await close();
    }
    _snapshot = _snapshot.copyWith(
      networkId: _networkId,
      clearErrorMessage: true,
    );
    notifyListeners();
  }

  Future<bool> connect([String? inputNetworkId]) async {
    await initialize();

    if (!isSupported) {
      _snapshot = _snapshot.copyWith(
        connectionState: ZeroTierConnectionState.failed,
        errorMessage: '虚拟局域网当前仅支持 Android。',
        isBusy: false,
      );
      notifyListeners();
      return false;
    }

    final normalized = normalizeNetworkId(inputNetworkId ?? _networkId);
    if (!isValidNetworkId(normalized)) {
      _snapshot = _snapshot.copyWith(
        connectionState: ZeroTierConnectionState.failed,
        networkId: normalized,
        clearVirtualIp: true,
        errorMessage: '网络 ID 必须是 16 位十六进制字符。',
        isBusy: false,
      );
      notifyListeners();
      return false;
    }

    await saveNetworkId(normalized);
    _snapshot = _snapshot.copyWith(
      connectionState: ZeroTierConnectionState.connecting,
      networkId: normalized,
      clearVirtualIp: true,
      clearErrorMessage: true,
      isBusy: true,
    );
    notifyListeners();

    try {
      final client = _ensureClient();
      await client.startNode();
      await client.joinNetwork(normalized);
      final refreshed = await client.refreshSnapshot();
      _snapshot = refreshed.copyWith(isBusy: false);
      notifyListeners();
      return _snapshot.connectionState == ZeroTierConnectionState.joined;
    } catch (error) {
      _snapshot = _snapshot.copyWith(
        connectionState: ZeroTierConnectionState.failed,
        errorMessage: _formatError(error),
        isBusy: false,
      );
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshStatus() async {
    await initialize();
    if (_networkId.isEmpty || !isValidNetworkId(_networkId)) {
      _snapshot = _snapshot.copyWith(
        connectionState: ZeroTierConnectionState.uninitialized,
        clearVirtualIp: true,
        errorMessage: _networkId.isEmpty ? null : '网络 ID 格式无效。',
        isBusy: false,
      );
      notifyListeners();
      return;
    }

    _snapshot = _snapshot.copyWith(isBusy: true, clearErrorMessage: true);
    notifyListeners();

    try {
      final refreshed = await _ensureClient().refreshSnapshot();
      _snapshot = refreshed.copyWith(isBusy: false);
    } catch (error) {
      _snapshot = _snapshot.copyWith(
        connectionState: ZeroTierConnectionState.failed,
        errorMessage: _formatError(error),
        isBusy: false,
      );
    }
    notifyListeners();
  }

  Future<void> close() async {
    final client = _client;
    _client = null;
    if (client != null) {
      await client.dispose();
    }
  }

  ZeroTierClient _ensureClient() {
    return _client ??=
        _customClientFactory?.call() ??
        ZeroTierPluginClient(initialNetworkId: _networkId);
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.startsWith('Bad state: ')) {
      return message.substring('Bad state: '.length);
    }
    return message;
  }
}
