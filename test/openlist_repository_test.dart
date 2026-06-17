import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:course_helper/features/openlist/openlist_client.dart';
import 'package:course_helper/features/openlist/openlist_controller.dart';
import 'package:course_helper/features/openlist/openlist_endpoint_config.dart';
import 'package:course_helper/features/openlist/openlist_models.dart';
import 'package:course_helper/features/openlist/openlist_repository.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/tronclass_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OpenList models and repository helpers', () {
    test('permission bits parse readonly and readwrite capabilities', () {
      const readonly = OpenListSession(
        mode: OpenListAccountMode.readonly,
        token: 't',
        username: 'cszm',
        permission: 16640,
        basePath: '/',
      );
      const readwrite = OpenListSession(
        mode: OpenListAccountMode.personal,
        token: 't',
        username: 'cszm1',
        permission: 16648,
        basePath: '/',
      );

      expect(readonly.canUpload, isFalse);
      expect(readonly.canShare, isFalse);
      expect(readonly.permissions.enabledBits, [8, 14]);
      expect(readwrite.canUpload, isTrue);
      expect(readwrite.canShare, isTrue);
      expect(readwrite.permissions.enabledBits, [3, 8, 14]);
      expect(readwrite.permissions.canRename, isFalse);
      expect(readwrite.permissions.canMove, isFalse);
      expect(readwrite.permissions.canCopy, isFalse);
      expect(readwrite.permissions.canRemove, isFalse);
      expect(const OpenListPermission(17160).canWebDavManage, isTrue);
    });

    test('list response parses and sorts directories first', () {
      final listing = OpenListDirectoryListing.fromJson({
        'total': 2,
        'write': true,
        'provider': 'unknown',
        'content': [
          {'name': 'b.txt', 'size': 12, 'is_dir': false, 'type': 0},
          {'name': 'a', 'size': 0, 'is_dir': true, 'type': 1},
        ],
      });

      expect(listing.total, 2);
      expect(listing.write, isTrue);
      expect(listing.content.map((item) => item.name), ['a', 'b.txt']);
    });

    test('normalizes remote paths and breadcrumbs', () async {
      expect(OpenListRepository.normalizePath('foo//bar'), '/foo/bar');
      expect(
        OpenListRepository.joinRemotePath('/foo', 'bar.txt'),
        '/foo/bar.txt',
      );
      expect(OpenListRepository.breadcrumbPaths('/foo/bar'), [
        '/',
        '/foo',
        '/foo/bar',
      ]);
      expect(
        OpenListRepository.pathWithBasePath('/资料', '/foo/bar.txt'),
        '/资料/foo/bar.txt',
      );
      expect(OpenListEndpointConfig.baseUrl, startsWith('http://'));
      expect(OpenListEndpointConfig.provisionEndpoint, contains('ensure-user'));
      final forbiddenIp = ['10', '33', '108', '81'].join('.');
      for (final path in [
        'lib/features/openlist/openlist_client.dart',
        'lib/features/openlist/openlist_endpoint_config.dart',
      ]) {
        expect(await File(path).readAsString(), isNot(contains(forbiddenIp)));
      }
    });
  });

  group('OpenList auth retry', () {
    test('relogins and retries once after auth expiration', () async {
      final client = _RetryClient();
      final repository = OpenListRepository(
        client: client,
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
      );

      final listing = await repository.list('/');

      expect(listing.total, 1);
      expect(client.loginCalls, 2);
      expect(client.listCalls, 2);
    });
  });

  group('OpenList controller filtering and sorting', () {
    test('filters current directory locally and keeps folders first', () async {
      final controller = OpenListController(
        repository: OpenListRepository(
          client: _ListingClient(),
          auditClient: _NoopAuditClient(),
          accountResolver: () async => const OpenListCredentials(
            mode: OpenListAccountMode.personal,
            username: '20240001',
            password: '20240001',
          ),
        ),
      );

      await controller.load();

      expect(controller.visibleItems.map((item) => item.name), [
        'folder',
        'a.txt',
        'b.txt',
      ]);

      controller.setQuery('b');
      expect(controller.visibleItems.map((item) => item.name), ['b.txt']);

      controller.setQuery('');
      controller.setSort(OpenListSortKey.size);
      expect(controller.visibleItems.map((item) => item.name), [
        'folder',
        'a.txt',
        'b.txt',
      ]);
    });

    test('upload progress is exposed by controller', () async {
      final client = _UploadProgressClient();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final controller = OpenListController(
        repository: OpenListRepository(
          client: client,
          auditClient: _FailingAuditClient(),
          accountResolver: () async => const OpenListCredentials(
            mode: OpenListAccountMode.personal,
            username: '20240001',
            password: '20240001',
          ),
          uploaderResolver: () async => const OpenListUploaderIdentity(
            studentId: '20240001',
            studentName: '张三',
          ),
        ),
      );
      final progressValues = <double>[];
      controller.addListener(() {
        final progress = controller.transferProgress;
        if (progress != null) {
          progressValues.add(progress);
        }
      });
      final tempDir = await Directory.systemTemp.createTemp('openlist_upload_');
      final file = File('${tempDir.path}${Platform.pathSeparator}a.txt');
      await file.writeAsString('hello');

      await controller.load();
      await controller.uploadFiles([file.path]);

      expect(client.uploadCalls, 1);
      expect(progressValues.any((value) => value > 0 && value <= 1), isTrue);
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('openlist_pending_upload_audits');
      expect(pending, isNotNull);
      expect(pending!.single, contains('20240001'));

      await tempDir.delete(recursive: true);
    });

    test('personal account upload audit uses student id username', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final client = _UploadProgressClient();
      final auditClient = _CaptureAuditClient();
      final tempDir = await Directory.systemTemp.createTemp('openlist_audit_');
      final file = File('${tempDir.path}${Platform.pathSeparator}audit.txt');
      await file.writeAsString('hello');
      final repository = OpenListRepository(
        client: client,
        auditClient: auditClient,
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
        uploaderResolver: () async => const OpenListUploaderIdentity(
          studentId: '20240001',
          studentName: '张三',
        ),
      );

      await repository.uploadFile(currentPath: '/', localPath: file.path);

      expect(client.lastCredentials?.username, '20240001');
      expect(client.lastCredentials?.password, '20240001');
      expect(auditClient.records.single.studentId, '20240001');
      expect(auditClient.records.single.studentName, '张三');
      expect(auditClient.records.single.openListUsername, '20240001');
      expect(auditClient.records.single.source, 'app');
      expect(auditClient.records.single.requestMethod, 'PUT');

      await tempDir.delete(recursive: true);
    });

    test(
      'current tronclass account must be provisioned before personal login',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        PlatformManager().setPlatformSync(PlatformType.tronclass);
        await AccountManager.initialize();
        await AccountManager.addAccountForPlatformName(
          'tronclass',
          User(
            name: '张三',
            avatar: '',
            phone: '',
            uid: '117246',
            school: 'GUET',
            platform: 'tronclass',
            studentId: '2500520215',
          ),
          notify: false,
          migrateTempCookies: false,
        );
        await AccountManager.setCurrentSession('117246', notify: false);
        await TronclassAuthManager.setSessionIdForUser('117246', 'session-abc');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'openlist_provisioned_user_20240001',
          jsonEncode(<String, dynamic>{
            'username': '20240001',
            'password': '20240001',
            'studentId': '20240001',
            'studentName': '旧缓存',
            'permission': 16648,
            'basePath': '/',
          }),
        );
        final provisionClient = _CaptureProvisionClient();
        final repository = OpenListRepository(
          client: _ListingClient(),
          auditClient: _NoopAuditClient(),
          provisionClient: provisionClient,
        );

        final credentials = await repository.resolveCredentials();

        expect(provisionClient.calls, 1);
        expect(provisionClient.lastProof?.accountUid, '117246');
        expect(provisionClient.lastProof?.studentId, '2500520215');
        expect(provisionClient.lastProof?.studentName, '张三');
        expect(provisionClient.lastProof?.sessionId, 'session-abc');
        expect(credentials.mode, OpenListAccountMode.personal);
        expect(credentials.username, '2500520215');
        expect(credentials.password, '2500520215');
        expect(
          prefs.getString('openlist_provisioned_user_2500520215'),
          contains('张三'),
        );
      },
    );

    test(
      'missing real student id falls back readonly without provision',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        PlatformManager().setPlatformSync(PlatformType.tronclass);
        await AccountManager.initialize();
        await AccountManager.addAccountForPlatformName(
          'tronclass',
          User(
            name: '张三',
            avatar: '',
            phone: '',
            uid: '117246',
            school: 'GUET',
            platform: 'tronclass',
          ),
          notify: false,
          migrateTempCookies: false,
        );
        await AccountManager.setCurrentSession('117246', notify: false);
        await TronclassAuthManager.setSessionIdForUser('117246', 'session-abc');
        final provisionClient = _CaptureProvisionClient();
        final repository = OpenListRepository(
          client: _ListingClient(permission: 16640),
          auditClient: _NoopAuditClient(),
          provisionClient: provisionClient,
        );

        final credentials = await repository.resolveCredentials();

        expect(provisionClient.calls, 0);
        expect(credentials.mode, OpenListAccountMode.readonly);
        expect(credentials.username, 'cszm');
      },
    );

    test('write buttons depend on permission and listing write flag', () async {
      final controller = OpenListController(
        repository: OpenListRepository(
          client: _ListingClient(permission: 16648, write: false),
          auditClient: _NoopAuditClient(),
          accountResolver: () async => const OpenListCredentials(
            mode: OpenListAccountMode.personal,
            username: '20240001',
            password: '20240001',
          ),
        ),
      );

      await controller.load();

      expect(controller.canUpload, isFalse);
      expect(controller.canCreateFolder, isFalse);
      expect(controller.canCreateShare, isTrue);
    });
  });

  group('OpenList raw url retry', () {
    test('relogins and retries once when resolving raw url expires', () async {
      final client = _RetryGetClient();
      final repository = OpenListRepository(
        client: client,
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
      );

      final rawUrl = await repository.resolveRawUrl('/a.txt');

      expect(rawUrl, 'http://example.test/a.txt');
      expect(client.loginCalls, 2);
      expect(client.getCalls, 2);
    });
  });

  group('OpenList upload request', () {
    test(
      'provision client posts tronclass proof and parses personal account',
      () async {
        final adapter = _CaptureAdapter(
          responseData:
              '{"username":"2500520215","password":"2500520215","studentId":"2500520215","studentName":"张三","permission":16648,"basePath":"/资料"}',
          wrapResponse: false,
        );
        final dio = Dio(
          BaseOptions(
            validateStatus: (status) => status != null && status < 500,
          ),
        )..httpClientAdapter = adapter;
        final client = OpenListProvisionClient(
          dio: dio,
          endpoint: 'http://audit.test/api/gueter/openlist/ensure-user',
        );

        final user = await client.ensureUser(
          const OpenListUserProvisionProof(
            accountUid: '117246',
            studentId: '2500520215',
            studentName: '张三',
            sessionId: 'session-abc',
            cookie: 'session=xyz',
          ),
        );

        expect(adapter.method, 'POST');
        expect(
          adapter.path,
          'http://audit.test/api/gueter/openlist/ensure-user',
        );
        expect(adapter.body, contains('"accountUid":"117246"'));
        expect(adapter.body, contains('"studentId":"2500520215"'));
        expect(adapter.body, contains('"sessionId":"session-abc"'));
        expect(adapter.body, contains('"cookie":"session=xyz"'));
        expect(user.username, '2500520215');
        expect(user.password, '2500520215');
      },
    );

    test('sets File-Path, Overwrite, and Authorization headers', () async {
      final adapter = _CaptureAdapter();
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://openlist.test',
          validateStatus: (status) => status != null && status < 500,
        ),
      )..httpClientAdapter = adapter;
      final client = OpenListClient(dio: dio);
      final tempDir = await Directory.systemTemp.createTemp('openlist_test_');
      final file = File('${tempDir.path}${Platform.pathSeparator}a.txt');
      await file.writeAsString('hello');
      final progressEvents = <int>[];

      await client.uploadForm(
        token: 'token-123',
        remotePath: '/资料/a.txt',
        localPath: file.path,
        onSendProgress: (sent, total) => progressEvents.add(sent),
      );

      expect(adapter.method, 'PUT');
      expect(adapter.path, '/api/fs/form');
      expect(adapter.headers['Authorization'], 'token-123');
      expect(adapter.headers['Overwrite'], 'true');
      expect(adapter.headers['File-Path'], Uri.encodeComponent('/资料/a.txt'));
      expect(progressEvents, isNotEmpty);

      await tempDir.delete(recursive: true);
    });

    test('stream upload uses fs put with file path headers', () async {
      final adapter = _CaptureAdapter();
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://openlist.test',
          validateStatus: (status) => status != null && status < 500,
        ),
      )..httpClientAdapter = adapter;
      final client = OpenListClient(dio: dio);
      final tempDir = await Directory.systemTemp.createTemp('openlist_test_');
      final file = File('${tempDir.path}${Platform.pathSeparator}a.txt');
      await file.writeAsString('hello');
      final progressEvents = <int>[];

      await client.uploadFile(
        token: 'token-123',
        remotePath: '/资料/a.txt',
        localPath: file.path,
        onSendProgress: (sent, total) => progressEvents.add(sent),
      );

      expect(adapter.method, 'PUT');
      expect(adapter.path, '/api/fs/put');
      expect(adapter.headers['Authorization'], 'token-123');
      expect(adapter.headers['Overwrite'], 'true');
      expect(adapter.headers['File-Path'], Uri.encodeComponent('/资料/a.txt'));
      expect(adapter.headers['Content-Type'], 'application/octet-stream');
      expect(adapter.body, 'hello');

      await tempDir.delete(recursive: true);
    });

    test(
      'stream upload falls back to form when fs put is unsupported',
      () async {
        final adapter = _SequenceAdapter(<_AdapterReply>[
          const _AdapterReply(
            statusCode: 404,
            body: '{"code":404,"message":"not found","data":null}',
          ),
          const _AdapterReply(
            statusCode: 200,
            body: '{"code":200,"message":"success","data":null}',
          ),
        ]);
        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://openlist.test',
            validateStatus: (status) => status != null && status < 500,
          ),
        )..httpClientAdapter = adapter;
        final client = OpenListClient(dio: dio);
        final tempDir = await Directory.systemTemp.createTemp('openlist_test_');
        final file = File('${tempDir.path}${Platform.pathSeparator}a.txt');
        await file.writeAsString('hello');

        await client.uploadFile(
          token: 'token-123',
          remotePath: '/资料/a.txt',
          localPath: file.path,
        );

        expect(adapter.paths, ['/api/fs/put', '/api/fs/form']);
        expect(
          adapter.headers.last['File-Path'],
          Uri.encodeComponent('/资料/a.txt'),
        );

        await tempDir.delete(recursive: true);
      },
    );

    test('broken pipe upload is retried once and audit is recorded', () async {
      final client = _BrokenPipeUploadClient();
      final auditClient = _CaptureAuditClient();
      final repository = OpenListRepository(
        client: client,
        auditClient: auditClient,
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
        uploaderResolver: () async => const OpenListUploaderIdentity(
          studentId: '20240001',
          studentName: 'Tester',
        ),
      );
      final tempDir = await Directory.systemTemp.createTemp('openlist_test_');
      final file = File('${tempDir.path}${Platform.pathSeparator}a.txt');
      await file.writeAsString('hello');

      await repository.uploadFile(currentPath: '/', localPath: file.path);

      expect(client.loginCalls, 2);
      expect(client.uploadCalls, 2);
      expect(auditClient.records, hasLength(1));

      await tempDir.delete(recursive: true);
    });

    test('auth expired during upload relogins and retries', () async {
      final client = _AuthExpiredUploadClient();
      final repository = OpenListRepository(
        client: client,
        accountResolver: () async => const OpenListCredentials(
          mode: OpenListAccountMode.personal,
          username: '20240001',
          password: '20240001',
        ),
      );
      final tempDir = await Directory.systemTemp.createTemp('openlist_test_');
      final file = File('${tempDir.path}${Platform.pathSeparator}a.txt');
      await file.writeAsString('hello');

      await repository.uploadFile(currentPath: '/', localPath: file.path);

      expect(client.loginCalls, 2);
      expect(client.uploadCalls, 2);

      await tempDir.delete(recursive: true);
    });

    test('mkdir request sets path and Authorization header', () async {
      final adapter = _CaptureAdapter();
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://openlist.test',
          validateStatus: (status) => status != null && status < 500,
        ),
      )..httpClientAdapter = adapter;
      final client = OpenListClient(dio: dio);

      await client.mkdir(token: 'token-123', path: '/资料/new');

      expect(adapter.method, 'POST');
      expect(adapter.path, '/api/fs/mkdir');
      expect(adapter.headers['Authorization'], 'token-123');
      expect(adapter.body, contains('"path":"/资料/new"'));
    });

    test('share request creates OpenList share url', () async {
      final adapter = _CaptureAdapter(
        responseData: '{"id":"abc123","files":["/资料/a.txt"]}',
      );
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://openlist.test',
          validateStatus: (status) => status != null && status < 500,
        ),
      )..httpClientAdapter = adapter;
      final client = OpenListClient(dio: dio);

      final share = await client.createShare(
        token: 'token-123',
        path: '/资料/a.txt',
      );

      expect(adapter.method, 'POST');
      expect(adapter.path, '/api/share/create');
      expect(adapter.headers['Authorization'], 'token-123');
      expect(adapter.body, contains('/资料/a.txt'));
      expect(share.id, 'abc123');
      expect(share.url, endsWith('/sd/abc123'));
    });

    test(
      'audit client sends upload record payload and secret header',
      () async {
        final adapter = _CaptureAdapter();
        final dio = Dio(
          BaseOptions(
            validateStatus: (status) => status != null && status < 500,
          ),
        )..httpClientAdapter = adapter;
        final client = OpenListUploadAuditClient(
          dio: dio,
          endpoint: 'http://audit.test/upload-record',
          auditKey: 'secret',
        );

        await client.submit(
          OpenListUploadAuditRecord(
            studentId: '20240001',
            studentName: '张三',
            remotePath: '/a.txt',
            fileName: 'a.txt',
            size: 5,
            uploadedAt: DateTime.utc(2026),
            openListUsername: 'cszm1',
            permission: 16648,
            clientPlatform: 'windows',
            source: 'app',
          ),
        );

        expect(adapter.method, 'POST');
        expect(adapter.path, 'http://audit.test/upload-record');
        expect(adapter.headers['X-GUETer-Audit-Key'], 'secret');
        expect(adapter.body, contains('"studentId":"20240001"'));
        expect(adapter.body, contains('"studentName":"张三"'));
        expect(adapter.body, contains('"source":"app"'));
      },
    );
  });
}

class _RetryClient extends OpenListClient {
  int loginCalls = 0;
  int listCalls = 0;

  @override
  Future<String> login(OpenListCredentials credentials) async {
    loginCalls++;
    return 'token-$loginCalls';
  }

  @override
  Future<OpenListUserProfile> me(String token) async {
    return const OpenListUserProfile(
      username: 'cszm1',
      permission: 16648,
      basePath: '/',
      disabled: false,
    );
  }

  @override
  Future<OpenListDirectoryListing> list({
    required String token,
    required String path,
  }) async {
    listCalls++;
    if (listCalls == 1) {
      throw const OpenListApiException('token expired', code: 401);
    }
    return const OpenListDirectoryListing(
      content: [],
      total: 1,
      write: true,
      provider: 'unknown',
      readme: '',
      header: '',
    );
  }
}

class _RetryGetClient extends _RetryClient {
  int getCalls = 0;

  @override
  Future<OpenListFileDetail> get({
    required String token,
    required String path,
  }) async {
    getCalls++;
    if (getCalls == 1) {
      throw const OpenListApiException('token expired', code: 401);
    }
    return const OpenListFileDetail(
      name: 'a.txt',
      size: 1,
      isDir: false,
      rawUrl: 'http://example.test/a.txt',
    );
  }
}

class _ListingClient extends OpenListClient {
  _ListingClient({this.permission = 16648, this.write = true});

  final int permission;
  final bool write;
  OpenListCredentials? lastCredentials;

  @override
  Future<String> login(OpenListCredentials credentials) async {
    lastCredentials = credentials;
    return 'token';
  }

  @override
  Future<OpenListDirectoryListing> list({
    required String token,
    required String path,
  }) async {
    return OpenListDirectoryListing(
      content: [
        const OpenListFileItem(
          name: 'folder',
          size: 0,
          isDir: true,
          modified: null,
          created: null,
          sign: '',
          thumb: '',
          type: 1,
        ),
        const OpenListFileItem(
          name: 'b.txt',
          size: 20,
          isDir: false,
          modified: null,
          created: null,
          sign: '',
          thumb: '',
          type: 0,
        ),
        const OpenListFileItem(
          name: 'a.txt',
          size: 10,
          isDir: false,
          modified: null,
          created: null,
          sign: '',
          thumb: '',
          type: 0,
        ),
      ],
      total: 3,
      write: write,
      provider: 'unknown',
      readme: '',
      header: '',
    );
  }

  @override
  Future<OpenListUserProfile> me(String token) async {
    return OpenListUserProfile(
      username: permission == 16648
          ? lastCredentials?.username ?? 'cszm1'
          : 'cszm',
      permission: permission,
      basePath: '/',
      disabled: false,
    );
  }
}

class _UploadProgressClient extends _ListingClient {
  int uploadCalls = 0;

  @override
  Future<void> uploadFile({
    required String token,
    required String remotePath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    uploadCalls++;
    onSendProgress?.call(5, 10);
    onSendProgress?.call(10, 10);
  }
}

class _BrokenPipeUploadClient extends _ListingClient {
  int loginCalls = 0;
  int uploadCalls = 0;

  @override
  Future<String> login(OpenListCredentials credentials) async {
    loginCalls++;
    return 'token-$loginCalls';
  }

  @override
  Future<void> uploadFile({
    required String token,
    required String remotePath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    uploadCalls++;
    if (uploadCalls == 1) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/fs/put'),
        type: DioExceptionType.unknown,
        error: SocketException(
          'Broken pipe',
          address: InternetAddress('192.0.2.1'),
          port: 48580,
        ),
      );
    }
  }
}

class _AuthExpiredUploadClient extends _ListingClient {
  int loginCalls = 0;
  int uploadCalls = 0;

  @override
  Future<String> login(OpenListCredentials credentials) async {
    loginCalls++;
    return 'token-$loginCalls';
  }

  @override
  Future<void> uploadFile({
    required String token,
    required String remotePath,
    required String localPath,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    uploadCalls++;
    if (uploadCalls == 1) {
      throw const OpenListApiException('token expired', code: 401);
    }
  }
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter({this.responseData = 'null', this.wrapResponse = true});

  final String responseData;
  final bool wrapResponse;
  String? method;
  String? path;
  Map<String, dynamic> headers = {};
  String body = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    path = options.path.startsWith('http') ? options.path : options.uri.path;
    headers = Map<String, dynamic>.from(options.headers);
    final chunks = <int>[];
    await for (final chunk
        in requestStream ?? const Stream<Uint8List>.empty()) {
      chunks.addAll(chunk);
    }
    body = utf8.decode(chunks);
    final responseBody = wrapResponse
        ? '{"code":200,"message":"success","data":$responseData}'
        : responseData;
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterReply {
  const _AdapterReply({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.replies);

  final List<_AdapterReply> replies;
  final paths = <String>[];
  final headers = <Map<String, dynamic>>[];
  var _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(
      options.path.startsWith('http') ? options.path : options.uri.path,
    );
    headers.add(Map<String, dynamic>.from(options.headers));
    await for (final _ in requestStream ?? const Stream<Uint8List>.empty()) {}
    final reply = replies[_index++];
    return ResponseBody.fromString(
      reply.body,
      reply.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NoopAuditClient extends OpenListUploadAuditClient {
  @override
  Future<void> submit(OpenListUploadAuditRecord record) async {}
}

class _CaptureAuditClient extends OpenListUploadAuditClient {
  final records = <OpenListUploadAuditRecord>[];

  @override
  Future<void> submit(OpenListUploadAuditRecord record) async {
    records.add(record);
  }
}

class _CaptureProvisionClient extends OpenListProvisionClient {
  int calls = 0;
  OpenListUserProvisionProof? lastProof;

  @override
  Future<OpenListProvisionedUser> ensureUser(
    OpenListUserProvisionProof proof,
  ) async {
    calls++;
    lastProof = proof;
    return OpenListProvisionedUser(
      username: proof.studentId,
      password: proof.studentId,
      studentId: proof.studentId,
      studentName: proof.studentName,
      permission: 16648,
      basePath: '/资料',
    );
  }
}

class _FailingAuditClient extends OpenListUploadAuditClient {
  @override
  Future<void> submit(OpenListUploadAuditRecord record) async {
    throw const OpenListApiException('audit offline');
  }
}
