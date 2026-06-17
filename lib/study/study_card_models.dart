import 'dart:convert';

enum StudyReviewRating {
  forgot('forgot'),
  hard('hard'),
  good('good'),
  easy('easy');

  const StudyReviewRating(this.id);

  final String id;

  static StudyReviewRating fromId(String id) {
    return values.firstWhere(
      (rating) => rating.id == id,
      orElse: () => StudyReviewRating.good,
    );
  }
}

class StudyDeck {
  const StudyDeck({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyDeck copyWith({String? title, DateTime? updatedAt}) {
    return StudyDeck(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StudyDeck.fromJson(Map<String, Object?> json) {
    return StudyDeck(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '未命名卡组',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class StudyCard {
  const StudyCard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    required this.updatedAt,
    required this.dueAt,
    this.sourceFileName,
    this.sourcePath,
    this.sourcePage,
    this.sourceSnippet,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.lapses = 0,
    this.lastReviewedAt,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime dueAt;
  final String? sourceFileName;
  final String? sourcePath;
  final int? sourcePage;
  final String? sourceSnippet;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final int lapses;
  final DateTime? lastReviewedAt;

  bool isDue(DateTime now) => !dueAt.isAfter(now);

  StudyCard copyWith({
    String? deckId,
    String? front,
    String? back,
    DateTime? updatedAt,
    DateTime? dueAt,
    String? sourceFileName,
    String? sourcePath,
    int? sourcePage,
    String? sourceSnippet,
    int? intervalDays,
    double? easeFactor,
    int? repetitions,
    int? lapses,
    DateTime? lastReviewedAt,
  }) {
    return StudyCard(
      id: id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueAt: dueAt ?? this.dueAt,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourcePath: sourcePath ?? this.sourcePath,
      sourcePage: sourcePage ?? this.sourcePage,
      sourceSnippet: sourceSnippet ?? this.sourceSnippet,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'deckId': deckId,
      'front': front,
      'back': back,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dueAt': dueAt.toIso8601String(),
      'sourceFileName': sourceFileName,
      'sourcePath': sourcePath,
      'sourcePage': sourcePage,
      'sourceSnippet': sourceSnippet,
      'intervalDays': intervalDays,
      'easeFactor': easeFactor,
      'repetitions': repetitions,
      'lapses': lapses,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    };
  }

  factory StudyCard.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return StudyCard(
      id: json['id']?.toString() ?? '',
      deckId: json['deckId']?.toString() ?? '',
      front: json['front']?.toString() ?? '',
      back: json['back']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']) ?? now,
      updatedAt: _parseDate(json['updatedAt']) ?? now,
      dueAt: _parseDate(json['dueAt']) ?? now,
      sourceFileName: json['sourceFileName']?.toString(),
      sourcePath: json['sourcePath']?.toString(),
      sourcePage: _parseInt(json['sourcePage']),
      sourceSnippet: json['sourceSnippet']?.toString(),
      intervalDays: _parseInt(json['intervalDays']) ?? 0,
      easeFactor: _parseDouble(json['easeFactor']) ?? 2.5,
      repetitions: _parseInt(json['repetitions']) ?? 0,
      lapses: _parseInt(json['lapses']) ?? 0,
      lastReviewedAt: _parseDate(json['lastReviewedAt']),
    );
  }

  static List<StudyCard> listFromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <StudyCard>[];
    return decoded
        .whereType<Map>()
        .map((item) => StudyCard.fromJson(item.cast<String, Object?>()))
        .where((card) => card.id.isNotEmpty && card.front.trim().isNotEmpty)
        .toList(growable: false);
  }
}

class StudySourceGroup {
  const StudySourceGroup({
    required this.sourcePath,
    required this.sourceFileName,
    required this.cards,
    required this.cardCount,
    required this.dueCount,
    required this.lastUpdatedAt,
  });

  final String sourcePath;
  final String sourceFileName;
  final List<StudyCard> cards;
  final int cardCount;
  final int dueCount;
  final DateTime lastUpdatedAt;
}

class StudyCardExportBundle {
  const StudyCardExportBundle({
    required this.version,
    required this.exportedAt,
    required this.decks,
    required this.cards,
  });

  final int version;
  final DateTime exportedAt;
  final List<StudyDeck> decks;
  final List<StudyCard> cards;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'decks': decks.map((deck) => deck.toJson()).toList(),
      'cards': cards.map((card) => card.toJson()).toList(),
    };
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory StudyCardExportBundle.fromJson(Map<String, Object?> json) {
    final decksRaw = json['decks'];
    final cardsRaw = json['cards'];
    if (decksRaw is! List || cardsRaw is! List) {
      throw const FormatException('Invalid study card bundle shape');
    }
    return StudyCardExportBundle(
      version: _parseInt(json['version']) ?? 1,
      exportedAt: _parseDate(json['exportedAt']) ?? DateTime.now(),
      decks: decksRaw
          .whereType<Map>()
          .map((item) => StudyDeck.fromJson(item.cast<String, Object?>()))
          .where((deck) => deck.id.isNotEmpty)
          .toList(growable: false),
      cards: cardsRaw
          .whereType<Map>()
          .map((item) => StudyCard.fromJson(item.cast<String, Object?>()))
          .where((card) => card.id.isNotEmpty && card.front.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  factory StudyCardExportBundle.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Study card bundle must be a JSON object');
    }
    return StudyCardExportBundle.fromJson(decoded.cast<String, Object?>());
  }
}

enum StudyCardImportMode { merge }

class StudyCardImportResult {
  const StudyCardImportResult({
    required this.importedDecks,
    required this.importedCards,
    required this.skippedCards,
    required this.errors,
  });

  final int importedDecks;
  final int importedCards;
  final int skippedCards;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

class StudySummary {
  const StudySummary({
    required this.totalCards,
    required this.dueCards,
    required this.deckCount,
    this.nextDueAt,
  });

  final int totalCards;
  final int dueCards;
  final int deckCount;
  final DateTime? nextDueAt;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int? _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _parseDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
