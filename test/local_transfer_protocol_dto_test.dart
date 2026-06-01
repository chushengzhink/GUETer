import 'package:flutter_test/flutter_test.dart';

import 'package:course_helper/modules/local_transfer/model/transfer_file_models.dart';
import 'package:course_helper/modules/local_transfer/model/transfer_protocol_dto.dart';

void main() {
  test('register dto serializes and deserializes', () {
    const dto = TransferRegisterDto(
      alias: 'GUETer',
      version: '2.0',
      deviceModel: 'Android',
      deviceType: 'mobile',
      fingerprint: 'abc123',
      port: 53317,
      protocol: 'https',
      download: false,
      announce: true,
    );

    final decoded = TransferRegisterDto.fromJson(dto.toJson());
    expect(decoded.alias, 'GUETer');
    expect(decoded.protocol, 'https');
    expect(decoded.announce, isTrue);
  });

  test('prepare-upload response round-trip', () {
    const response = TransferPrepareUploadResponseDto(
      sessionId: 'session-1',
      files: <String, String>{
        'file-a': 'token-a',
        'file-b': 'token-b',
      },
    );

    final decoded = TransferPrepareUploadResponseDto.fromJson(response.toJson());
    expect(decoded.sessionId, 'session-1');
    expect(decoded.files['file-a'], 'token-a');
    expect(decoded.files.length, 2);
  });

  test('prepare-upload request parses files map', () {
    final request = TransferPrepareUploadRequestDto(
      info: const TransferRegisterDto(
        alias: 'Sender',
        version: '2.0',
        deviceModel: 'Windows',
        deviceType: 'desktop',
        fingerprint: 'hash',
        port: 53317,
        protocol: 'https',
        download: false,
      ),
      files: const <String, TransferFileDescriptor>{
        'f1': TransferFileDescriptor(
          id: 'f1',
          fileName: 'note.txt',
          size: 5,
          fileType: 'text/plain',
          preview: 'hello',
        ),
      },
    );

    final decoded = TransferPrepareUploadRequestDto.fromJson(request.toJson());
    expect(decoded.files['f1']?.fileName, 'note.txt');
    expect(decoded.files['f1']?.preview, 'hello');
  });
}
