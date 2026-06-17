import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:course_helper/study/study_card_models.dart';
import 'package:course_helper/study/study_card_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SM-2 ratings produce different schedules', () async {
    final store = StudyCardStore();
    final card = await store.addCard(front: 'Q', back: 'A');
    final now = DateTime(2026, 1, 1, 8);

    final forgot = store.schedule(card, StudyReviewRating.forgot, now: now);
    final hard = store.schedule(card, StudyReviewRating.hard, now: now);
    final good = store.schedule(card, StudyReviewRating.good, now: now);
    final easy = store.schedule(card, StudyReviewRating.easy, now: now);

    expect(forgot.dueAt, now.add(const Duration(minutes: 10)));
    expect(hard.intervalDays, 1);
    expect(good.intervalDays, 1);
    expect(easy.intervalDays, 3);
    expect(easy.easeFactor, greaterThan(card.easeFactor));
  });

  test('serializes decks and cards locally', () async {
    final store = StudyCardStore();
    final deck = await store.addDeck('Math');
    await store.addCard(deckId: deck.id, front: '1+1', back: '2');

    final decks = await store.loadDecks();
    final cards = await store.loadCards();

    expect(decks.any((item) => item.title == 'Math'), isTrue);
    expect(cards.single.front, '1+1');
    expect((await store.summary()).totalCards, 1);
  });

  test('stores material source metadata for review cards', () async {
    final store = StudyCardStore();

    await store.addCard(
      front: 'linear.txt',
      back: 'eigenvalue review',
      sourceFileName: 'linear.txt',
      sourcePath: 'C:/tmp/linear.txt',
      sourceSnippet: 'eigenvalue review',
    );

    final card = (await store.loadCards()).single;
    expect(card.sourceFileName, 'linear.txt');
    expect(card.sourcePath, 'C:/tmp/linear.txt');
    expect(card.sourceSnippet, 'eigenvalue review');
  });

  test('groups cards by normalized source path and counts due cards', () async {
    final store = StudyCardStore();
    final deck = await store.addDeck('Materials');
    final sourcePath = 'C:/tmp/linear.txt';
    final sameSourcePath = 'C:\\tmp\\linear.txt';
    final otherSourcePath = 'C:/tmp/algebra.txt';

    final dueCard = await store.addCard(
      deckId: deck.id,
      front: 'linear 1',
      back: 'answer',
      sourceFileName: 'linear.txt',
      sourcePath: sourcePath,
    );
    final futureCard = await store.addCard(
      deckId: deck.id,
      front: 'linear 2',
      back: 'answer',
      sourceFileName: 'linear.txt',
      sourcePath: sameSourcePath,
    );
    final otherCard = await store.addCard(
      deckId: deck.id,
      front: 'algebra',
      back: 'answer',
      sourceFileName: 'algebra.txt',
      sourcePath: otherSourcePath,
    );
    await store.addCard(front: 'manual', back: 'no source');

    final reviewAt = DateTime.now();
    await store.reviewCard(
      futureCard.id,
      StudyReviewRating.easy,
      now: reviewAt,
    );
    await store.reviewCard(otherCard.id, StudyReviewRating.easy, now: reviewAt);

    final groups = await store.sourceGroups(
      now: reviewAt.add(const Duration(minutes: 1)),
    );

    expect(groups, hasLength(2));
    expect(groups.first.sourceFileName, 'linear.txt');
    expect(groups.first.cardCount, 2);
    expect(groups.first.dueCount, 1);
    expect(groups.first.cards.map((card) => card.id), contains(dueCard.id));
    expect(groups.last.sourceFileName, 'algebra.txt');
  });

  test('cardsForSource matches normalized paths', () async {
    final store = StudyCardStore();
    await store.addCard(
      front: 'source card',
      back: 'answer',
      sourceFileName: 'source.txt',
      sourcePath: 'C:/tmp/source.txt',
    );
    await store.addCard(front: 'plain card', back: 'answer');

    final cards = await store.cardsForSource('C:\\tmp\\source.txt');

    expect(cards, hasLength(1));
    expect(cards.single.front, 'source card');
  });

  test('updates card while preserving source and review schedule', () async {
    final store = StudyCardStore();
    final deck = await store.addDeck('Deck A');
    final targetDeck = await store.addDeck('Deck B');
    final card = await store.addCard(
      deckId: deck.id,
      front: 'old',
      back: 'old answer',
      sourceFileName: 'source.txt',
      sourcePath: 'C:/tmp/source.txt',
      sourceSnippet: 'snippet',
    );
    final reviewed = await store.reviewCard(card.id, StudyReviewRating.easy);

    final updated = await store.updateCard(
      cardId: card.id,
      front: 'new',
      back: 'new answer',
      deckId: targetDeck.id,
    );

    expect(updated.front, 'new');
    expect(updated.back, 'new answer');
    expect(updated.deckId, targetDeck.id);
    expect(updated.sourcePath, 'C:/tmp/source.txt');
    expect(updated.sourceSnippet, 'snippet');
    expect(updated.dueAt, reviewed.dueAt);
    expect(updated.repetitions, reviewed.repetitions);
  });

  test('moves and deletes cards in batches', () async {
    final store = StudyCardStore();
    final deck = await store.addDeck('Target');
    final first = await store.addCard(front: 'first', back: 'a');
    final second = await store.addCard(front: 'second', back: 'b');

    final moved = await store.moveCards(<String>[first.id, second.id], deck.id);

    expect(moved, hasLength(2));
    expect(
      (await store.loadCards()).every((card) => card.deckId == deck.id),
      isTrue,
    );

    await store.deleteCards(<String>[first.id, second.id]);
    expect(await store.loadCards(), isEmpty);
  });

  test(
    'renames and deletes decks while moving cards to default deck',
    () async {
      final store = StudyCardStore();
      final deck = await store.addDeck('Old');
      final card = await store.addCard(deckId: deck.id, front: 'Q', back: 'A');

      final renamed = await store.renameDeck(deck.id, 'New');
      expect(renamed.title, 'New');

      await store.deleteDeck(deck.id);
      final decks = await store.loadDecks();
      final cards = await store.loadCards();

      expect(decks.any((item) => item.id == deck.id), isFalse);
      expect(cards.single.id, card.id);
      expect(cards.single.deckId, StudyCardStore.defaultDeckId);
      expect(
        () => store.deleteDeck(StudyCardStore.defaultDeckId),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('exports and imports bundle while skipping duplicate cards', () async {
    final store = StudyCardStore();
    final deck = await store.addDeck('Imported');
    final card = await store.addCard(
      deckId: deck.id,
      front: 'Q',
      back: 'A',
      sourceFileName: 'source.txt',
      sourcePath: 'C:/tmp/source.txt',
    );
    await store.reviewCard(card.id, StudyReviewRating.easy);
    final exported = (await store.exportBundle()).toJsonString();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final target = StudyCardStore();
    final firstImport = await target.importBundle(exported);
    final secondImport = await target.importBundle(exported);

    expect(firstImport.importedCards, 1);
    expect(firstImport.importedDecks, 1);
    expect(secondImport.importedCards, 0);
    expect(secondImport.skippedCards, 1);
    final importedCard = (await target.loadCards()).single;
    expect(importedCard.sourcePath, 'C:/tmp/source.txt');
    expect(importedCard.repetitions, greaterThan(0));
  });

  test('invalid import returns error and keeps local data', () async {
    final store = StudyCardStore();
    await store.addCard(front: 'local', back: 'data');

    final result = await store.importBundle('not json');

    expect(result.hasErrors, isTrue);
    expect((await store.loadCards()).single.front, 'local');
  });
}
