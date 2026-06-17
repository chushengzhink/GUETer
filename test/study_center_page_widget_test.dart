import 'dart:io';

import 'package:course_helper/pages/file_preview_page.dart';
import 'package:course_helper/pages/study_center_page.dart';
import 'package:course_helper/study/study_card_models.dart';
import 'package:course_helper/study/study_card_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sourceFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('study_center_widget_');
    sourceFile = File(p.join(tempDir.path, 'source.txt'));
    await sourceFile.writeAsString('source text');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('source card shows open source action and navigates to preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudyCenterPage(store: _FakeStudyCardStore(sourceFile)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('资料来源'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'source.txt').first);
    await tester.pumpAndSettle();
    expect(find.text('来源：source.txt'), findsWidgets);
    await tester.tap(find.byTooltip('打开来源').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(FilePreviewPage), findsOneWidget);
  });

  testWidgets('renders source groups and opens source card list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudyCenterPage(store: _FakeStudyCardStore(sourceFile)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('资料来源'), findsOneWidget);
    expect(find.textContaining('已制卡 1 张'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'source.txt').first);
    await tester.pumpAndSettle();

    expect(find.text('来源卡片'), findsOneWidget);
    expect(find.text('source question'), findsWidgets);
    expect(find.byTooltip('打开来源'), findsWidgets);
  });

  testWidgets('missing source shows snackbar instead of crashing', (
    tester,
  ) async {
    final missing = File(p.join(tempDir.path, 'missing.txt'));
    await tester.pumpWidget(
      MaterialApp(home: StudyCenterPage(store: _FakeStudyCardStore(missing))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'source.txt').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('打开来源').first);
    await tester.pump();

    expect(find.text('来源文件不存在或已移动'), findsOneWidget);
  });

  testWidgets('card menu edits a card and preserves store data', (
    tester,
  ) async {
    final store = _FakeStudyCardStore(sourceFile);
    await tester.pumpWidget(MaterialApp(home: StudyCenterPage(store: store)));
    await tester.pumpAndSettle();

    await _scrollToAllCard(tester, 'source question');
    final tile = find.widgetWithText(ListTile, 'source question').last;
    await tester.tap(
      find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(dialogFields.at(0), 'updated question');
    await tester.enterText(dialogFields.at(1), 'updated answer');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(store.cards.single.front, 'updated question');
    expect(store.cards.single.back, 'updated answer');
    expect(store.cards.single.sourcePath, sourceFile.path);
    expect(find.text('复习卡片已更新'), findsOneWidget);
  });

  testWidgets('search, deck filter and source filter narrow all cards', (
    tester,
  ) async {
    final store = _FakeStudyCardStore(
      sourceFile,
      extraDecks: <StudyDeck>[_deck('target', 'Target deck')],
      extraCards: <StudyCard>[
        _card(
          id: 'card-2',
          deckId: 'target',
          front: 'math theorem',
          back: 'calculus note',
          dueAt: DateTime(2027, 1, 1),
        ),
        _card(
          id: 'card-3',
          front: 'plain grammar',
          back: 'language note',
          dueAt: DateTime(2027, 1, 1),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: StudyCenterPage(store: store)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('搜索卡片'), 500);

    await tester.enterText(find.widgetWithText(TextField, '搜索卡片'), 'math');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'math theorem'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'plain grammar'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '搜索卡片'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部卡组'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target deck').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'math theorem'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'source question'), findsNothing);

    await tester.tap(find.text('有来源'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'math theorem'), findsNothing);
    expect(find.text('没有匹配的卡片。'), findsOneWidget);
  });

  testWidgets('batch move and delete update selected cards', (tester) async {
    final store = _FakeStudyCardStore(
      sourceFile,
      extraDecks: <StudyDeck>[_deck('target', 'Target deck')],
      extraCards: <StudyCard>[
        _card(id: 'card-2', front: 'batch second', back: 'answer'),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: StudyCenterPage(store: store)));
    await tester.pumpAndSettle();

    await _scrollToAllCard(tester, 'source question');
    await tester.tap(find.widgetWithText(ListTile, 'source question').last);
    await tester.pumpAndSettle();
    expect(find.text('已选择 1 张卡片'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '批量移动'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认卡组').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target deck').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '移动'));
    await tester.pumpAndSettle();
    expect(
      store.cards.firstWhere((card) => card.id == 'card-1').deckId,
      'target',
    );

    await _scrollToAllCard(tester, 'batch second');
    await tester.tap(find.widgetWithText(ListTile, 'batch second').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '批量删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除').last);
    await tester.pumpAndSettle();

    expect(store.cards.any((card) => card.id == 'card-2'), isFalse);
  });
}

class _FakeStudyCardStore extends StudyCardStore {
  _FakeStudyCardStore(
    this.sourceFile, {
    List<StudyDeck> extraDecks = const <StudyDeck>[],
    List<StudyCard> extraCards = const <StudyCard>[],
  }) : decks = <StudyDeck>[
         _deck(StudyCardStore.defaultDeckId, '默认卡组'),
         ...extraDecks,
       ],
       cards = <StudyCard>[
         _card(
           id: 'card-1',
           front: 'source question',
           back: 'source answer',
           sourceFileName: 'source.txt',
           sourcePath: sourceFile.path,
           sourceSnippet: 'source text',
         ),
         ...extraCards,
       ];

  final File sourceFile;
  final List<StudyDeck> decks;
  final List<StudyCard> cards;

  @override
  Future<List<StudyDeck>> loadDecks() async {
    return decks;
  }

  @override
  Future<List<StudyCard>> loadCards() async {
    return cards;
  }

  @override
  Future<StudySummary> summary({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    return StudySummary(
      totalCards: cards.length,
      dueCards: cards.where((card) => card.isDue(effectiveNow)).length,
      deckCount: decks.length,
    );
  }

  @override
  Future<List<StudySourceGroup>> sourceGroups({DateTime? now}) async {
    final sourceCards = cards
        .where((card) => card.sourcePath?.trim().isNotEmpty == true)
        .toList();
    if (sourceCards.isEmpty) return const <StudySourceGroup>[];
    return <StudySourceGroup>[
      StudySourceGroup(
        sourcePath: sourceFile.path,
        sourceFileName: 'source.txt',
        cards: sourceCards,
        cardCount: sourceCards.length,
        dueCount: sourceCards
            .where((card) => card.isDue(now ?? DateTime.now()))
            .length,
        lastUpdatedAt: sourceCards.first.updatedAt,
      ),
    ];
  }

  @override
  Future<StudyCard> updateCard({
    required String cardId,
    required String front,
    required String back,
    required String deckId,
  }) async {
    final index = cards.indexWhere((card) => card.id == cardId);
    if (index < 0) throw StateError('Card not found.');
    final updated = cards[index].copyWith(
      front: front.trim(),
      back: back.trim(),
      deckId: deckId,
      updatedAt: DateTime(2026, 2, 1),
    );
    cards[index] = updated;
    return updated;
  }

  @override
  Future<StudyCard> moveCard(String cardId, String deckId) async {
    final moved = await moveCards(<String>[cardId], deckId);
    if (moved.isEmpty) throw StateError('Card not found.');
    return moved.single;
  }

  @override
  Future<List<StudyCard>> moveCards(List<String> cardIds, String deckId) async {
    final ids = cardIds.toSet();
    final moved = <StudyCard>[];
    for (var i = 0; i < cards.length; i++) {
      if (!ids.contains(cards[i].id)) continue;
      final updated = cards[i].copyWith(
        deckId: deckId,
        updatedAt: DateTime(2026, 2, 1),
      );
      cards[i] = updated;
      moved.add(updated);
    }
    return moved;
  }

  @override
  Future<void> deleteCard(String cardId) async {
    await deleteCards(<String>[cardId]);
  }

  @override
  Future<void> deleteCards(List<String> cardIds) async {
    final ids = cardIds.toSet();
    cards.removeWhere((card) => ids.contains(card.id));
  }

  @override
  Future<StudyDeck> renameDeck(String deckId, String title) async {
    final index = decks.indexWhere((deck) => deck.id == deckId);
    if (index < 0) throw StateError('Deck not found.');
    final updated = decks[index].copyWith(
      title: title.trim(),
      updatedAt: DateTime(2026, 2, 1),
    );
    decks[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDeck(
    String deckId, {
    String moveCardsToDeckId = StudyCardStore.defaultDeckId,
  }) async {
    decks.removeWhere((deck) => deck.id == deckId);
    await moveCards(
      cards
          .where((card) => card.deckId == deckId)
          .map((card) => card.id)
          .toList(),
      moveCardsToDeckId,
    );
  }
}

Future<void> _scrollToAllCard(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.widgetWithText(ListTile, text),
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

StudyDeck _deck(String id, String title) {
  return StudyDeck(
    id: id,
    title: title,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

StudyCard _card({
  required String id,
  String deckId = StudyCardStore.defaultDeckId,
  required String front,
  required String back,
  DateTime? dueAt,
  String? sourceFileName,
  String? sourcePath,
  String? sourceSnippet,
}) {
  return StudyCard(
    id: id,
    deckId: deckId,
    front: front,
    back: back,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    dueAt: dueAt ?? DateTime(2026, 1, 1),
    sourceFileName: sourceFileName,
    sourcePath: sourcePath,
    sourceSnippet: sourceSnippet,
  );
}
