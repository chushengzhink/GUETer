import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<void> ensurePickerPermissions() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final status = await Permission.storage.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        await Permission.storage.request();
      }
    } catch (_) {
      // File picker can still work through SAF, so permission failures are non-fatal.
    }
  }
}
