import 'package:flutter/material.dart';

import '../api/course.dart';
import '../api/kt_follow_sign.dart';
import '../api/login.dart';
import '../models/course.dart';
import '../models/user.dart';
import '../session/account.dart';
import 'ketangpai_add_user_page.dart';
import 'ketangpai_number_sign_page.dart';
import 'widget/scan.dart';

/// 本地签到页面
/// 功能说明：针对正在进行的签到任务，支持多种签到方式（二维码、GPS、数字）
/// 与共享房间的区别：本地签到需要先检测到课程有签到任务，然后根据签到类型选择对应方式完成签到
class KetangpaiPrivateSignPage extends StatefulWidget {
  const KetangpaiPrivateSignPage({super.key});

  @override
  State<KetangpaiPrivateSignPage> createState() =>
      _KetangpaiPrivateSignPageState();
}

class _SigningCourseEntry {
  _SigningCourseEntry({
    required this.course,
    required this.signId,
    required this.signType,
  });

  final Course course;
  final String signId;
  final int signType;
}

class _KetangpaiPrivateSignPageState extends State<KetangpaiPrivateSignPage> {
  final List<User> _users = [];
  final List<_SigningCourseEntry> _signingCourses = [];
  final Set<String> _selectedUserIds = <String>{};
  final Map<String, bool> _tokenHealth = <String, bool>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<User> get _ketangpaiUsers => AccountManager.getAllAccounts()
      .where((user) => user.isKetangpai)
      .toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    final users = _ketangpaiUsers;
    final courses = await KTCourseApi.getSigningCourses();
    final entries = <_SigningCourseEntry>[];
    for (final course in courses) {
      final signs = await KTCourseApi.getNotFinishSign(course.courseId);
      if (signs.isNotEmpty) {
        final sign = signs.first;
        entries.add(
          _SigningCourseEntry(
            course: course,
            signId: sign['id']?.toString() ?? '',
            signType: int.tryParse(sign['type']?.toString() ?? '') ?? 0,
          ),
        );
      }
    }

    if (!mounted) return;
    final defaultSelection = users.map((user) => user.uid).toSet();
    final tokenHealth = await _buildTokenHealthMap(users);
    if (!mounted) return;
    setState(() {
      _users
        ..clear()
        ..addAll(users);
      _signingCourses
        ..clear()
        ..addAll(entries);
      _selectedUserIds
        ..clear()
        ..addAll(defaultSelection);
      _tokenHealth
        ..clear()
        ..addAll(tokenHealth);
      _loading = false;
    });
  }

  Future<Map<String, bool>> _buildTokenHealthMap(List<User> users) async {
    final result = <String, bool>{};
    for (final user in users) {
      final token = user.token.trim();
      if (token.isEmpty) {
        result[user.uid] = false;
        continue;
      }
      result[user.uid] = await KTLoginApi.checkTokenStatus(token);
    }
    return result;
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedUserIds.contains(uid)) {
        _selectedUserIds.remove(uid);
      } else {
        _selectedUserIds.add(uid);
      }
    });
  }

  void _selectAllPeople() {
    setState(() {
      _selectedUserIds
        ..clear()
        ..addAll(_users.map((user) => user.uid));
    });
  }

  Future<void> _openAddUserPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KetangpaiAddUserPage()),
    );
    await _load();
  }

  Future<void> _signSelectedByScan(String url) async {
    if (_selectedUserIds.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先选择至少一个账号')));
      }
      return;
    }

    final selectedUsers = _users
        .where((user) => _selectedUserIds.contains(user.uid))
        .toList();
    final result = await KtFollowSignExecutor.signByScan(
      scanUrl: url,
      users: selectedUsers,
      courseName: '课堂派扫码签到',
      tokenHealthHint: _tokenHealth,
    );

    if (!mounted) return;
    _showBatchSignResult(
      title: '扫码签到结果',
      successCount: result.successCount,
      totalCount: result.totalCount,
      failedAccounts: result.failedAccounts,
    );
  }

  void _showBatchSignResult({
    required String title,
    required int successCount,
    required int totalCount,
    required List<String> failedAccounts,
  }) {
    var content = '成功: $successCount/$totalCount';
    if (failedAccounts.isNotEmpty) {
      content += '\n\n失败账号:\n${failedAccounts.join('\n')}';
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _signSelectedByNumber(
    String code,
    String signId,
    String courseName,
  ) async {
    if (_selectedUserIds.isEmpty) {
      return;
    }
    final selectedUsers = _users
        .where((user) => _selectedUserIds.contains(user.uid))
        .toList();
    final result = await KtFollowSignExecutor.signByNumber(
      code: code,
      signId: signId,
      users: selectedUsers,
      courseName: courseName,
      tokenHealthHint: _tokenHealth,
    );
    if (!mounted) return;
    _showBatchSignResult(
      title: '数字签到结果',
      successCount: result.successCount,
      totalCount: result.totalCount,
      failedAccounts: result.failedAccounts,
    );
  }

  Future<void> _signSelectedByGps(String signId, String courseName) async {
    if (_selectedUserIds.isEmpty) {
      return;
    }
    final selectedUsers = _users
        .where((user) => _selectedUserIds.contains(user.uid))
        .toList();
    final result = await KtFollowSignExecutor.signByGps(
      signId: signId,
      users: selectedUsers,
      courseName: courseName,
      tokenHealthHint: _tokenHealth,
    );
    if (!mounted) return;
    _showBatchSignResult(
      title: 'GPS签到结果',
      successCount: result.successCount,
      totalCount: result.totalCount,
      failedAccounts: result.failedAccounts,
    );
  }

  Future<void> _signSelectedByCheckInOut(String signId, String courseName) async {
    if (_selectedUserIds.isEmpty) {
      return;
    }
    final selectedUsers = _users
        .where((user) => _selectedUserIds.contains(user.uid))
        .toList();
    final result = await KtFollowSignExecutor.signByCheckInOut(
      signId: signId,
      users: selectedUsers,
      courseName: courseName,
      tokenHealthHint: _tokenHealth,
    );
    if (!mounted) return;
    _showBatchSignResult(
      title: '签入签出结果',
      successCount: result.successCount,
      totalCount: result.totalCount,
      failedAccounts: result.failedAccounts,
    );
  }

  Future<void> _handleRoomScanSign() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (result == null || result.isEmpty) {
      return;
    }
    await _signSelectedByScan(result);
  }

  Future<void> _handleCourseSign(_SigningCourseEntry entry) async {
    if (entry.signType == 1) {
      final code = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const KetangpaiNumberSignPage()),
      );
      if (code != null && code.isNotEmpty) {
        await _signSelectedByNumber(code, entry.signId, entry.course.name);
      }
    } else if (entry.signType == 2) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('GPS签到'),
          content: const Text('点击即可签到，无需担心，老师不会发现你溜了'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _signSelectedByGps(entry.signId, entry.course.name);
      }
    } else if (entry.signType == 3) {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const ScanPage()),
      );
      if (result != null && result.isNotEmpty) {
        await _signSelectedByScan(result);
      }
    } else if (entry.signType == 4) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('签入签出'),
          content: const Text('确认进行签入签出操作？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _signSelectedByCheckInOut(entry.signId, entry.course.name);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteUser(User user) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('确认删除此用户吗'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await AccountManager.removeAccounts([user.uid]);
      await _load();
    }
  }

  Widget _buildUserTile(User user) {
    final isSelected = _selectedUserIds.contains(user.uid);
    final tokenValid = _tokenHealth[user.uid] ?? false;
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      title: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) {
              _toggleSelection(user.uid);
            },
          ),
          const SizedBox(width: 8),
          Text(
            user.name,
            style: TextStyle(color: scheme.onSurface, fontSize: 18),
          ),
          const SizedBox(width: 8),
          if (!tokenValid) const Icon(Icons.error_outlined, color: Colors.red),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ListTile(title: const Text('电话号码'), trailing: Text(user.phone)),
              ListTile(
                title: const Text('账号状态是否过期'),
                trailing: Text(
                  tokenValid ? 'false' : 'true',
                  style: TextStyle(
                    color: tokenValid ? scheme.primary : scheme.error,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openAddUserPage,
                      icon: const Icon(
                        Icons.update_outlined,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                      ),
                      label: const Text('更新用户'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteUser(user),
                      icon: const Icon(
                        Icons.delete_forever_outlined,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      label: const Text('删除用户'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSigningCourse(_SigningCourseEntry entry) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(entry.course.name),
      subtitle: Text(entry.course.teacher),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
        onPressed: () => _handleCourseSign(entry),
        child: Text(_signWayLabel(entry.signType)),
      ),
    );
  }

  String _signWayLabel(int type) {
    switch (type) {
      case 1:
        return '数字签到';
      case 2:
        return 'GPS签到';
      case 3:
        return '扫码签到';
      case 4:
        return '签入签出';
      default:
        return '未知类型';
    }
  }

  Future<void> _showSignWayDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('选择签到方式'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(1),
              child: const Text('扫码签到'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(2),
              child: const Text('数字签到'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(3),
              child: const Text('GPS签到'),
            ),
          ],
        );
      },
    );

    if (result == 1) {
      await _handleRoomScanSign();
    } else if (result == 2) {
      final entry = _signingCourses.isNotEmpty ? _signingCourses.first : null;
      if (entry != null) {
        await _handleCourseSign(entry);
      }
    } else if (result == 3) {
      final entry = _signingCourses.isNotEmpty ? _signingCourses.first : null;
      if (entry != null) {
        await _handleCourseSign(entry);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: _openAddUserPage,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                          onPressed: _showSignWayDialog,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner_outlined),
                              SizedBox(width: 8),
                              Text('扫码签到'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    const SliverToBoxAdapter(
                      child: Text(
                        '正在签到课程：',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 5)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        childCount: _signingCourses.length,
                        (context, index) =>
                            _buildSigningCourse(_signingCourses[index]),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '本地签到用户：',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: _selectAllPeople,
                            child: const Text('全选'),
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 5)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        childCount: _users.length,
                        (context, index) => _buildUserTile(_users[index]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
