import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session/app_settings.dart';
import '../smart/smart_brief_builder.dart';
import '../smart/smart_models.dart';
import '../smart/smart_organizer_service.dart';
import 'file_output_manager_page.dart';
import 'material_search_page.dart';
import 'request_console_page.dart';
import 'study_center_page.dart';
import 'todos_page.dart';
import 'web_archive_page.dart';

class SmartOrganizerPage extends StatefulWidget {
  const SmartOrganizerPage({
    super.key,
    SmartOrganizerService? service,
    SmartBriefBuilder? briefBuilder,
  }) : _service = service,
       _briefBuilder = briefBuilder;

  final SmartOrganizerService? _service;
  final SmartBriefBuilder? _briefBuilder;

  @override
  State<SmartOrganizerPage> createState() => _SmartOrganizerPageState();
}

class _SmartOrganizerPageState extends State<SmartOrganizerPage> {
  late final SmartOrganizerService _service =
      widget._service ?? SmartOrganizerService();
  late final SmartBriefBuilder _briefBuilder =
      widget._briefBuilder ?? const SmartBriefBuilder();

  bool _enabled = true;
  bool _loading = true;
  bool _runningAction = false;
  String? _error;
  List<SmartInsight> _insights = const <SmartInsight>[];
  SmartBrief _brief = const SmartBrief(
    title: '正在生成本地智能整理摘要',
    lines: <String>['读取本地资料、待办、复习卡和诊断状态。'],
    totalCount: 0,
    urgentCount: 0,
    highCount: 0,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _enabled = await AppSettings.getBool(
        AppSettings.smartOrganizerEnabledKey,
        true,
      );
      if (!_enabled) {
        _insights = const <SmartInsight>[];
        _brief = const SmartBrief(
          title: '本地智能整理已关闭',
          lines: <String>['开启后会基于本地规则生成资料、待办、复习和诊断建议。'],
          totalCount: 0,
          urgentCount: 0,
          highCount: 0,
        );
      } else {
        _insights = await _service.generateInsights();
        _brief = _briefBuilder.build(_insights);
      }
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _setEnabled(bool value) async {
    await AppSettings.setBool(AppSettings.smartOrganizerEnabledKey, value);
    if (!mounted) return;
    setState(() => _enabled = value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能整理'),
        actions: [
          IconButton(
            tooltip: '刷新建议',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          Switch(value: _enabled, onChanged: _loading ? null : _setEnabled),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _BriefPanel(brief: _brief, loading: _loading, enabled: _enabled),
            const SizedBox(height: 12),
            if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _load)
            else if (!_enabled)
              const _DisabledPanel()
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._buildSections(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    final widgets = <Widget>[];
    for (final type in SmartInsightType.values) {
      final items = _insights.where((item) => item.type == type).toList();
      widgets.add(
        _InsightSection(
          title: type.labelZh,
          items: items,
          onAction: _handleAction,
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }
    if (_insights.isEmpty) {
      widgets.insert(0, const _EmptyPanel());
    }
    return widgets;
  }

  Future<void> _handleAction(
    SmartInsight insight,
    SmartInsightAction action,
  ) async {
    switch (action.type) {
      case SmartInsightActionType.openCourses:
        Navigator.of(context).popUntil((route) => route.isFirst);
      case SmartInsightActionType.openTodos:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const TodosPage()));
      case SmartInsightActionType.openMaterials:
      case SmartInsightActionType.createStudyCards:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MaterialSearchPage()));
      case SmartInsightActionType.openWebArchive:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WebArchivePage()));
      case SmartInsightActionType.openStudyCenter:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const StudyCenterPage()));
      case SmartInsightActionType.openOutputManager:
      case SmartInsightActionType.addToLibrary:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FileOutputManagerPage()),
        );
      case SmartInsightActionType.openDiagnostics:
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const RequestConsolePage()));
      case SmartInsightActionType.rebuildIndex:
        await _runAction('正在重建资料索引', () async {
          await _service.rebuildMaterialIndex();
        });
      case SmartInsightActionType.copyText:
        final text =
            action.payload['text']?.toString() ??
            action.targetPath ??
            insight.summary;
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已复制')));
        }
      case SmartInsightActionType.markDone:
        await _service.markDone(insight.id);
        await _load();
      case SmartInsightActionType.ignore:
        await _service.ignore(insight.id);
        await _load();
    }
  }

  Future<void> _runAction(String message, Future<void> Function() task) async {
    if (_runningAction) return;
    setState(() => _runningAction = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    try {
      await task();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作完成')));
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _runningAction = false);
      }
    }
  }
}

class _BriefPanel extends StatelessWidget {
  const _BriefPanel({
    required this.brief,
    required this.loading,
    required this.enabled,
  });

  final SmartBrief brief;
  final bool loading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enabled ? Icons.tips_and_updates_rounded : Icons.pause_circle,
                color: color.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  brief.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in brief.lines)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(line)),
          if (brief.totalCount > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(label: '全部', value: brief.totalCount),
                _CountChip(label: '紧急', value: brief.urgentCount),
                _CountChip(label: '高优先级', value: brief.highCount),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label $value'),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.items,
    required this.onAction,
  });

  final String title;
  final List<SmartInsight> items;
  final Future<void> Function(SmartInsight, SmartInsightAction) onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const _SectionEmpty()
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _InsightCard(insight: item, onAction: onAction),
              ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.onAction});

  final SmartInsight insight;
  final Future<void> Function(SmartInsight, SmartInsightAction) onAction;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PriorityBadge(priority: insight.priority),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(insight.summary),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '为什么出现：${insight.reason}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color.onSurfaceVariant),
            ),
            if (insight.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: insight.tags
                    .map(
                      (tag) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(tag),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _visibleActions(insight.actions)
                  .map(
                    (action) => TextButton.icon(
                      onPressed: () => onAction(insight, action),
                      icon: Icon(_iconFor(action.type), size: 18),
                      label: Text(action.label),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<SmartInsightAction> _visibleActions(List<SmartInsightAction> actions) {
    final seen = <SmartInsightActionType>{};
    return actions.where((action) => seen.add(action.type)).toList();
  }

  IconData _iconFor(SmartInsightActionType type) {
    return switch (type) {
      SmartInsightActionType.openCourses => Icons.school_rounded,
      SmartInsightActionType.openTodos => Icons.check_circle_outline_rounded,
      SmartInsightActionType.openMaterials => Icons.manage_search_rounded,
      SmartInsightActionType.openWebArchive => Icons.public_rounded,
      SmartInsightActionType.openStudyCenter => Icons.style_rounded,
      SmartInsightActionType.openOutputManager => Icons.folder_copy_rounded,
      SmartInsightActionType.openDiagnostics => Icons.monitor_heart_rounded,
      SmartInsightActionType.rebuildIndex => Icons.sync_rounded,
      SmartInsightActionType.createStudyCards => Icons.note_add_rounded,
      SmartInsightActionType.addToLibrary => Icons.library_add_rounded,
      SmartInsightActionType.copyText => Icons.copy_rounded,
      SmartInsightActionType.markDone => Icons.done_rounded,
      SmartInsightActionType.ignore => Icons.visibility_off_rounded,
    };
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final SmartInsightPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        priority.labelZh,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _color(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return switch (priority) {
      SmartInsightPriority.urgent => color.error,
      SmartInsightPriority.high => Colors.deepOrange,
      SmartInsightPriority.medium => color.primary,
      SmartInsightPriority.low => color.onSurfaceVariant,
    };
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('暂无建议', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text('当前没有需要处理的智能整理建议。')),
    );
  }
}

class _DisabledPanel extends StatelessWidget {
  const _DisabledPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text('本地智能整理已关闭，不会生成新的建议。')),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('智能整理加载失败'),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
