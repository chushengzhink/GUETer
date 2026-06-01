import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zerotier_sockets/zerotier_sockets.dart';

import '../models/zerotier_snapshot.dart';
import 'zerotier_client.dart';

class ZeroTierPluginClient implements ZeroTierClient {
  ZeroTierPluginClient({
    this.initialNetworkId,
    Duration onlineTimeout = const Duration(seconds: 10),
    Duration joinTimeout = const Duration(seconds: 15),
  }) : _onlineTimeout = onlineTimeout,
       _joinTimeout = joinTimeout;

  final String? initialNetworkId;
  final ZeroTierNode _node = ZeroTierNode.instance;
  final Duration _onlineTimeout;
  final Duration _joinTimeout;

  bool _storageInitialized = false;
  String? _currentNetworkId;

  @override
  Future<void> startNode() async {
    if (!_storageInitialized) {
      final appSupportDirectory = await getApplicationSupportDirectory();
      final storagePath = p.join(appSupportDirectory.path, 'zerotier');
      _ensureResult(_node.initSetPath(storagePath));
      _storageInitialized = true;
    }

    _currentNetworkId ??= _normalizeNetworkId(initialNetworkId ?? '');

    if (!_node.running) {
      _ensureResult(_node.start());
    }

    _ensureResult(
      await _node.waitForOnline(_onlineTimeout.inMilliseconds),
      fallbackMessage: 'ZeroTier 节点启动超时。',
    );
  }

  @override
  Future<void> joinNetwork(String networkId) async {
    final normalized = _normalizeNetworkId(networkId);
    final parsedNetworkId = BigInt.parse(normalized, radix: 16);

    await startNode();
    _currentNetworkId = normalized;
    _ensureResult(_node.join(parsedNetworkId));
    await _waitForJoinOutcome(parsedNetworkId, normalized);
  }

  @override
  Future<ZeroTierSnapshot> refreshSnapshot() async {
    final networkId = _normalizeNetworkId(
      _currentNetworkId ?? initialNetworkId ?? '',
    );
    if (networkId.isEmpty) {
      return ZeroTierSnapshot.initial();
    }

    _currentNetworkId = networkId;
    final parsedNetworkId = BigInt.parse(networkId, radix: 16);
    final network = _node.getNetworkInfo(parsedNetworkId);
    final addressResult = _node.getAddress(parsedNetworkId);
    final virtualIp = addressResult.success ? addressResult.data : null;

    if (network == null) {
      return ZeroTierSnapshot(
        connectionState: ZeroTierConnectionState.connecting,
        networkId: networkId,
        virtualIp: virtualIp,
        errorMessage: addressResult.success ? null : addressResult.toString(),
        isBusy: false,
        updatedAt: DateTime.now(),
        networkName: null,
        networkStatus: null,
      );
    }

    final state = switch (network.status) {
      NetworkStatus.ok when (virtualIp?.isNotEmpty ?? false) =>
        ZeroTierConnectionState.joined,
      NetworkStatus.accessDenied ||
      NetworkStatus.notFound ||
      NetworkStatus.portError ||
      NetworkStatus.clientTooOld => ZeroTierConnectionState.failed,
      _ => ZeroTierConnectionState.connecting,
    };

    return ZeroTierSnapshot(
      connectionState: state,
      networkId: networkId,
      virtualIp: virtualIp?.isNotEmpty == true ? virtualIp : null,
      errorMessage: state == ZeroTierConnectionState.failed
          ? _mapNetworkStatusMessage(network.status)
          : null,
      isBusy: false,
      updatedAt: DateTime.now(),
      networkName: network.name.isNotEmpty ? network.name : null,
      networkStatus: network.status.name,
    );
  }

  @override
  Future<void> dispose() async {}

  Future<void> _waitForJoinOutcome(
    BigInt networkId,
    String networkIdText,
  ) async {
    final deadline = DateTime.now().add(_joinTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final snapshot = await refreshSnapshot();
      if (snapshot.connectionState == ZeroTierConnectionState.joined) {
        return;
      }
      if (snapshot.connectionState == ZeroTierConnectionState.failed) {
        throw StateError(
          snapshot.errorMessage ?? 'ZeroTier 网络 $networkIdText 加入失败。',
        );
      }

      final readyResult = await _node.waitForNetworkReady(
        networkId,
        const Duration(milliseconds: 250).inMilliseconds,
      );
      if (readyResult.success) {
        final addressResult = await _node.waitForAddressAssignment(
          networkId,
          const Duration(milliseconds: 250).inMilliseconds,
        );
        if (addressResult.success) {
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    throw TimeoutException('等待 ZeroTier 分配虚拟 IP 超时。');
  }

  void _ensureResult(ZeroTierResult result, {String? fallbackMessage}) {
    if (result.success) {
      return;
    }
    throw StateError(fallbackMessage ?? result.toString());
  }

  String _normalizeNetworkId(String value) {
    return value.trim().toLowerCase();
  }

  String _mapNetworkStatusMessage(NetworkStatus status) {
    return switch (status) {
      NetworkStatus.accessDenied => 'ZeroTier 网络拒绝该设备加入。',
      NetworkStatus.notFound => 'ZeroTier 网络不存在或 ID 错误。',
      NetworkStatus.portError => 'ZeroTier 网络端口不可用。',
      NetworkStatus.clientTooOld => 'ZeroTier 客户端版本过旧。',
      NetworkStatus.waitingForConfig => 'ZeroTier 正在等待网络配置。',
      NetworkStatus.ok => 'ZeroTier 网络已连接。',
    };
  }
}
