// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../model/transfer_device.dart';
import '../model/transfer_protocol_dto.dart';
import '../model/transfer_source_file.dart';
import 'certificate_service.dart';

class TransferHttpException implements Exception {
  TransferHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => '[$statusCode] $message';
}

class TransferPrepareUploadResult {
  const TransferPrepareUploadResult({
    required this.statusCode,
    required this.response,
  });

  final int statusCode;
  final TransferPrepareUploadResponseDto? response;
}

class TransferClient {
  TransferClient({required CertificateService certificateService})
    : _certificateService = certificateService;

  final CertificateService _certificateService;

  Future<TransferDevice?> register({
    required String ip,
    required int port,
    required String protocol,
    required String? expectedFingerprint,
    required TransferRegisterDto request,
    required String discoveryMethod,
  }) async {
    final response = await _sendJson(
      ip: ip,
      port: port,
      protocol: protocol,
      path: '/api/localsend/v2/register',
      method: 'POST',
      expectedFingerprint: expectedFingerprint,
      body: request.toJson(),
    );
    if (response.statusCode == 412) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransferHttpException(
        response.statusCode,
        response.body ?? 'Register failed',
      );
    }

    final json = response.jsonBody;
    if (json == null) {
      return null;
    }
    final info = TransferInfoDto.fromJson(json);
    return TransferDevice(
      ip: ip,
      port: port,
      alias: info.alias,
      version: info.version,
      deviceModel: info.deviceModel,
      deviceType: info.deviceType,
      fingerprint: info.fingerprint,
      protocol: protocol,
      download: info.download,
      discoveryMethod: discoveryMethod,
      lastSeen: DateTime.now(),
    );
  }

  Future<TransferPrepareUploadResult> prepareUpload({
    required TransferDevice target,
    required TransferPrepareUploadRequestDto request,
  }) async {
    final response = await _sendJson(
      ip: target.ip,
      port: target.port,
      protocol: target.protocol,
      path: '/api/localsend/v2/prepare-upload',
      method: 'POST',
      expectedFingerprint: target.fingerprint,
      body: request.toJson(),
    );
    if (response.statusCode == 204) {
      return const TransferPrepareUploadResult(statusCode: 204, response: null);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransferHttpException(
        response.statusCode,
        response.body ?? 'prepare-upload failed',
      );
    }
    final json = response.jsonBody;
    if (json == null) {
      throw TransferHttpException(response.statusCode, 'Missing JSON body');
    }
    return TransferPrepareUploadResult(
      statusCode: response.statusCode,
      response: TransferPrepareUploadResponseDto.fromJson(json),
    );
  }

  Future<TransferDevice?> ping({
    required String ip,
    required int port,
    required String protocol,
    required TransferRegisterDto selfInfo,
    required String discoveryMethod,
    Duration timeout = const Duration(milliseconds: 300),
  }) async {
    final response = await _sendJson(
      ip: ip,
      port: port,
      protocol: protocol,
      path: localTransferPingPath,
      method: 'GET',
      expectedFingerprint: null,
      body: const <String, dynamic>{},
      timeout: timeout,
      headers: <String, String>{
        localTransferPingSelfInfoHeader: base64Encode(
          utf8.encode(jsonEncode(selfInfo.toJson())),
        ),
      },
    );
    if (response.statusCode == 412) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TransferHttpException(
        response.statusCode,
        response.body ?? 'ping failed',
      );
    }
    final json = response.jsonBody;
    if (json == null) {
      return null;
    }
    final info = TransferRegisterDto.fromJson(json);
    return info.toDevice(
      ip: json['ip']?.toString() ?? ip,
      discoveryMethod: discoveryMethod,
      fallbackPort: port,
      fallbackProtocol: protocol,
    );
  }

  Future<void> uploadFile({
    required TransferDevice target,
    required String remoteSessionId,
    required String fileId,
    required String token,
    required TransferSourceFile sourceFile,
    required void Function(int sentBytes) onProgress,
  }) async {
    final client = _createHttpClient(
      protocol: target.protocol,
      expectedFingerprint: target.fingerprint,
    );
    try {
      final uri = Uri.parse(
        '${target.protocol}://${target.ip}:${target.port}/api/localsend/v2/upload'
        '?sessionId=$remoteSessionId&fileId=$fileId&token=$token',
      );
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.parse(sourceFile.fileType);
      request.contentLength = sourceFile.size;

      if (sourceFile.bytes != null) {
        request.add(sourceFile.bytes!);
        onProgress(sourceFile.bytes!.length);
      } else if (sourceFile.path != null) {
        int sent = 0;
        await for (final chunk in File(sourceFile.path!).openRead()) {
          request.add(chunk);
          sent += chunk.length;
          onProgress(sent);
        }
      } else {
        throw const FileSystemException('Source file missing path and bytes.');
      }

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TransferHttpException(
          response.statusCode,
          body.isEmpty ? 'upload failed' : body,
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<void> cancel({
    required TransferDevice target,
    required String sessionId,
  }) async {
    final response = await _sendJson(
      ip: target.ip,
      port: target.port,
      protocol: target.protocol,
      path: '/api/localsend/v2/cancel?sessionId=$sessionId',
      method: 'POST',
      expectedFingerprint: target.fingerprint,
      body: const <String, dynamic>{},
    );
    if (response.statusCode >= 400) {
      throw TransferHttpException(
        response.statusCode,
        response.body ?? 'cancel failed',
      );
    }
  }

  HttpClient _createHttpClient({
    required String protocol,
    required String? expectedFingerprint,
  }) {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);
    if (protocol == 'https') {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
            if (expectedFingerprint == null || expectedFingerprint.isEmpty) {
              return true;
            }
            final actual = _certificateService.calculateHashFromPem(cert.pem);
            return actual == expectedFingerprint;
          };
    }
    return client;
  }

  Future<_HttpResult> _sendJson({
    required String ip,
    required int port,
    required String protocol,
    required String path,
    required String method,
    required String? expectedFingerprint,
    required Map<String, dynamic> body,
    Duration? timeout,
    Map<String, String>? headers,
  }) async {
    final client = _createHttpClient(
      protocol: protocol,
      expectedFingerprint: expectedFingerprint,
    );
    if (timeout != null) {
      client.connectionTimeout = timeout;
    }
    try {
      final uri = Uri.parse('$protocol://$ip:$port$path');
      final request = switch (method.toUpperCase()) {
        'GET' => await client.getUrl(uri),
        _ => await client.postUrl(uri),
      };
      headers?.forEach(request.headers.add);
      if (method.toUpperCase() != 'GET') {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
      final response = timeout == null
          ? await request.close()
          : await request.close().timeout(timeout);
      final bodyString = await utf8.decoder.bind(response).join();
      Map<String, dynamic>? jsonBody;
      try {
        final decoded = jsonDecode(bodyString);
        if (decoded is Map<String, dynamic>) {
          jsonBody = decoded;
        } else if (decoded is Map) {
          jsonBody = decoded.cast<String, dynamic>();
        }
      } catch (_) {
        // Non-JSON body is valid for some status codes.
      }
      return _HttpResult(
        statusCode: response.statusCode,
        body: bodyString,
        jsonBody: jsonBody,
      );
    } on SocketException catch (error) {
      throw TransferHttpException(0, error.message);
    } on HandshakeException catch (error) {
      throw TransferHttpException(0, error.message);
    } on TimeoutException catch (_) {
      throw TransferHttpException(0, 'Request timed out');
    } finally {
      client.close(force: true);
    }
  }
}

class _HttpResult {
  const _HttpResult({
    required this.statusCode,
    required this.body,
    required this.jsonBody,
  });

  final int statusCode;
  final String? body;
  final Map<String, dynamic>? jsonBody;
}
