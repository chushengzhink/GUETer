import 'dart:convert';

enum WebArchiveStatus {
  saved('saved'),
  fetchError('fetchError'),
  missing('missing'),
  archived('archived'),
  ignored('ignored');

  const WebArchiveStatus(this.id);

  final String id;

  static WebArchiveStatus fromId(String id) {
    return values.firstWhere(
      (status) => status.id == id,
      orElse: () => WebArchiveStatus.saved,
    );
  }
}

class WebArchiveItem {
  const WebArchiveItem({
    required this.id,
    required this.url,
    required this.title,
    this.description = '',
    this.siteName = '',
    this.faviconUrl = '',
    this.textSnapshotPath = '',
    this.sourceHtmlPath = '',
    this.tags = const <String>[],
    this.status = WebArchiveStatus.saved,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
  });

  final String id;
  final String url;
  final String title;
  final String description;
  final String siteName;
  final String faviconUrl;
  final String textSnapshotPath;
  final String sourceHtmlPath;
  final List<String> tags;
  final WebArchiveStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastOpenedAt;

  String get displayTitle => title.trim().isNotEmpty ? title.trim() : url;
  bool get hasTextSnapshot => textSnapshotPath.trim().isNotEmpty;

  WebArchiveItem copyWith({
    String? id,
    String? url,
    String? title,
    String? description,
    String? siteName,
    String? faviconUrl,
    String? textSnapshotPath,
    String? sourceHtmlPath,
    List<String>? tags,
    WebArchiveStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastOpenedAt,
  }) {
    return WebArchiveItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      description: description ?? this.description,
      siteName: siteName ?? this.siteName,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      textSnapshotPath: textSnapshotPath ?? this.textSnapshotPath,
      sourceHtmlPath: sourceHtmlPath ?? this.sourceHtmlPath,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'url': url,
      'title': title,
      'description': description,
      'siteName': siteName,
      'faviconUrl': faviconUrl,
      'textSnapshotPath': textSnapshotPath,
      'sourceHtmlPath': sourceHtmlPath,
      'tags': tags,
      'status': status.id,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastOpenedAt': lastOpenedAt?.toIso8601String(),
    };
  }

  factory WebArchiveItem.fromJson(Map<String, Object?> json) {
    final url = json['url']?.toString() ?? '';
    return WebArchiveItem(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString()
          : base64Url.encode(utf8.encode(url)).replaceAll('=', ''),
      url: url,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      siteName: json['siteName']?.toString() ?? '',
      faviconUrl: json['faviconUrl']?.toString() ?? '',
      textSnapshotPath: json['textSnapshotPath']?.toString() ?? '',
      sourceHtmlPath: json['sourceHtmlPath']?.toString() ?? '',
      tags:
          (json['tags'] as List?)
              ?.whereType<String>()
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList() ??
          const <String>[],
      status: WebArchiveStatus.fromId(json['status']?.toString() ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt']?.toString() ?? ''),
    );
  }
}
