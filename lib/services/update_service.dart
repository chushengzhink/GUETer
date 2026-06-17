import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.tag,
    required this.releaseNotes,
    required this.apk,
    required this.publishedAt,
    required this.announcements,
    this.metadataSource = 'update.txt',
    this.metadataWarning,
    this.forceUpdate = false,
    this.forceFromVersions = const <String>[],
    this.minSupportedVersion,
  });

  final String version;
  final int buildNumber;
  final String tag;
  final String releaseNotes;
  final UpdateApkInfo apk;
  final DateTime? publishedAt;
  final List<UpdateAnnouncement> announcements;
  final String metadataSource;
  final String? metadataWarning;
  final bool forceUpdate;
  final List<String> forceFromVersions;
  final String? minSupportedVersion;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString().trim() ?? '';
    final apkRaw = json['apk'];
    if (version.isEmpty) {
      throw const FormatException('update version is empty');
    }
    if (apkRaw is! Map) {
      throw const FormatException('update apk is missing');
    }

    final releaseNotes = json['releaseNotes']?.toString() ?? '暂无更新说明';
    final tag = json['tag']?.toString() ?? version;
    final publishedAt = DateTime.tryParse(
      json['publishedAt']?.toString() ?? '',
    );

    return UpdateInfo(
      version: version,
      buildNumber: _intValue(json['buildNumber']),
      tag: tag,
      releaseNotes: releaseNotes,
      apk: UpdateApkInfo.fromJson(
        apkRaw.map((key, value) => MapEntry('$key', value)),
      ),
      publishedAt: publishedAt,
      announcements: _announcementListValue(
        json['announcements'],
        fallback: UpdateAnnouncement.fromReleaseInfo(
          version: version,
          buildNumber: _intValue(json['buildNumber']),
          tag: tag,
          publishedAt: publishedAt,
          releaseNotes: releaseNotes,
        ),
      ),
      metadataSource: json['metadataSource']?.toString() ?? 'update.txt',
      metadataWarning: _optionalTrimmedString(json['metadataWarning']),
      forceUpdate: _boolValue(json['forceUpdate']),
      forceFromVersions: _stringListValue(json['forceFromVersions']),
      minSupportedVersion: _optionalTrimmedString(json['minSupportedVersion']),
    );
  }

  bool isNewerThan(String currentVersion) {
    return isNewerVersion(version, currentVersion);
  }

  bool isForcedFor(String currentVersion) {
    if (!forceUpdate) {
      return false;
    }

    final normalizedCurrent = _normalizeVersion(currentVersion);
    if (normalizedCurrent == null) {
      return false;
    }

    if (forceFromVersions.isNotEmpty) {
      return forceFromVersions.any(
        (candidate) => _normalizeVersion(candidate) == normalizedCurrent,
      );
    }

    final minimum = minSupportedVersion;
    if (minimum != null && minimum.isNotEmpty) {
      return isNewerVersion(minimum, currentVersion);
    }

    return isNewerThan(currentVersion);
  }

  static bool isNewerVersion(String latest, String current) {
    try {
      final latestParts = _parseVersionParts(latest);
      final currentParts = _parseVersionParts(current);
      if (latestParts == null || currentParts == null) {
        return false;
      }

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

class UpdateAnnouncement {
  const UpdateAnnouncement({
    required this.version,
    required this.buildNumber,
    required this.tag,
    required this.title,
    required this.notes,
    this.publishedAt,
  });

  final String version;
  final int buildNumber;
  final String tag;
  final String title;
  final List<String> notes;
  final DateTime? publishedAt;

  factory UpdateAnnouncement.fromJson(Map<String, dynamic> json) {
    final version = json['version']?.toString().trim() ?? '';
    if (version.isEmpty) {
      throw const FormatException('announcement version is empty');
    }
    final buildNumber = _intValue(json['buildNumber']);
    final tag = json['tag']?.toString().trim() ?? version;
    final notes = _stringListValue(json['notes']);
    final releaseNotes = json['releaseNotes']?.toString().trim() ?? '';
    return UpdateAnnouncement(
      version: version,
      buildNumber: buildNumber,
      tag: tag,
      title: json['title']?.toString().trim() ?? 'GUETer $version 更新公告',
      notes: notes.isNotEmpty
          ? notes
          : _splitReleaseNotes(releaseNotes.isEmpty ? '暂无更新说明' : releaseNotes),
      publishedAt: DateTime.tryParse(json['publishedAt']?.toString() ?? ''),
    );
  }

  factory UpdateAnnouncement.fromReleaseInfo({
    required String version,
    required int buildNumber,
    required String tag,
    required DateTime? publishedAt,
    required String releaseNotes,
  }) {
    return UpdateAnnouncement(
      version: version,
      buildNumber: buildNumber,
      tag: tag,
      title: 'GUETer $version 更新公告',
      notes: _splitReleaseNotes(releaseNotes),
      publishedAt: publishedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'buildNumber': buildNumber,
      'tag': tag,
      'title': title,
      'notes': notes,
      if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
    };
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

class UpdateCheckStatus {
  const UpdateCheckStatus({
    required this.currentVersion,
    required this.latestVersion,
    required this.hasUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.checkedAt,
  });

  final String currentVersion;
  final String latestVersion;
  final bool hasUpdate;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime checkedAt;

  factory UpdateCheckStatus.fromInfo({
    required String currentVersion,
    required UpdateInfo info,
    DateTime? checkedAt,
  }) {
    final displayNotes = info.metadataWarning ?? info.releaseNotes;
    return UpdateCheckStatus(
      currentVersion: currentVersion,
      latestVersion: info.version,
      hasUpdate: info.isNewerThan(currentVersion),
      downloadUrl: info.apk.downloadUrl,
      releaseNotes: displayNotes,
      checkedAt: checkedAt ?? DateTime.now(),
    );
  }

  factory UpdateCheckStatus.fromJson(Map<String, dynamic> json) {
    return UpdateCheckStatus(
      currentVersion: json['currentVersion']?.toString() ?? '',
      latestVersion: json['latestVersion']?.toString() ?? '',
      hasUpdate: _boolValue(json['hasUpdate']),
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      releaseNotes: json['releaseNotes']?.toString() ?? '',
      checkedAt:
          DateTime.tryParse(json['checkedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'hasUpdate': hasUpdate,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'checkedAt': checkedAt.toIso8601String(),
    };
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

  static const String defaultFolderUrl = '';
  static const String defaultFolderPassword = '';

  final Dio _dio;
  final String _folderUrl;
  final String _folderPassword;

  Future<UpdateInfo> fetchLatest() async {
    if (_folderUrl.trim().isEmpty) {
      throw const FormatException('update folder url is not configured');
    }
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
    final forceFromVersions = _selectForceFromVersions(files, metadata.version);

    final updateEntry = _selectLatestUpdateText(files);
    if (updateEntry == null) {
      return _withMetadataWarning(
        _withForceMarker(metadata, forceFromVersions),
        metadataSource: 'apk',
        metadataWarning: '暂未获取到完整更新公告，请确认 update.txt 已上传到更新文件夹。',
      );
    }

    final fromText = await _tryFetchUpdateTextMetadata(
      updateEntry,
      params.origin,
    );
    if (fromText == null) {
      return _withMetadataWarning(
        _withForceMarker(metadata, forceFromVersions),
        metadataSource: 'apk',
        metadataWarning: '暂未获取到完整更新公告，请确认 update.txt 已上传到更新文件夹。',
      );
    }

    final textForceFromVersions = fromText.forceFromVersions.isNotEmpty
        ? fromText.forceFromVersions
        : forceFromVersions;
    return UpdateInfo(
      version: fromText.version,
      buildNumber: fromText.buildNumber,
      tag: fromText.tag,
      releaseNotes: fromText.releaseNotes,
      apk: metadata.apk,
      publishedAt: fromText.publishedAt,
      announcements: fromText.announcements,
      metadataSource: 'update.txt',
      metadataWarning: null,
      forceUpdate: fromText.forceUpdate || forceFromVersions.isNotEmpty,
      forceFromVersions: textForceFromVersions,
      minSupportedVersion: fromText.minSupportedVersion,
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
      final directJsonText = _extractJsonObject(pageOrText);
      if (directJsonText != null) {
        return UpdateInfo.fromJson(_decodeJsonMap(directJsonText));
      }

      final textUrl = _extractDownloadUrl(pageOrText, origin);
      if (textUrl == null) {
        return null;
      }
      final textResponse = await _dio.get<String>(
        textUrl,
        options: Options(responseType: ResponseType.plain),
      );
      _ensureSuccess(textResponse);
      final jsonText = _extractJsonObject(textResponse.data ?? '');
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
    matches.sort((a, b) => _compareApkEntries(b, a));
    return matches.first;
  }

  static LanzouFileEntry? _selectLatestUpdateText(List<LanzouFileEntry> files) {
    final matches = files.where((entry) => entry.name == 'update.txt').toList();
    if (matches.isEmpty) {
      return null;
    }
    matches.sort(_compareFileFreshness);
    return matches.first;
  }

  static List<String> _selectForceFromVersions(
    List<LanzouFileEntry> files,
    String latestVersion,
  ) {
    final markerPattern = RegExp(
      r'^force_(\d+\.\d+\.\d+)_from_([0-9A-Za-z+.,-]+)\.txt$',
    );
    for (final entry in files) {
      final match = markerPattern.firstMatch(entry.name);
      if (match == null || match.group(1) != latestVersion) {
        continue;
      }
      return match
          .group(2)!
          .split(',')
          .map((version) => version.trim())
          .where((version) => version.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static UpdateInfo _withForceMarker(
    UpdateInfo info,
    List<String> forceFromVersions,
  ) {
    if (forceFromVersions.isEmpty || info.forceUpdate) {
      return info;
    }
    return UpdateInfo(
      version: info.version,
      buildNumber: info.buildNumber,
      tag: info.tag,
      releaseNotes: info.releaseNotes,
      apk: info.apk,
      publishedAt: info.publishedAt,
      announcements: info.announcements,
      metadataSource: info.metadataSource,
      metadataWarning: info.metadataWarning,
      forceUpdate: true,
      forceFromVersions: forceFromVersions,
      minSupportedVersion: info.minSupportedVersion,
    );
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
      announcements: [
        UpdateAnnouncement.fromReleaseInfo(
          version: version,
          buildNumber: buildNumber,
          tag: '$version+$buildNumber',
          publishedAt: null,
          releaseNotes: '发现 GUETer 新版本，点击前往蓝奏云下载。',
        ),
      ],
      metadataSource: 'apk',
    );
  }

  static UpdateInfo _withMetadataWarning(
    UpdateInfo info, {
    required String metadataSource,
    required String metadataWarning,
  }) {
    return UpdateInfo(
      version: info.version,
      buildNumber: info.buildNumber,
      tag: info.tag,
      releaseNotes: info.releaseNotes,
      apk: info.apk,
      publishedAt: info.publishedAt,
      announcements: info.announcements,
      metadataSource: metadataSource,
      metadataWarning: metadataWarning,
      forceUpdate: info.forceUpdate,
      forceFromVersions: info.forceFromVersions,
      minSupportedVersion: info.minSupportedVersion,
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

  static String? _extractDownloadUrl(String html, String origin) {
    final patterns = <RegExp>[
      RegExp(
        r'''href=["']([^"']*(?:download|file|txt)[^"']*)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''(?:url|downloadUrl)\s*[:=]\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(html)) {
        final raw = match.group(1)?.trim();
        if (raw == null || raw.isEmpty || raw.startsWith('javascript:')) {
          continue;
        }
        final uri = Uri.tryParse(raw);
        if (uri == null) {
          continue;
        }
        final resolved = uri.hasScheme ? uri : Uri.parse(origin).resolve(raw);
        if (resolved.scheme == 'http' || resolved.scheme == 'https') {
          return resolved.toString();
        }
      }
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

class UpdateCheckStatusStore {
  UpdateCheckStatusStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String _cacheKey = 'app_update_check_status_cache';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<UpdateCheckStatus?> load() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return null;
      }
      return UpdateCheckStatus.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(UpdateCheckStatus status) async {
    final prefs = await _preferencesLoader();
    await prefs.setString(_cacheKey, json.encode(status.toJson()));
  }
}

class UpdateAnnouncementStore {
  UpdateAnnouncementStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String _cacheKey = 'app_update_announcements_cache';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<List<UpdateAnnouncement>> loadCached() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return const <UpdateAnnouncement>[];
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) {
        return const <UpdateAnnouncement>[];
      }
      return decoded
          .whereType<Map>()
          .map(
            (item) => UpdateAnnouncement.fromJson(
              item.map((key, value) => MapEntry('$key', value)),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <UpdateAnnouncement>[];
    }
  }

  Future<void> save(List<UpdateAnnouncement> announcements) async {
    final prefs = await _preferencesLoader();
    final encoded = json.encode(
      announcements.map((item) => item.toJson()).toList(growable: false),
    );
    await prefs.setString(_cacheKey, encoded);
  }

  Future<List<UpdateAnnouncement>> refresh({
    UpdateService? updateService,
  }) async {
    final info = await (updateService ?? UpdateService()).fetchLatest();
    await save(info.announcements);
    return info.announcements;
  }
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

List<String> _stringListValue(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return const <String>[];
  }
  return text
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _optionalTrimmedString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

List<UpdateAnnouncement> _announcementListValue(
  dynamic value, {
  required UpdateAnnouncement fallback,
}) {
  if (value is! List) {
    return <UpdateAnnouncement>[fallback];
  }
  final items = <UpdateAnnouncement>[];
  for (final raw in value) {
    if (raw is! Map) {
      continue;
    }
    try {
      items.add(
        UpdateAnnouncement.fromJson(
          raw.map((key, value) => MapEntry('$key', value)),
        ),
      );
    } catch (_) {
      continue;
    }
  }
  return items.isEmpty ? <UpdateAnnouncement>[fallback] : items;
}

List<String> _splitReleaseNotes(String releaseNotes) {
  final normalized = releaseNotes.trim();
  if (normalized.isEmpty) {
    return const <String>['暂无更新说明'];
  }
  return normalized
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
}

String? _normalizeVersion(String version) {
  final parts = _parseVersionParts(version);
  if (parts == null) {
    return null;
  }
  return '${parts[0]}.${parts[1]}.${parts[2]}';
}

List<int>? _parseVersionParts(String version) {
  final clean = version.trim().split('+').first;
  final rawParts = clean.split('.');
  if (rawParts.isEmpty || rawParts.length > 3) {
    return null;
  }

  final parts = <int>[];
  for (final part in rawParts) {
    final value = int.tryParse(part);
    if (value == null) {
      return null;
    }
    parts.add(value);
  }
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}

int _compareApkEntries(LanzouFileEntry a, LanzouFileEntry b) {
  final aMatch = a.apkVersionMatch;
  final bMatch = b.apkVersionMatch;
  if (aMatch == null || bMatch == null) {
    return 0;
  }

  final aVersion = _parseVersionParts(aMatch.group(1)!);
  final bVersion = _parseVersionParts(bMatch.group(1)!);
  if (aVersion == null || bVersion == null) {
    return 0;
  }

  for (var i = 0; i < 3; i++) {
    final result = aVersion[i].compareTo(bVersion[i]);
    if (result != 0) {
      return result;
    }
  }

  return int.parse(aMatch.group(2)!).compareTo(int.parse(bMatch.group(2)!));
}

int _compareFileFreshness(LanzouFileEntry a, LanzouFileEntry b) {
  final aAge = _relativeAgeMinutes(a.time);
  final bAge = _relativeAgeMinutes(b.time);
  if (aAge != null && bAge != null) {
    return aAge.compareTo(bAge);
  }
  if (aAge != null) {
    return -1;
  }
  if (bAge != null) {
    return 1;
  }
  return 0;
}

int? _relativeAgeMinutes(String raw) {
  final text = raw.trim();
  final match = RegExp(r'(\d+)').firstMatch(text);
  if (match == null) {
    return null;
  }
  final value = int.tryParse(match.group(1)!);
  if (value == null) {
    return null;
  }
  if (text.contains('分钟') || text.toLowerCase().contains('minute')) {
    return value;
  }
  if (text.contains('小时') || text.toLowerCase().contains('hour')) {
    return value * 60;
  }
  if (text.contains('天') || text.toLowerCase().contains('day')) {
    return value * 24 * 60;
  }
  return null;
}
