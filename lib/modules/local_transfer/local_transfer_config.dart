class LocalTransferConfig {
  const LocalTransferConfig({
    this.appAlias = 'GUETer',
    this.defaultSaveDirPath,
    this.enableHttps = true,
    this.enableHttpSubnetFallback = true,
    this.autoStartDiscovery = true,
  });

  final String appAlias;
  final String? defaultSaveDirPath;
  final bool enableHttps;
  final bool enableHttpSubnetFallback;
  final bool autoStartDiscovery;
}
