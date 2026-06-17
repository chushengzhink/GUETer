import 'package:flutter/material.dart';

import '../session/app_settings.dart';
import '../smart/smart_models.dart';
import '../smart/smart_organizer_service.dart';

class SmartInlinePanel extends StatefulWidget {
  const SmartInlinePanel({
    super.key,
    required this.title,
    required this.types,
    this.service,
    this.maxItems = 3,
    this.loadTimeout = const Duration(milliseconds: 800),
    this.compact = true,
    this.showReasons = false,
  });

  final String title;
  final Set<SmartInsightType> types;
  final SmartOrganizerService? service;
  final int maxItems;
  final Duration loadTimeout;
  final bool compact;
  final bool showReasons;

  @override
  State<SmartInlinePanel> createState() => _SmartInlinePanelState();
}

class _SmartInlinePanelState extends State<SmartInlinePanel> {
  late final SmartOrganizerService _service =
      widget.service ?? SmartOrganizerService();
  bool _loading = false;
  bool _enabled = true;
  List<SmartInsight> _items = const <SmartInsight>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AppSettings.getBool(
      AppSettings.smartOrganizerEnabledKey,
      true,
    );
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _enabled = false;
        _loading = false;
        _items = const <SmartInsight>[];
      });
      return;
    }
    if (_items.isNotEmpty) {
      setState(() {
        _enabled = true;
        _loading = true;
      });
    }

    List<SmartInsight> insights = const <SmartInsight>[];
    try {
      insights = await _service.generateInsights();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _items = insights
          .where((item) => widget.types.contains(item.type))
          .take(widget.maxItems)
          .toList();
      _loading = false;
    });
  }

  Future<void> _ignore(SmartInsight item) async {
    await _service.ignore(item.id);
    await _load();
  }

  Future<void> _done(SmartInsight item) async {
    await _service.markDone(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled || (!_loading && _items.isEmpty)) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final padding = widget.compact ? 10.0 : 12.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: colors.primary,
                  size: widget.compact ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '刷新建议',
                  onPressed: _loading ? null : _load,
                  icon: _loading
                      ? const Icon(Icons.hourglass_empty_rounded)
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 4),
                child: Text('正在读取本页相关建议...'),
              )
            else
              for (final item in _items)
                _InlineInsightTile(
                  item: item,
                  compact: widget.compact,
                  showReason: widget.showReasons,
                  onDone: () => _done(item),
                  onIgnore: () => _ignore(item),
                ),
          ],
        ),
      ),
    );
  }
}

class _InlineInsightTile extends StatelessWidget {
  const _InlineInsightTile({
    required this.item,
    required this.compact,
    required this.showReason,
    required this.onDone,
    required this.onIgnore,
  });

  final SmartInsight item;
  final bool compact;
  final bool showReason;
  final VoidCallback onDone;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: compact ? 6 : 8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 8 : 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PriorityDot(priority: item.priority),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: compact ? 1 : null,
                    overflow: compact ? TextOverflow.ellipsis : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.summary,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
            ),
            if (showReason) ...[
              const SizedBox(height: 4),
              Text(
                '原因：${item.reason}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            SizedBox(height: compact ? 2 : 6),
            Wrap(
              spacing: compact ? 4 : 8,
              children: [
                TextButton.icon(
                  onPressed: onDone,
                  icon: const Icon(Icons.done_rounded, size: 18),
                  label: const Text('完成'),
                ),
                TextButton.icon(
                  onPressed: onIgnore,
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: const Text('忽略'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final SmartInsightPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      SmartInsightPriority.urgent => Theme.of(context).colorScheme.error,
      SmartInsightPriority.high => Colors.deepOrange,
      SmartInsightPriority.medium => Theme.of(context).colorScheme.primary,
      SmartInsightPriority.low => Theme.of(context).colorScheme.outline,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
