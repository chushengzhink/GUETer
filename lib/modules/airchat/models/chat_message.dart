class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isRead = false,
    this.type = 'text',
    this.fileName,
    this.filePath,
    this.mimeType,
    this.transferProgress,
    this.status,
  });

  final int id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isRead;
  final String type;
  final String? fileName;
  final String? filePath;
  final String? mimeType;
  final double? transferProgress;
  final int? status;

  ChatMessage copyWith({
    int? id,
    String? senderId,
    String? text,
    DateTime? timestamp,
    bool? isMe,
    bool? isRead,
    String? type,
    String? fileName,
    String? filePath,
    String? mimeType,
    double? transferProgress,
    int? status,
    bool clearFileName = false,
    bool clearFilePath = false,
    bool clearMimeType = false,
    bool clearTransferProgress = false,
    bool clearStatus = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      fileName: clearFileName ? null : (fileName ?? this.fileName),
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      mimeType: clearMimeType ? null : (mimeType ?? this.mimeType),
      transferProgress: clearTransferProgress
          ? null
          : (transferProgress ?? this.transferProgress),
      status: clearStatus ? null : (status ?? this.status),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe,
      'isRead': isRead,
      'type': type,
      'fileName': fileName,
      'filePath': filePath,
      'mimeType': mimeType,
      'transferProgress': transferProgress,
      'status': status,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      senderId: json['senderId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isMe: json['isMe'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      type: json['type'] as String? ?? 'text',
      fileName: json['fileName'] as String?,
      filePath: json['filePath'] as String?,
      mimeType: json['mimeType'] as String?,
      transferProgress: (json['transferProgress'] as num?)?.toDouble(),
      status: (json['status'] as num?)?.toInt(),
    );
  }
}
