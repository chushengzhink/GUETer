import 'dart:ffi' as ffi;
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

class NativeString {
  NativeString.empty(int length) {
    pointer = malloc.allocate<ffi.Char>(length);
  }

  NativeString(String data) {
    pointer = data.toNativeUtf8().cast();
  }

  String get value => pointer.cast<Utf8>().toDartString();

  void free() {
    malloc.free(pointer);
  }

  late Pointer<ffi.Char> pointer;
}

class NativeByteArray {
  NativeByteArray.empty(int length) {
    pointer = malloc.allocate<ffi.Uint8>(length);
    voidPointer = pointer.cast();
    data = pointer.asTypedList(length);
  }

  NativeByteArray(Uint8List data) {
    pointer = malloc.allocate<ffi.Uint8>(data.length);
    voidPointer = pointer.cast();
    this.data = pointer.asTypedList(data.length);
    this.data.setAll(0, data);
  }

  void free() {
    malloc.free(pointer);
  }

  late Uint8List data;
  late Pointer<ffi.Uint8> pointer;
  late Pointer<ffi.Void> voidPointer;
}

class NativeUnsignedInt {
  NativeUnsignedInt([int value = 0]) {
    pointer = malloc<ffi.UnsignedInt>();
    pointer.value = value;
  }

  late Pointer<ffi.UnsignedInt> pointer;

  int get value => pointer.value;
  set value(int val) => pointer.value = val;

  void free() {
    malloc.free(pointer);
  }
}
