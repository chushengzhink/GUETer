import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/help_manual_models.dart';

class ComputerHelpArticlePage extends StatelessWidget {
  const ComputerHelpArticlePage({super.key, required this.article});

  final HelpArticle article;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: article.platforms
                  .map(
                    (platform) =>
                        _PlatformBadge(label: _platformLabel(l10n, platform)),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.computerHelpDiagnosisLabel,
              child: Text(
                article.diagnosis,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.computerHelpStepsLabel,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < article.steps.length;
                    index++
                  ) ...[
                    _StepTile(index: index + 1, content: article.steps[index]),
                    if (index != article.steps.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.computerHelpTipsLabel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < article.tips.length; index++) ...[
                    _TipRow(text: article.tips[index]),
                    if (index != article.tips.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.computerHelpKeywordsLabel,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: article.keywords
                    .map((keyword) => Chip(label: Text(keyword)))
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _copySteps(context),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(l10n.computerHelpCopySteps),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyKeywords(context),
                  icon: const Icon(Icons.sell_outlined),
                  label: Text(l10n.computerHelpCopyKeywords),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _platformLabel(AppLocalizations l10n, HelpPlatformTag platform) {
    switch (platform) {
      case HelpPlatformTag.windows:
        return l10n.computerHelpPlatformWindows;
      case HelpPlatformTag.android:
        return l10n.computerHelpPlatformAndroid;
    }
  }

  Future<void> _copySteps(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final content = article.steps
        .asMap()
        .entries
        .map((entry) => '${entry.key + 1}. ${entry.value}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.computerHelpCopiedSteps)));
  }

  Future<void> _copyKeywords(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: article.keywords.join(' / ')));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.computerHelpCopiedKeywords)));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.content});

  final int index;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.indigo,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.55),
          ),
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.deepOrange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
        ),
      ],
    );
  }
}
