import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../session/app_settings.dart';

enum AcademicSource { crossRef, arxiv }

extension AcademicSourceX on AcademicSource {
  String get displayName {
    switch (this) {
      case AcademicSource.crossRef:
        return 'CrossRef';
      case AcademicSource.arxiv:
        return 'arXiv';
    }
  }
}

class AcademicPaper {
  const AcademicPaper({
    required this.id,
    required this.source,
    required this.title,
    required this.authors,
    this.year,
    this.venue,
    this.doi,
    this.citationCount,
    this.abstractText,
    this.pdfUrl,
    this.detailUrl,
    this.isPrefetchedDetail = false,
    this.volume,
    this.issue,
    this.pages,
    this.favoritedAt,
    this.metadataOrigins = const <String, String>{},
  });

  final String id;
  final AcademicSource source;
  final String title;
  final List<String> authors;
  final int? year;
  final String? venue;
  final String? doi;
  final int? citationCount;
  final String? abstractText;
  final String? pdfUrl;
  final String? detailUrl;
  final bool isPrefetchedDetail;
  final String? volume;
  final String? issue;
  final String? pages;
  final DateTime? favoritedAt;
  final Map<String, String> metadataOrigins;

  String get stableKey => '${source.name}:$id';

  String get selectionKey => stableKey;

  String get authorsText {
    if (authors.isEmpty) {
      return 'Unknown';
    }
    return authors.join(', ');
  }

  bool get hasDetailData {
    return _hasText(abstractText) ||
        _hasText(venue) ||
        _hasText(doi) ||
        _hasText(volume) ||
        _hasText(issue) ||
        _hasText(pages) ||
        _hasText(pdfUrl);
  }

  AcademicPaper copyWith({
    String? id,
    AcademicSource? source,
    String? title,
    List<String>? authors,
    int? year,
    String? venue,
    String? doi,
    int? citationCount,
    String? abstractText,
    String? pdfUrl,
    String? detailUrl,
    bool? isPrefetchedDetail,
    String? volume,
    String? issue,
    String? pages,
    DateTime? favoritedAt,
    Map<String, String>? metadataOrigins,
  }) {
    return AcademicPaper(
      id: id ?? this.id,
      source: source ?? this.source,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      year: year ?? this.year,
      venue: venue ?? this.venue,
      doi: doi ?? this.doi,
      citationCount: citationCount ?? this.citationCount,
      abstractText: abstractText ?? this.abstractText,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      detailUrl: detailUrl ?? this.detailUrl,
      isPrefetchedDetail: isPrefetchedDetail ?? this.isPrefetchedDetail,
      volume: volume ?? this.volume,
      issue: issue ?? this.issue,
      pages: pages ?? this.pages,
      favoritedAt: favoritedAt ?? this.favoritedAt,
      metadataOrigins: metadataOrigins ?? this.metadataOrigins,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'source': source.name,
      'title': title,
      'authors': authors,
      'year': year,
      'venue': venue,
      'doi': doi,
      'citationCount': citationCount,
      'abstractText': abstractText,
      'pdfUrl': pdfUrl,
      'detailUrl': detailUrl,
      'isPrefetchedDetail': isPrefetchedDetail,
      'volume': volume,
      'issue': issue,
      'pages': pages,
      'favoritedAt': favoritedAt?.toIso8601String(),
      'metadataOrigins': metadataOrigins,
    };
  }

  factory AcademicPaper.fromJson(Map<String, dynamic> json) {
    return AcademicPaper(
      id: json['id']?.toString() ?? '',
      source: _academicSourceFromString(json['source']?.toString()),
      title: json['title']?.toString() ?? 'Untitled',
      authors: (json['authors'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic item) => item.toString())
          .where((String item) => item.trim().isNotEmpty)
          .toList(),
      year: _asInt(json['year']),
      venue: _trimmedOrNull(json['venue']?.toString()),
      doi: _trimmedOrNull(json['doi']?.toString()),
      citationCount: _asInt(json['citationCount']),
      abstractText: _trimmedOrNull(json['abstractText']?.toString()),
      pdfUrl: _trimmedOrNull(json['pdfUrl']?.toString()),
      detailUrl: _trimmedOrNull(json['detailUrl']?.toString()),
      isPrefetchedDetail: json['isPrefetchedDetail'] == true,
      volume: _trimmedOrNull(json['volume']?.toString()),
      issue: _trimmedOrNull(json['issue']?.toString()),
      pages: _trimmedOrNull(json['pages']?.toString()),
      favoritedAt: _parseDateTime(json['favoritedAt']?.toString()),
      metadataOrigins:
          (json['metadataOrigins'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .map(
                (dynamic key, dynamic value) =>
                    MapEntry(key.toString(), value.toString()),
              ),
    );
  }
}

class AcademicReference {
  const AcademicReference({
    required this.title,
    required this.authorsText,
    this.year,
    this.doi,
    this.journal,
    this.rawCitation,
  });

  final String title;
  final String authorsText;
  final int? year;
  final String? doi;
  final String? journal;
  final String? rawCitation;
}

class AcademicNote {
  const AcademicNote({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  AcademicNote copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AcademicNote(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AcademicNote.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return AcademicNote(
      id: json['id']?.toString() ?? now.microsecondsSinceEpoch.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: _parseDateTime(json['createdAt']?.toString()) ?? now,
      updatedAt: _parseDateTime(json['updatedAt']?.toString()) ?? now,
    );
  }
}

class AcademicSearchSnapshot {
  const AcademicSearchSnapshot({
    required this.papers,
    required this.isFromCache,
    required this.isRefreshing,
    this.completedSources = const <AcademicSource>{},
    this.failedSources = const <AcademicSource>{},
  });

  final List<AcademicPaper> papers;
  final bool isFromCache;
  final bool isRefreshing;
  final Set<AcademicSource> completedSources;
  final Set<AcademicSource> failedSources;
}

class _SourceSearchResult {
  const _SourceSearchResult({
    required this.source,
    required this.papers,
    this.error,
  });

  final AcademicSource source;
  final List<AcademicPaper> papers;
  final Object? error;
}

class AcademicApiService {
  factory AcademicApiService() => _instance;

  AcademicApiService._internal();

  static final AcademicApiService _instance = AcademicApiService._internal();

  static const String _crossRefBaseUrl = 'https://api.crossref.org';
  static const String _arxivBaseUrl = 'https://export.arxiv.org/api';
  static const String _semanticScholarBaseUrl =
      'https://api.semanticscholar.org/graph/v1';
  static const String _searchCachePrefix = 'academic_search_cache_';
  static const String _favoritesKey = 'academic_favorites';
  static const String _notesKey = 'academic_notes';
  static const Duration _searchCacheTtl = Duration(hours: 1);
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const List<Duration> _retryBackoff = <Duration>[
    Duration(milliseconds: 500),
    Duration(seconds: 1),
  ];

  final Dio _crossRefDio = Dio(
    BaseOptions(
      baseUrl: _crossRefBaseUrl,
      connectTimeout: _requestTimeout,
      receiveTimeout: _requestTimeout,
      headers: const <String, String>{'Accept': 'application/json'},
    ),
  );
  final Dio _arxivDio = Dio(
    BaseOptions(
      baseUrl: _arxivBaseUrl,
      connectTimeout: _requestTimeout,
      receiveTimeout: _requestTimeout,
      responseType: ResponseType.plain,
    ),
  );
  final Dio _semanticScholarDio = Dio(
    BaseOptions(
      baseUrl: _semanticScholarBaseUrl,
      connectTimeout: _requestTimeout,
      receiveTimeout: _requestTimeout,
      headers: const <String, String>{'Accept': 'application/json'},
    ),
  );

  Future<SharedPreferences>? _prefsFuture;
  final Map<String, AcademicPaper> _detailMemoryCache =
      <String, AcademicPaper>{};
  final Map<String, Future<AcademicPaper>> _detailPrefetchFutures =
      <String, Future<AcademicPaper>>{};

  Future<List<AcademicPaper>> searchPapers(String query) async {
    final results = await Future.wait<_SourceSearchResult>(
      <Future<_SourceSearchResult>>[
        _safeSearchCrossRef(query),
        _safeSearchArxiv(query),
      ],
    );

    final papers = _mergePaperLists(
      results
          .where((result) => result.error == null)
          .map((result) => result.papers)
          .toList(),
    );

    if (papers.isNotEmpty) {
      await _writeSearchCache(query, papers);
    }

    return papers;
  }

  Stream<AcademicSearchSnapshot> searchPapersStream(String query) async* {
    final cached = await _readSearchCache(query);
    if (cached != null && cached.isNotEmpty) {
      yield AcademicSearchSnapshot(
        papers: cached,
        isFromCache: true,
        isRefreshing: true,
      );
    }

    final futures = <AcademicSource, Future<_SourceSearchResult>>{
      AcademicSource.crossRef: _safeSearchCrossRef(query),
      AcademicSource.arxiv: _safeSearchArxiv(query),
    };
    final sourceResults = <AcademicSource, List<AcademicPaper>>{};
    final completedSources = <AcademicSource>{};
    final failedSources = <AcademicSource>{};

    while (futures.isNotEmpty) {
      final MapEntry<AcademicSource, _SourceSearchResult> completed =
          await Future.any<MapEntry<AcademicSource, _SourceSearchResult>>(
            futures.entries.map((
              MapEntry<AcademicSource, Future<_SourceSearchResult>> entry,
            ) async {
              final result = await entry.value;
              return MapEntry<AcademicSource, _SourceSearchResult>(
                entry.key,
                result,
              );
            }),
          );

      futures.remove(completed.key);
      completedSources.add(completed.key);

      if (completed.value.error != null) {
        failedSources.add(completed.key);
      } else {
        sourceResults[completed.key] = completed.value.papers;
      }

      final partial = _mergeSnapshotPapers(
        cached: cached,
        completedSources: completedSources,
        sourceResults: sourceResults,
      );

      yield AcademicSearchSnapshot(
        papers: partial,
        isFromCache: partial == cached,
        isRefreshing: futures.isNotEmpty,
        completedSources: Set<AcademicSource>.from(completedSources),
        failedSources: Set<AcademicSource>.from(failedSources),
      );
    }

    final fresh = _mergePaperLists(sourceResults.values.toList());
    final finalPapers = fresh.isNotEmpty
        ? fresh
        : (cached ?? <AcademicPaper>[]);
    if (fresh.isNotEmpty) {
      await _writeSearchCache(query, fresh);
    }

    yield AcademicSearchSnapshot(
      papers: finalPapers,
      isFromCache: fresh.isEmpty,
      isRefreshing: false,
      completedSources: Set<AcademicSource>.from(completedSources),
      failedSources: Set<AcademicSource>.from(failedSources),
    );
  }

  Future<AcademicPaper> getPaperDetail(String id, AcademicSource source) async {
    final stableKey = '${source.name}:$id';
    final cached = _detailMemoryCache[stableKey];
    if (cached != null && cached.hasDetailData) {
      return cached;
    }

    final favorite = await getFavoritePaper(stableKey);

    try {
      final detail = source == AcademicSource.crossRef
          ? await _fetchCrossRefDetailByDoi(id)
          : await _fetchArxivDetail(id);
      final merged = _mergeDuplicatePapers(detail, favorite);
      _detailMemoryCache[stableKey] = merged;
      await _persistFavoriteIfExists(merged);
      return merged;
    } catch (_) {
      if (favorite != null) {
        return favorite;
      }
      rethrow;
    }
  }

  Future<void> prefetchPaperDetail(AcademicPaper paper) async {
    final key = paper.stableKey;
    if (_detailMemoryCache.containsKey(key) &&
        _detailMemoryCache[key]!.hasDetailData) {
      return;
    }

    final existing = _detailPrefetchFutures[key];
    if (existing != null) {
      await existing;
      return;
    }

    final future = getPaperDetail(paper.id, paper.source);
    _detailPrefetchFutures[key] = future;
    try {
      await future;
    } catch (_) {
      // Ignore prefetch failures.
    } finally {
      _detailPrefetchFutures.remove(key);
    }
  }

  Future<List<AcademicReference>> getReferences(String doi) async {
    if (!_hasText(doi)) {
      return <AcademicReference>[];
    }

    final response = await _withRetry<Response<dynamic>>(
      () => _crossRefGet('/works/${Uri.encodeComponent(doi.trim())}'),
    );
    final message = _crossRefMessage(response.data);
    final references =
        message['reference'] as List<dynamic>? ?? const <dynamic>[];

    return references.map((dynamic item) {
      final Map<String, dynamic> map = (item as Map<dynamic, dynamic>).map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
      final title =
          _firstString(map['article-title']) ??
          _firstString(map['series-title']) ??
          _trimmedOrNull(map['unstructured']?.toString()) ??
          _trimmedOrNull(map['DOI']?.toString()) ??
          'Untitled reference';
      final authors = <String>[
        if (_hasText(map['author']?.toString()))
          map['author'].toString().trim(),
        if (_hasText(map['editor']?.toString()))
          map['editor'].toString().trim(),
      ].join(', ');
      return AcademicReference(
        title: title,
        authorsText: authors.isEmpty ? 'Unknown' : authors,
        year: _asInt(map['year']),
        doi: _trimmedOrNull(map['DOI']?.toString()),
        journal:
            _firstString(map['journal-title']) ??
            _trimmedOrNull(map['volume-title']?.toString()),
        rawCitation: _trimmedOrNull(map['unstructured']?.toString()),
      );
    }).toList();
  }

  Future<String> getBibTeX(AcademicPaper paper) async {
    final identifier = _sanitizeBibtexIdentifier(
      paper.doi ?? '${paper.authors.firstOrNull ?? 'paper'}${paper.year ?? ''}',
    );
    final authorValue = paper.authors.isEmpty
        ? 'Unknown'
        : paper.authors.join(' and ');
    final fields = <String>[
      '  title = {${_escapeBibtexValue(paper.title)}}',
      '  author = {${_escapeBibtexValue(authorValue)}}',
      if (paper.year != null) '  year = {${paper.year}}',
      if (_hasText(paper.venue))
        '  journal = {${_escapeBibtexValue(paper.venue!.trim())}}',
      if (_hasText(paper.volume))
        '  volume = {${_escapeBibtexValue(paper.volume!.trim())}}',
      if (_hasText(paper.issue))
        '  number = {${_escapeBibtexValue(paper.issue!.trim())}}',
      if (_hasText(paper.pages))
        '  pages = {${_escapeBibtexValue(paper.pages!.trim())}}',
      if (_hasText(paper.doi))
        '  doi = {${_escapeBibtexValue(paper.doi!.trim())}}',
      if (_hasText(paper.detailUrl))
        '  url = {${_escapeBibtexValue(paper.detailUrl!.trim())}}',
    ];

    return '@article{$identifier,\n${fields.join(',\n')}\n}';
  }

  Future<Uint8List> exportToPdf(List<AcademicPaper> papers) async {
    final document = PdfDocument();
    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      18,
      style: PdfFontStyle.bold,
    );
    final headingFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      13,
      style: PdfFontStyle.bold,
    );
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    PdfPage page = document.pages.add();
    double top = 0;

    PdfLayoutResult drawBlock(
      String text,
      PdfFont font, {
      double spacingBefore = 0,
      double spacingAfter = 8,
    }) {
      top += spacingBefore;
      final PdfTextElement element = PdfTextElement(text: text, font: font);
      final PdfLayoutResult result = element.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          top,
          page.getClientSize().width,
          page.getClientSize().height - top,
        ),
        format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
      )!;
      page = result.page;
      top = result.bounds.bottom + spacingAfter;
      if (top > page.getClientSize().height - 40) {
        page = document.pages.add();
        top = 0;
      }
      return result;
    }

    drawBlock('Academic Papers Export', titleFont, spacingAfter: 16);
    drawBlock(
      'Generated at ${DateTime.now().toLocal()}',
      bodyFont,
      spacingAfter: 20,
    );

    for (int index = 0; index < papers.length; index++) {
      final AcademicPaper paper = papers[index];
      final lines = <String>[
        'Authors: ${paper.authorsText}',
        'Year: ${paper.year?.toString() ?? '--'}',
        'Source: ${paper.source.displayName}',
        'Venue: ${paper.venue?.trim().isNotEmpty == true ? paper.venue!.trim() : '--'}',
        'DOI: ${paper.doi ?? '--'}',
        'Citations: ${paper.citationCount?.toString() ?? '--'}',
        if (_hasText(paper.volume)) 'Volume: ${paper.volume}',
        if (_hasText(paper.issue)) 'Issue: ${paper.issue}',
        if (_hasText(paper.pages)) 'Pages: ${paper.pages}',
        if (_hasText(paper.pdfUrl)) 'PDF: ${paper.pdfUrl}',
      ];
      drawBlock('${index + 1}. ${paper.title}', headingFont, spacingAfter: 8);
      drawBlock(lines.join('\n'), bodyFont, spacingAfter: 8);
      if (_hasText(paper.abstractText)) {
        drawBlock(
          'Abstract\n${paper.abstractText!.trim()}',
          bodyFont,
          spacingAfter: 14,
        );
      } else {
        top += 8;
      }
    }

    final bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  Future<void> addToFavorites(AcademicPaper paper) async {
    final prefs = await _preferences();
    final favorites = await _readFavorites();
    final existing = favorites[paper.stableKey];
    final base = _mergeDuplicatePapers(paper, existing);
    final enriched = await enrichPaperMetadata(base);
    final favorited = enriched.copyWith(favoritedAt: DateTime.now());
    favorites[favorited.stableKey] = favorited;
    final encodedFavorites = favorites.values.toList()
      ..sort(
        (AcademicPaper a, AcademicPaper b) =>
            (b.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
      );
    await prefs.setString(
      _favoritesKey,
      jsonEncode(
        encodedFavorites.map((AcademicPaper item) => item.toJson()).toList(),
      ),
    );
    _detailMemoryCache[favorited.stableKey] = favorited;
  }

  Future<void> removeFromFavorites(String paperId) async {
    final prefs = await _preferences();
    final favorites = await _readFavorites();
    favorites.remove(paperId);
    await prefs.setString(
      _favoritesKey,
      jsonEncode(
        favorites.values.map((AcademicPaper item) => item.toJson()).toList(),
      ),
    );
  }

  Future<List<AcademicPaper>> getFavorites() async {
    final favorites = await _readFavorites();
    final list = favorites.values.toList()
      ..sort(
        (AcademicPaper a, AcademicPaper b) =>
            (b.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
              a.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            ),
      );
    return list;
  }

  Future<AcademicPaper?> getFavoritePaper(String paperId) async {
    final favorites = await _readFavorites();
    return favorites[paperId];
  }

  Future<bool> isFavorite(String paperId) async {
    final favorites = await _readFavorites();
    return favorites.containsKey(paperId);
  }

  Future<AcademicPaper> enrichPaperMetadata(AcademicPaper paper) async {
    final existing = await getFavoritePaper(paper.stableKey);
    AcademicPaper current = _mergeDuplicatePapers(paper, existing);

    final crossRefEnriched = await _enrichWithCrossRef(current);
    current = _mergeEnrichment(current, crossRefEnriched);

    if (_paperNeedsEnrichment(current)) {
      final semanticEnriched = await _enrichWithSemanticScholar(current);
      current = _mergeEnrichment(current, semanticEnriched);
    }

    return current;
  }

  Future<List<AcademicNote>> getNotes(String paperId) async {
    final notesMap = await _readNotesMap();
    final notes = notesMap[paperId] ?? <AcademicNote>[];
    notes.sort(
      (AcademicNote a, AcademicNote b) => b.createdAt.compareTo(a.createdAt),
    );
    return notes;
  }

  Future<AcademicNote> addNote(String paperId, String content) async {
    final now = DateTime.now();
    final note = AcademicNote(
      id: now.microsecondsSinceEpoch.toString(),
      content: content.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final notesMap = await _readNotesMap();
    final list = List<AcademicNote>.from(notesMap[paperId] ?? <AcademicNote>[]);
    list.add(note);
    notesMap[paperId] = list;
    await _writeNotesMap(notesMap);
    return note;
  }

  Future<AcademicNote?> updateNote(
    String paperId,
    String noteId,
    String content,
  ) async {
    final notesMap = await _readNotesMap();
    final list = List<AcademicNote>.from(notesMap[paperId] ?? <AcademicNote>[]);
    final index = list.indexWhere((AcademicNote note) => note.id == noteId);
    if (index < 0) {
      return null;
    }

    final updated = list[index].copyWith(
      content: content.trim(),
      updatedAt: DateTime.now(),
    );
    list[index] = updated;
    notesMap[paperId] = list;
    await _writeNotesMap(notesMap);
    return updated;
  }

  Future<void> deleteNote(String paperId, String noteId) async {
    final notesMap = await _readNotesMap();
    final list = List<AcademicNote>.from(notesMap[paperId] ?? <AcademicNote>[]);
    list.removeWhere((AcademicNote note) => note.id == noteId);
    notesMap[paperId] = list;
    await _writeNotesMap(notesMap);
  }

  Future<_SourceSearchResult> _safeSearchCrossRef(String query) async {
    try {
      final papers = await _searchCrossRef(query);
      return _SourceSearchResult(
        source: AcademicSource.crossRef,
        papers: papers,
      );
    } catch (error) {
      return _SourceSearchResult(
        source: AcademicSource.crossRef,
        papers: const <AcademicPaper>[],
        error: error,
      );
    }
  }

  Future<_SourceSearchResult> _safeSearchArxiv(String query) async {
    try {
      final papers = await _searchArxiv(query);
      return _SourceSearchResult(source: AcademicSource.arxiv, papers: papers);
    } catch (error) {
      return _SourceSearchResult(
        source: AcademicSource.arxiv,
        papers: const <AcademicPaper>[],
        error: error,
      );
    }
  }

  Future<List<AcademicPaper>> _searchCrossRef(String query) async {
    final response = await _withRetry<Response<dynamic>>(
      () => _crossRefGet(
        '/works',
        queryParameters: <String, dynamic>{
          'query': query,
          'rows': 20,
          'sort': 'relevance',
        },
      ),
    );
    final message = _crossRefMessage(response.data);
    final items = message['items'] as List<dynamic>? ?? const <dynamic>[];
    return items
        .map((dynamic item) => _paperFromCrossRefItem(_stringKeyedMap(item)))
        .where((AcademicPaper paper) => _hasText(paper.title))
        .toList();
  }

  Future<List<AcademicPaper>> _searchArxiv(String query) async {
    final response = await _withRetry<Response<String>>(
      () => _arxivDio.get<String>(
        '/query',
        queryParameters: <String, dynamic>{
          'search_query': 'all:$query',
          'max_results': 20,
          'sortBy': 'submittedDate',
          'sortOrder': 'descending',
        },
      ),
    );
    return _parseArxivFeed(response.data ?? '');
  }

  Future<AcademicPaper> _fetchCrossRefDetailByDoi(String doi) async {
    final response = await _withRetry<Response<dynamic>>(
      () => _crossRefGet('/works/${Uri.encodeComponent(doi)}'),
    );
    final message = _crossRefMessage(response.data);
    return _paperFromCrossRefItem(message);
  }

  Future<AcademicPaper> _fetchArxivDetail(String id) async {
    final response = await _withRetry<Response<String>>(
      () => _arxivDio.get<String>(
        '/query',
        queryParameters: <String, dynamic>{'id_list': id},
      ),
    );
    final papers = _parseArxivFeed(response.data ?? '');
    if (papers.isEmpty) {
      throw StateError('arXiv detail not found for $id');
    }
    return papers.first;
  }

  Future<AcademicPaper> _enrichWithCrossRef(AcademicPaper paper) async {
    try {
      if (_hasText(paper.doi)) {
        return await _fetchCrossRefDetailByDoi(paper.doi!.trim());
      }

      final response = await _withRetry<Response<dynamic>>(
        () => _crossRefGet(
          '/works',
          queryParameters: <String, dynamic>{
            'query.title': paper.title,
            'rows': 5,
            'sort': 'relevance',
          },
        ),
      );
      final message = _crossRefMessage(response.data);
      final items = message['items'] as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic item in items) {
        final candidate = _paperFromCrossRefItem(_stringKeyedMap(item));
        if (_titleSimilarity(candidate.title, paper.title) >= 0.6) {
          return candidate;
        }
      }
    } catch (_) {
      // Ignore enrichment failures.
    }
    return paper;
  }

  Future<AcademicPaper> _enrichWithSemanticScholar(AcademicPaper paper) async {
    try {
      final response = await _withRetry<Response<dynamic>>(
        () => _semanticScholarDio.get<dynamic>(
          '/paper/search',
          queryParameters: <String, dynamic>{
            'query': paper.title,
            'limit': 3,
            'fields':
                'title,abstract,venue,journal,year,externalIds,authors,url',
          },
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return paper;
      }

      final items = data['data'] as List<dynamic>? ?? const <dynamic>[];
      for (final dynamic item in items) {
        final map = (item as Map<dynamic, dynamic>).map(
          (dynamic key, dynamic value) => MapEntry(key.toString(), value),
        );
        final title = _trimmedOrNull(map['title']?.toString());
        if (!_hasText(title) || _titleSimilarity(title!, paper.title) < 0.6) {
          continue;
        }

        final journal = map['journal'];
        String? venue = _trimmedOrNull(map['venue']?.toString());
        String? volume;
        String? pages;
        if (journal is Map<dynamic, dynamic>) {
          venue ??= _trimmedOrNull(journal['name']?.toString());
          volume = _trimmedOrNull(journal['volume']?.toString());
          pages = _trimmedOrNull(journal['pages']?.toString());
        }
        final externalIds = map['externalIds'];
        String? doi;
        if (externalIds is Map<dynamic, dynamic>) {
          doi = _trimmedOrNull(externalIds['DOI']?.toString());
        }

        return AcademicPaper(
          id: paper.id,
          source: paper.source,
          title: paper.title,
          authors: paper.authors,
          year: paper.year ?? _asInt(map['year']),
          venue: venue,
          doi: doi,
          citationCount: paper.citationCount,
          abstractText: _trimmedOrNull(map['abstract']?.toString()),
          pdfUrl: paper.pdfUrl,
          detailUrl: _trimmedOrNull(map['url']?.toString()) ?? paper.detailUrl,
          volume: volume,
          pages: pages,
          metadataOrigins: <String, String>{
            if (_hasText(venue)) 'venue': 'semanticScholar',
            if (_hasText(doi)) 'doi': 'semanticScholar',
            if (_hasText(map['abstract']?.toString()))
              'abstractText': 'semanticScholar',
            if (_hasText(volume)) 'volume': 'semanticScholar',
            if (_hasText(pages)) 'pages': 'semanticScholar',
          },
        );
      }
    } catch (error) {
      debugPrint('Semantic Scholar enrichment skipped: $error');
    }
    return paper;
  }

  List<AcademicPaper> _parseArxivFeed(String xmlSource) {
    if (xmlSource.trim().isEmpty) {
      return <AcademicPaper>[];
    }

    final document = XmlDocument.parse(xmlSource);
    final entries = document.findAllElements('entry');
    return entries.map(_paperFromArxivEntry).toList();
  }

  AcademicPaper _paperFromArxivEntry(XmlElement entry) {
    final title = _compactWhitespace(_xmlText(entry, 'title') ?? 'Untitled');
    final summary = _compactWhitespace(_xmlText(entry, 'summary') ?? '');
    final published =
        _xmlText(entry, 'published') ?? _xmlText(entry, 'updated');
    final year = _parseDateTime(published)?.year;
    final authors = entry
        .findElements('author')
        .map((XmlElement element) => _xmlText(element, 'name') ?? '')
        .where((String item) => item.trim().isNotEmpty)
        .toList();
    final idUrl = _compactWhitespace(_xmlText(entry, 'id') ?? '');
    final id = idUrl.split('/').last.trim();
    final links = entry.findElements('link').toList();
    String? pdfUrl;
    String? detailUrl;
    for (final XmlElement link in links) {
      final href = _trimmedOrNull(link.getAttribute('href'));
      if (!_hasText(href)) {
        continue;
      }
      final titleAttr = link.getAttribute('title') ?? '';
      final typeAttr = link.getAttribute('type') ?? '';
      final relAttr = link.getAttribute('rel') ?? '';
      if (titleAttr == 'pdf' ||
          typeAttr == 'application/pdf' ||
          href!.contains('/pdf/')) {
        pdfUrl = href;
      } else if (relAttr == 'alternate' || detailUrl == null) {
        detailUrl = href;
      }
    }

    return AcademicPaper(
      id: id,
      source: AcademicSource.arxiv,
      title: title,
      authors: authors,
      year: year,
      venue: 'arXiv',
      abstractText: summary.isEmpty ? null : summary,
      pdfUrl: pdfUrl,
      detailUrl: detailUrl ?? idUrl,
      metadataOrigins: <String, String>{
        if (summary.isNotEmpty) 'abstractText': 'arxiv',
        'venue': 'arxiv',
        if (_hasText(pdfUrl)) 'pdfUrl': 'arxiv',
      },
    );
  }

  AcademicPaper _paperFromCrossRefItem(Map<String, dynamic> item) {
    final title = _compactWhitespace(_firstString(item['title']) ?? 'Untitled');
    final authors = (item['author'] as List<dynamic>? ?? const <dynamic>[])
        .map((dynamic author) {
          if (author is! Map<dynamic, dynamic>) {
            return '';
          }
          final given = _trimmedOrNull(author['given']?.toString());
          final family = _trimmedOrNull(author['family']?.toString());
          return <String>[?given, ?family].join(' ').trim();
        })
        .where((String item) => item.isNotEmpty)
        .toList();
    final venue =
        _firstString(item['container-title']) ??
        _firstString(item['short-container-title']) ??
        _trimmedOrNull(item['publisher']?.toString());
    final doi = _trimmedOrNull(item['DOI']?.toString());
    final abstractText = _stripMarkup(
      _trimmedOrNull(item['abstract']?.toString()),
    );
    final year = _extractYearFromCrossRef(item);
    final detailUrl =
        _firstString(item['URL']) ??
        (_hasText(doi) ? 'https://doi.org/$doi' : null);

    final metadataOrigins = <String, String>{
      if (_hasText(venue)) 'venue': 'crossRef',
      if (_hasText(doi)) 'doi': 'crossRef',
      if (_hasText(abstractText)) 'abstractText': 'crossRef',
      if (_hasText(item['volume']?.toString())) 'volume': 'crossRef',
      if (_hasText(item['issue']?.toString())) 'issue': 'crossRef',
      if (_hasText(item['page']?.toString())) 'pages': 'crossRef',
    };

    return AcademicPaper(
      id: doi ?? title,
      source: AcademicSource.crossRef,
      title: title,
      authors: authors,
      year: year,
      venue: venue,
      doi: doi,
      citationCount: _asInt(item['is-referenced-by-count']),
      abstractText: abstractText,
      detailUrl: detailUrl,
      volume: _trimmedOrNull(item['volume']?.toString()),
      issue: _trimmedOrNull(item['issue']?.toString()),
      pages: _trimmedOrNull(item['page']?.toString()),
      metadataOrigins: metadataOrigins,
    );
  }

  Future<Response<dynamic>> _crossRefGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final email = await AppSettings.getString(
      AppSettings.academicApiEmailKey,
      '',
    );
    final mergedQuery = <String, dynamic>{...?queryParameters};
    if (_hasText(email)) {
      mergedQuery['mailto'] = email.trim();
    }
    return _crossRefDio.get<dynamic>(path, queryParameters: mergedQuery);
  }

  Future<T> _withRetry<T>(Future<T> Function() action) async {
    Object? lastError;
    for (int attempt = 0; attempt <= _retryBackoff.length; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (attempt >= _retryBackoff.length || !_shouldRetry(error)) {
          break;
        }
        await Future<void>.delayed(_retryBackoff[attempt]);
      }
    }
    throw lastError ?? StateError('Unknown request failure');
  }

  bool _shouldRetry(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        return true;
      }
      final statusCode = error.response?.statusCode;
      return statusCode == null || statusCode >= 500;
    }
    return false;
  }

  Future<SharedPreferences> _preferences() {
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  Future<List<AcademicPaper>?> _readSearchCache(String query) async {
    final prefs = await _preferences();
    final key = '$_searchCachePrefix${_normalizeQuery(query)}';
    final raw = prefs.getString(key);
    if (!_hasText(raw)) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      final decodedMap = _stringKeyedMap(decoded);
      final cachedAt = _parseDateTime(decodedMap['cachedAt']?.toString());
      if (cachedAt == null ||
          DateTime.now().difference(cachedAt) > _searchCacheTtl) {
        return null;
      }
      final items = decodedMap['papers'] as List<dynamic>? ?? const <dynamic>[];
      return items
          .map((dynamic item) => AcademicPaper.fromJson(_stringKeyedMap(item)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeSearchCache(
    String query,
    List<AcademicPaper> papers,
  ) async {
    final prefs = await _preferences();
    final key = '$_searchCachePrefix${_normalizeQuery(query)}';
    final payload = <String, dynamic>{
      'cachedAt': DateTime.now().toIso8601String(),
      'papers': papers.map((AcademicPaper item) => item.toJson()).toList(),
    };
    await prefs.setString(key, jsonEncode(payload));
  }

  Future<Map<String, AcademicPaper>> _readFavorites() async {
    final prefs = await _preferences();
    final raw = prefs.getString(_favoritesKey);
    if (!_hasText(raw)) {
      return <String, AcademicPaper>{};
    }

    try {
      final items = jsonDecode(raw!) as List<dynamic>;
      final map = <String, AcademicPaper>{};
      for (final dynamic item in items) {
        final paper = AcademicPaper.fromJson(_stringKeyedMap(item));
        map[paper.stableKey] = paper;
      }
      return map;
    } catch (_) {
      return <String, AcademicPaper>{};
    }
  }

  Future<void> _persistFavoriteIfExists(AcademicPaper paper) async {
    final favorites = await _readFavorites();
    final existing = favorites[paper.stableKey];
    if (existing == null) {
      return;
    }
    favorites[paper.stableKey] = _mergeDuplicatePapers(
      paper.copyWith(favoritedAt: existing.favoritedAt),
      existing,
    );
    final prefs = await _preferences();
    await prefs.setString(
      _favoritesKey,
      jsonEncode(
        favorites.values.map((AcademicPaper item) => item.toJson()).toList(),
      ),
    );
  }

  Future<Map<String, List<AcademicNote>>> _readNotesMap() async {
    final prefs = await _preferences();
    final raw = prefs.getString(_notesKey);
    if (!_hasText(raw)) {
      return <String, List<AcademicNote>>{};
    }

    try {
      final decoded = _stringKeyedMap(jsonDecode(raw!));
      final map = <String, List<AcademicNote>>{};
      decoded.forEach((String key, dynamic value) {
        final list = (value as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic item) => AcademicNote.fromJson(_stringKeyedMap(item)))
            .toList();
        map[key] = list;
      });
      return map;
    } catch (_) {
      return <String, List<AcademicNote>>{};
    }
  }

  Future<void> _writeNotesMap(Map<String, List<AcademicNote>> notesMap) async {
    final prefs = await _preferences();
    final encoded = <String, dynamic>{};
    notesMap.forEach((String key, List<AcademicNote> value) {
      encoded[key] = value.map((AcademicNote note) => note.toJson()).toList();
    });
    await prefs.setString(_notesKey, jsonEncode(encoded));
  }

  AcademicPaper _mergeDuplicatePapers(
    AcademicPaper primary,
    AcademicPaper? secondary,
  ) {
    if (secondary == null) {
      return primary;
    }

    final preferred = primary.source == AcademicSource.crossRef
        ? primary
        : secondary.source == AcademicSource.crossRef
        ? secondary
        : primary;
    final fallback = identical(preferred, primary) ? secondary : primary;

    final mergedOrigins = <String, String>{
      ...secondary.metadataOrigins,
      ...primary.metadataOrigins,
    };

    String? pickString(String? current, String? other, String field) {
      if (_hasText(current)) {
        return current!.trim();
      }
      if (_hasText(other)) {
        final value = other!.trim();
        final origin =
            secondary.metadataOrigins[field] ?? primary.metadataOrigins[field];
        if (origin != null) {
          mergedOrigins[field] = origin;
        }
        return value;
      }
      return null;
    }

    int? pickInt(int? current, int? other) => current ?? other;
    List<String> pickAuthors(List<String> current, List<String> other) =>
        current.isNotEmpty ? current : other;

    final merged = AcademicPaper(
      id: preferred.id,
      source: preferred.source,
      title: preferred.title.isNotEmpty ? preferred.title : fallback.title,
      authors: pickAuthors(preferred.authors, fallback.authors),
      year: pickInt(preferred.year, fallback.year),
      venue: pickString(preferred.venue, fallback.venue, 'venue'),
      doi: pickString(preferred.doi, fallback.doi, 'doi'),
      citationCount: pickInt(preferred.citationCount, fallback.citationCount),
      abstractText: pickString(
        preferred.abstractText,
        fallback.abstractText,
        'abstractText',
      ),
      pdfUrl: pickString(preferred.pdfUrl, fallback.pdfUrl, 'pdfUrl'),
      detailUrl: pickString(
        preferred.detailUrl,
        fallback.detailUrl,
        'detailUrl',
      ),
      isPrefetchedDetail:
          preferred.isPrefetchedDetail || fallback.isPrefetchedDetail,
      volume: pickString(preferred.volume, fallback.volume, 'volume'),
      issue: pickString(preferred.issue, fallback.issue, 'issue'),
      pages: pickString(preferred.pages, fallback.pages, 'pages'),
      favoritedAt: preferred.favoritedAt ?? fallback.favoritedAt,
      metadataOrigins: mergedOrigins,
    );

    return merged;
  }

  AcademicPaper _mergeEnrichment(
    AcademicPaper current,
    AcademicPaper enriched,
  ) {
    if (identical(current, enriched)) {
      return current;
    }

    final origins = <String, String>{...current.metadataOrigins};

    String? mergeField(
      String field,
      String? currentValue,
      String? enrichedValue,
    ) {
      if (_hasText(currentValue)) {
        return currentValue;
      }
      if (_hasText(enrichedValue)) {
        final origin = enriched.metadataOrigins[field];
        if (origin != null) {
          origins[field] = origin;
        }
        return enrichedValue!.trim();
      }
      return currentValue;
    }

    int? mergeInt(String field, int? currentValue, int? enrichedValue) {
      if (currentValue != null) {
        return currentValue;
      }
      if (enrichedValue != null) {
        final origin = enriched.metadataOrigins[field];
        if (origin != null) {
          origins[field] = origin;
        }
      }
      return enrichedValue;
    }

    return current.copyWith(
      authors: current.authors.isNotEmpty ? current.authors : enriched.authors,
      year: mergeInt('year', current.year, enriched.year),
      venue: mergeField('venue', current.venue, enriched.venue),
      doi: mergeField('doi', current.doi, enriched.doi),
      citationCount: current.citationCount ?? enriched.citationCount,
      abstractText: mergeField(
        'abstractText',
        current.abstractText,
        enriched.abstractText,
      ),
      pdfUrl: mergeField('pdfUrl', current.pdfUrl, enriched.pdfUrl),
      detailUrl: mergeField('detailUrl', current.detailUrl, enriched.detailUrl),
      volume: mergeField('volume', current.volume, enriched.volume),
      issue: mergeField('issue', current.issue, enriched.issue),
      pages: mergeField('pages', current.pages, enriched.pages),
      metadataOrigins: origins,
    );
  }

  List<AcademicPaper> _mergePaperLists(List<List<AcademicPaper>> lists) {
    final merged = <String, AcademicPaper>{};
    for (final list in lists) {
      for (final paper in list) {
        final key = _dedupeKey(paper);
        final existing = merged[key];
        merged[key] = existing == null
            ? paper
            : _mergeDuplicatePapers(existing, paper);
      }
    }

    final result = merged.values.toList()
      ..sort((AcademicPaper a, AcademicPaper b) {
        final citationCompare = (b.citationCount ?? 0).compareTo(
          a.citationCount ?? 0,
        );
        if (citationCompare != 0) {
          return citationCompare;
        }
        final yearCompare = (b.year ?? 0).compareTo(a.year ?? 0);
        if (yearCompare != 0) {
          return yearCompare;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    return result;
  }

  List<AcademicPaper> _mergeSnapshotPapers({
    required List<AcademicPaper>? cached,
    required Set<AcademicSource> completedSources,
    required Map<AcademicSource, List<AcademicPaper>> sourceResults,
  }) {
    final lists = <List<AcademicPaper>>[];
    if (cached != null && cached.isNotEmpty) {
      lists.add(
        cached.where((AcademicPaper paper) {
          return !completedSources.contains(paper.source);
        }).toList(),
      );
    }
    lists.addAll(sourceResults.values);
    final merged = _mergePaperLists(lists);
    if (merged.isEmpty && cached != null) {
      return cached;
    }
    return merged;
  }

  bool _paperNeedsEnrichment(AcademicPaper paper) {
    return !_hasText(paper.venue) ||
        !_hasText(paper.abstractText) ||
        !_hasText(paper.doi) ||
        !_hasText(paper.volume) ||
        !_hasText(paper.issue) ||
        !_hasText(paper.pages);
  }

  String _dedupeKey(AcademicPaper paper) {
    if (_hasText(paper.doi)) {
      return 'doi:${paper.doi!.trim().toLowerCase()}';
    }
    final title = _normalizeText(paper.title);
    final firstAuthor = paper.authors.isEmpty
        ? ''
        : _normalizeText(paper.authors.first);
    final year = paper.year?.toString() ?? '';
    return 'title:$title|author:$firstAuthor|year:$year';
  }

  Map<String, dynamic> _crossRefMessage(dynamic data) {
    if (data is Map<dynamic, dynamic>) {
      final mapped = _stringKeyedMap(data);
      final message = mapped['message'];
      if (message is Map<dynamic, dynamic>) {
        return _stringKeyedMap(message);
      }
    }
    throw const FormatException('Invalid CrossRef response');
  }
}

AcademicSource _academicSourceFromString(String? value) {
  switch (value) {
    case 'crossRef':
      return AcademicSource.crossRef;
    case 'arxiv':
    default:
      return AcademicSource.arxiv;
  }
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value.trim());
}

String? _trimmedOrNull(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _normalizeText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _compactWhitespace(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalizeQuery(String query) => _normalizeText(query);

String? _firstString(dynamic value) {
  if (value is String) {
    return _trimmedOrNull(value);
  }
  if (value is List<dynamic>) {
    for (final dynamic item in value) {
      final result = _trimmedOrNull(item?.toString());
      if (result != null) {
        return result;
      }
    }
  }
  return null;
}

int? _extractYearFromCrossRef(Map<String, dynamic> item) {
  const keys = <String>[
    'published-print',
    'published-online',
    'issued',
    'created',
    'deposited',
  ];
  for (final key in keys) {
    final dynamic value = item[key];
    if (value is! Map<dynamic, dynamic>) {
      continue;
    }
    final dateParts = _stringKeyedMap(value)['date-parts'];
    if (dateParts is List<dynamic> && dateParts.isNotEmpty) {
      final first = dateParts.first;
      if (first is List<dynamic> && first.isNotEmpty) {
        final year = _asInt(first.first);
        if (year != null) {
          return year;
        }
      }
    }
  }
  return null;
}

Map<String, dynamic> _stringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map<dynamic, dynamic>) {
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
  return <String, dynamic>{};
}

String? _stripMarkup(String? input) {
  if (!_hasText(input)) {
    return null;
  }
  return _compactWhitespace(
    input!
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&'),
  );
}

String? _xmlText(XmlElement parent, String tagName) {
  final element = parent.findElements(tagName).cast<XmlElement?>().firstOrNull;
  final text = element?.innerText;
  return _trimmedOrNull(text);
}

double _titleSimilarity(String left, String right) {
  final normalizedLeft = _normalizeText(left);
  final normalizedRight = _normalizeText(right);
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return 0;
  }
  if (normalizedLeft == normalizedRight) {
    return 1;
  }
  if (normalizedLeft.contains(normalizedRight) ||
      normalizedRight.contains(normalizedLeft)) {
    return 0.9;
  }

  final leftTokens = normalizedLeft
      .split(' ')
      .where((String t) => t.isNotEmpty)
      .toSet();
  final rightTokens = normalizedRight
      .split(' ')
      .where((String t) => t.isNotEmpty)
      .toSet();
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return 0;
  }
  final intersection = leftTokens.intersection(rightTokens).length;
  final overlap = intersection / max(leftTokens.length, rightTokens.length);
  final union = intersection / leftTokens.union(rightTokens).length;
  return (overlap * 0.7) + (union * 0.3);
}

String _sanitizeBibtexIdentifier(String raw) {
  final normalized = raw
      .replaceAll(RegExp(r'https?://'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9:_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .trim();
  return normalized.isEmpty ? 'paper' : normalized;
}

String _escapeBibtexValue(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}');
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
