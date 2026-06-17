import 'package:path/path.dart' as p;

import 'material_index_models.dart';

enum MaterialSearchScope {
  general,
  course,
  todo,
  review,
  filePreview,
  webArchive,
  output,
}

class MaterialSearchContext {
  const MaterialSearchContext({
    required this.scope,
    required this.query,
    this.sourceType,
    this.courseName,
    this.todoTitle,
    this.sourcePath,
    this.tags = const <String>[],
    this.limit = 5,
  });

  final MaterialSearchScope scope;
  final String query;
  final MaterialSourceType? sourceType;
  final String? courseName;
  final String? todoTitle;
  final String? sourcePath;
  final List<String> tags;
  final int limit;

  factory MaterialSearchContext.course({
    required String courseName,
    String? teacher,
    int limit = 5,
  }) {
    return MaterialSearchContext(
      scope: MaterialSearchScope.course,
      query: _joinTerms(<String?>[courseName, teacher]),
      courseName: courseName,
      limit: limit,
    );
  }

  factory MaterialSearchContext.todo({
    required String title,
    String? courseName,
    int limit = 5,
  }) {
    return MaterialSearchContext(
      scope: MaterialSearchScope.todo,
      query: _joinTerms(<String?>[title, courseName]),
      todoTitle: title,
      courseName: courseName,
      limit: limit,
    );
  }

  factory MaterialSearchContext.reviewSource({
    required String sourceFileName,
    required String sourcePath,
    int limit = 5,
  }) {
    return MaterialSearchContext(
      scope: MaterialSearchScope.review,
      query: sourceFileName,
      sourcePath: sourcePath,
      limit: limit,
    );
  }

  factory MaterialSearchContext.filePreview({
    required String path,
    String? title,
    int limit = 5,
  }) {
    return MaterialSearchContext(
      scope: MaterialSearchScope.filePreview,
      query: _joinTerms(<String?>[title, p.basename(path)]),
      sourcePath: path,
      limit: limit,
    );
  }

  factory MaterialSearchContext.webArchive({
    required String title,
    required String url,
    List<String> tags = const <String>[],
    int limit = 5,
  }) {
    return MaterialSearchContext(
      scope: MaterialSearchScope.webArchive,
      query: _joinTerms(<String?>[title, url]),
      sourceType: MaterialSourceType.webArchive,
      tags: tags,
      limit: limit,
    );
  }

  factory MaterialSearchContext.output({
    required String path,
    required String name,
    int limit = 5,
  }) {
    return MaterialSearchContext(
      scope: MaterialSearchScope.output,
      query: _joinTerms(<String?>[name, p.basenameWithoutExtension(path)]),
      sourcePath: path,
      limit: limit,
    );
  }

  List<String> get contextTerms {
    final terms = <String>[
      query,
      ?courseName,
      ?todoTitle,
      if (sourcePath case final path?) p.basenameWithoutExtension(path),
      ...tags,
    ];
    return terms
        .expand((term) => term.split(RegExp(r'[\s,，。/\\_\-]+')))
        .map((term) => term.trim())
        .where((term) => term.length >= 2)
        .toSet()
        .toList();
  }

  String get normalizedQuery {
    final text = query.trim();
    if (text.isNotEmpty) return text;
    return contextTerms.join(' ');
  }

  String? get sourcePathPrefix {
    final path = sourcePath?.trim();
    if (path == null || path.isEmpty) return null;
    return p.dirname(path);
  }

  static String _joinTerms(Iterable<String?> values) {
    return values
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(' ');
  }
}
