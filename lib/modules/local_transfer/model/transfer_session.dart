import 'transfer_device.dart';
import 'transfer_file_models.dart';
import 'transfer_source_file.dart';

enum TransferSessionDirection { sending, receiving }

enum TransferSessionStatus {
  waiting,
  awaitingAcceptance,
  sending,
  finished,
  finishedWithErrors,
  rejected,
  canceledBySender,
  canceledByReceiver,
  error,
}

enum TransferFileStatus { queued, sending, finished, failed, skipped }

class TransferSessionEntry {
  const TransferSessionEntry({
    required this.descriptor,
    required this.sourceFile,
    required this.status,
    required this.token,
    required this.bytesTransferred,
    required this.outputPath,
    required this.errorMessage,
  });

  final TransferFileDescriptor descriptor;
  final TransferSourceFile? sourceFile;
  final TransferFileStatus status;
  final String? token;
  final int bytesTransferred;
  final String? outputPath;
  final String? errorMessage;

  double get progress => descriptor.size <= 0
      ? (status == TransferFileStatus.finished ? 1 : 0)
      : bytesTransferred / descriptor.size;

  TransferSessionEntry copyWith({
    TransferFileDescriptor? descriptor,
    TransferSourceFile? sourceFile,
    TransferFileStatus? status,
    String? token,
    int? bytesTransferred,
    String? outputPath,
    String? errorMessage,
    bool clearOutputPath = false,
    bool clearErrorMessage = false,
  }) {
    return TransferSessionEntry(
      descriptor: descriptor ?? this.descriptor,
      sourceFile: sourceFile ?? this.sourceFile,
      status: status ?? this.status,
      token: token ?? this.token,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      outputPath: clearOutputPath ? null : outputPath ?? this.outputPath,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class TransferSession {
  const TransferSession({
    required this.localSessionId,
    required this.remoteSessionId,
    required this.direction,
    required this.device,
    required this.status,
    required this.entries,
    required this.message,
    required this.errorMessage,
    required this.createdAt,
    required this.startedAt,
    required this.finishedAt,
    this.sourceLabel,
  });

  final String localSessionId;
  final String? remoteSessionId;
  final TransferSessionDirection direction;
  final TransferDevice device;
  final TransferSessionStatus status;
  final Map<String, TransferSessionEntry> entries;
  final String? message;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? sourceLabel;

  bool get isMessageOnly => message != null && entries.isEmpty;

  int get totalBytes =>
      entries.values.fold<int>(0, (int sum, TransferSessionEntry item) {
        return sum + item.descriptor.size;
      });

  int get transferredBytes => entries.values.fold<int>(
    0,
    (int sum, TransferSessionEntry item) => sum + item.bytesTransferred,
  );

  double get overallProgress => totalBytes <= 0
      ? (status == TransferSessionStatus.finished ? 1 : 0)
      : transferredBytes / totalBytes;

  bool get hasFailures => entries.values.any(
    (TransferSessionEntry item) => item.status == TransferFileStatus.failed,
  );

  TransferSession copyWith({
    String? localSessionId,
    String? remoteSessionId,
    bool clearRemoteSessionId = false,
    TransferSessionDirection? direction,
    TransferDevice? device,
    TransferSessionStatus? status,
    Map<String, TransferSessionEntry>? entries,
    String? message,
    bool clearMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    DateTime? createdAt,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    String? sourceLabel,
    bool clearSourceLabel = false,
  }) {
    return TransferSession(
      localSessionId: localSessionId ?? this.localSessionId,
      remoteSessionId: clearRemoteSessionId
          ? null
          : remoteSessionId ?? this.remoteSessionId,
      direction: direction ?? this.direction,
      device: device ?? this.device,
      status: status ?? this.status,
      entries: entries ?? this.entries,
      message: clearMessage ? null : message ?? this.message,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
      sourceLabel: clearSourceLabel ? null : sourceLabel ?? this.sourceLabel,
    );
  }
}
