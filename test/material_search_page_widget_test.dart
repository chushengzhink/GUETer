import 'dart:io';

import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_index_service.dart';
import 'package:course_helper/materials/material_library_store.dart';
import 'package:course_helper/pages/file_preview_page.dart';
import 'package:course_helper/pages/material_search_page.dart';
import 'package:course_helper/study/study_card_models.dart';
import 'package:course_helper/study/study_card_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File recentFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('material_search_widget_');
    recentFile = File(p.join(tempDir.path, 'recent.txt'));
    await recentFile.writeAsString('recent material');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('shows workbench search, filters and collapsible overview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MaterialSearchPage(
          service: _FakeMaterialIndexService(),
          libraryStore: _FakeMaterialLibraryStore(
            inboxItems: const <MaterialLibraryItem>[],
            recentItems: <MaterialLibraryItem>[
              _libraryItem(path: recentFile.path, name: 'recent.txt'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('资料检索工作台'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('文件工具输出'), findsOneWidget);
    expect(find.text('资料库概况'), findsOneWidget);
    expect(find.text('先建立资料索引'), findsOneWidget);

    await tester.tap(find.text('资料库概况'));
    await tester.pumpAndSettle();

    expect(find.text('收件箱'), findsOneWidget);
    expect(find.text('最近打开'), findsOneWidget);
    expect(find.text('索引概览'), findsOneWidget);
    expect(find.text('资料收件箱'), findsOneWidget);
    expect(find.text('最近资料'), findsOneWidget);
    expect(find.text('暂无待整理资料'), findsOneWidget);
    expect(find.text('recent.txt'), findsOneWidget);
  });

  testWidgets('search result menu creates editable study card with source', (
    tester,
  ) async {
    final entry = MaterialIndexEntry(
      id: 'entry-1',
      path: p.join(tempDir.path, 'notes.txt'),
      name: 'notes.txt',
      sourceType: MaterialSourceType.fileToolOutput,
      sourceLabel: '文件工具',
      sizeBytes: 12,
      modifiedAt: DateTime(2026, 1, 1),
      indexedAt: DateTime(2026, 1, 2),
      content: 'matrix review content',
    );
    final studyStore = _FakeStudyCardStore();

    await tester.pumpWidget(
      MaterialApp(
        home: MaterialSearchPage(
          service: _FakeMaterialIndexService(
            searchResults: <MaterialSearchResult>[
              MaterialSearchResult(
                entry: entry,
                snippet: 'matrix review snippet',
                score: 3,
              ),
            ],
          ),
          libraryStore: _FakeMaterialLibraryStore(),
          studyCardStore: studyStore,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'matrix');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(find.text('notes.txt'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用当前片段生成复习卡'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(studyStore.addedCards, hasLength(1));
    expect(studyStore.addedCards.single.sourceFileName, 'notes.txt');
    expect(studyStore.addedCards.single.sourcePath, entry.path);
    expect(studyStore.addedCards.single.sourceSnippet, 'matrix review snippet');
    expect(find.text('已生成复习卡片'), findsOneWidget);
  });

  testWidgets('selected search results can be batch-created as study cards', (
    tester,
  ) async {
    final entries = List.generate(2, (index) {
      return MaterialSearchResult(
        entry: MaterialIndexEntry(
          id: 'entry-$index',
          path: p.join(tempDir.path, 'notes-$index.txt'),
          name: 'notes-$index.txt',
          sourceType: MaterialSourceType.fileToolOutput,
          sourceLabel: '文件工具',
          sizeBytes: 12,
          modifiedAt: DateTime(2026, 1, 1),
          indexedAt: DateTime(2026, 1, 2),
          content: 'content $index',
        ),
        snippet: 'snippet $index',
        score: 3,
      );
    });
    final studyStore = _FakeStudyCardStore();

    await tester.pumpWidget(
      MaterialApp(
        home: MaterialSearchPage(
          service: _FakeMaterialIndexService(searchResults: entries),
          libraryStore: _FakeMaterialLibraryStore(),
          studyCardStore: studyStore,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'snippet');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    await tester.tap(find.text('notes-0.txt'));
    await tester.drag(find.byType(ListView).last, const Offset(0, -160));
    await tester.pump();
    await tester.tap(find.text('notes-1.txt'));
    await tester.pump();
    expect(find.text('批量生成复习卡'), findsOneWidget);

    await tester.tap(find.text('批量生成复习卡'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存 2 张'));
    await tester.pump();

    expect(studyStore.addedCards, hasLength(2));
    expect(studyStore.addedCards.map((card) => card.sourceSnippet), [
      'snippet 0',
      'snippet 1',
    ]);
    expect(find.text('已生成 2 张复习卡'), findsOneWidget);
  });

  testWidgets('opens recent material with FilePreviewPage', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MaterialSearchPage(
          service: _FakeMaterialIndexService(),
          libraryStore: _FakeMaterialLibraryStore(
            recentItems: <MaterialLibraryItem>[
              _libraryItem(path: recentFile.path, name: 'recent.txt'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('资料库概况'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'recent.txt'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(FilePreviewPage), findsOneWidget);
  });

  testWidgets('shows source card stats and opens source card sheet', (
    tester,
  ) async {
    final studyStore = _FakeStudyCardStore()
      ..seedCard(
        front: 'recent question',
        back: 'recent answer',
        sourceFileName: 'recent.txt',
        sourcePath: recentFile.path,
      );

    await tester.pumpWidget(
      MaterialApp(
        home: MaterialSearchPage(
          service: _FakeMaterialIndexService(),
          libraryStore: _FakeMaterialLibraryStore(
            inboxItems: <MaterialLibraryItem>[
              _libraryItem(path: recentFile.path, name: 'recent.txt'),
            ],
          ),
          studyCardStore: studyStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('资料库概况'));
    await tester.pumpAndSettle();
    expect(find.text('recent.txt'), findsOneWidget);
    expect(find.textContaining('已制卡 1 张'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看来源卡片'));
    await tester.pumpAndSettle();

    expect(find.text('来源卡片 1 张'), findsOneWidget);
    expect(find.text('recent question'), findsOneWidget);
    expect(find.text('打开来源'), findsOneWidget);
    expect(find.text('去复习中心'), findsOneWidget);
  });
}

MaterialLibraryItem _libraryItem({required String path, required String name}) {
  return MaterialLibraryItem(
    id: MaterialLibraryStore.idForPath(path),
    path: path,
    name: name,
    sourceType: MaterialSourceType.fileToolOutput,
    sourceLabel: '文件工具',
    importedAt: DateTime(2026, 1, 1),
    lastOpenedAt: DateTime(2026, 1, 2),
  );
}

class _FakeMaterialIndexService extends MaterialIndexService {
  _FakeMaterialIndexService({
    this.searchResults = const <MaterialSearchResult>[],
  });

  final List<MaterialSearchResult> searchResults;

  @override
  Future<MaterialIndexSummary> summary() async {
    return MaterialIndexSummary(
      total: searchResults.length,
      indexed: searchResults.where((result) => !result.entry.hasError).length,
      failed: searchResults.where((result) => result.entry.hasError).length,
      updatedAt: DateTime(2026, 1, 2),
    );
  }

  @override
  Future<List<MaterialSearchResult>> search({
    required String query,
    MaterialSourceType? sourceType,
    int? limit,
    Iterable<String> contextTerms = const <String>[],
    String? sourcePathPrefix,
  }) async {
    return limit == null ? searchResults : searchResults.take(limit).toList();
  }
}

class _FakeMaterialLibraryStore extends MaterialLibraryStore {
  _FakeMaterialLibraryStore({
    List<MaterialLibraryItem> inboxItems = const <MaterialLibraryItem>[],
    List<MaterialLibraryItem> recentItems = const <MaterialLibraryItem>[],
  }) : _inboxItems = inboxItems,
       _recentItems = recentItems;

  final List<MaterialLibraryItem> _inboxItems;
  final List<MaterialLibraryItem> _recentItems;

  @override
  Future<List<MaterialLibraryItem>> refreshMissingStatuses() async {
    return <MaterialLibraryItem>[..._inboxItems, ..._recentItems];
  }

  @override
  Future<List<MaterialLibraryItem>> inboxItems({int? limit}) async {
    return limit == null ? _inboxItems : _inboxItems.take(limit).toList();
  }

  @override
  Future<List<MaterialLibraryItem>> recentItems({int? limit}) async {
    return limit == null ? _recentItems : _recentItems.take(limit).toList();
  }
}

class _FakeStudyCardStore extends StudyCardStore {
  final List<StudyCard> addedCards = <StudyCard>[];

  void seedCard({
    required String front,
    required String back,
    required String sourceFileName,
    required String sourcePath,
  }) {
    addedCards.add(
      StudyCard(
        id: 'seed-${addedCards.length + 1}',
        deckId: StudyCardStore.defaultDeckId,
        front: front,
        back: back,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        dueAt: DateTime(2026, 1, 1),
        sourceFileName: sourceFileName,
        sourcePath: sourcePath,
        sourceSnippet: back,
      ),
    );
  }

  @override
  Future<StudyCard> addCard({
    required String front,
    required String back,
    String deckId = StudyCardStore.defaultDeckId,
    String? sourceFileName,
    String? sourcePath,
    int? sourcePage,
    String? sourceSnippet,
  }) async {
    final card = StudyCard(
      id: 'card-${addedCards.length + 1}',
      deckId: deckId,
      front: front.trim(),
      back: back.trim(),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      dueAt: DateTime(2026, 1, 1),
      sourceFileName: sourceFileName,
      sourcePath: sourcePath,
      sourcePage: sourcePage,
      sourceSnippet: sourceSnippet,
    );
    addedCards.add(card);
    return card;
  }

  @override
  Future<List<StudyCard>> loadCards() async => addedCards;

  @override
  Future<List<StudyDeck>> loadDecks() async {
    return <StudyDeck>[
      StudyDeck(
        id: StudyCardStore.defaultDeckId,
        title: '默认卡组',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<List<StudySourceGroup>> sourceGroups({DateTime? now}) async {
    final effectiveNow = now ?? DateTime(2026, 1, 1, 12);
    final grouped = <String, List<StudyCard>>{};
    for (final card in addedCards) {
      final path = card.sourcePath;
      if (path == null || path.trim().isEmpty) continue;
      grouped
          .putIfAbsent(p.normalize(path).toLowerCase(), () => <StudyCard>[])
          .add(card);
    }
    return grouped.values.map((cards) {
      final first = cards.first;
      return StudySourceGroup(
        sourcePath: first.sourcePath!,
        sourceFileName: first.sourceFileName ?? p.basename(first.sourcePath!),
        cards: cards,
        cardCount: cards.length,
        dueCount: cards.where((card) => card.isDue(effectiveNow)).length,
        lastUpdatedAt: cards.first.updatedAt,
      );
    }).toList();
  }

  @override
  Future<List<StudyCard>> cardsForSource(String sourcePath) async {
    final normalized = p.normalize(sourcePath).toLowerCase();
    return addedCards
        .where(
          (card) =>
              p.normalize(card.sourcePath ?? '').toLowerCase() == normalized,
        )
        .toList();
  }
}
