import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'study_card_models.dart';

class StudyCardStore {
  StudyCardStore({Future<SharedPreferences> Function()? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String decksKey = 'study_decks_v1';
  static const String cardsKey = 'study_cards_v1';
  static const String defaultDeckId = 'default';

  final Future<SharedPreferences> Function() _preferencesLoader;
  final Random _random = Random();

  Future<List<StudyDeck>> loadDecks() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(decksKey);
    if (raw == null || raw.isEmpty) {
      return <StudyDeck>[_defaultDeck()];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <StudyDeck>[_defaultDeck()];
      final decks = decoded
          .whereType<Map>()
          .map((item) => StudyDeck.fromJson(item.cast<String, Object?>()))
          .where((deck) => deck.id.isNotEmpty)
          .toList();
      if (decks.where((deck) => deck.id == defaultDeckId).isEmpty) {
        decks.insert(0, _defaultDeck());
      }
      return decks;
    } catch (_) {
      return <StudyDeck>[_defaultDeck()];
    }
  }

  Future<List<StudyCard>> loadCards() async {
    final prefs = await _preferencesLoader();
    final raw = prefs.getString(cardsKey);
    if (raw == null || raw.isEmpty) return const <StudyCard>[];
    try {
      return StudyCard.listFromJsonString(raw);
    } catch (_) {
      return const <StudyCard>[];
    }
  }

  Future<StudySummary> summary({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final decks = await loadDecks();
    final cards = await loadCards();
    final due = cards.where((card) => card.isDue(effectiveNow)).length;
    final futureDue =
        cards
            .where((card) => card.dueAt.isAfter(effectiveNow))
            .map((card) => card.dueAt)
            .toList()
          ..sort();
    return StudySummary(
      totalCards: cards.length,
      dueCards: due,
      deckCount: decks.length,
      nextDueAt: futureDue.isEmpty ? null : futureDue.first,
    );
  }

  Future<StudyCard> addCard({
    required String front,
    required String back,
    String deckId = defaultDeckId,
    String? sourceFileName,
    String? sourcePath,
    int? sourcePage,
    String? sourceSnippet,
  }) async {
    final normalizedFront = front.trim();
    final normalizedBack = back.trim();
    if (normalizedFront.isEmpty) {
      throw ArgumentError('卡片正面不能为空。');
    }
    final now = DateTime.now();
    final card = StudyCard(
      id: _newId('card'),
      deckId: deckId,
      front: normalizedFront,
      back: normalizedBack,
      createdAt: now,
      updatedAt: now,
      dueAt: now,
      sourceFileName: sourceFileName,
      sourcePath: sourcePath,
      sourcePage: sourcePage,
      sourceSnippet: sourceSnippet,
    );
    final cards = await loadCards();
    await _saveCards(<StudyCard>[card, ...cards]);
    await _ensureDeck(deckId);
    return card;
  }

  Future<StudyDeck> addDeck(String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('卡组名称不能为空。');
    }
    final now = DateTime.now();
    final deck = StudyDeck(
      id: _newId('deck'),
      title: normalized,
      createdAt: now,
      updatedAt: now,
    );
    final decks = await loadDecks();
    await _saveDecks(<StudyDeck>[...decks, deck]);
    return deck;
  }

  Future<StudyCard> updateCard({
    required String cardId,
    required String front,
    required String back,
    required String deckId,
  }) async {
    final normalizedFront = front.trim();
    if (normalizedFront.isEmpty) {
      throw ArgumentError('Card front cannot be empty.');
    }
    await _ensureDeck(deckId);
    final cards = await loadCards();
    final index = cards.indexWhere((card) => card.id == cardId);
    if (index < 0) {
      throw StateError('Card not found.');
    }
    final updated = cards[index].copyWith(
      deckId: deckId,
      front: normalizedFront,
      back: back.trim(),
      updatedAt: DateTime.now(),
    );
    cards[index] = updated;
    await _saveCards(cards);
    return updated;
  }

  Future<StudyDeck> renameDeck(String deckId, String title) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Deck title cannot be empty.');
    }
    final decks = await loadDecks();
    final index = decks.indexWhere((deck) => deck.id == deckId);
    if (index < 0) {
      throw StateError('Deck not found.');
    }
    final updated = decks[index].copyWith(
      title: normalized,
      updatedAt: DateTime.now(),
    );
    decks[index] = updated;
    await _saveDecks(decks);
    return updated;
  }

  Future<void> deleteDeck(
    String deckId, {
    String moveCardsToDeckId = defaultDeckId,
  }) async {
    if (deckId == defaultDeckId) {
      throw StateError('Default deck cannot be deleted.');
    }
    await _ensureDeck(moveCardsToDeckId);
    final decks = await loadDecks();
    if (decks.every((deck) => deck.id != deckId)) {
      throw StateError('Deck not found.');
    }
    await _saveDecks(decks.where((deck) => deck.id != deckId).toList());
    final cards = await loadCards();
    final now = DateTime.now();
    final moved = cards
        .map(
          (card) => card.deckId == deckId
              ? card.copyWith(deckId: moveCardsToDeckId, updatedAt: now)
              : card,
        )
        .toList();
    await _saveCards(moved);
  }

  Future<StudyCard> moveCard(String cardId, String deckId) async {
    final moved = await moveCards(<String>[cardId], deckId);
    if (moved.isEmpty) {
      throw StateError('Card not found.');
    }
    return moved.single;
  }

  Future<List<StudyCard>> moveCards(List<String> cardIds, String deckId) async {
    final ids = cardIds.toSet();
    if (ids.isEmpty) return const <StudyCard>[];
    await _ensureDeck(deckId);
    final cards = await loadCards();
    final moved = <StudyCard>[];
    final now = DateTime.now();
    final nextCards = cards.map((card) {
      if (!ids.contains(card.id)) return card;
      final updated = card.copyWith(deckId: deckId, updatedAt: now);
      moved.add(updated);
      return updated;
    }).toList();
    await _saveCards(nextCards);
    return moved;
  }

  Future<StudyCard> reviewCard(
    String cardId,
    StudyReviewRating rating, {
    DateTime? now,
  }) async {
    final cards = await loadCards();
    final index = cards.indexWhere((card) => card.id == cardId);
    if (index < 0) {
      throw StateError('卡片不存在。');
    }
    final reviewed = schedule(cards[index], rating, now: now);
    cards[index] = reviewed;
    await _saveCards(cards);
    return reviewed;
  }

  Future<void> deleteCard(String cardId) async {
    final cards = await loadCards();
    await _saveCards(cards.where((card) => card.id != cardId).toList());
  }

  Future<void> deleteCards(List<String> cardIds) async {
    final ids = cardIds.toSet();
    if (ids.isEmpty) return;
    final cards = await loadCards();
    await _saveCards(cards.where((card) => !ids.contains(card.id)).toList());
  }

  Future<List<StudyCard>> dueCards({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final cards = await loadCards();
    return cards.where((card) => card.isDue(effectiveNow)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  Future<List<StudySourceGroup>> sourceGroups({DateTime? now}) async {
    final effectiveNow = now ?? DateTime.now();
    final cards = await loadCards();
    final grouped = <String, List<StudyCard>>{};
    final pathsByKey = <String, String>{};
    for (final card in cards) {
      final sourcePath = card.sourcePath?.trim();
      if (sourcePath == null || sourcePath.isEmpty) continue;
      final normalized = _normalizeSourcePath(sourcePath);
      grouped.putIfAbsent(normalized, () => <StudyCard>[]).add(card);
      pathsByKey[normalized] ??= p.normalize(sourcePath);
    }

    final groups = grouped.entries.map((entry) {
      final groupCards = entry.value.toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      final lastUpdatedAt = groupCards
          .map((card) => card.updatedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final sourceFileName = groupCards
          .map((card) => card.sourceFileName?.trim())
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .firstOrNull;
      return StudySourceGroup(
        sourcePath: pathsByKey[entry.key] ?? entry.key,
        sourceFileName: sourceFileName ?? p.basename(entry.key),
        cards: groupCards,
        cardCount: groupCards.length,
        dueCount: groupCards.where((card) => card.isDue(effectiveNow)).length,
        lastUpdatedAt: lastUpdatedAt,
      );
    }).toList();

    groups.sort((a, b) {
      final dueCompare = b.dueCount.compareTo(a.dueCount);
      if (dueCompare != 0) return dueCompare;
      return b.lastUpdatedAt.compareTo(a.lastUpdatedAt);
    });
    return groups;
  }

  Future<List<StudyCard>> cardsForSource(String sourcePath) async {
    final normalized = _normalizeSourcePath(sourcePath);
    final cards = await loadCards();
    return cards.where((card) {
      final current = card.sourcePath?.trim();
      return current != null &&
          current.isNotEmpty &&
          _normalizeSourcePath(current) == normalized;
    }).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  Future<StudyCardExportBundle> exportBundle() async {
    return StudyCardExportBundle(
      version: 1,
      exportedAt: DateTime.now(),
      decks: await loadDecks(),
      cards: await loadCards(),
    );
  }

  Future<StudyCardImportResult> importBundle(
    String rawJson, {
    StudyCardImportMode mode = StudyCardImportMode.merge,
  }) async {
    try {
      final bundle = StudyCardExportBundle.fromJsonString(rawJson);
      final currentDecks = await loadDecks();
      final currentCards = await loadCards();
      final currentDeckIds = currentDecks.map((deck) => deck.id).toSet();
      final currentCardIds = currentCards.map((card) => card.id).toSet();
      final decksToImport = bundle.decks
          .where(
            (deck) => deck.id.isNotEmpty && !currentDeckIds.contains(deck.id),
          )
          .toList();
      final cardsToImport = bundle.cards
          .where(
            (card) => card.id.isNotEmpty && !currentCardIds.contains(card.id),
          )
          .toList();
      await _saveDecks(<StudyDeck>[...currentDecks, ...decksToImport]);
      await _saveCards(<StudyCard>[...cardsToImport, ...currentCards]);
      return StudyCardImportResult(
        importedDecks: decksToImport.length,
        importedCards: cardsToImport.length,
        skippedCards: bundle.cards.length - cardsToImport.length,
        errors: const <String>[],
      );
    } catch (error) {
      return StudyCardImportResult(
        importedDecks: 0,
        importedCards: 0,
        skippedCards: 0,
        errors: <String>['$error'],
      );
    }
  }

  StudyCard schedule(
    StudyCard card,
    StudyReviewRating rating, {
    DateTime? now,
  }) {
    final reviewedAt = now ?? DateTime.now();
    var ease = card.easeFactor;
    var repetitions = card.repetitions;
    var lapses = card.lapses;
    var interval = card.intervalDays;

    switch (rating) {
      case StudyReviewRating.forgot:
        repetitions = 0;
        lapses += 1;
        interval = 0;
        ease = (ease - 0.2).clamp(1.3, 3.2);
      case StudyReviewRating.hard:
        repetitions += 1;
        interval = interval <= 0 ? 1 : max(1, (interval * 1.2).round());
        ease = (ease - 0.15).clamp(1.3, 3.2);
      case StudyReviewRating.good:
        repetitions += 1;
        interval = repetitions <= 1
            ? 1
            : repetitions == 2
            ? 3
            : max(3, (interval * ease).round());
      case StudyReviewRating.easy:
        repetitions += 1;
        interval = repetitions <= 1
            ? 3
            : max(4, (interval * (ease + 0.35)).round());
        ease = (ease + 0.15).clamp(1.3, 3.2);
    }

    final dueAt = rating == StudyReviewRating.forgot
        ? reviewedAt.add(const Duration(minutes: 10))
        : reviewedAt.add(Duration(days: interval));
    return card.copyWith(
      updatedAt: reviewedAt,
      dueAt: dueAt,
      intervalDays: interval,
      easeFactor: ease.toDouble(),
      repetitions: repetitions,
      lapses: lapses,
      lastReviewedAt: reviewedAt,
    );
  }

  Future<void> _ensureDeck(String deckId) async {
    final decks = await loadDecks();
    if (decks.any((deck) => deck.id == deckId)) return;
    await _saveDecks(<StudyDeck>[...decks, _defaultDeck()]);
  }

  Future<void> _saveDecks(List<StudyDeck> decks) async {
    final prefs = await _preferencesLoader();
    await prefs.setString(
      decksKey,
      jsonEncode(decks.map((deck) => deck.toJson()).toList()),
    );
  }

  Future<void> _saveCards(List<StudyCard> cards) async {
    final prefs = await _preferencesLoader();
    await prefs.setString(
      cardsKey,
      jsonEncode(cards.map((card) => card.toJson()).toList()),
    );
  }

  StudyDeck _defaultDeck() {
    final now = DateTime.now();
    return StudyDeck(
      id: defaultDeckId,
      title: '默认卡组',
      createdAt: now,
      updatedAt: now,
    );
  }

  String _newId(String prefix) {
    final randomPart = _random.nextInt(0x7fffffff).toRadixString(16);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$randomPart';
  }

  String _normalizeSourcePath(String sourcePath) {
    return p.normalize(sourcePath.trim()).toLowerCase();
  }
}
