// Copyright 2024 LocalSend contributors
// SPDX-License-Identifier: Apache-2.0
//
// Adapted from LocalSend for GUETer local transfer integration.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../model/transfer_device.dart';
import '../model/transfer_file_models.dart';
import '../model/transfer_protocol_dto.dart';
import '../model/transfer_session.dart';
import 'certificate_service.dart';

typedef IncomingSessionHandler =
    Future<Map<String, String>?> Function(TransferSession session);
typedef ServerDeviceCallback = Future<void> Function(TransferDevice device);
typedef ServerLogCallback = void Function(String message);
typedef SessionChangedCallback = void Function(TransferSession session);
typedef SessionCanceledCallback =
    bool Function(String sessionId, String senderIp);
typedef SelfInfoProvider = TransferRegisterDto Function();

class TransferServer {
  TransferServer({
    required LocalTransferSecurityContext securityContext,
    required String saveDirectoryPath,
    required bool enableHttps,
    required ServerDeviceCallback onDeviceDiscovered,
    required IncomingSessionHandler onIncomingSession,
    required SessionChangedCallback onSessionChanged,
    required SessionCanceledCallback onCancelSendingSession,
    required ServerLogCallback onLog,
    required SelfInfoProvider selfInfoProvider,
  }) : _securityContext = securityContext,
       _saveDirectoryPath = saveDirectoryPath,
       _enableHttps = enableHttps,
       _onDeviceDiscovered = onDeviceDiscovered,
       _onIncomingSession = onIncomingSession,
       _onSessionChanged = onSessionChanged,
       _onCancelSendingSession = onCancelSendingSession,
       _onLog = onLog,
       _selfInfoProvider = selfInfoProvider;

  final LocalTransferSecurityContext _securityContext;
  final String _saveDirectoryPath;
  final bool _enableHttps;
  final ServerDeviceCallback _onDeviceDiscovered;
  final IncomingSessionHandler _onIncomingSession;
  final SessionChangedCallback _onSessionChanged;
  final SessionCanceledCallback _onCancelSendingSession;
  final ServerLogCallback _onLog;
  final SelfInfoProvider _selfInfoProvider;

  HttpServer? _server;
  TransferSession? _activeReceiveSession;

  int get port => _server?.port ?? 53317;
  String get protocol => _enableHttps ? 'https' : 'http';

  Future<int> start({int preferredPort = 53317}) async {
    if (_server != null) {
      return _server!.port;
    }

    Directory(_saveDirectoryPath).createSync(recursive: true);

    HttpServer server;
    try {
      server = await _bind(preferredPort);
    } on SocketException {
      server = await _bind(0);
    }
    _server = server;
    unawaited(_serve(server));
    _onLog('Transfer server listening on ${server.port} ($protocol).');
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _activeReceiveSession = null;
    await server?.close(force: true);
  }

  Future<HttpServer> _bind(int port) {
    if (_enableHttps) {
      final context = SecurityContext()
        ..usePrivateKeyBytes(_securityContext.privateKeyPem.codeUnits)
        ..useCertificateChainBytes(_securityContext.certificatePem.codeUnits);
      return HttpServer.bindSecure(InternetAddress.anyIPv4, port, context);
    }
    return HttpServer.bind(InternetAddress.anyIPv4, port);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final HttpRequest request in server) {
      unawaited(_handleRequest(request));
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (request.method == 'GET' && path == localTransferPingPath) {
        await _handlePing(request);
        return;
      }
      if (request.method == 'GET' && path == '/api/localsend/v2/info') {
        await _respondJson(request.response, 200, _buildInfo().toJson());
        return;
      }
      if (request.method == 'POST' && path == '/api/localsend/v2/register') {
        await _handleRegister(request);
        return;
      }
      if (request.method == 'POST' &&
          path == '/api/localsend/v2/prepare-upload') {
        await _handlePrepareUpload(request);
        return;
      }
      if (request.method == 'POST' && path == '/api/localsend/v2/upload') {
        await _handleUpload(request);
        return;
      }
      if (request.method == 'POST' && path == '/api/localsend/v2/cancel') {
        await _handleCancel(request);
        return;
      }
      await _respondJson(request.response, 404, <String, dynamic>{
        'message': 'Not found',
      });
    } catch (error) {
      _onLog('Server error: $error');
      await _respondJson(request.response, 500, <String, dynamic>{
        'message': error.toString(),
      });
    }
  }

  TransferInfoDto _buildInfo() {
    final self = _selfInfoProvider();
    return TransferInfoDto(
      alias: self.alias,
      version: self.version,
      deviceModel: self.deviceModel,
      deviceType: self.deviceType,
      fingerprint: self.fingerprint,
      download: self.download,
    );
  }

  Future<void> _handlePing(HttpRequest request) async {
    final self = _selfInfoProvider();
    final requesterInfo = _parsePingRequesterHeader(
      request.headers.value(localTransferPingSelfInfoHeader),
    );
    if (requesterInfo != null &&
        requesterInfo.fingerprint != self.fingerprint) {
      await _onDeviceDiscovered(
        requesterInfo.toDevice(
          ip: request.connectionInfo?.remoteAddress.address ?? '',
          discoveryMethod: 'ping',
          fallbackPort: 53317,
          fallbackProtocol: request.requestedUri.scheme,
        ),
      );
    }

    final responseBody = buildPingResponseBody(
      self: self,
      ip: request.requestedUri.host,
      port: port,
    );
    await _respondJson(request.response, 200, responseBody);
  }

  Future<void> _handleRegister(HttpRequest request) async {
    final payload = await utf8.decoder.bind(request).join();
    final dto = TransferRegisterDto.fromJson(
      (jsonDecode(payload) as Map).cast<String, dynamic>(),
    );
    final self = _selfInfoProvider();
    if (dto.fingerprint == self.fingerprint) {
      await _respondJson(request.response, 412, <String, dynamic>{
        'message': 'Self-discovered',
      });
      return;
    }

    await _onDeviceDiscovered(
      dto.toDevice(
        ip:
            request.connectionInfo?.remoteAddress.address ??
            request.headers.host ??
            '',
        discoveryMethod: 'register',
      ),
    );
    await _respondJson(request.response, 200, _buildInfo().toJson());
  }

  Future<void> _handlePrepareUpload(HttpRequest request) async {
    if (_activeReceiveSession != null) {
      await _respondJson(request.response, 409, <String, dynamic>{
        'message': 'Blocked by another session',
      });
      return;
    }

    final payload = await utf8.decoder.bind(request).join();
    final dto = TransferPrepareUploadRequestDto.fromJson(
      (jsonDecode(payload) as Map).cast<String, dynamic>(),
    );
    if (dto.files.isEmpty) {
      await _respondJson(request.response, 400, <String, dynamic>{
        'message': 'Request must contain at least one file',
      });
      return;
    }

    final self = _selfInfoProvider();
    if (dto.info.fingerprint == self.fingerprint) {
      await _respondJson(request.response, 412, <String, dynamic>{
        'message': 'Self-discovered',
      });
      return;
    }

    final senderIp = request.connectionInfo?.remoteAddress.address ?? '';
    final sessionId = _randomId();
    final message = _detectTextMessage(dto.files.values.toList());
    final entries = <String, TransferSessionEntry>{
      for (final TransferFileDescriptor file in dto.files.values)
        file.id: TransferSessionEntry(
          descriptor: file,
          sourceFile: null,
          status: TransferFileStatus.queued,
          token: null,
          bytesTransferred: 0,
          outputPath: null,
          errorMessage: null,
        ),
    };
    final session = TransferSession(
      localSessionId: sessionId,
      remoteSessionId: null,
      direction: TransferSessionDirection.receiving,
      device: dto.info.toDevice(ip: senderIp, discoveryMethod: 'incoming'),
      status: TransferSessionStatus.awaitingAcceptance,
      entries: message == null ? entries : <String, TransferSessionEntry>{},
      message: message,
      errorMessage: null,
      createdAt: DateTime.now(),
      startedAt: null,
      finishedAt: null,
    );
    _activeReceiveSession = session;
    _onSessionChanged(session);

    final selection = await _onIncomingSession(session);
    if (_activeReceiveSession == null) {
      await _respondJson(request.response, 500, <String, dynamic>{
        'message': 'Session unexpectedly closed',
      });
      return;
    }

    if (selection == null) {
      _activeReceiveSession = null;
      _onSessionChanged(
        session.copyWith(
          status: TransferSessionStatus.rejected,
          finishedAt: DateTime.now(),
        ),
      );
      await _respondJson(request.response, 403, <String, dynamic>{
        'message': 'Rejected',
      });
      return;
    }

    if (selection.isEmpty) {
      final finished = session.copyWith(
        status: TransferSessionStatus.finished,
        finishedAt: DateTime.now(),
      );
      _activeReceiveSession = null;
      _onSessionChanged(finished);
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }

    final updatedEntries = <String, TransferSessionEntry>{};
    final tokens = <String, String>{};
    for (final MapEntry<String, TransferSessionEntry> entry
        in session.entries.entries) {
      final desiredName = selection[entry.key];
      if (desiredName == null) {
        updatedEntries[entry.key] = entry.value.copyWith(
          status: TransferFileStatus.skipped,
        );
        continue;
      }
      final token = _randomId();
      tokens[entry.key] = token;
      updatedEntries[entry.key] = entry.value.copyWith(token: token);
    }
    final accepted = session.copyWith(
      status: TransferSessionStatus.sending,
      entries: updatedEntries,
      startedAt: DateTime.now(),
    );
    _activeReceiveSession = accepted;
    _onSessionChanged(accepted);
    await _respondJson(
      request.response,
      200,
      TransferPrepareUploadResponseDto(
        sessionId: sessionId,
        files: tokens,
      ).toJson(),
    );
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final session = _activeReceiveSession;
    if (session == null) {
      await _respondJson(request.response, 409, <String, dynamic>{
        'message': 'No active receive session',
      });
      return;
    }

    final senderIp = request.connectionInfo?.remoteAddress.address ?? '';
    if (senderIp != session.device.ip) {
      await _respondJson(request.response, 403, <String, dynamic>{
        'message': 'Invalid IP address',
      });
      return;
    }

    final fileId = request.uri.queryParameters['fileId'];
    final token = request.uri.queryParameters['token'];
    final sessionId = request.uri.queryParameters['sessionId'];
    if (fileId == null || token == null || sessionId == null) {
      await _respondJson(request.response, 400, <String, dynamic>{
        'message': 'Missing parameters',
      });
      return;
    }
    if (sessionId != session.localSessionId) {
      await _respondJson(request.response, 403, <String, dynamic>{
        'message': 'Invalid session id',
      });
      return;
    }

    final currentEntry = session.entries[fileId];
    if (currentEntry == null || currentEntry.token != token) {
      await _respondJson(request.response, 403, <String, dynamic>{
        'message': 'Invalid token',
      });
      return;
    }

    final sanitizedName = sanitizeFileName(currentEntry.descriptor.fileName);
    final finalPath = await _nextAvailableFilePath(
      baseDirectory: _saveDirectoryPath,
      fileName: sanitizedName,
    );
    final tempPath = '$finalPath.part';
    final sink = File(tempPath).openWrite();

    TransferSession updated = session.copyWith(
      entries: <String, TransferSessionEntry>{
        ...session.entries,
        fileId: currentEntry.copyWith(status: TransferFileStatus.sending),
      },
    );
    _activeReceiveSession = updated;
    _onSessionChanged(updated);

    int written = 0;
    try {
      await for (final List<int> chunk in request) {
        sink.add(chunk);
        written += chunk.length;
        final entry = updated.entries[fileId]!;
        updated = updated.copyWith(
          entries: <String, TransferSessionEntry>{
            ...updated.entries,
            fileId: entry.copyWith(bytesTransferred: written),
          },
        );
        _activeReceiveSession = updated;
        _onSessionChanged(updated);
      }
      await sink.flush();
      await sink.close();
      await File(tempPath).rename(finalPath);

      updated = updated.copyWith(
        entries: <String, TransferSessionEntry>{
          ...updated.entries,
          fileId: updated.entries[fileId]!.copyWith(
            status: TransferFileStatus.finished,
            bytesTransferred: written,
            outputPath: finalPath,
          ),
        },
      );
    } catch (error) {
      try {
        await sink.close();
      } catch (_) {
        // no-op
      }
      updated = updated.copyWith(
        entries: <String, TransferSessionEntry>{
          ...updated.entries,
          fileId: updated.entries[fileId]!.copyWith(
            status: TransferFileStatus.failed,
            errorMessage: error.toString(),
          ),
        },
        status: TransferSessionStatus.finishedWithErrors,
      );
    }

    final statuses = updated.entries.values.map((TransferSessionEntry item) {
      return item.status;
    }).toList();
    final allDone = statuses.every(
      (TransferFileStatus status) =>
          status == TransferFileStatus.finished ||
          status == TransferFileStatus.failed ||
          status == TransferFileStatus.skipped,
    );
    if (allDone) {
      updated = updated.copyWith(
        status: updated.hasFailures
            ? TransferSessionStatus.finishedWithErrors
            : TransferSessionStatus.finished,
        finishedAt: DateTime.now(),
      );
      _activeReceiveSession = null;
    } else {
      _activeReceiveSession = updated;
    }
    _onSessionChanged(updated);

    if (updated.entries[fileId]!.status == TransferFileStatus.finished) {
      await _respondJson(request.response, 200, const <String, dynamic>{});
      return;
    }
    await _respondJson(request.response, 500, <String, dynamic>{
      'message': updated.entries[fileId]!.errorMessage,
    });
  }

  Future<void> _handleCancel(HttpRequest request) async {
    final sessionId = request.uri.queryParameters['sessionId'];
    final senderIp = request.connectionInfo?.remoteAddress.address ?? '';
    final receiveSession = _activeReceiveSession;
    if (receiveSession != null && sessionId == receiveSession.localSessionId) {
      final canceled = receiveSession.copyWith(
        status: TransferSessionStatus.canceledBySender,
        finishedAt: DateTime.now(),
      );
      _activeReceiveSession = null;
      _onSessionChanged(canceled);
      await _respondJson(request.response, 200, const <String, dynamic>{});
      return;
    }

    if (sessionId != null && _onCancelSendingSession(sessionId, senderIp)) {
      await _respondJson(request.response, 200, const <String, dynamic>{});
      return;
    }

    await _respondJson(request.response, 403, <String, dynamic>{
      'message': 'No permission',
    });
  }

  Future<void> _respondJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}

Map<String, dynamic> buildPingResponseBody({
  required TransferRegisterDto self,
  required String ip,
  required int port,
}) {
  return <String, dynamic>{...self.toJson(), 'ip': ip, 'port': port};
}

TransferRegisterDto? parsePingRequesterHeader(String? rawHeader) {
  return _parsePingRequesterHeader(rawHeader);
}

TransferRegisterDto? _parsePingRequesterHeader(String? rawHeader) {
  if (rawHeader == null || rawHeader.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = utf8.decode(base64Decode(rawHeader.trim()));
    final json = jsonDecode(decoded);
    if (json is Map<String, dynamic>) {
      return TransferRegisterDto.fromJson(json);
    }
    if (json is Map) {
      return TransferRegisterDto.fromJson(json.cast<String, dynamic>());
    }
  } catch (_) {
    return null;
  }
  return null;
}

String sanitizeFileName(String name) {
  final trimmed = name.trim();
  final base = p.basename(trimmed);
  if (base.isEmpty || base == '.' || base == '..') {
    return 'received_file';
  }
  final sanitized = base
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[\x00-\x1F]'), '_')
      .replaceAll('..', '_')
      .trim();
  if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
    return 'received_file';
  }
  return sanitized;
}

Future<String> nextAvailableFilePath({
  required String baseDirectory,
  required String fileName,
}) {
  return _nextAvailableFilePath(
    baseDirectory: baseDirectory,
    fileName: fileName,
  );
}

Future<String> _nextAvailableFilePath({
  required String baseDirectory,
  required String fileName,
}) async {
  final extension = p.extension(fileName);
  final stem = extension.isEmpty
      ? fileName
      : p.basenameWithoutExtension(fileName);
  var candidate = p.join(baseDirectory, fileName);
  var counter = 1;
  while (await File(candidate).exists()) {
    candidate = p.join(baseDirectory, '$stem ($counter)$extension');
    counter += 1;
  }
  return candidate;
}

String? detectTextMessage(List<TransferFileDescriptor> files) {
  return _detectTextMessage(files);
}

String? _detectTextMessage(List<TransferFileDescriptor> files) {
  if (files.length != 1) {
    return null;
  }
  final file = files.first;
  if (!file.isTextLike) {
    return null;
  }
  final preview = file.preview?.trim();
  if (preview == null || preview.isEmpty) {
    return null;
  }
  return preview;
}

String _randomId() {
  final random = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '$random$salt';
}
