import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:course_helper/modules/local_transfer/services/certificate_service.dart';

void main() {
  test('certificate hash uses DER payload bytes', () {
    const fakePem = '-----BEGIN CERTIFICATE-----\naGVsbG8=\n-----END CERTIFICATE-----';
    final expected = sha256.convert(base64Decode('aGVsbG8=')).toString();

    expect(
      CertificateService.calculateHashOfCertificate(fakePem),
      expected,
    );
  });
}
