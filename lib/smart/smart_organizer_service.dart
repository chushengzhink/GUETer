import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_service.dart';
import '../core/performance/app_performance.dart';
import '../materials/material_index_models.dart';
import '../materials/material_index_service.dart';
import '../materials/material_library_store.dart';
import '../materials/web_archive_models.dart';
import '../materials/web_archive_store.dart';
import '../models/file_output_manager_models.dart';
import '../platform.dart';
import '../plugins/plugin_store.dart';
import '../services/file_output_manager_service.dart';
import '../session/app_settings.dart';
import '../study/study_card_store.dart';
import 'smart_insight_store.dart';
import 'smart_models.dart';
import 'smart_tagger.dart';

typedef SmartTodoLoader = Future<List<Map<String, dynamic>>> Function();

class SmartOrganizerService {
  SmartOrganizerService({
    MaterialLibraryStore? materialLibraryStore,
    MaterialIndexService? materialIndexService,
    WebArchiveStore? webArchiveStore,
    StudyCardStore? studyCardStore,
    FileOutputManagerService? outputService,
    PluginStore? pluginStore,
    SmartInsightStore? insightStore,
    SmartTagger? tagger,
    SmartTodoLoader? todoLoader,
    DateTime Function()? clock,
  }) : _materialLibraryStore = materialLibraryStore ?? MaterialLibraryStore(),
       _materialIndexService = materialIndexService ?? MaterialIndexService(),
       _webArchiveStore = webArchiveStore ?? WebArchiveStore(),
       _studyCardStore = studyCardStore ?? StudyCardStore(),
       _outputService = outputService ?? FileOutputManagerService(),
       _pluginStore = pluginStore ?? AppSettings.pluginStore,
       _insightStore = insightStore ?? SmartInsightStore(),
       _tagger = tagger ?? const SmartTagger(),
       _todoLoader = todoLoader,
       _clock = clock ?? DateTime.now;

  final MaterialLibraryStore _materialLibraryStore;
  final MaterialIndexService _materialIndexService;
  final WebArchiveStore _webArchiveStore;
  final StudyCardStore _studyCardStore;
  final FileOutputManagerService _outputService;
  final PluginStore _pluginStore;
  final SmartInsightStore _insightStore;
  final SmartTagger _tagger;
  final SmartTodoLoader? _todoLoader;
  final DateTime Function() _clock;

  Future<List<SmartInsight>> generateInsights({
    bool includeInactive = false,
  }) async {
    final generated = <SmartInsight>[];
    await _collectSafely(generated, _todoInsights);
    await _collectSafely(generated, _materialInsights);
    await _collectSafely(generated, _webArchiveInsights);
    await _collectSafely(generated, _reviewInsights);
    await _collectSafely(generated, _outputInsights);
    await _collectSafely(generated, _diagnosticInsights);
    await _collectSafely(generated, _pluginInsights);

    final byId = <String, SmartInsight>{};
    for (final insight in generated) {
      byId[insight.id] = insight;
    }
    final withStatuses = await _insightStore.applyStatuses(
      byId.values.toList(),
      includeInactive: includeInactive,
    );
    return _sortInsights(withStatuses);
  }

  Future<void> markDone(String id) {
    return _insightStore.setStatus(id, SmartInsightStatus.done);
  }

  Future<void> ignore(String id) {
    return _insightStore.setStatus(id, SmartInsightStatus.ignored);
  }

  Future<void> rebuildMaterialIndex() async {
    await _materialIndexService.rebuildIndex(
      performanceMode: AppSettings.performanceMode,
    );
  }

  Future<void> _collectSafely(
    List<SmartInsight> target,
    Future<List<SmartInsight>> Function() collector,
  ) async {
    try {
      target.addAll(await collector());
    } catch (error) {
      target.add(
        _insight(
          type: SmartInsightType.pluginSystem,
          rule: 'collector-error',
          sourceKind: 'system',
          sourceId: collector.hashCode.toString(),
          title: '智能整理规则读取失败',
          summary: '某个本地数据源暂时无法读取，其他建议仍会正常显示。',
          reason: error.toString(),
          priority: SmartInsightPriority.low,
          actions: const <SmartInsightAction>[
            SmartInsightAction(
              type: SmartInsightActionType.openDiagnostics,
              label: '查看诊断',
            ),
          ],
        ),
      );
    }
  }

  Future<List<SmartInsight>> _todoInsights() async {
    final now = _clock();
    final todos = await (_todoLoader?.call() ?? _loadPersistedTodos());
    final result = <SmartInsight>[];
    for (final todo in todos) {
      final title = _todoTitle(todo);
      final platform = todo['platform']?.toString() ?? 'unknown';
      final id = todo['id']?.toString().trim().isNotEmpty == true
          ? todo['id'].toString()
          : _stableHash('$platform|$title|${todo['deadline'] ?? ''}');
      final deadline = _extractDate(todo);
      final tags = _tagger.suggestTags(title: title, text: jsonEncode(todo));
      final hasRiskKeyword = tags.contains('考试') || tags.contains('作业');
      if (deadline != null) {
        final diff = deadline.difference(now);
        if (!diff.isNegative && diff <= const Duration(hours: 24)) {
          result.add(
            _insight(
              type: SmartInsightType.today,
              rule: 'todo-due-24h',
              sourceKind: 'todo',
              sourceId: id,
              title: '待办即将截止：$title',
              summary: '截止时间在 24 小时内，建议优先处理。',
              reason: '本地待办缓存显示截止时间为 ${deadline.toLocal()}。',
              priority: SmartInsightPriority.urgent,
              dueAt: deadline,
              tags: tags,
              actions: const <SmartInsightAction>[
                SmartInsightAction(
                  type: SmartInsightActionType.openTodos,
                  label: '打开待办',
                ),
              ],
            ),
          );
        } else if (diff.isNegative) {
          result.add(
            _insight(
              type: SmartInsightType.todoRisk,
              rule: 'todo-overdue',
              sourceKind: 'todo',
              sourceId: id,
              title: '待办可能已过期：$title',
              summary: '本地记录显示该事项已经超过截止时间。',
              reason: '截止时间早于当前时间：${deadline.toLocal()}。',
              priority: SmartInsightPriority.urgent,
              dueAt: deadline,
              tags: tags,
              actions: const <SmartInsightAction>[
                SmartInsightAction(
                  type: SmartInsightActionType.openTodos,
                  label: '打开待办',
                ),
              ],
            ),
          );
        } else if (diff <= const Duration(days: 3) || hasRiskKeyword) {
          result.add(
            _insight(
              type: SmartInsightType.todoRisk,
              rule: 'todo-due-soon',
              sourceKind: 'todo',
              sourceId: id,
              title: '待办需要关注：$title',
              summary: hasRiskKeyword ? '包含作业或考试关键词。' : '截止时间在三天内。',
              reason: '由本地待办标题和截止时间规则识别。',
              priority: SmartInsightPriority.high,
              dueAt: deadline,
              tags: tags,
              actions: const <SmartInsightAction>[
                SmartInsightAction(
                  type: SmartInsightActionType.openTodos,
                  label: '打开待办',
                ),
              ],
            ),
          );
        }
      } else if (hasRiskKeyword) {
        result.add(
          _insight(
            type: SmartInsightType.todoRisk,
            rule: 'todo-keyword',
            sourceKind: 'todo',
            sourceId: id,
            title: '待办含高风险关键词：$title',
            summary: '检测到作业、考试或测验相关关键词。',
            reason: '标题或内容命中了本地关键词规则。',
            priority: SmartInsightPriority.medium,
            tags: tags,
            actions: const <SmartInsightAction>[
              SmartInsightAction(
                type: SmartInsightActionType.openTodos,
                label: '打开待办',
              ),
            ],
          ),
        );
      }
    }
    return result;
  }

  Future<List<SmartInsight>> _materialInsights() async {
    final now = _clock();
    final items = await _materialLibraryStore.refreshMissingStatuses();
    final indexEntries = await _materialIndexService.loadIndex();
    final indexedPaths = indexEntries
        .map((entry) => p.normalize(entry.path))
        .toSet();
    final cardGroups = await _studyCardStore.sourceGroups(now: now);
    final cardSourcePaths = cardGroups
        .map((group) => p.normalize(group.sourcePath))
        .toSet();
    final result = <SmartInsight>[];
    for (final item in items) {
      if (item.status == MaterialLibraryStatus.ignored ||
          item.status == MaterialLibraryStatus.archived) {
        continue;
      }
      final normalizedPath = p.normalize(item.path);
      final tags = _tagger.suggestTags(
        title: item.name,
        path: item.path,
        sourceLabel: item.sourceLabel,
        isWebArchive: item.sourceType == MaterialSourceType.webArchive,
      );
      if (item.status == MaterialLibraryStatus.missing) {
        result.add(
          _insight(
            type: SmartInsightType.material,
            rule: 'material-missing',
            sourceKind: 'material',
            sourceId: item.id,
            title: '资料文件缺失：${item.name}',
            summary: '资料库记录存在，但本地文件或目录已经找不到。',
            reason: '刷新资料库状态时检测到路径不存在：${item.path}',
            priority: SmartInsightPriority.high,
            tags: tags,
            actions: _materialActions(item.path),
          ),
        );
        continue;
      }
      if (!indexedPaths.contains(normalizedPath)) {
        result.add(
          _insight(
            type: SmartInsightType.material,
            rule: 'material-unindexed',
            sourceKind: 'material',
            sourceId: item.id,
            title: '资料尚未进入搜索索引：${item.name}',
            summary: '重建索引后可在资料页搜索到它，也更容易生成复习卡。',
            reason: '资料库中存在该路径，但资料索引文件没有对应记录。',
            priority: SmartInsightPriority.medium,
            tags: tags,
            actions: const <SmartInsightAction>[
              SmartInsightAction(
                type: SmartInsightActionType.rebuildIndex,
                label: '重建索引',
              ),
              SmartInsightAction(
                type: SmartInsightActionType.openMaterials,
                label: '打开资料',
              ),
            ],
          ),
        );
      }
      if (item.lastOpenedAt == null &&
          now.difference(item.importedAt) <= const Duration(days: 7)) {
        result.add(
          _insight(
            type: SmartInsightType.today,
            rule: 'material-recent-unopened',
            sourceKind: 'material',
            sourceId: item.id,
            title: '最近导入资料未查看：${item.name}',
            summary: '这是最近加入的资料，还没有打开记录。',
            reason: '导入时间在 7 天内，lastOpenedAt 为空。',
            priority: SmartInsightPriority.low,
            tags: tags,
            actions: _materialActions(item.path),
          ),
        );
      }
      final shouldMakeCards =
          tags.contains('考试') || tags.contains('重点') || tags.contains('作业');
      if (shouldMakeCards && !cardSourcePaths.contains(normalizedPath)) {
        result.add(
          _insight(
            type: SmartInsightType.review,
            rule: 'material-no-cards',
            sourceKind: 'material',
            sourceId: item.id,
            title: '可从资料生成复习卡：${item.name}',
            summary: '资料带有复习、考试或作业特征，但还没有来源复习卡。',
            reason: '本地标签规则命中 ${tags.join('、')}，复习卡来源中未发现该路径。',
            priority: SmartInsightPriority.medium,
            tags: tags,
            actions: const <SmartInsightAction>[
              SmartInsightAction(
                type: SmartInsightActionType.openMaterials,
                label: '打开资料',
              ),
              SmartInsightAction(
                type: SmartInsightActionType.createStudyCards,
                label: '生成复习卡候选',
              ),
            ],
          ),
        );
      }
      final missingTags = tags
          .where((tag) => !item.tags.contains(tag))
          .toList();
      if (missingTags.isNotEmpty) {
        result.add(
          _insight(
            type: SmartInsightType.material,
            rule: 'material-suggest-tags',
            sourceKind: 'material',
            sourceId: item.id,
            title: '建议给资料补充标签：${item.name}',
            summary: '建议标签：${missingTags.join('、')}',
            reason: '根据文件名、来源标签和路径识别，不会自动覆盖用户标签。',
            priority: SmartInsightPriority.low,
            tags: missingTags,
            actions: _materialActions(item.path),
          ),
        );
      }
    }
    return result;
  }

  Future<List<SmartInsight>> _webArchiveInsights() async {
    final items = await _webArchiveStore.refreshMissingStatuses();
    final result = <SmartInsight>[];
    for (final item in items) {
      if (item.status == WebArchiveStatus.ignored ||
          item.status == WebArchiveStatus.archived) {
        continue;
      }
      final tags = _tagger.suggestTags(
        title: item.displayTitle,
        text: item.description,
        path: item.textSnapshotPath,
        isWebArchive: true,
      );
      if (item.status == WebArchiveStatus.fetchError) {
        result.add(
          _insight(
            type: SmartInsightType.material,
            rule: 'web-fetch-error',
            sourceKind: 'webArchive',
            sourceId: item.id,
            title: '网页归档抓取失败：${item.displayTitle}',
            summary: '链接已保存，但正文快照未成功生成。',
            reason: '网页归档状态为 fetchError，可能是登录态页面、403 或超时。',
            priority: SmartInsightPriority.high,
            tags: tags,
            actions: _webActions(item.url),
          ),
        );
      } else if (item.status == WebArchiveStatus.missing) {
        result.add(
          _insight(
            type: SmartInsightType.material,
            rule: 'web-snapshot-missing',
            sourceKind: 'webArchive',
            sourceId: item.id,
            title: '网页快照缺失：${item.displayTitle}',
            summary: '归档记录存在，但本地文本快照路径找不到。',
            reason: 'textSnapshotPath 不为空但文件已缺失。',
            priority: SmartInsightPriority.high,
            tags: tags,
            actions: _webActions(item.url),
          ),
        );
      }
      final missingTags = tags
          .where((tag) => !item.tags.contains(tag))
          .toList();
      if (missingTags.isNotEmpty) {
        result.add(
          _insight(
            type: SmartInsightType.material,
            rule: 'web-suggest-tags',
            sourceKind: 'webArchive',
            sourceId: item.id,
            title: '建议给网页归档补充标签：${item.displayTitle}',
            summary: '建议标签：${missingTags.join('、')}',
            reason: '根据网页标题、描述和 URL 识别，不会自动写入。',
            priority: SmartInsightPriority.low,
            tags: missingTags,
            actions: _webActions(item.url),
          ),
        );
      }
    }
    return result;
  }

  Future<List<SmartInsight>> _reviewInsights() async {
    final now = _clock();
    final result = <SmartInsight>[];
    final summary = await _studyCardStore.summary(now: now);
    if (summary.dueCards > 0) {
      result.add(
        _insight(
          type: SmartInsightType.today,
          rule: 'review-due',
          sourceKind: 'study',
          sourceId: 'due',
          title: '今日有 ${summary.dueCards} 张复习卡到期',
          summary: '及时复习能保持 SM-2 调度效果。',
          reason: '复习卡 dueAt 不晚于当前时间。',
          priority: summary.dueCards >= 20
              ? SmartInsightPriority.urgent
              : SmartInsightPriority.high,
          actions: const <SmartInsightAction>[
            SmartInsightAction(
              type: SmartInsightActionType.openStudyCenter,
              label: '去复习中心',
            ),
          ],
        ),
      );
    }
    final cards = await _studyCardStore.loadCards();
    for (final card in cards) {
      final sourcePath = card.sourcePath?.trim();
      if (sourcePath != null &&
          sourcePath.isNotEmpty &&
          !File(sourcePath).existsSync() &&
          !Directory(sourcePath).existsSync()) {
        result.add(
          _insight(
            type: SmartInsightType.review,
            rule: 'card-source-missing',
            sourceKind: 'studyCard',
            sourceId: card.id,
            title: '复习卡来源缺失：${card.front}',
            summary: '卡片保留来源信息，但本地来源文件找不到。',
            reason: 'sourcePath 指向的文件或目录不存在：$sourcePath',
            priority: SmartInsightPriority.high,
            actions: const <SmartInsightAction>[
              SmartInsightAction(
                type: SmartInsightActionType.openStudyCenter,
                label: '打开复习中心',
              ),
            ],
          ),
        );
      }
      if (card.back.trim().isEmpty || card.back.length > 1200) {
        result.add(
          _insight(
            type: SmartInsightType.review,
            rule: card.back.trim().isEmpty
                ? 'card-empty-back'
                : 'card-long-back',
            sourceKind: 'studyCard',
            sourceId: card.id,
            title: '复习卡内容需要维护：${card.front}',
            summary: card.back.trim().isEmpty ? '背面为空。' : '背面内容较长，可能不适合记忆卡。',
            reason: '本地规则检测到背面为空或长度超过 1200 字符。',
            priority: SmartInsightPriority.low,
            actions: const <SmartInsightAction>[
              SmartInsightAction(
                type: SmartInsightActionType.openStudyCenter,
                label: '编辑复习卡',
              ),
            ],
          ),
        );
      }
    }
    final groups = await _studyCardStore.sourceGroups(now: now);
    for (final group in groups.where((group) => group.dueCount > 0).take(5)) {
      result.add(
        _insight(
          type: SmartInsightType.review,
          rule: 'source-due',
          sourceKind: 'studySource',
          sourceId: group.sourcePath,
          title: '资料来源有到期卡：${group.sourceFileName}',
          summary: '${group.dueCount} / ${group.cardCount} 张卡片今日到期。',
          reason: '按复习卡 sourcePath 聚合得到。',
          priority: SmartInsightPriority.high,
          actions: const <SmartInsightAction>[
            SmartInsightAction(
              type: SmartInsightActionType.openStudyCenter,
              label: '查看来源卡片',
            ),
          ],
        ),
      );
    }
    return result;
  }

  Future<List<SmartInsight>> _outputInsights() async {
    final outputs = await _outputService.loadOutputs(
      performanceMode: AppSettings.lowPowerMode
          ? AppPerformanceMode.lowPower
          : AppPerformanceMode.balanced,
    );
    final result = <SmartInsight>[];
    for (final item in outputs) {
      final tags = _tagger.suggestTags(
        title: item.name,
        path: item.path,
        sourceLabel: item.sourceLabel,
        isOutput: true,
      );
      if (item.status == FileOutputStatus.missing) {
        result.add(
          _insight(
            type: SmartInsightType.output,
            rule: 'output-missing',
            sourceKind: 'output',
            sourceId: item.id,
            title: '输出历史文件缺失：${item.name}',
            summary: '历史记录存在，但文件已经不存在。',
            reason: '输出文件管家状态为 missing。',
            priority: SmartInsightPriority.medium,
            tags: tags,
            actions: _outputActions(item.path),
          ),
        );
      } else if (item.exists && !item.inMaterialLibrary && !item.isDirectory) {
        result.add(
          _insight(
            type: SmartInsightType.output,
            rule: 'output-not-in-library',
            sourceKind: 'output',
            sourceId: item.id,
            title: '输出文件未入资料库：${item.name}',
            summary: '可加入资料库，后续能搜索和转复习卡。',
            reason: '输出文件存在，且资料库中没有相同路径。',
            priority: SmartInsightPriority.medium,
            tags: tags,
            actions: _outputActions(item.path),
          ),
        );
      }
      if (item.status == FileOutputStatus.scanOnly) {
        result.add(
          _insight(
            type: SmartInsightType.output,
            rule: 'output-scan-only',
            sourceKind: 'output',
            sourceId: item.id,
            title: '扫描发现未记录输出：${item.name}',
            summary: '该文件在公共输出目录中，但没有历史记录。',
            reason: '输出文件管家将其标记为 scanOnly。',
            priority: SmartInsightPriority.low,
            tags: tags,
            actions: _outputActions(item.path),
          ),
        );
      }
      if (item.exists && item.sizeBytes >= 50 * 1024 * 1024) {
        result.add(
          _insight(
            type: SmartInsightType.output,
            rule: 'output-large',
            sourceKind: 'output',
            sourceId: item.id,
            title: '大体积输出文件：${item.name}',
            summary: '文件大小约 ${_formatSize(item.sizeBytes)}，可按需归档或清理。',
            reason: '输出文件大小超过 50 MB，智能整理不会自动删除。',
            priority: SmartInsightPriority.low,
            tags: tags,
            actions: _outputActions(item.path),
          ),
        );
      }
    }
    return result;
  }

  Future<List<SmartInsight>> _diagnosticInsights() async {
    final result = <SmartInsight>[];
    final summary = ApiService.getConsoleHealthSummary();
    if ((summary['failures'] ?? 0) > 0) {
      result.add(
        _insight(
          type: SmartInsightType.accountNetwork,
          rule: 'request-failures',
          sourceKind: 'diagnostic',
          sourceId: 'request-console',
          title: '平台请求最近出现失败',
          summary: '请求控制台记录到 ${summary['failures']} 条失败日志。',
          reason: '来自本地请求控制台健康摘要，不包含 cookie/token 明文。',
          priority: SmartInsightPriority.high,
          actions: const <SmartInsightAction>[
            SmartInsightAction(
              type: SmartInsightActionType.openDiagnostics,
              label: '查看诊断',
            ),
          ],
        ),
      );
    }
    if ((summary['staleFallbacks'] ?? 0) > 0 ||
        (summary['cacheHits'] ?? 0) > 0) {
      result.add(
        _insight(
          type: SmartInsightType.accountNetwork,
          rule: 'request-cache',
          sourceKind: 'diagnostic',
          sourceId: 'request-cache',
          title: '平台数据正在使用缓存兜底',
          summary:
              '缓存命中 ${summary['cacheHits'] ?? 0} 次，stale 兜底 ${summary['staleFallbacks'] ?? 0} 次。',
          reason: '网络波动或平台错误时，功能 GET 请求可能显示旧数据。',
          priority: SmartInsightPriority.medium,
          actions: const <SmartInsightAction>[
            SmartInsightAction(
              type: SmartInsightActionType.openDiagnostics,
              label: '查看请求控制台',
            ),
          ],
        ),
      );
    }
    final performance = AppSettings.performanceSettings;
    final jank = AppSettings.frameJankMonitor.snapshot();
    if (!performance.lowPower && jank.uiJankFrames >= 8) {
      result.add(
        _insight(
          type: SmartInsightType.pluginSystem,
          rule: 'low-power-suggestion',
          sourceKind: 'performance',
          sourceId: 'frame-jank',
          title: '建议开启低算力流畅模式',
          summary: '最近检测到 ${jank.uiJankFrames} 个 UI 卡顿帧。',
          reason: '性能诊断采样显示 UI jank 较多，低算力模式会降低缩略图和批处理压力。',
          priority: SmartInsightPriority.medium,
          actions: const <SmartInsightAction>[
            SmartInsightAction(
              type: SmartInsightActionType.openDiagnostics,
              label: '打开设置',
            ),
          ],
        ),
      );
    }
    return result;
  }

  Future<List<SmartInsight>> _pluginInsights() async {
    await _pluginStore.scan();
    final invalid = _pluginStore.invalidPluginsNotifier.value;
    return invalid
        .map(
          (plugin) => _insight(
            type: SmartInsightType.pluginSystem,
            rule: 'plugin-invalid',
            sourceKind: 'plugin',
            sourceId: plugin.path,
            title: '插件清单异常：${plugin.directoryName}',
            summary: '插件 manifest 无法解析或不符合规范。',
            reason: plugin.error,
            priority: SmartInsightPriority.high,
            actions: const <SmartInsightAction>[
              SmartInsightAction(
                type: SmartInsightActionType.openDiagnostics,
                label: '查看插件',
              ),
            ],
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _loadPersistedTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todos = <Map<String, dynamic>>[];
    for (final platform in <PlatformType>[
      PlatformType.chaoxing,
      PlatformType.rainClassroom,
      PlatformType.tronclass,
      PlatformType.ketangpai,
    ]) {
      final raw = prefs.getString('todos_${platform.name}');
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        for (final key in const <String>['pending', 'completed']) {
          final list = decoded[key];
          if (list is! List) continue;
          for (final item in list.whereType<Map>()) {
            todos.add(<String, dynamic>{
              ...item.map((key, value) => MapEntry(key.toString(), value)),
              'platform': platform.name,
            });
          }
        }
      } catch (_) {
        continue;
      }
    }
    return todos;
  }

  String _todoTitle(Map<String, dynamic> todo) {
    for (final key in const <String>[
      'title',
      'name',
      'taskName',
      'activityName',
      'courseName',
      'content',
    ]) {
      final value = todo[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '未命名待办';
  }

  DateTime? _extractDate(Map<String, dynamic> values) {
    for (final key in const <String>[
      'deadline',
      'dueAt',
      'dueDate',
      'endTime',
      'end_time',
      'finishTime',
      'closeTime',
      'time',
      'startAt',
    ]) {
      final parsed = _parseDate(values[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is int) {
      final millis = value > 100000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (value is num) {
      final intValue = value.toInt();
      final millis = intValue > 100000000000 ? intValue : intValue * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    final number = int.tryParse(text);
    if (number != null) return _parseDate(number);
    return null;
  }

  List<SmartInsightAction> _materialActions(String path) {
    return <SmartInsightAction>[
      SmartInsightAction(
        type: SmartInsightActionType.openMaterials,
        label: '打开资料',
        targetPath: path,
      ),
    ];
  }

  List<SmartInsightAction> _webActions(String url) {
    return <SmartInsightAction>[
      SmartInsightAction(
        type: SmartInsightActionType.openWebArchive,
        label: '打开网页归档',
        targetPath: url,
      ),
    ];
  }

  List<SmartInsightAction> _outputActions(String path) {
    return <SmartInsightAction>[
      SmartInsightAction(
        type: SmartInsightActionType.openOutputManager,
        label: '打开输出文件管家',
        targetPath: path,
      ),
      SmartInsightAction(
        type: SmartInsightActionType.copyText,
        label: '复制路径',
        targetPath: path,
        payload: <String, Object?>{'text': path},
      ),
    ];
  }

  SmartInsight _insight({
    required SmartInsightType type,
    required String rule,
    required String sourceKind,
    required String sourceId,
    required String title,
    required String summary,
    required String reason,
    required SmartInsightPriority priority,
    DateTime? dueAt,
    List<String> tags = const <String>[],
    List<SmartInsightAction> actions = const <SmartInsightAction>[],
  }) {
    return SmartInsight(
      id: 'smart:${type.id}:$rule:${_stableHash('$sourceKind|$sourceId')}',
      type: type,
      title: title,
      summary: summary,
      reason: reason,
      sourceKind: sourceKind,
      sourceId: sourceId,
      priority: priority,
      actions: <SmartInsightAction>[
        ...actions,
        const SmartInsightAction(
          type: SmartInsightActionType.markDone,
          label: '标记完成',
        ),
        const SmartInsightAction(
          type: SmartInsightActionType.ignore,
          label: '忽略',
        ),
      ],
      createdAt: _clock(),
      dueAt: dueAt,
      tags: tags.toSet().toList()..sort(),
    );
  }

  List<SmartInsight> _sortInsights(List<SmartInsight> insights) {
    return insights..sort((a, b) {
      final priority = b.priority.rank.compareTo(a.priority.rank);
      if (priority != 0) return priority;
      final aDue = a.dueAt;
      final bDue = b.dueAt;
      if (aDue != null && bDue != null) {
        final due = aDue.compareTo(bDue);
        if (due != 0) return due;
      } else if (aDue != null) {
        return -1;
      } else if (bDue != null) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  String _stableHash(String value) {
    return sha1.convert(utf8.encode(value)).toString().substring(0, 16);
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}
