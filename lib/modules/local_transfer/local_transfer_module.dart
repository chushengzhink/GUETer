import 'package:flutter/material.dart';

import 'controller/local_transfer_controller.dart';
import 'local_transfer_config.dart';

class LocalTransferModule {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<void> initialize(LocalTransferConfig config) {
    return LocalTransferController.instance.initialize(config);
  }
}
