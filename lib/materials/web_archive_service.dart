import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'material_index_models.dart';
import 'material_index_service.dart';
import 'material_library_store.dart';
import 'web_archive_models.dart';
import 'web_archive_store.dart';

typedef WebArchiveFetch = Future<Response<dynamic>> Function(String url);
typedef WebArchiveDirectoryLoader = Future<Directory> Function();

class WebArchiveService {
  WebArchiveService({
    Dio? dio,
    WebArchiveStore? store,
    MaterialLibraryStore? materialLibraryStore,
    MaterialIndexService? materialIndexService,
    WebArchiveFetch? fetch,
    WebArchiveDirectoryLoader? directoryLoader,
  }) : _dio = dio ?? _defaultDio(),
       _store = store ?? WebArchiveStore(),
       _materialLibraryStore = materialLibraryStore ?? MaterialLibraryStore(),
       _materialIndexService = materialIndexService ?? MaterialIndexService(),
       _fetch = fetch,
       _directoryLoader = directoryLoader ?? getApplicationSupportDirectory;

  static const String sourceLabel = '网页归档';
  static const int maxSnapshotChars = 160000;

  final Dio _dio;
  final WebArchiveStore _store;
  final MaterialLibraryStore _materialLibraryStore;
  final MaterialIndexService _materialIndexService;
  final WebArchiveFetch? _fetch;
  final WebArchiveDirectoryLoader _directoryLoader;

  static Dio _defaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        followRedirects: true,
        responseType: ResponseType.plain,
        headers: const <String, String>{
          'Accept': 'text/html,application/xhtml+xml,text/plain,*/*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.7',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 GUETer-WebArchive',
        },
      ),
    );
  }

  Future<WebArchiveItem> archiveUrl({
    required String url,
    List<String> tags = const <String>[],
  }) async {
    final normalizedUrl = WebArchiveStore.normalizeUrl(url);
    final parsed = Uri.tryParse(normalizedUrl);
    if (parsed == null || !parsed.hasScheme) {
      throw ArgumentError('请输入有效链接。');
    }
    try {
      final response = _fetch == null
          ? await _dio.get<dynamic>(normalizedUrl)
          : await _fetch(normalizedUrl);
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw DioException.badResponse(
          statusCode: status,
          requestOptions: response.requestOptions,
          response: response,
        );
      }
      final html = response.data?.toString() ?? '';
      final parsedPage = parseHtml(normalizedUrl, html);
      final files = await _writeSnapshots(
        url: normalizedUrl,
        html: html,
        text: parsedPage.text,
      );
      final now = DateTime.now();
      final item = await _store.upsertItem(
        WebArchiveItem(
          id: WebArchiveStore.idForUrl(normalizedUrl),
          url: normalizedUrl,
          title: parsedPage.title.trim().isNotEmpty
              ? parsedPage.title.trim()
              : normalizedUrl,
          description: parsedPage.description,
          siteName: parsedPage.siteName,
          faviconUrl: parsedPage.faviconUrl,
          textSnapshotPath: files.textPath,
          sourceHtmlPath: files.htmlPath,
          tags: tags,
          status: WebArchiveStatus.saved,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await addToMaterialLibrary(item);
      try {
        await _materialIndexService.indexExternalFile(
          path: item.textSnapshotPath,
          sourceType: MaterialSourceType.webArchive,
          sourceLabel: sourceLabel,
        );
      } catch (_) {
        // Index rebuild can recover later; a saved snapshot should not become
        // a failed archive just because indexing is unavailable in a test or
        // temporary file-system state.
      }
      return item;
    } catch (_) {
      return _store.saveUrlOnly(
        url: normalizedUrl,
        tags: tags,
        status: WebArchiveStatus.fetchError,
      );
    }
  }

  Future<MaterialLibraryItem?> addToMaterialLibrary(WebArchiveItem item) async {
    if (item.textSnapshotPath.trim().isEmpty) return null;
    final file = File(item.textSnapshotPath);
    if (!await file.exists()) return null;
    return _materialLibraryStore.upsertItem(
      path: item.textSnapshotPath,
      name: '${item.displayTitle}.txt',
      sourceType: MaterialSourceType.webArchive,
      sourceLabel: sourceLabel,
      tags: item.tags,
    );
  }

  Future<Directory> snapshotsDirectory() async {
    final base = await _directoryLoader();
    final dir = Directory(p.join(base.path, 'web_archive'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<MaterialScanRoot>> scanRoots() async {
    final dir = await snapshotsDirectory();
    return <MaterialScanRoot>[
      MaterialScanRoot(
        sourceType: MaterialSourceType.webArchive,
        sourceLabel: sourceLabel,
        path: dir.path,
      ),
    ];
  }

  WebArchiveParsedPage parseHtml(String url, String html) {
    final document = html_parser.parse(html);
    final title = _firstNonEmpty(<String>[
      _meta(document, 'property', 'og:title'),
      document.querySelector('title')?.text ?? '',
      _meta(document, 'name', 'twitter:title'),
    ]);
    final description = _firstNonEmpty(<String>[
      _meta(document, 'name', 'description'),
      _meta(document, 'property', 'og:description'),
      _meta(document, 'name', 'twitter:description'),
    ]);
    final siteName = _firstNonEmpty(<String>[
      _meta(document, 'property', 'og:site_name'),
      Uri.tryParse(url)?.host ?? '',
    ]);
    final favicon = _resolveUrl(
      url,
      document.querySelector('link[rel="icon"]')?.attributes['href']?.trim() ??
          document
              .querySelector('link[rel="shortcut icon"]')
              ?.attributes['href']
              ?.trim() ??
          '',
    );
    document.querySelectorAll('script,style,noscript,svg').forEach((node) {
      node.remove();
    });
    final main =
        document.querySelector('article') ??
        document.querySelector('main') ??
        document.querySelector('[role="main"]') ??
        document.body ??
        document.documentElement;
    final bodyText = _normalizeText(main?.text ?? document.outerHtml);
    final snapshot = <String>[
      if (title.trim().isNotEmpty) '# ${title.trim()}',
      if (url.trim().isNotEmpty) '链接：$url',
      if (siteName.trim().isNotEmpty) '站点：$siteName',
      if (description.trim().isNotEmpty) '摘要：$description',
      '',
      bodyText,
    ].join('\n');
    return WebArchiveParsedPage(
      title: title,
      description: description,
      siteName: siteName,
      faviconUrl: favicon,
      text: _clip(snapshot, maxSnapshotChars),
    );
  }

  Future<_SnapshotFiles> _writeSnapshots({
    required String url,
    required String html,
    required String text,
  }) async {
    final dir = await snapshotsDirectory();
    final digest = sha1.convert(utf8.encode(url)).toString();
    final textPath = p.join(dir.path, '$digest.txt');
    final htmlPath = p.join(dir.path, '$digest.html');
    await File(textPath).writeAsString(text, encoding: utf8, flush: true);
    await File(htmlPath).writeAsString(html, encoding: utf8, flush: true);
    return _SnapshotFiles(textPath: textPath, htmlPath: htmlPath);
  }

  String _meta(dynamic document, String key, String value) {
    return document
            .querySelector('meta[$key="$value"]')
            ?.attributes['content']
            ?.trim() ??
        '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return _normalizeText(value);
    }
    return '';
  }

  String _resolveUrl(String baseUrl, String value) {
    if (value.isEmpty) return '';
    final base = Uri.tryParse(baseUrl);
    final uri = Uri.tryParse(value);
    if (base == null || uri == null) return value;
    return base.resolveUri(uri).toString();
  }

  String _normalizeText(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  String _clip(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }
}

class WebArchiveParsedPage {
  const WebArchiveParsedPage({
    required this.title,
    required this.description,
    required this.siteName,
    required this.faviconUrl,
    required this.text,
  });

  final String title;
  final String description;
  final String siteName;
  final String faviconUrl;
  final String text;
}

class _SnapshotFiles {
  const _SnapshotFiles({required this.textPath, required this.htmlPath});

  final String textPath;
  final String htmlPath;
}
