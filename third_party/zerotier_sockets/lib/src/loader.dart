import 'dart:ffi';
import 'dart:io';

import 'bindings.dart';

abstract class ZeroTierNativeLoader {
  static ZeroTierNative load() {
    DynamicLibrary? lib;

    if (Platform.isAndroid) {
      lib = DynamicLibrary.open('libzt.so');
    }

    if (lib == null) {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    return ZeroTierNative(lib);
  }
}
