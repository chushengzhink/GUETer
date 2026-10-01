import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class KetangpaiSemester {
  const KetangpaiSemester(this.startYear, this.term)
    : assert(startYear >= 1000 && startYear <= 9998),
      assert(term == 1 || term == 2);

  final int startYear;
  final int term;
  String get semester => '$startYear-${startYear + 1}';
  String get key => '$semester:$term';
  String label({bool english = false}) => english
      ? '$semester · Semester $term'
      : '$semester 学年 · 第${term == 1 ? '一' : '二'}学期';

  factory KetangpaiSemester.forDate(DateTime date) => KetangpaiSemester(
    date.month >= 9 ? date.year : date.year - 1,
    date.month >= 2 && date.month < 9 ? 2 : 1,
  );

  @override
  bool operator ==(Object other) =>
      other is KetangpaiSemester && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

/// Selection is isolated by account and site; the clock is only a first-use default.
class KetangpaiSemesterStore extends ChangeNotifier {
  static final instance = KetangpaiSemesterStore();
  final _values = <String, KetangpaiSemester>{};
  final _loads = <String, Future<KetangpaiSemester>>{};

  String _key(String userId, String endpoint) =>
      'ketangpai_semester_v1_${Uri.encodeComponent(endpoint.replaceFirst(RegExp(r'/+$'), ''))}_${Uri.encodeComponent(userId)}';

  KetangpaiSemester current(String userId, String endpoint) =>
      _values.putIfAbsent(
        _key(userId, endpoint),
        () => KetangpaiSemester.forDate(DateTime.now()),
      );

  Future<KetangpaiSemester> load(String userId, String endpoint) {
    final key = _key(userId, endpoint);
    return _loads.putIfAbsent(key, () async {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      KetangpaiSemester? saved;
      try {
        final data = raw == null ? null : jsonDecode(raw);
        if (data is Map &&
            data['year'] is int &&
            data['year'] >= 1000 &&
            data['year'] <= 9998 &&
            (data['term'] == 1 || data['term'] == 2)) {
          saved = KetangpaiSemester(data['year'], data['term']);
        }
      } on FormatException {
        // Invalid stored preferences use the same date-based first-use default.
      }
      _values[key] = saved ?? current(userId, endpoint);
      return _values[key]!;
    });
  }

  Future<void> select(
    String userId,
    String endpoint,
    KetangpaiSemester value,
  ) async {
    await load(userId, endpoint);
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId, endpoint);
    final saved = await prefs.setString(
      key,
      jsonEncode({'year': value.startYear, 'term': value.term}),
    );
    if (!saved) throw StateError('Unable to save semester');
    _values[key] = value;
    // Completed load Futures must return the latest selected value on later reads.
    _loads[key] = Future.value(value);
    notifyListeners();
  }
}
