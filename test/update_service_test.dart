import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:course_helper/services/update_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UpdateInfo', () {
    test('parses update metadata json', () {
      final info = UpdateInfo.fromJson({
        'version': '1.0.3',
        'buildNumber': 4,
        'tag': '1.0.3+4',
        'releaseNotes': '更新说明',
        'apk': {
          'abi': 'arm64-v8a',
          'fileName': 'GUETer_1.0.3+4_arm64-v8a.apk',
          'downloadUrl': 'https://example.com/app.apk',
        },
        'publishedAt': '2026-06-05T03:18:57Z',
      });

      expect(info.version, '1.0.3');
      expect(info.buildNumber, 4);
      expect(info.tag, '1.0.3+4');
      expect(info.releaseNotes, '更新说明');
      expect(info.apk.abi, 'arm64-v8a');
      expect(info.apk.downloadUrl, 'https://example.com/app.apk');
      expect(info.publishedAt, DateTime.parse('2026-06-05T03:18:57Z'));
    });

    test('rejects metadata without version or download url', () {
      expect(
        () => UpdateInfo.fromJson({
          'apk': {'downloadUrl': 'https://example.com/app.apk'},
        }),
        throwsFormatException,
      );
      expect(
        () => UpdateInfo.fromJson({
          'version': '1.0.2',
          'apk': {'fileName': 'app.apk'},
        }),
        throwsFormatException,
      );
    });

    test('compares semantic app versions', () {
      expect(UpdateInfo.isNewerVersion('1.0.3', '1.0.2'), isTrue);
      expect(UpdateInfo.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(UpdateInfo.isNewerVersion('1.0.2', '1.0.2'), isFalse);
      expect(UpdateInfo.isNewerVersion('1.0.1', '1.0.2'), isFalse);
      expect(UpdateInfo.isNewerVersion('bad', '1.0.2'), isFalse);
    });
  });

  group('LanzouFolderParams', () {
    test('extracts fid uid t and k from folder page html', () {
      final params = LanzouFolderParams.parse(
        _folderHtml(),
        Uri.parse('https://wwbix.lanzouu.com/b0188dwqsd'),
      );

      expect(params.origin, 'https://wwbix.lanzouu.com');
      expect(params.fid, '13573753');
      expect(params.uid, '4981610');
      expect(params.t, '1780631275');
      expect(params.k, '53ebc445780f61f05fea715118abc286');
      expect(
        params.listUrl,
        'https://wwbix.lanzouu.com/filemoreajax.php?file=13573753',
      );
    });
  });

  group('UpdateService', () {
    test('loads lanzou folder list and builds stable apk page url', () async {
      final adapter = _LanzouAdapter(
        folderHtml: _folderHtml(),
        listJson: _folderListJson(),
      );
      final service = UpdateService(
        dio: _dioWith(adapter),
        folderUrl: 'https://wwbix.lanzouu.com/b0188dwqsd',
        folderPassword: '7ls6',
      );

      final info = await service.fetchLatest();

      expect(info.version, '1.0.3');
      expect(info.buildNumber, 4);
      expect(info.tag, '1.0.3+4');
      expect(info.releaseNotes, '发现 GUETer 新版本，点击前往蓝奏云下载。');
      expect(info.apk.abi, 'arm64-v8a');
      expect(info.apk.fileName, 'GUETer_1.0.3+4_arm64-v8a.apk');
      expect(
        info.apk.downloadUrl,
        'https://wwbix.lanzouu.com/ianQi3r5tfoj?webpage=BzZUNF47',
      );
      expect(adapter.lastForm?['pwd'], '7ls6');
      expect(adapter.lastHeaders?['Cookie'], contains('ylogin=abc'));
    });

    test(
      'uses latest update.txt json notes when the text page contains json',
      () async {
        final adapter = _LanzouAdapter(
          folderHtml: _folderHtml(),
          listJson: _folderListJson(),
          filePages: {
            'https://wwbix.lanzouu.com/iVlkZ3r5tkte':
                '\uFEFF{"version":"1.0.3","buildNumber":4,"releaseNotes":"正式发布","apk":{"downloadUrl":"https://expired.example/app.apk"}}',
          },
        );
        final service = UpdateService(
          dio: _dioWith(adapter),
          folderUrl: 'https://wwbix.lanzouu.com/b0188dwqsd',
          folderPassword: '7ls6',
        );

        final info = await service.fetchLatest();

        expect(info.releaseNotes, '正式发布');
        expect(
          info.apk.downloadUrl,
          'https://wwbix.lanzouu.com/ianQi3r5tfoj?webpage=BzZUNF47',
        );
      },
    );

    test(
      'duplicate update.txt files do not block apk-based metadata',
      () async {
        final adapter = _LanzouAdapter(
          folderHtml: _folderHtml(),
          listJson: _folderListJson(),
          filePages: {
            'https://wwbix.lanzouu.com/iVlkZ3r5tkte': '<html></html>',
          },
        );
        final service = UpdateService(
          dio: _dioWith(adapter),
          folderUrl: 'https://wwbix.lanzouu.com/b0188dwqsd',
          folderPassword: '7ls6',
        );

        final info = await service.fetchLatest();

        expect(info.version, '1.0.3');
        expect(info.apk.fileName, 'GUETer_1.0.3+4_arm64-v8a.apk');
      },
    );

    test('throws when folder password or list request fails', () {
      final adapter = _LanzouAdapter(
        folderHtml: _folderHtml(),
        listJson: {'zt': 3, 'info': '密码错误'},
      );
      final service = UpdateService(
        dio: _dioWith(adapter),
        folderUrl: 'https://wwbix.lanzouu.com/b0188dwqsd',
        folderPassword: 'bad',
      );

      expect(service.fetchLatest(), throwsFormatException);
    });

    test('throws on non-success response', () {
      final adapter = _LanzouAdapter(
        folderHtml: 'not found',
        listJson: _folderListJson(),
        folderStatusCode: 404,
      );
      final service = UpdateService(
        dio: _dioWith(adapter),
        folderUrl: 'https://wwbix.lanzouu.com/b0188dwqsd',
        folderPassword: '7ls6',
      );

      expect(service.fetchLatest(), throwsA(isA<DioException>()));
    });
  });
}

Dio _dioWith(HttpClientAdapter adapter) {
  return Dio(
    BaseOptions(validateStatus: (status) => status != null && status < 500),
  )..httpClientAdapter = adapter;
}

String _folderHtml() {
  return '''
<script>
var ibjbqp = '1780631275';
var _hhnsi = '53ebc445780f61f05fea715118abc286';
function file(){
  jQuery.ajax({
    type : 'post',
    url : '/filemoreajax.php?file=13573753',
    data : {
      'lx':2,
      'fid':13573753,
      'uid':'4981610',
      'pg':pgs,
      'rep':'0',
      't':ibjbqp,
      'k':_hhnsi,
      'up':1,
      'ls':1,
      'pwd':pwd
    }
  });
}
</script>
''';
}

Map<String, dynamic> _folderListJson() {
  return {
    'zt': 1,
    'info': 'sucess',
    'text': [
      {
        'icon': 'txt',
        'id': 'iVlkZ3r5tkte',
        'name_all': 'update.txt',
        'size': '424.0 B',
        'time': '17 分钟前',
      },
      {
        'icon': 'txt',
        'id': 'iA8nE3r5thkh',
        'name_all': 'update.txt',
        'size': '553.0 B',
        'time': '18 分钟前',
      },
      {
        'icon': 'apk',
        'id': 'ianQi3r5tfoj?webpage=BzZUNF47',
        'name_all': 'GUETer_1.0.3+4_arm64-v8a.apk',
        'size': '69.5 M',
        'time': '18 分钟前',
      },
    ],
  };
}

class _LanzouAdapter implements HttpClientAdapter {
  _LanzouAdapter({
    required this.folderHtml,
    required this.listJson,
    this.filePages = const {},
    this.folderStatusCode = 200,
  });

  final String folderHtml;
  final Map<String, dynamic> listJson;
  final Map<String, String> filePages;
  final int folderStatusCode;

  Map<String, dynamic>? lastForm;
  Map<String, dynamic>? lastHeaders;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyBytes = await requestStream?.fold<BytesBuilder>(
      BytesBuilder(),
      (builder, chunk) => builder..add(chunk),
    );
    final requestBody = utf8.decode(bodyBytes?.takeBytes() ?? Uint8List(0));
    final uri = options.uri.toString();

    if (options.method == 'GET' &&
        uri == 'https://wwbix.lanzouu.com/b0188dwqsd') {
      return ResponseBody.fromString(
        folderHtml,
        folderStatusCode,
        headers: {
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
          'set-cookie': ['ylogin=abc; path=/', 'folder=def; path=/'],
        },
      );
    }

    if (options.method == 'POST' &&
        uri == 'https://wwbix.lanzouu.com/filemoreajax.php?file=13573753') {
      lastForm = Uri.splitQueryString(requestBody);
      lastHeaders = options.headers;
      return ResponseBody.fromString(
        json.encode(listJson),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json; charset=utf-8'],
        },
      );
    }

    if (options.method == 'GET' && filePages.containsKey(uri)) {
      return ResponseBody.fromString(
        filePages[uri]!,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        },
      );
    }

    return ResponseBody.fromString(
      'not found',
      404,
      headers: {
        Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
