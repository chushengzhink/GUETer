import 'bindings.dart';
import 'loader.dart';

/// Top level declaration so that it can be accessed in another isolate
final ZeroTierNative zts = ZeroTierNativeLoader.load();
