import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/course.dart';
import 'tronclass_todo_detail_page.dart';

class TronclassTodosPage extends StatefulWidget {
  const TronclassTodosPage({super.key});

  @override
  State<TronclassTodosPage> createState() => _TronclassTodosPageState();
}

class _TronclassTodosPageState extends State<TronclassTodosPage> {
  List<Map<String, dynamic>> _todos = [];
  bool _loading = true;
  bool _hasError = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final todos = await TCCourseApi.getTodos();
      if (!mounted) return;
      setState(() {
        _todos = todos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredTodos {
    if (_filter == 'all') return _todos;
    return _todos.where((t) => t['type'] == _filter).toList();
  }

  int _countByType(String type) {
    return _todos.where((t) => t['type'] == type).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('畅课待办事项', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1DB6C2),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodos,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在获取信息中...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: _filteredTodos.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadTodos,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredTodos.length,
                            itemBuilder: (context, index) {
                              return _buildTodoCard(_filteredTodos[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('全部', 'all', _todos.length),
            const SizedBox(width: 8),
            _buildFilterChip('作业', 'homework', _countByType('homework')),
            const SizedBox(width: 8),
            _buildFilterChip('考试', 'exam', _countByType('exam')),
            const SizedBox(width: 8),
            _buildFilterChip('问卷', 'questionnaire', _countByType('questionnaire')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterValue, int count) {
    final selected = _filter == filterValue;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (bool isSelected) {
        setState(() => _filter = isSelected ? filterValue : 'all');
      },
      selectedColor: const Color(0xFF1DB6C2).withValues(alpha: 0.2),
      checkmarkColor: const Color(0xFF1DB6C2),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hasError ? Icons.error_outline : Icons.task_alt,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _hasError ? '获取待办失败' : '暂无待办事项',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _hasError ? '请检查网络或登录状态' : '所有任务都已完成',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(Map<String, dynamic> todo) {
    final type = todo['type']?.toString() ?? '';
    final title = todo['title']?.toString() ?? '未知任务';
    final courseName = todo['course_name']?.toString() ?? '';
    final endTimeStr = todo['end_time']?.toString() ?? '';
    final isLocked = todo['is_locked'] == true;

    DateTime? endTime;
    if (endTimeStr.isNotEmpty) {
      try {
        endTime = DateTime.parse(endTimeStr);
      } catch (_) {}
    }

    final now = DateTime.now();
    final isOverdue = endTime != null && endTime.isBefore(now);
    final isUrgent = endTime != null && endTime.difference(now).inHours < 24;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLocked ? null : () => _showTodoDetail(todo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTypeIcon(type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          courseName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLocked)
                    Icon(Icons.lock, size: 20, color: Colors.grey[400]),
                ],
              ),
              if (endTime != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isOverdue
                          ? Colors.red
                          : isUrgent
                              ? Colors.orange
                              : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '截止时间: ${DateFormat('yyyy-MM-dd HH:mm').format(endTime.toLocal())}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isOverdue
                            ? Colors.red
                            : isUrgent
                                ? Colors.orange
                                : Colors.grey[600],
                      ),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '已逾期',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ] else if (isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '紧急',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'homework':
        icon = Icons.assignment;
        color = const Color(0xFF1DB6C2);
        break;
      case 'exam':
        icon = Icons.quiz;
        color = Colors.orange;
        break;
      case 'questionnaire':
        icon = Icons.poll;
        color = Colors.purple;
        break;
      default:
        icon = Icons.task;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  void _showTodoDetail(Map<String, dynamic> todo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TronclassTodoDetailPage(todo: todo),
      ),
    ).then((result) {
      if (result == true) {
        _loadTodos();
      }
    });
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'homework':
        return '作业';
      case 'exam':
        return '考试';
      case 'questionnaire':
        return '问卷';
      default:
        return '未知';
    }
  }
}
