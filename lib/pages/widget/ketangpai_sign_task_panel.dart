import 'package:flutter/material.dart';

import '../../api/course.dart';
import '../../models/course.dart';
import '../../models/ketangpai_sign.dart';
import '../ketangpai_gps_sign_dialog.dart';
import '../ketangpai_number_sign_page.dart';
import '../ketangpai_private_sign_page.dart';
import '../ketangpai_scan_sign_page.dart';

typedef KetangpaiSignTaskLoader =
    Future<List<dynamic>> Function(String courseId);
typedef KetangpaiSignTaskAction =
    Future<void> Function(BuildContext context, KetangpaiSignTask task);

class KetangpaiSignTaskPanel extends StatefulWidget {
  const KetangpaiSignTaskPanel({
    super.key,
    this.course,
    required this.courseId,
    this.courseName,
    this.initialTasks,
    this.taskLoader,
    this.taskAction,
    this.showBatchEntry = true,
    this.compact = false,
  });

  final Course? course;
  final String courseId;
  final String? courseName;
  final List<dynamic>? initialTasks;
  final KetangpaiSignTaskLoader? taskLoader;
  final KetangpaiSignTaskAction? taskAction;
  final bool showBatchEntry;
  final bool compact;

  @override
  State<KetangpaiSignTaskPanel> createState() => _KetangpaiSignTaskPanelState();
}

class _KetangpaiSignTaskPanelState extends State<KetangpaiSignTaskPanel> {
  bool _loading = true;
  String? _error;
  List<KetangpaiSignTask> _tasks = const <KetangpaiSignTask>[];

  @override
  void initState() {
    super.initState();
    if (widget.initialTasks != null) {
      _tasks = _normalize(widget.initialTasks!);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant KetangpaiSignTaskPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId ||
        oldWidget.initialTasks != widget.initialTasks) {
      if (widget.initialTasks != null) {
        setState(() {
          _tasks = _normalize(widget.initialTasks!);
          _loading = false;
          _error = null;
        });
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    if (widget.taskLoader == null && widget.initialTasks != null) {
      setState(() {
        _tasks = _normalize(widget.initialTasks!);
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.taskLoader ?? KTCourseApi.getNotFinishSign;
      final data = await loader(widget.courseId);
      if (!mounted) return;
      setState(() {
        _tasks = _normalize(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tasks = const <KetangpaiSignTask>[];
        _error = '签到任务加载失败: $e';
        _loading = false;
      });
    }
  }

  List<KetangpaiSignTask> _normalize(List<dynamic> data) {
    return data
        .whereType<Map>()
        .map((item) {
          final map = item.map((key, value) => MapEntry(key.toString(), value));
          if ((map['courseid'] ?? map['courseId']) == null) {
            map['courseid'] = widget.courseId;
          }
          return KetangpaiSignTask.fromJson(map);
        })
        .where((task) => task.id.trim().isNotEmpty)
        .toList();
  }

  String _courseName() {
    final explicit = widget.courseName?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final course = widget.course;
    if (course != null && course.name.trim().isNotEmpty) return course.name;
    return '课堂派签到';
  }

  String _typeLabel(int type) {
    switch (type) {
      case 1:
        return '数字签到';
      case 2:
        return 'GPS 签到';
      case 3:
        return '扫码签到';
      default:
        return '暂不支持';
    }
  }

  IconData _typeIcon(int type) {
    switch (type) {
      case 1:
        return Icons.pin_outlined;
      case 2:
        return Icons.gps_fixed_outlined;
      case 3:
        return Icons.qr_code_scanner_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _typeColor(BuildContext context, int type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      case 3:
        return scheme.primary;
      default:
        return scheme.outline;
    }
  }

  Future<void> _handleTask(KetangpaiSignTask task) async {
    if (task.type < 1 || task.type > 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('暂不支持的课堂派签到类型: ${task.type}')));
      return;
    }

    final customAction = widget.taskAction;
    if (customAction != null) {
      await customAction(context, task);
      if (mounted) {
        await _load();
      }
      return;
    }

    switch (task.type) {
      case 1:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                KetangpaiNumberSignPage(signId: task.id, directSubmit: true),
          ),
        );
        break;
      case 2:
        await KetangpaiGpsSignDialog.show(
          context,
          signId: task.id,
          directSubmit: true,
        );
        break;
      case 3:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                KetangpaiScanSignPage(signId: task.id, directSubmit: true),
          ),
        );
        break;
    }
    if (mounted) {
      await _load();
    }
  }

  void _openBatchPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const KetangpaiPrivateSignPage()));
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.how_to_reg_outlined, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前签到任务',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _tasks.isEmpty ? '老师发起签到后会显示在这里' : '点击任务即可进入对应签到流程',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '刷新签到任务',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_outlined),
        ),
      ],
    );
  }

  Widget _buildTaskTile(KetangpaiSignTask task) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _typeColor(context, task.type);
    final timeText = [
      task.startTime,
      task.endTime,
    ].where((item) => item.trim().isNotEmpty).join(' - ');
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey<String>('ketangpai-sign-task-${task.type}-${task.id}'),
        onTap: task.type >= 1 && task.type <= 3
            ? () => _handleTask(task)
            : () => _handleTask(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_typeIcon(task.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _typeLabel(task.type),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'ID ${task.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (timeText.isNotEmpty)
                          Text(
                            timeText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: task.type >= 1 && task.type <= 3
                    ? () => _handleTask(task)
                    : null,
                icon: Icon(_typeIcon(task.type), size: 18),
                label: Text(_typeLabel(task.type)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, color: scheme.outline),
          const SizedBox(height: 8),
          Text('暂无进行中的签到', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '下拉刷新或点击右上角刷新按钮重新同步。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: widget.compact ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              )
            else if (_tasks.isEmpty)
              _buildEmpty(context)
            else
              Column(
                children: [
                  for (var index = 0; index < _tasks.length; index++) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _buildTaskTile(_tasks[index]),
                  ],
                ],
              ),
            if (widget.showBatchEntry) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openBatchPage,
                  icon: const Icon(Icons.groups_2_outlined),
                  label: Text('多账号批量签到 - ${_courseName()}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
