import 'package:flutter/material.dart';
import '../api/ketangpai_attendance_api.dart';
import '../models/course.dart';

/// 课堂派考勤统计页面
class KetangpaiAttendanceStatsPage extends StatefulWidget {
  final Course course;

  const KetangpaiAttendanceStatsPage({
    super.key,
    required this.course,
  });

  @override
  State<KetangpaiAttendanceStatsPage> createState() =>
      _KetangpaiAttendanceStatsPageState();
}

class _KetangpaiAttendanceStatsPageState
    extends State<KetangpaiAttendanceStatsPage> {
  bool _loading = true;
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _history = [];
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loading && _hasMore) {
        _loadMoreHistory();
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    try {
      final stats = await KetangpaiAttendanceApi.getAttendanceStats(
        widget.course.courseId,
      );
      final history = await KetangpaiAttendanceApi.getAttendanceHistory(
        courseId: widget.course.courseId,
        page: 1,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _history = history;
          _currentPage = 1;
          _hasMore = history.length >= 20;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final moreHistory = await KetangpaiAttendanceApi.getAttendanceHistory(
        courseId: widget.course.courseId,
        page: nextPage,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          _history.addAll(moreHistory);
          _currentPage = nextPage;
          _hasMore = moreHistory.length >= 20;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.course.name} - 考勤详情'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading && _history.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildStatsCard(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        '签到历史',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  if (_history.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('暂无签到记录')),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index < _history.length) {
                            return _buildHistoryItem(_history[index]);
                          } else if (_hasMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          } else {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: Text('没有更多了')),
                            );
                          }
                        },
                        childCount: _history.length + (_hasMore ? 1 : 1),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '考勤统计',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '出勤',
                  _stats['attendance'] ?? 0,
                  Colors.green,
                ),
                _buildStatItem(
                  '旷课',
                  _stats['absent'] ?? 0,
                  Colors.red,
                ),
                _buildStatItem(
                  '迟到',
                  _stats['late'] ?? 0,
                  Colors.orange,
                ),
                _buildStatItem(
                  '早退',
                  _stats['leaveEarly'] ?? 0,
                  Colors.deepOrange,
                ),
                _buildStatItem(
                  '请假',
                  _stats['leave'] ?? 0,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '签到';
    final state = item['state']?.toString() ?? '';
    final createTime = item['createtime']?.toString() ?? '';
    final signTime = item['studentattence_createtime']?.toString() ?? '';

    final statusText = KetangpaiAttendanceApi.parseAttendanceStatus(state);
    final statusColor = Color(
      KetangpaiAttendanceApi.getAttendanceStatusColor(state),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: ListTile(
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发起时间: $createTime'),
            if (signTime.isNotEmpty) Text('签到时间: $signTime'),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
