import 'dart:convert';

class TronclassQrParser {
  static final String _ta = String.fromCharCode(30);
  static final String _ea = String.fromCharCode(31);
  static final String _na = String.fromCharCode(26);
  static final String _ra = String.fromCharCode(16);
  static final String _ia = '${_na}1';
  static final String _oa = '${_na}0';

  static const String _baseUrl = 'https://courses.guet.edu.cn';

  static const List<String> _aaKeys = [
    'courseId',
    'activityId',
    'activityType',
    'data',
    'rollcallId',
    'groupSetId',
    'accessCode',
    'action',
    'enableGroupRollcall',
    'createUser',
    'joinCourse',
  ];

  static const List<String> _uaKeys = [
    'classroom-exam',
    'classroom-quiz',
    'rollcall',
    'group-course',
    'feedback',
    'vote',
  ];

  static final Map<String, String> _aa = Map.unmodifiable({
    for (final e in _aaKeys.asMap().entries) _toBase36(e.key): e.value,
  });

  static final Map<String, String> _ua = Map.unmodifiable({
    for (final e in _uaKeys.asMap().entries)
      e.value: _na + _toBase36(e.key + 2),
  });

  static final Map<String, String> _ca = {
    for (final entry in _aa.entries) entry.key: entry.value,
  };

  static final Map<String, String> _sa = {
    for (final entry in _ua.entries) entry.value: entry.key,
  };

  static Map<String, dynamic>? parse(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    final direct = _tryParseJsonObject(input);
    if (direct != null) return _normalize(direct, sourceText: input);

    String url = input;
    if (url.contains('/j?p=') && !url.startsWith('http')) {
      url = _baseUrl + url;
    }

    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return null;
    }

    final qp = uri.queryParameters;
    if (qp.containsKey('data') ||
        qp.containsKey('rollcallId') ||
        qp.containsKey('rollcall_id') ||
        qp.containsKey('rcode')) {
      return _normalize(qp, sourceText: input);
    }

    if (uri.path == '/j' || uri.path == '/scanner-jumper') {
      Map<String, dynamic>? parsed;

      final packedJson = qp['_p'];
      if (packedJson != null && packedJson.isNotEmpty) {
        parsed = _tryParseJsonObject(packedJson);
      }

      if (parsed == null) {
        final packed = qp['p'] ?? '';
        final map = _parseSignQrCode(packed);
        if (map.isNotEmpty) {
          parsed = map;
        }
      }

      if (parsed != null) {
        return _normalize(parsed, sourceText: input);
      }
    }

    return null;
  }

  static Map<String, dynamic> _normalize(
    Map<dynamic, dynamic> source, {
    String? sourceText,
  }) {
    final map = <String, dynamic>{};
    for (final entry in source.entries) {
      map[entry.key.toString()] = entry.value;
    }

    final rollcallId = map['rollcallId'] ?? map['rollcall_id'] ?? map['id'];
    final data = map['data'] ?? map['payload'];
    final rcode = map['rcode'];

    final normalized = <String, dynamic>{...map};
    if (rollcallId != null) normalized['rollcallId'] = rollcallId;
    if (data != null) normalized['data'] = data;
    if (rcode != null && normalized['data'] == null) {
      normalized['data'] = rcode;
    }

    if (!normalized.containsKey('rollcallId') && sourceText != null) {
      final directRollcallId = _extractRollcallIdFromText(sourceText);
      if (directRollcallId != null) {
        normalized['rollcallId'] = directRollcallId;
      }
    }

    return normalized;
  }

  static Map<String, dynamic>? _tryParseJsonObject(String text) {
    try {
      final obj = jsonDecode(text);
      if (obj is Map<String, dynamic>) {
        return obj;
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic> _parseSignQrCode(String input) {
    final result = <String, dynamic>{};
    if (input.isEmpty) return result;

    final parts = input.split('!').where((part) => part.isNotEmpty);
    for (final part in parts) {
      final splitted = part.split('~');
      if (splitted.length < 2) continue;

      final r = splitted[0];
      final iValue = splitted.sublist(1).join('~');
      final key = _ca[r] ?? r;
      dynamic value;

      if (iValue.startsWith(_na)) {
        if (iValue == _ia) {
          value = true;
        } else if (iValue == _oa) {
          value = false;
        } else {
          value = _sa[iValue] ?? iValue;
        }
      } else if (iValue.startsWith(_ra)) {
        final substr = iValue.substring(1);
        final base36Parts = substr.split('.');
        List<int> nums = [];
        try {
          nums = base36Parts.map((p) => int.parse(p, radix: 36)).toList();
        } catch (_) {
          nums = [];
        }

        if (nums.length > 1) {
          value =
              double.tryParse('${nums[0]}.${nums[1]}') ??
              '${nums[0]}.${nums[1]}';
        } else if (nums.isNotEmpty) {
          value = nums[0];
        } else {
          value = iValue;
        }
      } else {
        value = iValue.replaceAll(_ea, '~').replaceAll(_ta, '!');
      }

      result[key] = value;
    }

    return result;
  }

  static String? _extractRollcallIdFromText(String text) {
    final decoded = Uri.decodeFull(text);
    final patterns = <RegExp>[
      RegExp(r'/rollcall/([0-9]+)', caseSensitive: false),
      RegExp(r'rollcallId=([0-9]+)', caseSensitive: false),
      RegExp(r'rollcall_id=([0-9]+)', caseSensitive: false),
      RegExp(r'activePrimaryId=([0-9]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(decoded);
      if (match != null && match.groupCount >= 1) {
        final value = match.group(1);
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
    }

    return null;
  }

  static String _toBase36(int num) {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    if (num < 0) return '-${_toBase36(-num)}';
    if (num < 36) return chars[num];

    var n = num;
    var out = '';
    while (n > 0) {
      final rem = n % 36;
      out = chars[rem] + out;
      n = n ~/ 36;
    }
    return out;
  }
}
