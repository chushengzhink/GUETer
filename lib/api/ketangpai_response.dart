bool isKetangpaiSuccess(dynamic payload) {
  if (payload is! Map) return false;
  if (isKetangpaiAuthExpired(payload)) return false;
  final status = payload['status'];
  final code = payload['code'];
  return status == 1 ||
      status == '1' ||
      code == 10000 ||
      code == '10000' ||
      payload['success'] == true;
}

bool isKetangpaiAuthExpired(dynamic payload) {
  final map = asKetangpaiMap(payload);
  if (map == null) return false;

  final code = map['code'];
  final codeText = code?.toString().trim();
  if (code == 20003 ||
      code == 401 ||
      code == -1 ||
      codeText == '20003' ||
      codeText == '401' ||
      codeText == '-1') {
    return true;
  }

  final message = ketangpaiMessageOf(map).toLowerCase();
  if (message.isEmpty) return false;
  return message.contains('token') ||
      message.contains('\u767b\u5f55\u5df2\u8fc7\u671f') ||
      message.contains('\u767b\u9646\u5df2\u8fc7\u671f') ||
      message.contains('\u8bf7\u91cd\u65b0\u767b\u5f55') ||
      message.contains('\u8bf7\u91cd\u65b0\u767b\u9646');
}

Map<String, dynamic>? asKetangpaiMap(dynamic value) {
  if (value is! Map) return null;
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Map<String, dynamic>> asKetangpaiMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

List<Map<String, dynamic>> extractKetangpaiList(dynamic payload) {
  if (payload is List) return asKetangpaiMapList(payload);
  final map = asKetangpaiMap(payload);
  if (map == null || !isKetangpaiSuccess(map)) {
    return const <Map<String, dynamic>>[];
  }

  final data = map['data'];
  if (data is List) return asKetangpaiMapList(data);
  final dataMap = asKetangpaiMap(data);
  if (dataMap == null) return const <Map<String, dynamic>>[];

  for (final key in const <String>['list', 'data', 'lists', 'rows']) {
    final list = dataMap[key];
    if (list is List) return asKetangpaiMapList(list);
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic>? extractKetangpaiDataMap(dynamic payload) {
  final map = asKetangpaiMap(payload);
  if (map == null || !isKetangpaiSuccess(map)) return null;
  return asKetangpaiMap(map['data']);
}

String ketangpaiMessageOf(dynamic payload) {
  final map = asKetangpaiMap(payload);
  if (map == null) return '';
  final dataMap = asKetangpaiMap(map['data']);
  return dataMap?['info']?.toString().trim().isNotEmpty == true
      ? dataMap!['info'].toString().trim()
      : (map['message'] ?? map['msg'] ?? dataMap?['message'] ?? '')
            .toString()
            .trim();
}
