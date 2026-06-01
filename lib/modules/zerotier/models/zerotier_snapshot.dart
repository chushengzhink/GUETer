enum ZeroTierConnectionState { uninitialized, connecting, joined, failed }

class ZeroTierSnapshot {
  const ZeroTierSnapshot({
    required this.connectionState,
    required this.networkId,
    required this.virtualIp,
    required this.errorMessage,
    required this.isBusy,
    required this.updatedAt,
    this.networkName,
    this.networkStatus,
  });

  factory ZeroTierSnapshot.initial({String networkId = ''}) {
    return ZeroTierSnapshot(
      connectionState: ZeroTierConnectionState.uninitialized,
      networkId: networkId,
      virtualIp: null,
      errorMessage: null,
      isBusy: false,
      updatedAt: DateTime.now(),
      networkName: null,
      networkStatus: null,
    );
  }

  final ZeroTierConnectionState connectionState;
  final String networkId;
  final String? virtualIp;
  final String? errorMessage;
  final bool isBusy;
  final DateTime updatedAt;
  final String? networkName;
  final String? networkStatus;

  bool get hasVirtualIp => virtualIp?.trim().isNotEmpty == true;

  ZeroTierSnapshot copyWith({
    ZeroTierConnectionState? connectionState,
    String? networkId,
    String? virtualIp,
    bool clearVirtualIp = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    bool? isBusy,
    DateTime? updatedAt,
    String? networkName,
    bool clearNetworkName = false,
    String? networkStatus,
    bool clearNetworkStatus = false,
  }) {
    return ZeroTierSnapshot(
      connectionState: connectionState ?? this.connectionState,
      networkId: networkId ?? this.networkId,
      virtualIp: clearVirtualIp ? null : (virtualIp ?? this.virtualIp),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isBusy: isBusy ?? this.isBusy,
      updatedAt: updatedAt ?? DateTime.now(),
      networkName: clearNetworkName ? null : (networkName ?? this.networkName),
      networkStatus: clearNetworkStatus
          ? null
          : (networkStatus ?? this.networkStatus),
    );
  }
}
