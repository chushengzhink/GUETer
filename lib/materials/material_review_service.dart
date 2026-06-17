import 'package:path/path.dart' as p;

import '../study/study_card_models.dart';
import '../study/study_card_store.dart';
import 'material_index_models.dart';

class MaterialReviewCardDraft {
  const MaterialReviewCardDraft({
    required this.front,
    required this.back,
    required this.sourceFileName,
    required this.sourcePath,
    required this.sourceSnippet,
    this.deckId = StudyCardStore.defaultDeckId,
  });

  final String front;
  final String back;
  final String sourceFileName;
  final String sourcePath;
  final String sourceSnippet;
  final String deckId;

  MaterialReviewCardDraft copyWith({
    String? front,
    String? back,
    String? sourceFileName,
    String? sourcePath,
    String? sourceSnippet,
    String? deckId,
  }) {
    return MaterialReviewCardDraft(
      front: front ?? this.front,
      back: back ?? this.back,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourcePath: sourcePath ?? this.sourcePath,
      sourceSnippet: sourceSnippet ?? this.sourceSnippet,
      deckId: deckId ?? this.deckId,
    );
  }
}

class MaterialReviewCreateResult {
  const MaterialReviewCreateResult({
    required this.createdCards,
    required this.skippedCount,
    required this.errors,
  });

  final List<StudyCard> createdCards;
  final int skippedCount;
  final List<String> errors;

  int get successCount => createdCards.length;
  bool get hasErrors => errors.isNotEmpty;
}

class MaterialReviewService {
  const MaterialReviewService();

  static const int defaultMaxDrafts = 10;
  static const int maxBackLength = 1200;

  MaterialReviewCardDraft draftFromSearchResult(MaterialSearchResult result) {
    final entry = result.entry;
    final snippet = _bestSnippet(
      primary: result.snippet,
      fallback: entry.content.isNotEmpty ? entry.content : entry.path,
    );
    return MaterialReviewCardDraft(
      front: entry.name,
      back: snippet,
      sourceFileName: entry.name,
      sourcePath: entry.path,
      sourceSnippet: snippet,
    );
  }

  List<MaterialReviewCardDraft> draftsFromText({
    required String sourcePath,
    required String sourceName,
    required String text,
    int maxDrafts = defaultMaxDrafts,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || maxDrafts <= 0) {
      return const <MaterialReviewCardDraft>[];
    }
    final paragraphs = trimmed
        .split(RegExp(r'(?:\r?\n\s*){2,}|\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final chunks = paragraphs.isEmpty ? <String>[trimmed] : paragraphs;
    return chunks
        .take(maxDrafts)
        .map((chunk) {
          final clipped = _clip(chunk, maxBackLength);
          return MaterialReviewCardDraft(
            front: sourceName.trim().isNotEmpty
                ? sourceName.trim()
                : p.basename(sourcePath),
            back: clipped,
            sourceFileName: sourceName.trim().isNotEmpty
                ? sourceName.trim()
                : p.basename(sourcePath),
            sourcePath: sourcePath,
            sourceSnippet: clipped,
          );
        })
        .toList(growable: false);
  }

  Future<MaterialReviewCreateResult> createCards(
    List<MaterialReviewCardDraft> drafts,
    StudyCardStore store,
  ) async {
    final cards = <StudyCard>[];
    final errors = <String>[];
    var skipped = 0;
    for (final draft in drafts) {
      final front = draft.front.trim();
      if (front.isEmpty) {
        skipped++;
        continue;
      }
      try {
        cards.add(
          await store.addCard(
            deckId: draft.deckId,
            front: front,
            back: draft.back,
            sourceFileName: draft.sourceFileName,
            sourcePath: draft.sourcePath,
            sourceSnippet: draft.sourceSnippet,
          ),
        );
      } catch (error) {
        errors.add('$front: $error');
      }
    }
    return MaterialReviewCreateResult(
      createdCards: cards,
      skippedCount: skipped,
      errors: errors,
    );
  }

  String _bestSnippet({required String primary, required String fallback}) {
    final value = primary.trim().isNotEmpty ? primary.trim() : fallback.trim();
    return _clip(value, 800);
  }

  String _clip(String value, int maxLength) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }
}
