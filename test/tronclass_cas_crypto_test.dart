import 'dart:convert';
import 'dart:typed_data';

import 'package:course_helper/api/login.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CAS password encryption uses ASCII IV compatible with server decode',
    () {
      const salt = '1234567890abcdef';
      const password = 'password123';
      final key = encrypt_pkg.Key(Uint8List.fromList(utf8.encode(salt)));
      final zeroIv = encrypt_pkg.IV(Uint8List(16));
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc, padding: 'PKCS7'),
      );

      for (var i = 0; i < 40; i++) {
        final encrypted = encryptTronclassCasPassword(password, salt);
        final decrypted = encrypter.decrypt64(encrypted, iv: zeroIv);

        expect(decrypted, endsWith(password));
        expect(decrypted.length, greaterThanOrEqualTo(64 + password.length));
      }
    },
  );
}
