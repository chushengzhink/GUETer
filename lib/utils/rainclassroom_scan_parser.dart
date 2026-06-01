enum RainClassroomScanKind { dynamicQr, lessonPage, miniProgram }

class RainClassroomScanTarget {
  const RainClassroomScanTarget({required this.kind, required this.uri});

  final RainClassroomScanKind kind;
  final Uri uri;

  String? get lessonId => RainClassroomScanParser.extractLessonId(uri);
}

class RainClassroomScanParser {
  static bool isCandidate(String raw, Uri? uri) {
    final lowerRaw = raw.toLowerCase();
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    final query = uri?.queryParameters ?? const <String, String>{};

    if (host.endsWith('yuketang.cn') || lowerRaw.contains('yuketang.cn')) {
      return path.contains('/api/v3/lesson/check-in/dynamic-qr-code') ||
          path.contains('/lesson/check-in') ||
          path.contains('/lesson/student/v3/') ||
          path.contains('/v/lesson/lesson_info_entry/') ||
          lowerRaw.contains('/api/v3/lesson/check-in/dynamic-qr-code') ||
          lowerRaw.contains('/lesson/student/v3/') ||
          lowerRaw.contains('/v/lesson/lesson_info_entry/') ||
          lowerRaw.contains('dynamic-qr-code');
    }

    if (host.contains('weixin.qq.com') || lowerRaw.contains('weixin.qq.com')) {
      return path.startsWith('/q/') || lowerRaw.contains('/q/');
    }

    return lowerRaw.contains('dynamic-qr-code') ||
        lowerRaw.contains('/lesson/student/v3/') ||
        lowerRaw.contains('/v/lesson/lesson_info_entry/') ||
        lowerRaw.contains('c=') &&
            lowerRaw.contains('t=') &&
            lowerRaw.contains('s=') ||
        query.containsKey('c') &&
            query.containsKey('t') &&
            query.containsKey('s') &&
            (query.containsKey('v') || lowerRaw.contains('dynamic-qr-code'));
  }

  static RainClassroomScanTarget? classifyUri(Uri uri) {
    if (isDynamicQrUri(uri)) {
      return RainClassroomScanTarget(
        kind: RainClassroomScanKind.dynamicQr,
        uri: uri,
      );
    }

    if (isLessonPageUri(uri)) {
      return RainClassroomScanTarget(
        kind: RainClassroomScanKind.lessonPage,
        uri: uri,
      );
    }

    return null;
  }

  static bool isDynamicQrUri(Uri uri) {
    return uri.path == '/api/v3/lesson/check-in/dynamic-qr-code' &&
        uri.host.contains('yuketang.cn');
  }

  static bool isLessonPageUri(Uri uri) {
    return uri.host.contains('yuketang.cn') && extractLessonId(uri) != null;
  }

  static String? extractLessonId(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 4) {
      return null;
    }

    if (segments[0] == 'lesson' &&
        segments[1] == 'student' &&
        segments[2] == 'v3') {
      return _validateLessonId(segments[3]);
    }

    if (segments.length >= 4 &&
        segments[0] == 'v' &&
        segments[1] == 'lesson' &&
        segments[2] == 'lesson_info_entry') {
      return _validateLessonId(segments[3]);
    }

    return null;
  }

  static String? _validateLessonId(String lessonId) {
    final normalized = lessonId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return RegExp(r'^\d+$').hasMatch(normalized) ? normalized : null;
  }

  static Uri? extractTargetUriFromText(String? input) {
    final text = input?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final normalized = text.replaceAll('&amp;', '&');
    for (final pattern in _uriPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match == null) {
        continue;
      }

      final candidate = match.group(0)!;
      final parsed =
          _tryParse(candidate) ?? _tryParse(Uri.decodeFull(candidate));
      if (parsed != null) {
        return parsed;
      }
    }

    try {
      final decoded = Uri.decodeComponent(normalized);
      if (decoded != normalized) {
        return extractTargetUriFromText(decoded);
      }
    } catch (_) {
      // Ignore malformed encoded text and fall through.
    }

    return null;
  }

  static Uri? _tryParse(String? input) {
    if (input == null || input.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(input);
      return classifyUri(uri) == null ? null : uri;
    } catch (_) {
      return null;
    }
  }

  static final List<RegExp> _uriPatterns = <RegExp>[
    RegExp(
      r'''https?://[^\s"']+/api/v3/lesson/check-in/dynamic-qr-code\?[^\s"']+''',
      caseSensitive: false,
    ),
    RegExp(
      r'''https?://[^\s"']+/lesson/student/v3/\d+(?:\?[^\s"']+)?''',
      caseSensitive: false,
    ),
    RegExp(
      r'''https?://[^\s"']+/v/lesson/lesson_info_entry/\d+(?:\?[^\s"']+)?''',
      caseSensitive: false,
    ),
  ];
}
