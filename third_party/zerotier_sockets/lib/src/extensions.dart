import 'dart:typed_data';

extension BigIntEx on BigInt {
  /// Convert [BigInt] to [int].
  /// Copies bits as is, without truncating value to a signed 64 bit integer.
  /// Allows setting valid unsigned 64 bit value to Dart's [int] to pass into native code expecting uint64 value.
  /// May break on some systems due to endianness or other integer implementation details. Commented part might help.
  int toIntBitwise() {
    var number = this;

    // convert BigInt to byte array (from https://github.com/dart-lang/sdk/issues/32803)
    int bytes = (number.bitLength + 7) >> 3;
    var b256 = BigInt.from(256);
    var result = Uint8List(bytes);
    for (int i = 0; i < bytes; i++) {
      //result[bytes - 1 - i] = number.remainder(b256).toInt();
      result[i] = number.remainder(b256).toInt();
      number = number >> 8;
    }

    // interpret byte array as int (bits takes as is)
    return result.buffer.asInt64List().single;
  }
}

extension IntEx on int {
  BigInt toBigIntBitwise() {
    var bytes = Uint8List(8);
    //bytes.buffer.asInt64List()[0] = this;
    bytes.buffer.asByteData().setInt64(0, this, Endian.big);

    BigInt resultValue = BigInt.zero;

    for (final byte in bytes) {
      // reading in big-endian, so we essentially concat the new byte to the end
      resultValue = (resultValue << 8) | BigInt.from(byte & 0xff);
    }

    return resultValue;
  }
}
