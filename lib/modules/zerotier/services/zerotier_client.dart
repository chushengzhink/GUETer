import '../models/zerotier_snapshot.dart';

abstract class ZeroTierClient {
  Future<void> startNode();

  Future<void> joinNetwork(String networkId);

  Future<ZeroTierSnapshot> refreshSnapshot();

  Future<void> dispose();
}
