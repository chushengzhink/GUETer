import 'package:flutter/material.dart';

class ToolActionSpec {
  const ToolActionSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.tags = const [],
    this.badge,
    this.priority = 0,
  });
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final List<String> tags;
  final String? badge;
  final int priority;

  bool matches(String query) {
    final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
    final text = '$title $subtitle ${badge ?? ''} ${tags.join(' ')}'
        .toLowerCase();
    return terms.every(text.contains);
  }
}

class ToolCategorySpec {
  const ToolCategorySpec({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actions,
  });
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<ToolActionSpec> actions;
}

/// Search state belongs to the catalog, independent of file jobs and previews.
class ToolCatalogController extends ChangeNotifier {
  String _query = '';
  String get query => _query;
  void search(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  List<ToolActionSpec> results(List<ToolCategorySpec> categories) => [
    for (final category in categories)
      for (final action in category.actions)
        if (action.matches(_query) ||
            category.label.toLowerCase().contains(_query.trim().toLowerCase()))
          action,
  ];

  List<ToolActionSpec> favorites(
    List<ToolCategorySpec> categories,
    List<String> pinnedIds,
  ) {
    final actions = {
      for (final c in categories)
        for (final a in c.actions) a.id: a,
    };
    if (pinnedIds.isNotEmpty) {
      return [
        for (final id in pinnedIds.toSet())
          if (actions.containsKey(id)) actions[id]!,
      ];
    }
    const defaults = [
      'material-search',
      'material-ocr',
      'arrange-pdf',
      'file-output-manager',
    ];
    final ids = <String>{
      ...defaults.where(actions.containsKey),
      for (final c in categories)
        if (c.actions.isNotEmpty) c.actions.first.id,
    };
    return ids.take(4).map((id) => actions[id]!).toList();
  }
}

/// Intrinsically sized tiles stay usable with large Android font settings.
class ToolCatalog extends StatefulWidget {
  const ToolCatalog({
    super.key,
    required this.categories,
    required this.pinnedIds,
    required this.onOpenCategory,
  });
  final List<ToolCategorySpec> categories;
  final List<String> pinnedIds;
  final ValueChanged<ToolCategorySpec> onOpenCategory;

  @override
  State<ToolCatalog> createState() => _ToolCatalogState();
}

class _ToolCatalogState extends State<ToolCatalog> {
  final _controller = ToolCatalogController();
  final _textController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final searching = _controller.query.trim().isNotEmpty;
        final actions = searching
            ? _controller.results(widget.categories)
            : _controller.favorites(widget.categories, widget.pinnedIds);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('tool-search'),
              controller: _textController,
              onChanged: _controller.search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                labelText: en ? 'Search all tools' : '搜索全部工具',
                hintText: en ? 'PDF, files, transfer…' : 'PDF、资料、传输…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: en ? 'Clear search' : '清空搜索',
                        onPressed: () {
                          _textController.clear();
                          _controller.search('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              searching
                  ? (en
                        ? 'Search results (${actions.length})'
                        : '搜索结果（${actions.length}）')
                  : (en ? 'Quick access' : '常用工具'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (actions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  searching
                      ? (en
                            ? 'No matching tools. Try another keyword.'
                            : '没有匹配的工具，换个关键词试试。')
                      : (en
                            ? 'Pin tools in layout settings for quick access.'
                            : '可在布局设置中固定常用工具。'),
                ),
              ),
            _tiles(context, [
              for (final action in actions)
                _CatalogTile(
                  key: ValueKey('tool-${action.id}'),
                  title: action.title,
                  subtitle: action.subtitle,
                  icon: action.icon,
                  badge: action.badge,
                  onTap: action.onTap,
                ),
            ]),
            if (!searching) ...[
              const SizedBox(height: 24),
              Text(
                en ? 'All categories' : '全部分类',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final category in widget.categories)
                      ListTile(
                        key: ValueKey('category-${category.id}'),
                        leading: Icon(
                          category.icon,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(category.label),
                        subtitle: Text(
                          '${category.actions.length} ${en ? 'tools' : '个工具'} · ${category.subtitle}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => widget.onOpenCategory(category),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _tiles(BuildContext context, List<Widget> tiles) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
      final columns = largeText || constraints.maxWidth < 300
          ? 1
          : constraints.maxWidth >= 700
          ? 3
          : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final tile in tiles) SizedBox(width: width, child: tile),
        ],
      );
    },
  );
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badge,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Card(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  if (ModalRoute.of(context)?.isCurrent == false) return;
                  FocusScope.of(context).unfocus();
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
