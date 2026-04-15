import 'package:flutter/material.dart';

import '../api/kt_sign.dart';
import '../models/user.dart';
import '../session/account.dart';
import 'widget/scan.dart';

class KetangpaiSharedRoomPage extends StatefulWidget {
  const KetangpaiSharedRoomPage({super.key});

  @override
  State<KetangpaiSharedRoomPage> createState() => _KetangpaiSharedRoomPageState();
}

class _KetangpaiSharedRoomPageState extends State<KetangpaiSharedRoomPage> {
  final List<User> _users = <User>[];
  final Set<String> _selectedUserIds = <String>{};
  bool _loading = true;
  bool _signing = false;
  String _lastScanText = '扫码结果';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
    });

    final users = AccountManager.getAllAccounts()
        .where((user) => user.isKetangpai)
        .toList();

    if (!mounted) return;
    setState(() {
      _users
        ..clear()
        ..addAll(users);
      _selectedUserIds
        ..clear()
        ..addAll(users.map((user) => user.uid));
      _loading = false;
    });
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

  void _selectAll() {
    setState(() {
      _selectedUserIds
        ..clear()
        ..addAll(_users.map((user) => user.uid));
    });
  }

  Future<String?> _scanQrCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (result == null || result.isEmpty) {
      return null;
    }
    return result;
  }

  Future<void> _scanAndSignAll() async {
    if (_loading || _signing) return;

    if (_selectedUserIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择至少一个课堂派账号')),
      );
      return;
    }

    final qr = await _scanQrCode();
    if (qr == null) {
      return;
    }

    setState(() {
      _lastScanText = qr;
      _signing = true;
    });

    final selectedUsers = _users
        .where((user) => _selectedUserIds.contains(user.uid))
        .toList();

    int success = 0;
    final failed = <String>[];

    for (final user in selectedUsers) {
      if (user.token.isEmpty) {
        failed.add('${user.name} (token为空)');
        continue;
      }

      final ok = await KTSignApi.scanToSign(qr, user.token);
      if (ok) {
        success++;
      } else {
        failed.add('${user.name} (签到失败)');
      }
    }

    if (!mounted) return;
    setState(() {
      _signing = false;
    });

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(success == selectedUsers.length ? '全部签到成功' : '部分失败'),
        content: SingleChildScrollView(
          child: Text(
            '成功: $success/${selectedUsers.length}\n\n${failed.isEmpty ? '没有失败账号' : '失败账号:\n${failed.join('\n')}'}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(User user) {
    final isSelected = _selectedUserIds.contains(user.uid);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (_) => _toggleSelection(user.uid),
        title: Text(user.name),
        subtitle: Text(user.phone),
        secondary: CircleAvatar(
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Text(user.name.isNotEmpty ? user.name.substring(0, 1) : '课'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共享签到房间'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RefreshIndicator(
          onRefresh: _loadUsers,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '扫一次码，全部账号一起签到',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '已绑定课堂派账号：${_users.length} 个',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _signing ? null : _scanAndSignAll,
                                  icon: const Icon(Icons.qr_code_scanner_outlined),
                                  label: Text(_signing ? '签到中...' : '点击扫码'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: _selectAll,
                                child: const Text('全选'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '本地签到用户：',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_users.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('还没有绑定课堂派账号')),
                      )
                    else
                      ..._users.map(_buildUserTile),
                    const SizedBox(height: 12),
                    SelectableText('最近扫码内容：$_lastScanText'),
                  ],
                ),
        ),
      ),
    );
  }
}
