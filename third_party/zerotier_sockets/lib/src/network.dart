enum NetworkStatus { waitingForConfig, ok, accessDenied, notFound, portError, clientTooOld }

enum NetworkType { private, public }

class ZeroTierNetwork {
  ZeroTierNetwork(
    this.id,
    this.transportIsReady,
    this.mac,
    this.macString,
    this.broadcastEnabled,
    this.mtu,
    this.name,
    this.status,
    this.type,
    this.routeAssigned,
    this.address,
  );

  final BigInt id;
  String get idString => id.toRadixString(16);
  final bool transportIsReady;
  final BigInt mac;
  final String macString;
  final bool broadcastEnabled;
  final int mtu;
  final String name;
  final NetworkStatus status;
  final NetworkType type;
  final bool routeAssigned;
  final String address;
}
