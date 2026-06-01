class TransferFileMetadataDto {
  const TransferFileMetadataDto({this.lastModified, this.lastAccessed});

  final String? lastModified;
  final String? lastAccessed;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (lastModified != null) 'modified': lastModified,
      if (lastAccessed != null) 'accessed': lastAccessed,
    };
  }

  factory TransferFileMetadataDto.fromJson(Map<String, dynamic> json) {
    return TransferFileMetadataDto(
      lastModified: json['modified']?.toString(),
      lastAccessed: json['accessed']?.toString(),
    );
  }
}

class TransferFileDescriptor {
  const TransferFileDescriptor({
    required this.id,
    required this.fileName,
    required this.size,
    required this.fileType,
    this.sha256,
    this.preview,
    this.metadata,
  });

  final String id;
  final String fileName;
  final int size;
  final String fileType;
  final String? sha256;
  final String? preview;
  final TransferFileMetadataDto? metadata;

  bool get isTextLike => fileType.startsWith('text/');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fileName': fileName,
      'size': size,
      'fileType': fileType,
      if (sha256 != null) 'sha256': sha256,
      if (preview != null) 'preview': preview,
      if (metadata != null) 'metadata': metadata!.toJson(),
    };
  }

  factory TransferFileDescriptor.fromJson(Map<String, dynamic> json) {
    return TransferFileDescriptor(
      id: json['id']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      fileType: json['fileType']?.toString() ?? 'application/octet-stream',
      sha256: json['sha256']?.toString(),
      preview: json['preview']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? TransferFileMetadataDto.fromJson(
              json['metadata'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
