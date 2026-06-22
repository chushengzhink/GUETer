import 'dart:io';

import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/api/tronclass_homework_upload_api.dart';
import 'package:course_helper/platform.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiService.resetForTests();
    await ApiService.initialize();
    PlatformManager().setPlatformSync(PlatformType.tronclass);
    ApiService.debugCredentialValidatorOverride = (_) async => true;
    tempDir = await Directory.systemTemp.createTemp('tronclass-upload-test-');
  });

  tearDown(() async {
    ApiService.resetForTests();
    PlatformManager().setPlatformSync(PlatformType.chaoxing);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'uploadAndSubmit sends create, binary upload, and final submission',
    () async {
      final fileA = await _writeFile(tempDir, 'a.jpg', <int>[1, 2, 3]);
      final fileB = await _writeFile(tempDir, 'b.mp4', <int>[4, 5, 6, 7]);
      final calls = <_CapturedRequest>[];

      ApiService.debugSendRequestOverride =
          (
            url, {
            required String method,
            Map<String, String>? params,
            Map<String, String>? headers,
            dynamic body,
            ResponseType responseType = ResponseType.json,
            bool allowRedirects = true,
            bool skipCredentialValidation = false,
          }) async {
            calls.add(_CapturedRequest(url, method, headers, body));
            if (url == '/api/uploads') {
              final request = body as Map<String, dynamic>;
              final id = request['name'] == 'a.jpg' ? 101 : 102;
              return _response(
                url,
                statusCode: 201,
                data: <String, dynamic>{
                  'id': id,
                  'name': request['name'],
                  'upload_url': 'https://media.guet.edu.cn/upload/file/$id',
                },
              );
            }
            if (url.toString().contains('/upload/file/')) {
              expect(body, isA<FormData>());
              return _response(url, data: <String, dynamic>{'file_key': 'ok'});
            }
            if (url == '/api/course/activities/78820/submissions') {
              return _response(
                url,
                statusCode: 201,
                data: <String, dynamic>{'message': 'ok'},
              );
            }
            fail('Unexpected request $method $url');
          };

      final ids = await const TronclassHomeworkUploadApi().uploadAndSubmit(
        activityId: 78820,
        files: <File>[fileA, fileB],
      );

      expect(ids, <int>[101, 102]);
      expect(calls.map((call) => call.url), <String>[
        '/api/uploads',
        'https://media.guet.edu.cn/upload/file/101',
        '/api/uploads',
        'https://media.guet.edu.cn/upload/file/102',
        '/api/course/activities/78820/submissions',
      ]);
      expect(calls.first.body, <String, dynamic>{
        'name': 'a.jpg',
        'size': 3,
        'parent_type': null,
        'parent_id': 0,
      });
      expect(calls[2].body, <String, dynamic>{
        'name': 'b.mp4',
        'size': 4,
        'parent_type': null,
        'parent_id': 0,
      });
      expect(calls.last.body, <String, dynamic>{
        'comment': '',
        'is_draft': false,
        'slides': <dynamic>[],
        'uploads': <int>[101, 102],
      });
      expect(calls.first.headers?['Content-Type'], 'application/json');
      expect(calls.last.headers?['X-Requested-With'], 'XMLHttpRequest');
    },
  );

  test('createUpload failure stops before binary upload', () async {
    final file = await _writeFile(tempDir, 'fail.jpg', <int>[1]);
    var calls = 0;
    ApiService.debugSendRequestOverride =
        (
          url, {
          required String method,
          Map<String, String>? params,
          Map<String, String>? headers,
          dynamic body,
          ResponseType responseType = ResponseType.json,
          bool allowRedirects = true,
          bool skipCredentialValidation = false,
        }) async {
          calls++;
          return _response(
            url,
            statusCode: 400,
            data: <String, dynamic>{'message': 'bad upload'},
          );
        };

    await expectLater(
      const TronclassHomeworkUploadApi().uploadAndSubmit(
        activityId: 1,
        files: <File>[file],
      ),
      throwsA(isA<TronclassHomeworkUploadException>()),
    );
    expect(calls, 1);
  });

  test('binary upload failure stops before final submission', () async {
    final file = await _writeFile(tempDir, 'fail.jpg', <int>[1]);
    final urls = <String>[];
    ApiService.debugSendRequestOverride =
        (
          url, {
          required String method,
          Map<String, String>? params,
          Map<String, String>? headers,
          dynamic body,
          ResponseType responseType = ResponseType.json,
          bool allowRedirects = true,
          bool skipCredentialValidation = false,
        }) async {
          urls.add(url);
          if (url == '/api/uploads') {
            return _response(
              url,
              statusCode: 201,
              data: <String, dynamic>{
                'id': 201,
                'upload_url': 'https://media.guet.edu.cn/upload/file/201',
              },
            );
          }
          return _response(
            url,
            statusCode: 500,
            data: <String, dynamic>{'message': 'media failed'},
          );
        };

    await expectLater(
      const TronclassHomeworkUploadApi().uploadAndSubmit(
        activityId: 1,
        files: <File>[file],
      ),
      throwsA(isA<TronclassHomeworkUploadException>()),
    );
    expect(urls, <String>[
      '/api/uploads',
      'https://media.guet.edu.cn/upload/file/201',
    ]);
  });

  test('final submission failure is surfaced after uploads', () async {
    final file = await _writeFile(tempDir, 'ok.jpg', <int>[1]);
    final urls = <String>[];
    ApiService.debugSendRequestOverride =
        (
          url, {
          required String method,
          Map<String, String>? params,
          Map<String, String>? headers,
          dynamic body,
          ResponseType responseType = ResponseType.json,
          bool allowRedirects = true,
          bool skipCredentialValidation = false,
        }) async {
          urls.add(url);
          if (url == '/api/uploads') {
            return _response(
              url,
              statusCode: 201,
              data: <String, dynamic>{
                'id': 301,
                'upload_url': 'https://media.guet.edu.cn/upload/file/301',
              },
            );
          }
          if (url.toString().contains('/upload/file/')) {
            return _response(url, data: <String, dynamic>{'file_key': 'ok'});
          }
          return _response(
            url,
            statusCode: 400,
            data: <String, dynamic>{'message': 'submit failed'},
          );
        };

    await expectLater(
      const TronclassHomeworkUploadApi().uploadAndSubmit(
        activityId: 1,
        files: <File>[file],
      ),
      throwsA(
        isA<TronclassHomeworkUploadException>().having(
          (error) => error.message,
          'message',
          contains('submit failed'),
        ),
      ),
    );
    expect(urls, <String>[
      '/api/uploads',
      'https://media.guet.edu.cn/upload/file/301',
      '/api/course/activities/1/submissions',
    ]);
  });
}

Future<File> _writeFile(Directory dir, String name, List<int> bytes) async {
  final file = File(p.join(dir.path, name));
  await file.writeAsBytes(bytes);
  return file;
}

Response<dynamic> _response(String url, {int statusCode = 200, dynamic data}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: url),
    statusCode: statusCode,
    data: data ?? <String, dynamic>{'ok': true},
  );
}

class _CapturedRequest {
  const _CapturedRequest(this.url, this.method, this.headers, this.body);

  final String url;
  final String method;
  final Map<String, String>? headers;
  final dynamic body;
}
