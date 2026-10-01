import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/course.dart';
import '../../widgets/account_context_header.dart';

class CourseWorkspaceMemory {
  String query = '';
  double offset = 0;
  bool recentFirst = false;
  bool onlineOnly = true;
}

class CourseWorkspace extends StatefulWidget {
  const CourseWorkspace({
    super.key,
    required this.contextId,
    required this.memory,
    required this.header,
    required this.courses,
    required this.onOpen,
    required this.onRefresh,
    required this.onScan,
    required this.onOther,
    this.loading = false,
    this.refreshing = false,
    this.message,
    this.filter,
    this.enabled = true,
    this.preferenceId,
    this.failed = false,
    this.authExpired = false,
    this.signedIn = true,
    this.updatedAt,
    this.semesterLabel,
    this.onChangeSemester,
    this.onLogin,
  });
  final String contextId;
  final String? preferenceId;
  final bool failed, signedIn, authExpired;
  final DateTime? updatedAt;
  final String? semesterLabel;
  final VoidCallback? onChangeSemester, onLogin;
  final CourseWorkspaceMemory memory;
  final Widget header;
  final List<Course> courses;
  final ValueChanged<Course> onOpen;
  final Future<void> Function() onRefresh;
  final VoidCallback onScan;
  final VoidCallback onOther;
  final bool loading, refreshing, enabled;
  final String? message;
  final Widget? filter;
  @override
  State<CourseWorkspace> createState() => _CourseWorkspaceState();
}

class _CourseWorkspaceState extends State<CourseWorkspace> {
  late final TextEditingController _search;
  late final ScrollController _scroll;
  Future<void>? _refreshTask;
  bool get _busy => widget.loading || widget.refreshing || _refreshTask != null;

  Future<void> _refresh() {
    if (_refreshTask != null) return _refreshTask!;
    if (!widget.signedIn) return Future.value();
    final task = widget.onRefresh();
    setState(() {
      _refreshTask = task;
    });
    return task.whenComplete(() {
      if (mounted) setState(() => _refreshTask = null);
    });
  }

  void _clearSearch() {
    _search.clear();
    setState(() => widget.memory.query = '');
  }

  final Set<String> _pinned = {};
  final List<String> _recent = [];
  String get _key =>
      'course_workspace_preferences_v1_${widget.preferenceId ?? widget.contextId}';
  String _id(Course course) => '${course.courseId}|${course.classId}';

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.memory.query);
    _scroll = ScrollController(initialScrollOffset: widget.memory.offset);
    _scroll.addListener(() => widget.memory.offset = _scroll.offset);
    _load();
  }

  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (!mounted || raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _pinned.addAll((data['pinned'] as List? ?? []).whereType<String>());
        _recent.addAll((data['recent'] as List? ?? []).whereType<String>());
      });
    } catch (_) {
      /* Keep usable defaults for an invalid preference entry. */
    }
  }

  Future<void> _save() async {
    final key = _key;
    final data = jsonEncode({'pinned': _pinned.toList(), 'recent': _recent});
    await (await SharedPreferences.getInstance()).setString(key, data);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = widget.memory.query.toLowerCase().trim();
    final courses = widget.courses
        .where((c) => '${c.name} ${c.teacher}'.toLowerCase().contains(query))
        .toList();
    courses.sort((a, b) {
      final pinned =
          (_pinned.contains(_id(b)) ? 1 : 0) -
          (_pinned.contains(_id(a)) ? 1 : 0);
      if (pinned != 0) return pinned;
      if (widget.memory.recentFirst) {
        final ai = _recent.indexOf(_id(a)), bi = _recent.indexOf(_id(b));
        final result = (ai < 0 ? 999 : ai).compareTo(bi < 0 ? 999 : bi);
        if (result != 0) return result;
      }
      return widget.courses.indexOf(a).compareTo(widget.courses.indexOf(b));
    });
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.header,
                  if (widget.semesterLabel != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('workspace-semester'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: widget.onChangeSemester,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(widget.semesterLabel!),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('workspace-scan'),
                        onPressed: widget.enabled ? widget.onScan : null,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(
                          contextText(context, '扫码签到', 'Scan to check in'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.enabled ? widget.onOther : null,
                        icon: const Icon(Icons.tune),
                        label: Text(
                          contextText(
                            context,
                            '其他签到方式',
                            'More check-in options',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _search,
                    onChanged: (value) =>
                        setState(() => widget.memory.query = value),
                    decoration: InputDecoration(
                      hintText: contextText(
                        context,
                        '搜索课程、教师',
                        'Search courses or teachers',
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: contextText(
                                context,
                                '清空搜索',
                                'Clear search',
                              ),
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        contextText(
                          context,
                          query.isEmpty
                              ? '${widget.courses.length} 门课程'
                              : '匹配 ${courses.length} / 共 ${widget.courses.length} 门',
                          query.isEmpty
                              ? '${widget.courses.length} courses'
                              : '${courses.length} matches / ${widget.courses.length} courses',
                        ),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      FilterChip(
                        label: Text(contextText(context, '最近访问', 'Recent')),
                        selected: widget.memory.recentFirst,
                        onSelected: (value) =>
                            setState(() => widget.memory.recentFirst = value),
                      ),
                      if (widget.filter != null) widget.filter!,
                      IconButton(
                        key: const ValueKey('workspace-refresh'),
                        tooltip: contextText(
                          context,
                          '刷新课程',
                          'Refresh courses',
                        ),
                        onPressed: _busy || !widget.signedIn ? null : _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  if (_busy && widget.courses.isNotEmpty)
                    const LinearProgressIndicator(minHeight: 2),
                  if (widget.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${contextText(context, '更新于 ', 'Updated ')}${MaterialLocalizations.of(context).formatShortDate(widget.updatedAt!)} ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(widget.updatedAt!))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (widget.failed && widget.courses.isNotEmpty)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contextText(
                                context,
                                '刷新失败，已保留原有课程',
                                'Refresh failed. Previous courses retained.',
                              ),
                              style: TextStyle(color: colors.error),
                            ),
                            if (widget.message != null) Text(widget.message!),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : widget.authExpired
                                  ? widget.onLogin
                                  : _refresh,
                              child: Text(
                                contextText(
                                  context,
                                  widget.authExpired ? '重新登录' : '重试',
                                  widget.authExpired
                                      ? 'Sign in again'
                                      : 'Retry',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!widget.failed &&
                      widget.message != null &&
                      widget.courses.isNotEmpty)
                    Text(widget.message!),
                ],
              ),
            ),
          ),
          if (widget.loading && widget.courses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 12),
                    Text(contextText(context, '正在获取课程…', 'Loading courses…')),
                  ],
                ),
              ),
            )
          else if (courses.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      query.isEmpty
                          ? Icons.menu_book_outlined
                          : Icons.search_off,
                      size: 40,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        (!widget.signedIn || widget.authExpired)
                            ? contextText(context, '请先登录账号', 'Please sign in')
                            : widget.failed && widget.courses.isEmpty
                            ? contextText(
                                context,
                                '课程加载失败',
                                'Could not load courses',
                              )
                            : query.isNotEmpty
                            ? contextText(
                                context,
                                '未找到匹配课程',
                                'No matching courses',
                              )
                            : widget.semesterLabel != null
                            ? contextText(
                                context,
                                '本学期暂无课程',
                                'No courses in this semester',
                              )
                            : contextText(
                                context,
                                '暂无课程，可切换账号或下拉刷新',
                                'No courses. Switch account or pull to refresh.',
                              ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (widget.message != null &&
                        (widget.failed || !widget.enabled)) ...[
                      const SizedBox(height: 8),
                      Text(widget.message!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!widget.signedIn || widget.authExpired)
                          FilledButton(
                            onPressed: widget.onLogin,
                            child: Text(
                              contextText(
                                context,
                                '选择或登录账号',
                                'Choose an account',
                              ),
                            ),
                          )
                        else ...[
                          if (query.isNotEmpty)
                            TextButton(
                              onPressed: _clearSearch,
                              child: Text(
                                contextText(context, '清空搜索', 'Clear search'),
                              ),
                            ),
                          if (widget.onChangeSemester != null)
                            OutlinedButton(
                              onPressed: widget.onChangeSemester,
                              child: Text(
                                contextText(context, '切换学期', 'Change semester'),
                              ),
                            ),
                          if (query.isEmpty || widget.failed)
                            FilledButton(
                              onPressed: _busy ? null : _refresh,
                              child: Text(
                                contextText(
                                  context,
                                  widget.failed ? '重试' : '刷新',
                                  widget.failed ? 'Retry' : 'Refresh',
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  final course = courses[index];
                  final pinned = _pinned.contains(_id(course));
                  return Material(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(index == 0 ? 16 : 0),
                      bottom: Radius.circular(
                        index == courses.length - 1 ? 16 : 0,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            8,
                            8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.menu_book_outlined,
                              color: colors.primary,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            course.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(course.teacher),
                          trailing: IconButton(
                            tooltip: pinned
                                ? contextText(context, '取消置顶', 'Unpin course')
                                : contextText(context, '置顶课程', 'Pin course'),
                            icon: Icon(
                              pinned ? Icons.push_pin : Icons.push_pin_outlined,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                pinned
                                    ? _pinned.remove(_id(course))
                                    : _pinned.add(_id(course));
                              });
                              _save();
                            },
                          ),
                          onTap: widget.enabled
                              ? () {
                                  _recent.remove(_id(course));
                                  _recent.insert(0, _id(course));
                                  if (_recent.length > 30) _recent.removeLast();
                                  _save();
                                  widget.onOpen(course);
                                }
                              : null,
                        ),
                        if (index < courses.length - 1)
                          const Padding(
                            padding: EdgeInsets.only(left: 72),
                            child: Divider(height: 1, thickness: .5),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
