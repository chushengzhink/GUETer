import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'unipus_models.dart';

typedef UnipusCaptchaResolver =
    Future<String> Function(UnipusCaptchaChallenge challenge);

class UnipusService {
  UnipusService({Dio? dio, CookieJar? cookieJar})
    : _externalDio = dio,
      _externalCookieJar = cookieJar;

  static const String _baseUrl = 'https://u.unipus.cn';
  static const String _serviceUrl =
      'https://u.unipus.cn/user/comm/login?school_id=';

  final Dio? _externalDio;
  final CookieJar? _externalCookieJar;

  Dio? _dio;
  CookieJar? _cookieJar;
  String? _preparedUsername;
  UnipusSessionInfo? _sessionInfo;

  UnipusSessionInfo? get sessionInfo => _sessionInfo;

  Future<void> prepare(String username, {String? userAgent}) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('U 校园账号不能为空');
    }

    if (_dio != null && _preparedUsername == trimmed) {
      return;
    }

    _preparedUsername = trimmed;
    _cookieJar =
        _externalCookieJar ?? PersistCookieJar(storage: FileStorage(await _cookiePath(trimmed)));
    _dio = _externalDio ?? _createDio(_cookieJar!, userAgent: userAgent);
  }

  Future<bool> checkLoginAndSetupSession() async {
    final dio = _ensureDio();
    final response = await dio.get<String>('/user/student');
    final data = response.data ?? '';
    final authorized =
        data.contains('我的班课') ||
        data.contains('\u6211\u7684\u73ed\u8bfe') ||
        data.contains('class-content');
    if (authorized) {
      _sessionInfo = _extractSessionInfo(data);
    }
    return authorized;
  }

  Future<void> login({
    required String username,
    required String password,
    required UnipusCaptchaResolver captchaResolver,
    String? userAgent,
  }) async {
    await prepare(username, userAgent: userAgent);
    await _loginAttempt(
      username: username,
      password: password,
      captchaResolver: captchaResolver,
    );
  }

  Future<List<UnipusCourseBlock>> fetchCourses() async {
    final loggedIn = await checkLoginAndSetupSession();
    if (!loggedIn) {
      throw StateError('U 校园登录状态已失效，请重新登录');
    }
    final response = await _ensureDio().get<String>('/user/student');
    return parseCourseBlocks(response.data ?? '');
  }

  Future<List<UnipusTaskNode>> fetchCourseNodes(String tutorialId) async {
    final progress = await fetchCourseProgress(tutorialId);
    final leaves = await _fetchLeafProgress(tutorialId, progress);
    final detail = await fetchCourseDetail(tutorialId);
    final units = _extractUnitList(detail);
    return _buildNodes(
      tutorialId: tutorialId,
      units: units,
      leaves: leaves,
      prefix: const <int>[],
    );
  }

  Future<Map<String, dynamic>> fetchCourseProgress(String tutorialId) async {
    final openId = _sessionInfo?.openId;
    if (openId == null || openId.isEmpty) {
      throw StateError('U 校园会话缺少 openId');
    }
    final response = await _ensureDio().get<Map<String, dynamic>>(
      'https://ucontent.unipus.cn/course/api/v2/course_progress/$tutorialId/$openId/default/',
    );
    return Map<String, dynamic>.from(response.data ?? const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> fetchCourseDetail(String tutorialId) async {
    final response = await _ensureDio().get<Map<String, dynamic>>(
      'https://ucontent.unipus.cn/course/api/course/$tutorialId/default/',
    );
    final data = response.data ?? const <String, dynamic>{};
    final course = data['course'];
    if (course is String) {
      return Map<String, dynamic>.from(jsonDecode(course) as Map);
    }
    if (course is Map) {
      return Map<String, dynamic>.from(course);
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> fetchLeafContent({
    required String tutorialId,
    required String leaf,
  }) async {
    final response = await _ensureDio().get<Map<String, dynamic>>(
      'https://ucontent.unipus.cn/course/api/v3/content/$tutorialId/$leaf/default/',
    );
    return Map<String, dynamic>.from(response.data ?? const <String, dynamic>{});
  }

  Future<bool> openTaskPage(UnipusQueueItem item) async {
    final url = item.node.url.isNotEmpty
        ? item.node.url
        : buildStudyPageUrl(
            tutorialId: item.node.tutorialId,
            leafPath: item.node.leaf,
          );
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String exportQueueMarkdown(List<UnipusQueueItem> queue) {
    final buffer = StringBuffer()
      ..writeln('# U 校园辅助任务清单')
      ..writeln()
      ..writeln('- 导出时间：${DateTime.now().toIso8601String()}')
      ..writeln('- 任务数量：${queue.length}')
      ..writeln();
    for (var i = 0; i < queue.length; i++) {
      final item = queue[i];
      buffer.writeln(
        '${i + 1}. [${item.confirmed ? '已确认' : '待确认'}] '
        '${item.courseName} / ${item.node.displayTitle}',
      );
      if (item.node.url.isNotEmpty) {
        buffer.writeln('   - URL: ${item.node.url}');
      }
    }
    return buffer.toString();
  }

  List<UnipusCourseBlock> parseCourseBlocks(String htmlContent) {
    final document = html.parse(htmlContent);
    final result = <UnipusCourseBlock>[];
    final classBlocks = document.querySelectorAll('.class-content');

    for (final classBlock in classBlocks) {
      final className =
          classBlock.querySelector('.class-name')?.text.trim() ?? '';
      final classDate =
          classBlock
              .querySelector('.class-date')
              ?.text
              .replaceAll('\n', '')
              .trim() ??
          '';
      final courses = <UnipusCourse>[];
      final courseItems = classBlock.querySelectorAll('.my_course_item');

      for (final item in courseItems) {
        final courseName =
            item.querySelector('.my_course_name')?.attributes['title']?.trim() ??
            item.querySelector('.my_course_name')?.text.trim() ??
            '';
        final status =
            item.querySelector('.my_course_status')?.text.trim() ?? '';
        final imageUrl =
            item.querySelector('.my_course_cover')?.attributes['src'] ?? '';
        final courseUrl = item.querySelector('.hideurl')?.text.trim() ?? '';
        final normalizedCourseUrl = _normalizeUrl(courseUrl);
        final tutorialId = item.attributes['tutorialid'] ?? '';

        Uri? uri;
        if (normalizedCourseUrl.isNotEmpty) {
          uri = Uri.tryParse(normalizedCourseUrl);
        }

        courses.add(
          UnipusCourse(
            courseName: courseName,
            status: status,
            image: _normalizeUrl(imageUrl),
            courseUrl: normalizedCourseUrl,
            tutorialId: tutorialId,
            courseId: uri?.queryParameters['courseId'],
            schoolId: uri?.queryParameters['school_id'],
            eccId: uri?.queryParameters['eccId'],
            classId: uri?.queryParameters['classId'],
            courseType: uri?.queryParameters['coursetype'],
          ),
        );
      }

      final matches = RegExp(
        r'(\d{1,4}\.\d{1,2}\.\d{1,2})\s.+?\s+(\d{1,4}\.\d{1,2}\.\d{1,2})',
      ).firstMatch(classDate);
      result.add(
        UnipusCourseBlock(
          className: className,
          dateRange: classDate,
          startDate: matches?.group(1)?.replaceAll('.', '-') ?? '',
          endDate: matches?.group(2)?.replaceAll('.', '-') ?? '',
          courses: courses,
        ),
      );
    }

    return result;
  }

  Future<void> _loginAttempt({
    required String username,
    required String password,
    required UnipusCaptchaResolver captchaResolver,
    String? captcha,
    String? encodedCaptcha,
  }) async {
    final dio = _ensureDio();
    await dio.get(
      'https://sso.unipus.cn/sso/login',
      queryParameters: <String, dynamic>{'service': _serviceUrl},
    );
    await dio.post('https://sso.unipus.cn/sso/3.0/sso/server_time');

    final payload = <String, dynamic>{
      'service': _serviceUrl,
      'username': _encryptLoginUser(username),
      'password': _encryptLoginUser(password),
      'captcha': captcha ?? '',
      'rememberMe': 'on',
      'captchaCode': captcha ?? '',
    };
    if (encodedCaptcha != null) {
      payload['encodeCaptha'] = encodedCaptcha;
    }

    final response = await dio.post<Map<String, dynamic>>(
      'https://sso.unipus.cn/sso/0.1/sso/cip/login',
      data: payload,
    );

    final data = response.data ?? const <String, dynamic>{};
    final code = data['code']?.toString() ?? '';
    if (code == '1506') {
      final challenge = await getCaptcha();
      final answer = await captchaResolver(challenge);
      return _loginAttempt(
        username: username,
        password: password,
        captchaResolver: captchaResolver,
        captcha: answer,
        encodedCaptcha: challenge.encodedCaptcha,
      );
    }
    if (code == '1502' || (code.isNotEmpty && code != '0')) {
      throw Exception(data['msg']?.toString() ?? 'U 校园登录失败');
    }

    final rs = data['rs'];
    final rsMap = rs is Map ? Map<String, dynamic>.from(rs) : null;
    final ticket = rsMap?['serviceTicket']?.toString() ?? '';
    if (ticket.isEmpty) {
      throw Exception('U 校园登录失败：未返回 service ticket');
    }
    await _loginWithTicket(ticket);
    final loggedIn = await checkLoginAndSetupSession();
    if (!loggedIn) {
      throw Exception('U 校园登录后未能读取课程主页');
    }
  }

  Future<UnipusCaptchaChallenge> getCaptcha() async {
    final response = await _ensureDio().post<Map<String, dynamic>>(
      'https://sso.unipus.cn/sso/4.0/sso/image_captcha2',
    );
    final data = response.data ?? const <String, dynamic>{};
    final rs = data['rs'];
    final rsMap = rs is Map ? Map<String, dynamic>.from(rs) : null;
    return UnipusCaptchaChallenge(
      imageBase64: rsMap?['image']?.toString() ?? '',
      encodedCaptcha: rsMap?['encodeCaptha']?.toString() ?? '',
    );
  }

  Future<void> _loginWithTicket(String ticket) async {
    await _ensureDio().get(
      _serviceUrl,
      queryParameters: <String, dynamic>{'school_id': '', 'ticket': ticket},
      options: Options(followRedirects: true),
    );
  }

  Future<Map<String, dynamic>> _fetchCourseProgressLeaf(
    String tutorialId,
    String leaf,
  ) async {
    final openId = _sessionInfo?.openId;
    if (openId == null || openId.isEmpty) {
      throw StateError('U 校园会话缺少 openId');
    }
    final response = await _ensureDio().get<Map<String, dynamic>>(
      'https://ucontent.unipus.cn/course/api/v2/course_progress/$tutorialId/$leaf/$openId/default/',
    );
    return Map<String, dynamic>.from(response.data ?? const <String, dynamic>{});
  }

  Future<Map<String, dynamic>> _fetchLeafProgress(
    String tutorialId,
    Map<String, dynamic> progress,
  ) async {
    final units = _extractProgressUnits(progress);
    final leaves = <String, dynamic>{};
    for (final key in units.keys) {
      final response = await _fetchCourseProgressLeaf(tutorialId, key);
      leaves.addAll(_extractLeafs(response));
    }
    return leaves;
  }

  Map<String, dynamic> _extractProgressUnits(Map<String, dynamic> response) {
    final rt = response['rt'];
    if (rt is Map) {
      final units = rt['units'];
      if (units is Map) return Map<String, dynamic>.from(units);
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _extractLeafs(Map<String, dynamic> response) {
    final rt = response['rt'];
    if (rt is Map) {
      final leafs = rt['leafs'];
      if (leafs is Map) return Map<String, dynamic>.from(leafs);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractUnitList(Map<String, dynamic> detail) {
    final units = detail['units'];
    if (units is! List) return const <Map<String, dynamic>>[];
    return units
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  List<UnipusTaskNode> _buildNodes({
    required String tutorialId,
    required List<Map<String, dynamic>> units,
    required Map<String, dynamic> leaves,
    required List<int> prefix,
  }) {
    final items = <UnipusTaskNode>[];
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      final title = unit['name']?.toString() ?? '未命名任务';
      final url = unit['url']?.toString() ?? '';
      final indexPath = List<int>.from(prefix)..add(i + 1);
      final progress = leaves[url];
      final childrenRaw = unit['children'];
      final children = childrenRaw is List
          ? childrenRaw
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(growable: false)
          : const <Map<String, dynamic>>[];

      items.add(
        UnipusTaskNode(
          tutorialId: tutorialId,
          title: title,
          path: indexPath,
          leaf: url,
          url: _nodePageUrl(tutorialId: tutorialId, leaf: url),
          required: _isRequired(progress),
          passed: _isPassed(progress),
          children: _buildNodes(
            tutorialId: tutorialId,
            units: children,
            leaves: leaves,
            prefix: indexPath,
          ),
        ),
      );
    }
    return items;
  }

  bool _isRequired(dynamic progress) {
    if (progress is Map) {
      final strategies = progress['strategies'];
      return strategies is Map && strategies['required'] == true;
    }
    return false;
  }

  bool _isPassed(dynamic progress) {
    if (progress is Map) {
      final state = progress['state'];
      if (state is Map) {
        final passValue = state['pass'];
        if (passValue is bool) return passValue;
        if (passValue is num) return passValue != 0;
      }
    }
    return false;
  }

  UnipusSessionInfo _extractSessionInfo(String sourceHtml) {
    final document = html.parse(sourceHtml);
    final name =
        document
            .querySelector('div.content_left_top_info_welcome label')
            ?.text
            .trim() ??
        '';
    return UnipusSessionInfo(
      name: name,
      token: _extractJsVariable(sourceHtml, 'token'),
      openId: _extractJsVariable(sourceHtml, 'openId'),
      websocketUrl: _extractJsVariable(sourceHtml, 'wsURL'),
    );
  }

  String _extractJsVariable(String sourceHtml, String variable) {
    return RegExp('$variable:.*?"(.+?)"').firstMatch(sourceHtml)?.group(1) ??
        '';
  }

  Dio _createDio(CookieJar cookieJar, {String? userAgent}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
        headers: <String, dynamic>{
          'User-Agent': userAgent?.trim().isNotEmpty == true
              ? userAgent!.trim()
              : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36',
          'Connection': 'keep-alive',
        },
      ),
    );
    dio.interceptors.add(_SimpleCookieInterceptor(cookieJar));
    dio.interceptors.add(_RefererInterceptor(defaultReferer: _baseUrl));
    dio.interceptors.add(_UnipusContentDecryptInterceptor());
    return dio;
  }

  Dio _ensureDio() {
    final dio = _dio;
    if (dio == null) {
      throw StateError('U 校园服务尚未初始化');
    }
    return dio;
  }

  Future<String> _cookiePath(String username) async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'unipus_cookies', username));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  String _nodePageUrl({required String tutorialId, required String leaf}) {
    if (leaf.startsWith('http://') || leaf.startsWith('https://')) {
      return leaf;
    }
    if (leaf.isEmpty) return '';
    return buildStudyPageUrl(tutorialId: tutorialId, leafPath: leaf);
  }

  static String buildStudyPageUrl({
    required String tutorialId,
    required String leafPath,
  }) {
    return 'https://ucontent.unipus.cn/_pc_default/pc.html#/$tutorialId/courseware$leafPath/p_1';
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('://')) return 'https$url';
    if (url.startsWith('//')) return 'https:$url';
    return url;
  }

  String _encryptLoginUser(String value) {
    const keyHex = '8AD70B641C024C7ADA2ECD082EC0334F';
    const ivHex = '0102030405060708090A0B0C0D0E0F10';
    Uint8List hexToBytes(String hex) {
      return Uint8List.fromList(
        List.generate(
          hex.length ~/ 2,
          (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );
    }

    final key = encrypt.Key(hexToBytes(keyHex));
    final iv = encrypt.IV(hexToBytes(ivHex));
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
    );
    return encrypter
        .encrypt(value, iv: iv)
        .bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}

class _SimpleCookieInterceptor extends Interceptor {
  _SimpleCookieInterceptor(this.cookieJar);

  final CookieJar cookieJar;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final cookies = await cookieJar.loadForRequest(options.uri);
    if (cookies.isNotEmpty && options.headers['Cookie'] == null) {
      options.headers['Cookie'] = cookies
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join('; ');
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final setCookies = response.headers['set-cookie'];
    if (setCookies != null && setCookies.isNotEmpty) {
      await cookieJar.saveFromResponse(
        response.requestOptions.uri,
        setCookies.map(Cookie.fromSetCookieValue).toList(),
      );
    }
    handler.next(response);
  }
}

class _RefererInterceptor extends Interceptor {
  _RefererInterceptor({required this.defaultReferer});

  final String defaultReferer;
  String? _lastHtmlPageUrl;
  String? _lastRequestUrl;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.headers.containsKey('Referer') &&
        !options.headers.containsKey('referer')) {
      options.headers['Referer'] =
          _lastHtmlPageUrl ?? _lastRequestUrl ?? defaultReferer;
    }
    _lastRequestUrl = _fullUrl(options.uri);
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final contentType = response.headers.value('content-type')?.toLowerCase();
    if (contentType != null &&
        (contentType.contains('text/html') ||
            contentType.contains('application/xhtml+xml'))) {
      _lastHtmlPageUrl = _fullUrl(response.requestOptions.uri);
    }
    handler.next(response);
  }

  String _fullUrl(Uri uri) => '${uri.scheme}://${uri.host}${uri.path}';
}

class _UnipusContentDecryptInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final url = response.requestOptions.uri.toString();
    final contentType = response.headers.value('content-type');
    final data = response.data;
    if (url.startsWith(
          'https://ucontent.unipus.cn/course/api/v3/content/course-v1',
        ) &&
        contentType?.startsWith('application/json') == true &&
        data is Map<String, dynamic>) {
      final content = data['content'];
      final key = data['k'];
      if (content is String && key is String) {
        final decrypted = _decryptUnipusContent(content, key);
        if (decrypted != null) {
          response.data = jsonDecode(decrypted);
        }
      }
    }
    handler.next(response);
  }

  String? _decryptUnipusContent(String content, String keySuffix) {
    final separator = content.indexOf('.');
    if (separator == -1) return null;
    final cipherHex = content.substring(separator + 1);
    final key = _padKey('1a2b3c4d$keySuffix');
    final bytes = <int>[];
    for (var i = 0; i < cipherHex.length; i += 2) {
      bytes.add(int.parse(cipherHex.substring(i, i + 2), radix: 16));
    }
    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        encrypt.Key(Uint8List.fromList(utf8.encode(key))),
        mode: encrypt.AESMode.ecb,
        padding: null,
      ),
    );
    final decrypted = encrypter.decryptBytes(
      encrypt.Encrypted(Uint8List.fromList(bytes)),
      iv: encrypt.IV.fromLength(0),
    );
    return utf8.decode(decrypted, allowMalformed: true).replaceAll('\u0000', '');
  }

  String _padKey(String key) {
    var padded = key;
    while (padded.length < 16) {
      padded += '\u0000';
    }
    return padded.substring(0, 16);
  }
}
