import 'package:flutter/material.dart';

import '../app_entries/app_entry_registry.dart';
import '../layout/layout_preferences.dart';
import '../session/app_settings.dart';

class LayoutCustomizationPage extends StatefulWidget {
  const LayoutCustomizationPage({super.key});

  @override
  State<LayoutCustomizationPage> createState() =>
      _LayoutCustomizationPageState();
}

class _LayoutCustomizationPageState extends State<LayoutCustomizationPage> {
  late LayoutPreferences _preferences = AppSettings
      .layoutPreferencesStore
      .notifier
      .value
      .normalized(
        navIds: buildBuiltinAppEntries().map((entry) => entry.id).toList(),
      );

  Future<void> _save(LayoutPreferences preferences) async {
    setState(() => _preferences = preferences);
    await AppSettings.layoutPreferencesStore.save(preferences);
  }

  Future<void> _reset() async {
    await AppSettings.layoutPreferencesStore.reset();
    setState(() {
      _preferences = const LayoutPreferences();
    });
  }

  List<_LayoutItem> _toolCategories() {
    final items = <_LayoutItem>[
      const _LayoutItem(id: 'transfer', titleZh: '传输', titleEn: '传输'),
      const _LayoutItem(id: 'pdf', titleZh: 'PDF', titleEn: 'PDF'),
      const _LayoutItem(id: 'files', titleZh: '文件', titleEn: '文件'),
      const _LayoutItem(id: 'network', titleZh: '网络', titleEn: '网络'),
      const _LayoutItem(id: 'study', titleZh: '学习', titleEn: '学习'),
      const _LayoutItem(id: 'campus', titleZh: '校园', titleEn: '校园'),
    ];
    final seen = items.map((item) => item.id).toSet();
    for (final manifest
        in AppSettings.pluginStore.enabledPluginsNotifier.value) {
      for (final entry in manifest.entries) {
        final id = 'plugin:${entry.category}';
        if (seen.add(id)) {
          items.add(_LayoutItem(id: id, titleZh: '插件', titleEn: '插件'));
        }
      }
    }
    return items;
  }

  List<_LayoutItem> _toolActions() {
    final items = <_LayoutItem>[
      const _LayoutItem(id: 'nearby-room', titleZh: '附近房间', titleEn: '附近房间'),
      const _LayoutItem(
        id: 'local-transfer',
        titleZh: '局域网互传',
        titleEn: '局域网互传',
      ),
      const _LayoutItem(
        id: 'pdf-to-images',
        titleZh: 'PDF 转图片',
        titleEn: 'PDF 转图片',
      ),
      const _LayoutItem(
        id: 'images-to-pdf',
        titleZh: '图片合成 PDF',
        titleEn: '图片合成 PDF',
      ),
      const _LayoutItem(
        id: 'compress-pdf',
        titleZh: '压缩 PDF',
        titleEn: '压缩 PDF',
      ),
      const _LayoutItem(id: 'extract-pages', titleZh: '提取页面', titleEn: '提取页面'),
      const _LayoutItem(
        id: 'watermark-pdf',
        titleZh: 'PDF 水印',
        titleEn: 'PDF 水印',
      ),
      const _LayoutItem(id: 'file-tools', titleZh: '文件工具', titleEn: '文件工具'),
      const _LayoutItem(id: 'virtual-lan', titleZh: '虚拟局域网', titleEn: '虚拟局域网'),
      const _LayoutItem(id: 'reading', titleZh: '阅读', titleEn: '阅读'),
      const _LayoutItem(
        id: 'academic-search',
        titleZh: '学术检索',
        titleEn: '学术检索',
      ),
      const _LayoutItem(id: 'apod', titleZh: '每日天文图', titleEn: '每日天文图'),
      const _LayoutItem(id: 'guet-email', titleZh: '桂电邮箱', titleEn: '桂电邮箱'),
      const _LayoutItem(id: 'guet-official', titleZh: '桂电官网', titleEn: '桂电官网'),
      const _LayoutItem(id: 'ai-figure', titleZh: 'AI 科研', titleEn: 'AI 科研'),
      const _LayoutItem(id: 'computer-help', titleZh: '电脑帮助', titleEn: '电脑帮助'),
    ];
    for (final manifest
        in AppSettings.pluginStore.enabledPluginsNotifier.value) {
      for (final entry in manifest.entries) {
        items.add(
          _LayoutItem(
            id: 'plugin:${manifest.id}:${entry.id}',
            titleZh: entry.name.zh,
            titleEn: entry.name.en,
          ),
        );
      }
    }
    return items;
  }

  List<String> _orderedIds(List<String> saved, List<_LayoutItem> items) {
    final knownIds = items.map((item) => item.id).toList();
    return LayoutPreferences(
      toolActionOrder: saved,
    ).visibleToolActionOrder(knownIds);
  }

  @override
  Widget build(BuildContext context) {
    final entries = buildBuiltinAppEntries();
    final entryById = {for (final entry in entries) entry.id: entry};
    final navIds = _preferences
        .normalized(navIds: entryById.keys.toList())
        .navOrder;
    final locale = Localizations.localeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('界面布局'),
        actions: [TextButton(onPressed: _reset, child: const Text('恢复默认'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '主导航',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '拖动调整底部导航顺序；隐藏的入口不会出现在底栏。底栏最多显示 5 个入口。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: navIds.length,
            onReorder: (oldIndex, newIndex) async {
              final order = List<String>.from(navIds);
              if (newIndex > oldIndex) newIndex -= 1;
              final item = order.removeAt(oldIndex);
              order.insert(newIndex, item);
              await _save(_preferences.copyWith(navOrder: order));
            },
            itemBuilder: (context, index) {
              final id = navIds[index];
              final entry = entryById[id]!;
              final hidden = _preferences.hiddenNavIds.contains(id);
              return Card(
                key: ValueKey(id),
                child: SwitchListTile(
                  value: !hidden,
                  secondary: Icon(entry.icon),
                  title: Text(entry.titleFor(locale)),
                  subtitle: Text(id),
                  onChanged: (visible) async {
                    final hiddenIds = List<String>.from(
                      _preferences.hiddenNavIds,
                    );
                    if (visible) {
                      hiddenIds.remove(id);
                    } else if (hiddenIds.length < navIds.length - 1) {
                      hiddenIds.add(id);
                    }
                    await _save(_preferences.copyWith(hiddenNavIds: hiddenIds));
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '工具页',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('拖动调整工具分类和工具卡片顺序；关闭卡片后不会在工具页显示。'),
          const SizedBox(height: 12),
          _ToolReorderSection(
            title: '工具分类',
            items: _toolCategories(),
            order: _orderedIds(
              _preferences.toolCategoryOrder,
              _toolCategories(),
            ),
            hiddenIds: const <String>[],
            allowHide: false,
            onOrderChanged: (order) async {
              await _save(_preferences.copyWith(toolCategoryOrder: order));
            },
            onHiddenChanged: (_) async {},
          ),
          const SizedBox(height: 16),
          _ToolReorderSection(
            title: '工具卡片',
            items: _toolActions(),
            order: _orderedIds(_preferences.toolActionOrder, _toolActions()),
            hiddenIds: _preferences.hiddenToolActionIds,
            allowHide: true,
            onOrderChanged: (order) async {
              await _save(_preferences.copyWith(toolActionOrder: order));
            },
            onHiddenChanged: (hiddenIds) async {
              await _save(
                _preferences.copyWith(hiddenToolActionIds: hiddenIds),
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await _save(
                _preferences.copyWith(
                  toolCategoryOrder: <String>[],
                  toolActionOrder: <String>[],
                  hiddenToolActionIds: <String>[],
                  pinnedToolActionIds: <String>[],
                ),
              );
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('恢复工具页默认布局'),
          ),
        ],
      ),
    );
  }
}

class _LayoutItem {
  const _LayoutItem({
    required this.id,
    required this.titleZh,
    required this.titleEn,
  });

  final String id;
  final String titleZh;
  final String titleEn;

  String titleFor(Locale locale) {
    return locale.languageCode == 'en' ? titleEn : titleZh;
  }
}

class _ToolReorderSection extends StatelessWidget {
  const _ToolReorderSection({
    required this.title,
    required this.items,
    required this.order,
    required this.hiddenIds,
    required this.allowHide,
    required this.onOrderChanged,
    required this.onHiddenChanged,
  });

  final String title;
  final List<_LayoutItem> items;
  final List<String> order;
  final List<String> hiddenIds;
  final bool allowHide;
  final ValueChanged<List<String>> onOrderChanged;
  final ValueChanged<List<String>> onHiddenChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final itemById = {for (final item in items) item.id: item};
    final ids = order.where(itemById.containsKey).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ids.length,
              onReorder: (oldIndex, newIndex) {
                final next = List<String>.from(ids);
                if (newIndex > oldIndex) newIndex -= 1;
                final item = next.removeAt(oldIndex);
                next.insert(newIndex, item);
                onOrderChanged(next);
              },
              itemBuilder: (context, index) {
                final id = ids[index];
                final item = itemById[id]!;
                final hidden = hiddenIds.contains(id);
                return ListTile(
                  key: ValueKey('$title-$id'),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(item.titleFor(locale)),
                  subtitle: Text(id),
                  trailing: allowHide
                      ? Switch(
                          value: !hidden,
                          onChanged: (visible) {
                            final next = List<String>.from(hiddenIds);
                            if (visible) {
                              next.remove(id);
                            } else {
                              next.add(id);
                            }
                            onHiddenChanged(next);
                          },
                        )
                      : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
