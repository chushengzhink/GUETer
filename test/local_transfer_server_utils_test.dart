import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:course_helper/modules/local_transfer/model/transfer_device.dart';
import 'package:course_helper/modules/local_transfer/model/transfer_file_models.dart';
import 'package:course_helper/modules/local_transfer/model/transfer_protocol_dto.dart';
import 'package:course_helper/modules/local_transfer/model/transfer_session.dart';
import 'package:course_helper/modules/local_transfer/services/certificate_service.dart';
import 'package:course_helper/modules/local_transfer/services/transfer_client.dart';
import 'package:course_helper/modules/local_transfer/services/transfer_server.dart';

void main() {
  test('sanitizeFileName blocks path traversal and invalid chars', () {
    expect(sanitizeFileName('../a/bad:name?.txt'), 'bad_name_.txt');
    expect(sanitizeFileName('..'), 'received_file');
  });

  test('detectTextMessage recognizes preview text payload', () {
    const files = <TransferFileDescriptor>[
      TransferFileDescriptor(
        id: '1',
        fileName: 'message.txt',
        size: 5,
        fileType: 'text/plain',
        preview: 'hello',
      ),
    ];

    expect(detectTextMessage(files), 'hello');
  });

  test('nextAvailableFilePath increments duplicate file names', () async {
    final tempDir = await Directory.systemTemp.createTemp('localsend-test');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final original = File('${tempDir.path}${Platform.pathSeparator}demo.txt');
    await original.writeAsString('x');

    final candidate = await nextAvailableFilePath(
      baseDirectory: tempDir.path,
      fileName: 'demo.txt',
    );
    expect(candidate.endsWith('demo (1).txt'), isTrue);
  });

  test('ping route returns device info and records requester', () async {
    final tempDir = await Directory.systemTemp.createTemp('localsend-ping');
    final discovered = <TransferDevice>[];
    addTearDown(() async {
      await Directory(tempDir.path).delete(recursive: true);
    });

    final server = TransferServer(
      securityContext: const LocalTransferSecurityContext(
        privateKeyPem: '',
        certificatePem: '',
        certificateHash: 'server-fingerprint',
      ),
      saveDirectoryPath: tempDir.path,
      enableHttps: false,
      onDeviceDiscovered: (TransferDevice device) async {
        discovered.add(device);
      },
      onIncomingSession: (TransferSession session) async => null,
      onSessionChanged: (TransferSession session) {},
      onCancelSendingSession: (String sessionId, String senderIp) => false,
      onLog: (String message) {},
      selfInfoProvider: () => const TransferRegisterDto(
        alias: 'Server Device',
        version: '2.0',
        deviceModel: 'Android',
        deviceType: 'mobile',
        fingerprint: 'server-fingerprint',
        port: 53317,
        protocol: 'http',
        download: false,
      ),
    );
    final port = await server.start(preferredPort: 0);
    addTearDown(() async {
      await server.stop();
    });

    final client = TransferClient(certificateService: CertificateService());
    final device = await client.ping(
      ip: '127.0.0.1',
      port: port,
      protocol: 'http',
      selfInfo: const TransferRegisterDto(
        alias: 'Requester Device',
        version: '2.0',
        deviceModel: 'Windows',
        deviceType: 'desktop',
        fingerprint: 'requester-fingerprint',
        port: 53317,
        protocol: 'http',
        download: false,
      ),
      discoveryMethod: 'unicast',
    );

    expect(device, isNotNull);
    expect(device!.alias, 'Server Device');
    expect(device.fingerprint, 'server-fingerprint');
    expect(device.protocol, 'http');
    expect(device.port, port);
    expect(discovered, hasLength(1));
    expect(discovered.single.alias, 'Requester Device');
    expect(discovered.single.ip, '127.0.0.1');
  });

  test('buildPingResponseBody keeps full discovery fields', () {
    const dto = TransferRegisterDto(
      alias: 'Ping Device',
      version: '2.0',
      deviceModel: 'Android',
      deviceType: 'mobile',
      fingerprint: 'fp',
      port: 53317,
      protocol: 'https',
      download: false,
    );

    final body = buildPingResponseBody(self: dto, ip: '10.33.0.8', port: 9000);
    expect(body['alias'], 'Ping Device');
    expect(body['deviceModel'], 'Android');
    expect(body['fingerprint'], 'fp');
    expect(body['protocol'], 'https');
    expect(body['port'], 9000);
    expect(body['ip'], '10.33.0.8');
  });

  test('parsePingRequesterHeader decodes self info header', () {
    const dto = TransferRegisterDto(
      alias: 'Requester',
      version: '2.0',
      deviceModel: 'Android',
      deviceType: 'mobile',
      fingerprint: 'fp-123',
      port: 53317,
      protocol: 'https',
      download: false,
    );

    final header = base64Encode(utf8.encode(jsonEncode(dto.toJson())));
    final parsed = parsePingRequesterHeader(header);
    expect(parsed, isNotNull);
    expect(parsed!.alias, 'Requester');
    expect(parsed.fingerprint, 'fp-123');
  });
}
