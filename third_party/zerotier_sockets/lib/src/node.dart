import 'dart:typed_data';

import 'package:zerotier_sockets/src/extensions.dart';

import 'bindings.dart';
import 'native_utils.dart';
import 'network.dart';
import 'result.dart';
import 'zts.dart';

class ZeroTierNode {
  static final ZeroTierNode instance = ZeroTierNode._();
  ZeroTierNode._();

  bool get running => getId().success;

  bool get online => zts.node_is_online() == 1;

  /// Set path to storage directory.
  /// Must be called before node is started.
  /// If not set the identity (node id) won't be persisted.
  ZeroTierResult initSetPath(String path) {
    final str = NativeString(path);

    try {
      var res = zts.init_from_storage(str.pointer);
      return ZeroTierResult(res);
    } finally {
      str.free();
    }
  }

  /// Set identity (node id) from memory.
  /// Must be called before node is started.
  ZeroTierResult initSetIdentity(Uint8List data) {
    final key = NativeByteArray(data);
    final len = data.length;
    try {
      final res = zts.init_from_memory(key.pointer.cast(), len);
      return ZeroTierResult(res);
    } finally {
      key.free();
    }
  }

  /// Get identity (node id).
  ZeroTierResultWithData2<Uint8List, int> getIdentity() {
    var data = NativeByteArray.empty(ZTS_ID_STR_BUF_LEN);
    var len = NativeUnsignedInt(ZTS_ID_STR_BUF_LEN);

    try {
      final res = zts.node_get_id_pair(data.pointer.cast(), len.pointer);
      return ZeroTierResultWithData2(res, Uint8List.fromList(data.data), len.value);
    } finally {
      data.free();
      len.free();
    }
  }

  /// Start node
  ZeroTierResult start() {
    final res = zts.node_start();
    return ZeroTierResult(res);
  }

  /// Wait for the node to become online
  Future<ZeroTierResult> waitForOnline([int timeout = 10000]) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    while (true) {
      if (DateTime.now().millisecondsSinceEpoch - timestamp > timeout) {
        return ZeroTierResult(zts_error_t.ZTS_ERR_NO_RESULT);
      }

      if (online) {
        return ZeroTierResult(0);
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Stop node
  ZeroTierResult stop() {
    final res = zts.node_stop();
    return ZeroTierResult(res);
  }

  /// Join network by id
  ZeroTierResult join(BigInt networkId) {
    final res = zts.net_join(networkId.toIntBitwise());
    return ZeroTierResult(res);
  }

  /// Wait for network to become ready
  Future<ZeroTierResult> waitForNetworkReady(BigInt networkId, [int timeout = 10000]) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    while (true) {
      if (DateTime.now().millisecondsSinceEpoch - timestamp > timeout) {
        return ZeroTierResult(zts_error_t.ZTS_ERR_NO_RESULT);
      }

      var res = zts.net_transport_is_ready(networkId.toIntBitwise());
      if (res == 1) {
        return ZeroTierResult(0);
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Wait for address assignment
  Future<ZeroTierResult> waitForAddressAssignment(BigInt networkId, [int timeout = 10000]) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    while (true) {
      if (DateTime.now().millisecondsSinceEpoch - timestamp > timeout) {
        return ZeroTierResult(zts_error_t.ZTS_ERR_NO_RESULT);
      }

      var res = zts.addr_is_assigned(networkId.toIntBitwise(), ZTS_AF_INET);
      if (res == 1) {
        return ZeroTierResult(0);
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Get address assigned to network
  ZeroTierResultWithData<String?> getAddress(BigInt networkId) {
    final ipStr = NativeString.empty(ZTS_IP_MAX_STR_LEN);

    try {
      var res = zts.addr_get_str(networkId.toIntBitwise(), ZTS_AF_INET, ipStr.pointer, ZTS_IP_MAX_STR_LEN);
      return ZeroTierResultWithData(res, res == 0 ? ipStr.value : null);
    } finally {
      ipStr.free();
    }
  }

  /// Get node id
  ZeroTierResultWithData<BigInt> getId() {
    final res = zts.node_get_id();
    final id = res.toBigIntBitwise();
    return ZeroTierResultWithData(res, id);
  }

  /// Leave network
  ZeroTierResult leave(BigInt networkId) {
    final res = zts.net_leave(networkId.toIntBitwise());
    return ZeroTierResult(res);
  }

  /// Get network info. Returns null if any error occurs.
  ZeroTierNetwork? getNetworkInfo(BigInt networkId) {
    int res = 0;
    int nwId = networkId.toIntBitwise();

    res = zts.net_get_status(nwId);
    NetworkStatus status = NetworkStatus.waitingForConfig;
    switch (res) {
      case zts_network_status_t.ZTS_NETWORK_STATUS_REQUESTING_CONFIGURATION:
        status = NetworkStatus.waitingForConfig;
        break;
      case zts_network_status_t.ZTS_NETWORK_STATUS_OK:
        status = NetworkStatus.ok;
        break;
      case zts_network_status_t.ZTS_NETWORK_STATUS_ACCESS_DENIED:
        status = NetworkStatus.accessDenied;
        break;
      case zts_network_status_t.ZTS_NETWORK_STATUS_NOT_FOUND:
        status = NetworkStatus.notFound;
        break;
      case zts_network_status_t.ZTS_NETWORK_STATUS_PORT_ERROR:
        status = NetworkStatus.portError;
        break;
      case zts_network_status_t.ZTS_NETWORK_STATUS_CLIENT_TOO_OLD:
        status = NetworkStatus.clientTooOld;
        break;
    }

    if (res < 0) return null;

    var transportIsReady = zts.net_transport_is_ready(nwId) == 1;
    var mac = zts.net_get_mac(nwId).toBigIntBitwise();

    var macStrPointer = NativeString.empty(ZTS_MAC_ADDRSTRLEN);
    res = zts.net_get_mac_str(nwId, macStrPointer.pointer, ZTS_MAC_ADDRSTRLEN);
    var macStr = res == 0 ? macStrPointer.value : '';
    macStrPointer.free();

    if (res < 0) return null;

    var broadcast = zts.net_get_broadcast(nwId) == 1;
    var mtu = zts.net_get_mtu(nwId);

    var namePointer = NativeString.empty(ZTS_MAX_NETWORK_SHORT_NAME_LENGTH);
    res = zts.net_get_name(nwId, namePointer.pointer, ZTS_MAX_NETWORK_SHORT_NAME_LENGTH);
    var name = res == 0 ? namePointer.value : '';
    namePointer.free();

    if (res < 0) return null;

    res = zts.net_get_type(nwId);
    if (res < 0) return null;

    NetworkType type = NetworkType.public;
    switch (res) {
      case zts_net_info_type_t.ZTS_NETWORK_TYPE_PRIVATE:
        type = NetworkType.private;
        break;
      case zts_net_info_type_t.ZTS_NETWORK_TYPE_PUBLIC:
        type = NetworkType.public;
        break;
    }

    var routeAssigned = zts.route_is_assigned(nwId, ZTS_AF_INET) == 1;
    var address = getAddress(networkId).data;

    return ZeroTierNetwork(
      networkId,
      transportIsReady,
      mac,
      macStr,
      broadcast,
      mtu,
      name,
      status,
      type,
      routeAssigned,
      address ?? '',
    );
  }
}
