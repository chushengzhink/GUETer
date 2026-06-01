class TransferDevice {
  const TransferDevice({
    required this.ip,
    required this.port,
    required this.alias,
    required this.version,
    required this.deviceModel,
    required this.deviceType,
    required this.fingerprint,
    required this.protocol,
    required this.download,
    required this.discoveryMethod,
    required this.lastSeen,
  });

  final String ip;
  final int port;
  final String alias;
  final String version;
  final String? deviceModel;
  final String? deviceType;
  final String fingerprint;
  final String protocol;
  final bool download;
  final String discoveryMethod;
  final DateTime lastSeen;

  bool get isHttps => protocol.toLowerCase() == 'https';
  String get displayName {
    final normalizedAlias = alias.trim();
    if (normalizedAlias.isNotEmpty) {
      return normalizedAlias;
    }
    final normalizedModel = deviceModel?.trim() ?? '';
    if (normalizedModel.isNotEmpty) {
      return normalizedModel;
    }
    return ip;
  }

  String get stableId => '$ip:$port:$fingerprint';

  TransferDevice copyWith({
    String? ip,
    int? port,
    String? alias,
    String? version,
    String? deviceModel,
    String? deviceType,
    String? fingerprint,
    String? protocol,
    bool? download,
    String? discoveryMethod,
    DateTime? lastSeen,
  }) {
    return TransferDevice(
      ip: ip ?? this.ip,
      port: port ?? this.port,
      alias: alias ?? this.alias,
      version: version ?? this.version,
      deviceModel: deviceModel ?? this.deviceModel,
      deviceType: deviceType ?? this.deviceType,
      fingerprint: fingerprint ?? this.fingerprint,
      protocol: protocol ?? this.protocol,
      download: download ?? this.download,
      discoveryMethod: discoveryMethod ?? this.discoveryMethod,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
