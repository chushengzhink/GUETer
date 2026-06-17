class OpenListEndpointConfig {
  const OpenListEndpointConfig._();

  static const String _baseOverride = String.fromEnvironment(
    'OPENLIST_BASE_URL',
  );
  static const String _auditOverride = String.fromEnvironment(
    'OPENLIST_AUDIT_ENDPOINT',
  );
  static const String _provisionOverride = String.fromEnvironment(
    'OPENLIST_PROVISION_ENDPOINT',
  );

  static String get baseUrl {
    final override = _baseOverride.trim();
    return override.isNotEmpty ? override : _decode(_baseUrlBytes);
  }

  static String get auditEndpoint {
    final override = _auditOverride.trim();
    if (override.isNotEmpty) {
      return override;
    }
    return '$auditBaseUrl/api/gueter/openlist/upload-record';
  }

  static String get provisionEndpoint {
    final override = _provisionOverride.trim();
    if (override.isNotEmpty) {
      return override;
    }
    return '$auditBaseUrl/api/gueter/openlist/ensure-user';
  }

  static String get auditBaseUrl => _decode(_auditBaseUrlBytes);

  static String hostHash(String endpoint) {
    final uri = Uri.tryParse(endpoint);
    final host = uri?.host ?? endpoint;
    var hash = 0x811c9dc5;
    for (final unit in host.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _decode(List<int> values) {
    return String.fromCharCodes(values.map((value) => value ^ _mask));
  }

  static const int _mask = 0x5a;
  static const List<int> _baseUrlBytes = <int>[
    50,
    46,
    46,
    42,
    96,
    117,
    117,
    107,
    106,
    116,
    105,
    105,
    116,
    107,
    106,
    98,
    116,
    98,
    107,
    96,
    111,
    104,
    110,
    110,
  ];
  static const List<int> _auditBaseUrlBytes = <int>[
    50,
    46,
    46,
    42,
    96,
    117,
    117,
    107,
    106,
    116,
    105,
    105,
    116,
    107,
    106,
    98,
    116,
    98,
    107,
    96,
    111,
    104,
    110,
    111,
  ];
}
