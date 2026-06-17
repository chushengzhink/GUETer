class KetangpaiResourceLink {
  const KetangpaiResourceLink({
    required this.url,
    required this.name,
    this.sizeBytes,
  });

  final String url;
  final String name;
  final int? sizeBytes;
}

int ketangpaiContentTypeOf(Map<String, dynamic> item) {
  return int.tryParse(
        item['contenttype']?.toString() ??
            item['contentType']?.toString() ??
            item['type']?.toString() ??
            '',
      ) ??
      -1;
}

String ketangpaiTitleOf(
  Map<String, dynamic> item, {
  String fallback = 'ketangpai_file',
}) {
  for (final key in const <String>[
    'title',
    'name',
    'filename',
    'fileName',
    'resourcename',
    'resourceName',
  ]) {
    final value = item[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return fallback;
}

String ketangpaiSubtitleOf(Map<String, dynamic> item) {
  final fields = <String>[
    item['activitylabel']?.toString() ?? '',
    item['begintime']?.toString() ?? '',
    item['endtime']?.toString() ?? '',
    item['createtime']?.toString() ?? '',
    item['updatetime']?.toString() ?? '',
  ].where((value) => value.trim().isNotEmpty).toList();
  return fields.take(2).join('  |  ');
}

List<KetangpaiResourceLink> extractKetangpaiResourceLinks(
  Map<String, dynamic> item,
) {
  final links = <KetangpaiResourceLink>[];
  final seen = <String>{};

  void addLink(dynamic rawUrl, {dynamic rawName, dynamic rawSize}) {
    final url = _normalizeResourceUrl(rawUrl);
    if (url.isEmpty || !seen.add(url)) return;
    final name = _resourceName(rawName, url);
    links.add(
      KetangpaiResourceLink(
        url: url,
        name: name,
        sizeBytes: _intOrNull(rawSize),
      ),
    );
  }

  void scanMap(Map map) {
    final normalized = map.map((key, value) => MapEntry(key.toString(), value));
    for (final key in const <String>[
      'url',
      'downloadurl',
      'downloadUrl',
      'fileurl',
      'fileUrl',
      'previewurl',
      'previewUrl',
      'link',
      'href',
      'path',
    ]) {
      addLink(
        normalized[key],
        rawName:
            normalized['name'] ??
            normalized['filename'] ??
            normalized['fileName'] ??
            normalized['title'],
        rawSize:
            normalized['size'] ??
            normalized['filesize'] ??
            normalized['fileSize'],
      );
    }
  }

  scanMap(item);
  for (final key in const <String>[
    'attachments',
    'attachment',
    'files',
    'filelist',
    'fileList',
    'resources',
    'data',
  ]) {
    final value = item[key];
    if (value is List) {
      for (final entry in value) {
        if (entry is Map) {
          scanMap(entry);
        } else {
          addLink(entry);
        }
      }
    } else if (value is Map) {
      scanMap(value);
    }
  }
  return links;
}

String _normalizeResourceUrl(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  if (text.startsWith('//')) return 'https:$text';
  if (text.startsWith('http://') || text.startsWith('https://')) return text;
  if (text.startsWith('/')) return 'https://openapiv5.ketangpai.com$text';
  return '';
}

String _resourceName(dynamic value, String url) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isNotEmpty) return raw;
  final uri = Uri.tryParse(url);
  final segment = uri?.pathSegments.isNotEmpty == true
      ? uri!.pathSegments.last
      : '';
  return Uri.decodeComponent(segment.isNotEmpty ? segment : 'ketangpai_file');
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
