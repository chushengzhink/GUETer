import 'package:flutter/material.dart';

import '../api/kt_follow_sign.dart';
import '../api/login.dart';
import '../models/user.dart';
import '../platform.dart';
import '../services/sign_platform_context.dart';
import '../services/sign_run_console.dart';
import '../session/account.dart';
import '../widgets/sign_run_console_panel.dart';
import 'widget/scan.dart';

/// 共享房间签到页面
/// 功能说明：扫描一次二维码，为所有选中的课堂派账号批量签到
/// 适用场景：用户有多个课堂派账号需要同时签到时使用
class KetangpaiSharedRoomPage extends StatefulWidget {
  const KetangpaiSharedRoomPage({super.key});

  @override
  State<KetangpaiSharedRoomPage> createState() =>
      _KetangpaiSharedRoomPageState();
}

class _KetangpaiSharedRoomPageState extends State<KetangpaiSharedRoomPage> {
  final List<User> _users = <User>[];
  final Set<String> _selectedUserIds = <String>{};
  final Map<String, bool> _tokenHealth = <String, bool>{};
  final SignRunConsoleController _consoleController = SignRunConsoleController(
    platformContext: SignPlatformContext.ketangpai,
  );
  bool _loading = true;
  bool _signing = false;
  String _lastScanText = '扫码结果';

  @override
  void dispose() {
    _consoleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
    });

    final users = AccountManager.getAccountsForPlatform(PlatformType.ketangpai);

    final tokenHealth = <String, bool>{};
    for (final user in users) {
      final token = user.token.trim();
      tokenHealth[user.uid] = token.isNotEmpty
          ? await KTLoginApi.checkTokenStatus(token)
          : false;
    }

    if (!mounted) return;
    _consoleController.resetForPlatform(SignPlatformContext.ketangpai);
    setState(() {
      _users
        ..clear()
        ..addAll(users);
      _selectedUserIds
        ..clear()
        ..addAll(users.map((user) => user.uid));
      _tokenHealth
        ..clear()
        ..addAll(tokenHealth);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择至少一个课堂派账号')));
      return;
    }

    final qr = await _scanQrCode();
    if (qr == null) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _lastScanText = qr;
      _signing = true;
    });

    final selectedUsers = _users
        .where((user) => _selectedUserIds.contains(user.uid))
        .toList();

    final result = await KtFollowSignExecutor.signByScan(
      scanUrl: qr,
      users: selectedUsers,
      courseName: '课堂派共享房间扫码签到',
      tokenHealthHint: _tokenHealth,
      context: context,
      console: _consoleController,
      isContextMounted: () => mounted,
    );

    if (!mounted) return;
    setState(() {
      _signing = false;
    });

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.successCount == result.totalCount ? '全部签到成功' : '部分失败',
        ),
        content: SingleChildScrollView(
          child: Text(
            '成功: ${result.successCount}/${result.totalCount}\n\n${result.failedAccounts.isEmpty ? '没有失败账号' : '失败账号:\n${result.failedAccounts.join('\n')}'}',
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
    final tokenValid = _tokenHealth[user.uid] ?? false;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (_) => _toggleSelection(user.uid),
        title: Text(user.name),
        subtitle: Text(tokenValid ? user.phone : '${user.phone}（token失效）'),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '扫一次码，全部账号一起签到',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
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
                                  icon: const Icon(
                                    Icons.qr_code_scanner_outlined,
                                  ),
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
                    SignRunConsolePanel(controller: _consoleController),
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
