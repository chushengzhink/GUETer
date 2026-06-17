enum MaterialSourceType {
  openListDownload('openlist_download'),
  offlinePackage('offline_package'),
  fileToolOutput('file_tool_output'),
  studySource('study_source'),
  webArchive('web_archive');

  const MaterialSourceType(this.id);

  final String id;

  static MaterialSourceType fromId(String id) {
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => MaterialSourceType.fileToolOutput,
    );
  }
}

class MaterialIndexEntry {
  const MaterialIndexEntry({
    required this.id,
    required this.path,
    required this.name,
    required this.sourceType,
    required this.sourceLabel,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.indexedAt,
    this.content = '',
    this.error,
  });

  final String id;
  final String path;
  final String name;
  final MaterialSourceType sourceType;
  final String sourceLabel;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime indexedAt;
  final String content;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'path': path,
      'name': name,
      'sourceType': sourceType.id,
      'sourceLabel': sourceLabel,
      'sizeBytes': sizeBytes,
      'modifiedAt': modifiedAt.toIso8601String(),
      'indexedAt': indexedAt.toIso8601String(),
      'content': content,
      'error': error,
    };
  }

  factory MaterialIndexEntry.fromJson(Map<String, Object?> json) {
    return MaterialIndexEntry(
      id: json['id']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sourceType: MaterialSourceType.fromId(
        json['sourceType']?.toString() ?? '',
      ),
      sourceLabel: json['sourceLabel']?.toString() ?? '',
      sizeBytes: _intValue(json['sizeBytes']),
      modifiedAt:
          DateTime.tryParse(json['modifiedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      indexedAt:
          DateTime.tryParse(json['indexedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      content: json['content']?.toString() ?? '',
      error: json['error']?.toString(),
    );
  }
}

class MaterialSearchResult {
  const MaterialSearchResult({
    required this.entry,
    required this.snippet,
    required this.score,
  });

  final MaterialIndexEntry entry;
  final String snippet;
  final int score;
}

class MaterialIndexSummary {
  const MaterialIndexSummary({
    required this.total,
    required this.indexed,
    required this.failed,
    required this.updatedAt,
  });

  final int total;
  final int indexed;
  final int failed;
  final DateTime? updatedAt;
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
