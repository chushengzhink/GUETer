import 'dart:convert';

import 'package:dio/dio.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.tag,
    required this.releaseNotes,
    required this.apk,
    required this.publishedAt,
  });

  final String version;
  final int buildNumber;
  final String tag;
  final String releaseNotes;
  final UpdateApkInfo apk;
  final DateTime? publishedAt;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString().trim() ?? '';
    final apkRaw = json['apk'];
    if (version.isEmpty) {
      throw const FormatException('update version is empty');
    }
    if (apkRaw is! Map) {
      throw const FormatException('update apk is missing');
    }

    return UpdateInfo(
      version: version,
      buildNumber: _intValue(json['buildNumber']),
      tag: json['tag']?.toString() ?? version,
      releaseNotes: json['releaseNotes']?.toString() ?? '暂无更新说明',
      apk: UpdateApkInfo.fromJson(
        apkRaw.map((key, value) => MapEntry('$key', value)),
      ),
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
    );
  }

  bool isNewerThan(String currentVersion) {
    return isNewerVersion(version, currentVersion);
  }

  static bool isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (var i = 0; i < 3; i++) {
        final latestNum = i < latestParts.length ? latestParts[i] : 0;
        final currentNum = i < currentParts.length ? currentParts[i] : 0;

        if (latestNum > currentNum) return true;
        if (latestNum < currentNum) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class UpdateApkInfo {
  const UpdateApkInfo({
    required this.abi,
    required this.fileName,
    required this.downloadUrl,
  });

  final String abi;
  final String fileName;
  final String downloadUrl;

  factory UpdateApkInfo.fromJson(Map<String, dynamic> json) {
    final downloadUrl = json['downloadUrl']?.toString().trim() ?? '';
    if (downloadUrl.isEmpty) {
      throw const FormatException('update apk downloadUrl is empty');
    }
    return UpdateApkInfo(
      abi: json['abi']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      downloadUrl: downloadUrl,
    );
  }
}

class UpdateService {
  UpdateService({
    Dio? dio,
    String folderUrl = const String.fromEnvironment(
      'GUETER_UPDATE_FOLDER_URL',
      defaultValue: defaultFolderUrl,
    ),
    String folderPassword = const String.fromEnvironment(
      'GUETER_UPDATE_FOLDER_PASSWORD',
      defaultValue: defaultFolderPassword,
    ),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               validateStatus: (status) => status != null && status < 500,
             ),
           ),
       _folderUrl = folderUrl,
       _folderPassword = folderPassword;

  static const String defaultFolderUrl = 'https://wwbix.lanzouu.com/b0188dwqsd';
  static const String defaultFolderPassword = '7ls6';

  final Dio _dio;
  final String _folderUrl;
  final String _folderPassword;

  Future<UpdateInfo> fetchLatest() async {
    final folderUri = Uri.parse(_folderUrl);
    final pageResponse = await _dio.get<String>(
      _folderUrl,
      options: Options(responseType: ResponseType.plain),
    );
    _ensureSuccess(pageResponse);

    final html = pageResponse.data ?? '';
    final params = LanzouFolderParams.parse(html, folderUri);
    final cookie = _cookieHeader(pageResponse.headers);
    final files = await _fetchFolderFiles(params, cookie);
    final apkEntry = _selectLatestApk(files);
    final metadata = _metadataFromApkEntry(apkEntry, params.origin);

    final updateEntry = _selectLatestUpdateText(files);
    if (updateEntry == null) {
      return metadata;
    }

    final fromText = await _tryFetchUpdateTextMetadata(
      updateEntry,
      params.origin,
    );
    if (fromText == null) {
      return metadata;
    }

    return UpdateInfo(
      version: fromText.version,
      buildNumber: fromText.buildNumber,
      tag: fromText.tag,
      releaseNotes: fromText.releaseNotes,
      apk: metadata.apk,
      publishedAt: fromText.publishedAt,
    );
  }

  Future<List<LanzouFileEntry>> _fetchFolderFiles(
    LanzouFolderParams params,
    String? cookie,
  ) async {
    final response = await _dio.post<dynamic>(
      params.listUrl,
      data: <String, dynamic>{
        'lx': 2,
        'fid': params.fid,
        'uid': params.uid,
        'pg': 1,
        'rep': 0,
        't': params.t,
        'k': params.k,
        'up': 1,
        'ls': 1,
        'pwd': _folderPassword,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: <String, dynamic>{
          if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
          'Referer': _folderUrl,
        },
      ),
    );
    _ensureSuccess(response);

    final map = _asJsonMap(response.data);
    if (map['zt']?.toString() != '1') {
      throw FormatException(
        'lanzou folder list failed: ${map['info'] ?? 'unknown'}',
      );
    }

    final text = map['text'];
    if (text is! List) {
      throw const FormatException('lanzou folder list is missing files');
    }

    return text
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) => LanzouFileEntry.fromJson(raw))
        .where((entry) => entry.id.isNotEmpty && entry.id != '-1')
        .toList();
  }

  Future<UpdateInfo?> _tryFetchUpdateTextMetadata(
    LanzouFileEntry updateEntry,
    String origin,
  ) async {
    try {
      final response = await _dio.get<String>(
        updateEntry.downloadUrl(origin),
        options: Options(responseType: ResponseType.plain),
      );
      _ensureSuccess(response);
      final pageOrText = response.data ?? '';
      final jsonText = _extractJsonObject(pageOrText);
      if (jsonText == null) {
        return null;
      }
      return UpdateInfo.fromJson(_decodeJsonMap(jsonText));
    } catch (_) {
      return null;
    }
  }

  static LanzouFileEntry _selectLatestApk(List<LanzouFileEntry> files) {
    final matches = files
        .where((entry) => entry.apkVersionMatch != null)
        .toList();
    if (matches.isEmpty) {
      throw const FormatException('lanzou folder has no GUETer arm64 apk');
    }
    return matches.first;
  }

  static LanzouFileEntry? _selectLatestUpdateText(List<LanzouFileEntry> files) {
    for (final entry in files) {
      if (entry.name == 'update.txt') {
        return entry;
      }
    }
    return null;
  }

  static UpdateInfo _metadataFromApkEntry(
    LanzouFileEntry entry,
    String origin,
  ) {
    final match = entry.apkVersionMatch;
    if (match == null) {
      throw const FormatException(
        'apk file name is not a GUETer arm64 release',
      );
    }

    final version = match.group(1)!;
    final buildNumber = int.parse(match.group(2)!);
    return UpdateInfo(
      version: version,
      buildNumber: buildNumber,
      tag: '$version+$buildNumber',
      releaseNotes: '发现 GUETer 新版本，点击前往蓝奏云下载。',
      apk: UpdateApkInfo(
        abi: 'arm64-v8a',
        fileName: entry.name,
        downloadUrl: entry.downloadUrl(origin),
      ),
      publishedAt: null,
    );
  }

  static Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry('$key', value));
    }
    if (data is String) {
      return _decodeJsonMap(data);
    }
    throw const FormatException('response is not JSON');
  }

  static Map<String, dynamic> _decodeJsonMap(String text) {
    final normalized = text.startsWith('\uFEFF') ? text.substring(1) : text;
    final decoded = json.decode(normalized);
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry('$key', value));
    }
    throw const FormatException('update response JSON is not an object');
  }

  static String? _extractJsonObject(String text) {
    final normalized = text.startsWith('\uFEFF')
        ? text.substring(1)
        : text.trim();
    if (normalized.startsWith('{') && normalized.endsWith('}')) {
      return normalized;
    }
    final start = normalized.indexOf('{');
    final end = normalized.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return normalized.substring(start, end + 1);
    }
    return null;
  }

  static void _ensureSuccess(Response<dynamic> response) {
    final status = response.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw DioException.badResponse(
        statusCode: status ?? 0,
        requestOptions: response.requestOptions,
        response: response,
      );
    }
  }

  static String? _cookieHeader(Headers headers) {
    final values = headers['set-cookie'];
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.map((value) => value.split(';').first).join('; ');
  }
}

class LanzouFolderParams {
  const LanzouFolderParams({
    required this.origin,
    required this.fid,
    required this.uid,
    required this.t,
    required this.k,
  });

  final String origin;
  final String fid;
  final String uid;
  final String t;
  final String k;

  String get listUrl => '$origin/filemoreajax.php?file=$fid';

  static LanzouFolderParams parse(String html, Uri folderUri) {
    final origin = '${folderUri.scheme}://${folderUri.host}';
    final fid =
        _firstMatch(html, [
          RegExp(r'filemoreajax\.php\?file=(\d+)'),
          RegExp(r"'fid'\s*:\s*'?(\d+)'?"),
          RegExp(r"\bfid\s*:\s*'?(\d+)'?"),
        ]) ??
        (throw const FormatException('lanzou folder fid is missing'));
    final uid =
        _firstMatch(html, [
          RegExp(r"'uid'\s*:\s*'(\d+)'"),
          RegExp(r"\buid\s*:\s*'?(\d+)'?"),
        ]) ??
        (throw const FormatException('lanzou folder uid is missing'));
    final t =
        _ajaxDataValue(html, 't') ??
        _firstMatch(html, [RegExp(r"var\s+ibjbqp\s*=\s*'([^']+)'")]) ??
        (throw const FormatException('lanzou folder t is missing'));
    final k =
        _ajaxDataValue(html, 'k') ??
        _firstMatch(html, [RegExp(r"var\s+_hhnsi\s*=\s*'([^']+)'")]) ??
        (throw const FormatException('lanzou folder k is missing'));

    return LanzouFolderParams(origin: origin, fid: fid, uid: uid, t: t, k: k);
  }

  static String? _firstMatch(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  static String? _ajaxDataValue(String html, String key) {
    final literal = RegExp(
      "'${RegExp.escape(key)}'\\s*:\\s*'([^']+)'",
    ).firstMatch(html);
    if (literal != null) {
      return literal.group(1);
    }

    final variable = RegExp(
      "'${RegExp.escape(key)}'\\s*:\\s*([A-Za-z_][A-Za-z0-9_]*)",
    ).firstMatch(html);
    final variableName = variable?.group(1);
    if (variableName == null) {
      return null;
    }
    return RegExp(
      "var\\s+${RegExp.escape(variableName)}\\s*=\\s*'([^']+)'",
    ).firstMatch(html)?.group(1);
  }
}

class LanzouFileEntry {
  const LanzouFileEntry({
    required this.id,
    required this.name,
    required this.size,
    required this.time,
    required this.icon,
  });

  final String id;
  final String name;
  final String size;
  final String time;
  final String icon;

  static final RegExp _apkPattern = RegExp(
    r'^GUETer_(\d+\.\d+\.\d+)\+(\d+)_arm64-v8a\.apk$',
  );

  RegExpMatch? get apkVersionMatch => _apkPattern.firstMatch(name);

  factory LanzouFileEntry.fromJson(Map<dynamic, dynamic> json) {
    return LanzouFileEntry(
      id: json['id']?.toString() ?? '',
      name: json['name_all']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
    );
  }

  String downloadUrl(String origin) {
    if (id.startsWith('http://') || id.startsWith('https://')) {
      return id;
    }
    return '$origin/$id';
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
