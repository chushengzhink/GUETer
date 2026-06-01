import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/help_manual_models.dart';
import '../services/help_manual_repository.dart';
import 'computer_help_article_page.dart';

enum _HelpPlatformFilter { all, windows, android, dual }

class ComputerHelpManualPage extends StatefulWidget {
  const ComputerHelpManualPage({super.key});

  @override
  State<ComputerHelpManualPage> createState() => _ComputerHelpManualPageState();
}

class _ComputerHelpManualPageState extends State<ComputerHelpManualPage> {
  final HelpManualRepository _repository = const HelpManualRepository();

  String _query = '';
  HelpCategory? _selectedCategory;
  _HelpPlatformFilter _platformFilter = _HelpPlatformFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final articles = _filteredArticles();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.computerHelpPageTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.computerHelpSearchHint,
                  prefixIcon: const Icon(Icons.search_outlined),
                  filled: true,
                  fillColor: Colors.blueGrey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.computerHelpAllCategories,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.computerHelpAllCategories,
                      selected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    const SizedBox(width: 8),
                    for (final category in HelpCategory.values) ...[
                      _FilterChip(
                        label: _categoryLabel(l10n, category),
                        selected: _selectedCategory == category,
                        onTap: () =>
                            setState(() => _selectedCategory = category),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.computerHelpAllPlatforms,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: l10n.computerHelpAllPlatforms,
                    selected: _platformFilter == _HelpPlatformFilter.all,
                    onTap: () => setState(
                      () => _platformFilter = _HelpPlatformFilter.all,
                    ),
                  ),
                  _FilterChip(
                    label: l10n.computerHelpPlatformWindows,
                    selected: _platformFilter == _HelpPlatformFilter.windows,
                    onTap: () => setState(
                      () => _platformFilter = _HelpPlatformFilter.windows,
                    ),
                  ),
                  _FilterChip(
                    label: l10n.computerHelpPlatformAndroid,
                    selected: _platformFilter == _HelpPlatformFilter.android,
                    onTap: () => setState(
                      () => _platformFilter = _HelpPlatformFilter.android,
                    ),
                  ),
                  _FilterChip(
                    label: l10n.computerHelpPlatformBoth,
                    selected: _platformFilter == _HelpPlatformFilter.dual,
                    onTap: () => setState(
                      () => _platformFilter = _HelpPlatformFilter.dual,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: articles.isEmpty
                    ? Center(
                        child: Text(
                          l10n.computerHelpEmptyState,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: articles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final article = articles[index];
                          return _ArticleCard(
                            article: article,
                            categoryLabel: _categoryLabel(
                              l10n,
                              article.category,
                            ),
                            platformLabels: article.platforms
                                .map(
                                  (platform) => _platformLabel(l10n, platform),
                                )
                                .toList(growable: false),
                            viewDetailsLabel: l10n.computerHelpViewDetails,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ComputerHelpArticlePage(article: article),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<HelpArticle> _filteredArticles() {
    switch (_platformFilter) {
      case _HelpPlatformFilter.all:
        return _repository.searchArticles(
          query: _query,
          category: _selectedCategory,
        );
      case _HelpPlatformFilter.windows:
        return _repository.searchArticles(
          query: _query,
          category: _selectedCategory,
          platform: HelpPlatformTag.windows,
        );
      case _HelpPlatformFilter.android:
        return _repository.searchArticles(
          query: _query,
          category: _selectedCategory,
          platform: HelpPlatformTag.android,
        );
      case _HelpPlatformFilter.dual:
        return _repository.searchArticles(
          query: _query,
          category: _selectedCategory,
          dualPlatformOnly: true,
        );
    }
  }

  String _categoryLabel(AppLocalizations l10n, HelpCategory category) {
    switch (category) {
      case HelpCategory.fileTransfer:
        return l10n.computerHelpCategoryFileTransfer;
      case HelpCategory.archives:
        return l10n.computerHelpCategoryArchives;
      case HelpCategory.fileBasics:
        return l10n.computerHelpCategoryFileBasics;
      case HelpCategory.pdf:
        return l10n.computerHelpCategoryPdf;
      case HelpCategory.captureProjection:
        return l10n.computerHelpCategoryCaptureProjection;
      case HelpCategory.softwareInstall:
        return l10n.computerHelpCategorySoftwareInstall;
      case HelpCategory.downloads:
        return l10n.computerHelpCategoryDownloads;
      case HelpCategory.deviceConnection:
        return l10n.computerHelpCategoryDeviceConnection;
      case HelpCategory.networkBlock:
        return l10n.computerHelpCategoryNetworkBlock;
    }
  }

  String _platformLabel(AppLocalizations l10n, HelpPlatformTag platform) {
    switch (platform) {
      case HelpPlatformTag.windows:
        return l10n.computerHelpPlatformWindows;
      case HelpPlatformTag.android:
        return l10n.computerHelpPlatformAndroid;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: Colors.indigo.withValues(alpha: 0.12),
      side: BorderSide(
        color: selected
            ? Colors.indigo.withValues(alpha: 0.35)
            : Colors.blueGrey.withValues(alpha: 0.18),
      ),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.indigo : null,
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.categoryLabel,
    required this.platformLabels,
    required this.viewDetailsLabel,
    required this.onTap,
  });

  final HelpArticle article;
  final String categoryLabel;
  final List<String> platformLabels;
  final String viewDetailsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFF7FAFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right_rounded, color: Colors.indigo),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniBadge(
                    label: categoryLabel,
                    color: const Color(0xFF355CDE),
                  ),
                  for (final label in platformLabels)
                    _MiniBadge(label: label, color: const Color(0xFF0F766E)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article.diagnosis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${article.steps.length} 步 · ${article.keywords.join(' / ')}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  viewDetailsLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
