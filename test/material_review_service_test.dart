import 'package:course_helper/materials/material_index_models.dart';
import 'package:course_helper/materials/material_review_service.dart';
import 'package:course_helper/study/study_card_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('draftFromSearchResult keeps source metadata', () {
    const service = MaterialReviewService();
    final result = MaterialSearchResult(
      entry: MaterialIndexEntry(
        id: 'entry-1',
        path: 'C:/tmp/linear.txt',
        name: 'linear.txt',
        sourceType: MaterialSourceType.fileToolOutput,
        sourceLabel: '文件工具',
        sizeBytes: 100,
        modifiedAt: DateTime(2026, 1, 1),
        indexedAt: DateTime(2026, 1, 2),
        content: 'matrix content',
      ),
      snippet: 'matrix snippet',
      score: 3,
    );

    final draft = service.draftFromSearchResult(result);

    expect(draft.front, 'linear.txt');
    expect(draft.back, 'matrix snippet');
    expect(draft.sourceFileName, 'linear.txt');
    expect(draft.sourcePath, 'C:/tmp/linear.txt');
    expect(draft.sourceSnippet, 'matrix snippet');
  });

  test('draftsFromText splits paragraphs and limits candidate count', () {
    const service = MaterialReviewService();
    final text = List.generate(12, (index) => 'paragraph $index').join('\n\n');

    final drafts = service.draftsFromText(
      sourcePath: 'C:/tmp/notes.md',
      sourceName: 'notes.md',
      text: text,
    );

    expect(drafts, hasLength(10));
    expect(drafts.first.back, 'paragraph 0');
    expect(drafts.last.back, 'paragraph 9');
    expect(drafts.every((draft) => draft.sourceFileName == 'notes.md'), isTrue);
  });

  test(
    'createCards skips blank fronts and preserves source metadata',
    () async {
      const service = MaterialReviewService();
      final store = StudyCardStore();

      final result = await service.createCards(const <MaterialReviewCardDraft>[
        MaterialReviewCardDraft(
          front: '',
          back: 'skip',
          sourceFileName: 'a.txt',
          sourcePath: 'C:/tmp/a.txt',
          sourceSnippet: 'skip',
        ),
        MaterialReviewCardDraft(
          front: 'a.txt',
          back: 'alpha',
          sourceFileName: 'a.txt',
          sourcePath: 'C:/tmp/a.txt',
          sourceSnippet: 'alpha',
        ),
      ], store);

      expect(result.successCount, 1);
      expect(result.skippedCount, 1);
      final card = (await store.loadCards()).single;
      expect(card.front, 'a.txt');
      expect(card.sourcePath, 'C:/tmp/a.txt');
      expect(card.sourceSnippet, 'alpha');
    },
  );
}
