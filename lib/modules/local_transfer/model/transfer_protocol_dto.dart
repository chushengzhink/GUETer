import 'transfer_device.dart';
import 'transfer_file_models.dart';

const String localTransferPingPath = '/ping';
const String localTransferPingSelfInfoHeader = 'x-localtransfer-self-info';

class TransferRegisterDto {
  const TransferRegisterDto({
    required this.alias,
    required this.version,
    required this.deviceModel,
    required this.deviceType,
    required this.fingerprint,
    required this.port,
    required this.protocol,
    required this.download,
    this.announce,
  });

  final String alias;
  final String version;
  final String? deviceModel;
  final String? deviceType;
  final String fingerprint;
  final int port;
  final String protocol;
  final bool download;
  final bool? announce;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'alias': alias,
      'version': version,
      'deviceModel': deviceModel,
      'deviceType': deviceType,
      'fingerprint': fingerprint,
      'port': port,
      'protocol': protocol,
      'download': download,
      if (announce != null) 'announce': announce,
    };
  }

  factory TransferRegisterDto.fromJson(Map<String, dynamic> json) {
    return TransferRegisterDto(
      alias: json['alias']?.toString() ?? '',
      version: json['version']?.toString() ?? '2.0',
      deviceModel: json['deviceModel']?.toString(),
      deviceType: json['deviceType']?.toString(),
      fingerprint: json['fingerprint']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ?? 53317,
      protocol: json['protocol']?.toString() ?? 'https',
      download: json['download'] == true,
      announce: json['announce'] as bool?,
    );
  }

  TransferDevice toDevice({
    required String ip,
    String discoveryMethod = 'udp',
    int? fallbackPort,
    String? fallbackProtocol,
  }) {
    return TransferDevice(
      ip: ip,
      port: port == 0 ? (fallbackPort ?? 53317) : port,
      alias: alias,
      version: version,
      deviceModel: deviceModel,
      deviceType: deviceType,
      fingerprint: fingerprint,
      protocol: protocol.isEmpty ? (fallbackProtocol ?? 'https') : protocol,
      download: download,
      discoveryMethod: discoveryMethod,
      lastSeen: DateTime.now(),
    );
  }
}

class TransferInfoDto {
  const TransferInfoDto({
    required this.alias,
    required this.version,
    required this.deviceModel,
    required this.deviceType,
    required this.fingerprint,
    required this.download,
  });

  final String alias;
  final String version;
  final String? deviceModel;
  final String? deviceType;
  final String fingerprint;
  final bool download;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'alias': alias,
      'version': version,
      'deviceModel': deviceModel,
      'deviceType': deviceType,
      'fingerprint': fingerprint,
      'download': download,
    };
  }

  factory TransferInfoDto.fromJson(Map<String, dynamic> json) {
    return TransferInfoDto(
      alias: json['alias']?.toString() ?? '',
      version: json['version']?.toString() ?? '2.0',
      deviceModel: json['deviceModel']?.toString(),
      deviceType: json['deviceType']?.toString(),
      fingerprint: json['fingerprint']?.toString() ?? '',
      download: json['download'] == true,
    );
  }
}

class TransferPrepareUploadRequestDto {
  const TransferPrepareUploadRequestDto({
    required this.info,
    required this.files,
  });

  final TransferRegisterDto info;
  final Map<String, TransferFileDescriptor> files;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'info': info.toJson(),
      'files': files.map(
        (String key, TransferFileDescriptor value) =>
            MapEntry<String, dynamic>(key, value.toJson()),
      ),
    };
  }

  factory TransferPrepareUploadRequestDto.fromJson(Map<String, dynamic> json) {
    final rawFiles =
        json['files'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return TransferPrepareUploadRequestDto(
      info: TransferRegisterDto.fromJson(
        (json['info'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      files: rawFiles.map(
        (String key, dynamic value) => MapEntry<String, TransferFileDescriptor>(
          key,
          TransferFileDescriptor.fromJson(
            (value as Map).cast<String, dynamic>(),
          ),
        ),
      ),
    );
  }
}

class TransferPrepareUploadResponseDto {
  const TransferPrepareUploadResponseDto({
    required this.sessionId,
    required this.files,
  });

  final String sessionId;
  final Map<String, String> files;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'sessionId': sessionId, 'files': files};
  }

  factory TransferPrepareUploadResponseDto.fromJson(Map<String, dynamic> json) {
    return TransferPrepareUploadResponseDto(
      sessionId: json['sessionId']?.toString() ?? '',
      files:
          (json['files'] as Map?)?.cast<String, String>() ?? <String, String>{},
    );
  }
}
