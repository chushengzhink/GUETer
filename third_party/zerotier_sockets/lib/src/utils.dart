import 'dart:convert';
import 'dart:typed_data';

abstract class ZeroTierUtils {
  /// Get the public id part from the identity data (useful if you persist it yourself).
  static String? getIdentityString(Uint8List? identity) {
    if (identity == null) {
      return null;
    }

    return utf8.decode(identity, allowMalformed: true).split(':').first;
  }
}
