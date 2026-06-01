enum HelpPlatformTag { windows, android }

enum HelpCategory {
  fileTransfer,
  archives,
  fileBasics,
  pdf,
  captureProjection,
  softwareInstall,
  downloads,
  deviceConnection,
  networkBlock,
}

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.platforms,
    required this.diagnosis,
    required this.steps,
    required this.tips,
    required this.keywords,
  });

  final String id;
  final String title;
  final HelpCategory category;
  final Set<HelpPlatformTag> platforms;
  final String diagnosis;
  final List<String> steps;
  final List<String> tips;
  final List<String> keywords;

  bool get supportsBothPlatforms => platforms.length > 1;
}
