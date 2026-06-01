// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalTransferSecurityContext {
  const LocalTransferSecurityContext({
    required this.privateKeyPem,
    required this.certificatePem,
    required this.certificateHash,
  });

  final String privateKeyPem;
  final String certificatePem;
  final String certificateHash;
}

class CertificateService {
  static const String _directoryName = 'local_transfer_security';
  static const String _privateKeyFile = 'private_key.pem';
  static const String _certificateFile = 'certificate.pem';

  Future<LocalTransferSecurityContext> ensureSecurityContext() async {
    final supportDir = await getApplicationSupportDirectory();
    final directory = Directory(p.join(supportDir.path, _directoryName));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final privateKeyFile = File(p.join(directory.path, _privateKeyFile));
    final certificateFile = File(p.join(directory.path, _certificateFile));
    if (privateKeyFile.existsSync() && certificateFile.existsSync()) {
      final privateKeyPem = await privateKeyFile.readAsString();
      final certificatePem = await certificateFile.readAsString();
      return LocalTransferSecurityContext(
        privateKeyPem: privateKeyPem,
        certificatePem: certificatePem,
        certificateHash: calculateHashOfCertificate(certificatePem),
      );
    }

    final keyPair = CryptoUtils.generateRSAKeyPair();
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final dn = <String, String>{
      'CN': 'GUETer Local Transfer',
      'O': 'GUETer',
      'OU': 'Local Transfer',
      'L': '',
      'S': '',
      'C': '',
    };
    final csr = X509Utils.generateRsaCsrPem(dn, privateKey, publicKey);
    final certificate = X509Utils.generateSelfSignedCertificate(
      keyPair.privateKey,
      csr,
      3650,
    );
    final privateKeyPem = CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey);

    await privateKeyFile.writeAsString(privateKeyPem, flush: true);
    await certificateFile.writeAsString(certificate, flush: true);

    return LocalTransferSecurityContext(
      privateKeyPem: privateKeyPem,
      certificatePem: certificate,
      certificateHash: calculateHashOfCertificate(certificate),
    );
  }

  String calculateHashFromPem(String certificatePem) {
    return calculateHashOfCertificate(certificatePem);
  }

  static String calculateHashOfCertificate(String certificatePem) {
    final pemContent = certificatePem
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((String line) => line.isNotEmpty && !line.startsWith('---'))
        .join();
    final der = base64Decode(pemContent);
    return sha256.convert(der).toString();
  }
}
