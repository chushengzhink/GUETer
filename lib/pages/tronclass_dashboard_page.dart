import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../api/course.dart';
import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import 'tronclass_sign_in_list_page.dart';
import 'tronclass_todo_detail_page.dart';
import 'tronclass_web_login.dart';
import 'widget/scan.dart';
import 'widget/tronclass_liquid_glass.dart';

class TronclassDashboardPage extends StatefulWidget {
  final Future<void> Function(String) onScanResult;

  const TronclassDashboardPage({super.key, required this.onScanResult});

  @override
  State<TronclassDashboardPage> createState() => _TronclassDashboardPageState();
}

class _TronclassDashboardPageState extends State<TronclassDashboardPage> {
  bool _interactionsLoading = false;
  String? _interactionsError;
  List<TronclassInteractionItem> _interactions = [];

  @override
  void initState() {
    super.initState();
    _loadInteractions();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，注意休息';
    if (hour < 12) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  User? get _currentUser {
    final id = AccountManager.currentSessionId;
    if (id == null || id.isEmpty) return null;
    return AccountManager.getAccountById(id);
  }

  bool get _hasAccount => AccountManager.hasActiveSession();

  String get _accountName {
    final user = _currentUser;
    if (user?.name.isNotEmpty == true) return user!.name;
    return '当前账号';
  }

  Future<bool> _ensureLoggedIn() async {
    if (_hasAccount) return true;
    final result = await Navigator.pushNamed(context, '/login');
    if (mounted) setState(() {});
    return result == true;
  }

  Future<void> _openPortal() async {
    if (!await _ensureLoggedIn()) return;
    if (!mounted) return;

    final currentUserId = AccountManager.currentSessionId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final currentUser = _currentUser;
    final accountName = currentUser?.name.isNotEmpty == true
        ? currentUser!.name
        : currentUserId;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassWebLoginPage(
          accountName: accountName,
          accountId: currentUserId,
          initialUrl: Uri.parse(PlatformManager().tronclassBaseUrl),
          initialMessage: '已进入畅课门户，可直接查看课程、公告和作业',
          autoCloseOnAuthSuccess: false,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openSignList() async {
    if (!await _ensureLoggedIn()) return;
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TronclassSignInListPage()),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openScan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanPage(onScanResult: widget.onScanResult),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openAccounts() async {
    await Navigator.pushNamed(context, '/accounts');
    if (mounted) {
      setState(() {});
      await _loadInteractions();
    }
  }

  Future<void> _openLogin() async {
    await Navigator.pushNamed(context, '/login');
    if (mounted) {
      setState(() {});
      await _loadInteractions();
    }
  }

  Future<void> _logout() async {
    if (!_hasAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前畅课账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AccountManager.clearCurrentSession();
      if (mounted) {
        setState(() {
          _interactions = [];
          _interactionsError = null;
        });
      }
    }
  }

  Future<void> _loadInteractions() async {
    if (!_hasAccount) {
      if (!mounted) return;
      setState(() {
        _interactions = [];
        _interactionsLoading = false;
        _interactionsError = null;
      });
      return;
    }

    setState(() {
      _interactionsLoading = true;
      _interactionsError = null;
    });

    try {
      final items = await TCCourseApi.getOngoingInteractions();
      if (!mounted) return;
      setState(() {
        _interactions = items;
        _interactionsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _interactionsError = e.toString();
        _interactionsLoading = false;
      });
    }
  }

  void _openInteraction(TronclassInteractionItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassTodoDetailPage(todo: item.toTodoMap()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: TronclassGlassBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '畅课',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: TronclassGlassPalette.text,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '课程、签到与课堂互动',
                  style: TextStyle(
                    fontSize: 13,
                    color: TronclassGlassPalette.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _DashboardHeroCard(
                  greeting: _greeting(),
                  accountName: _hasAccount ? _accountName : '尚未登录',
                  isLoggedIn: _hasAccount,
                ),
                const SizedBox(height: 18),
                _buildActionCluster(context),
                const SizedBox(height: 24),
                _buildInteractionsCard(),
                const SizedBox(height: 24),
                TronclassGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TronclassSectionHeader(
                        title: '登录状态',
                        subtitle: _hasAccount
                            ? '当前账号已就绪，可直接进入签到或网页登录。'
                            : '登录后即可进入畅课签到与门户页面。',
                        trailing: TronclassGlassPill(
                          label: _hasAccount ? '已登录' : '未登录',
                          icon: _hasAccount
                              ? Icons.verified_rounded
                              : Icons.lock_outline_rounded,
                          color: _hasAccount
                              ? TronclassGlassPalette.success
                              : TronclassGlassPalette.warning,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LoginStatusBody(
                        hasAccount: _hasAccount,
                        accountName: _accountName,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton(
                            onPressed: _openLogin,
                            style: tronclassPrimaryButtonStyle(context),
                            child: Text(_hasAccount ? '添加账号' : '去登录'),
                          ),
                          OutlinedButton(
                            onPressed: _openAccounts,
                            style: tronclassGhostButtonStyle(context),
                            child: const Text('账号管理'),
                          ),
                          if (_hasAccount)
                            OutlinedButton(
                              onPressed: _logout,
                              style: tronclassGhostButtonStyle(
                                context,
                                foregroundColor: TronclassGlassPalette.danger,
                              ),
                              child: const Text('退出当前账号'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    _hasAccount ? '当前账号：$_accountName' : '当前账号：未登录',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TronclassGlassPalette.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCluster(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DashboardActionCard(
                title: '扫码签到',
                subtitle: '进入扫码页并处理签到结果',
                assetName: 'assets/images/scan_code.svg',
                accent: TronclassGlassPalette.accent,
                onTap: _openScan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardActionCard(
                title: '签到列表',
                subtitle: '查看二维码、数字和雷达签到活动',
                assetName: 'assets/images/sign.svg',
                accent: TronclassGlassPalette.success,
                onTap: _openSignList,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DashboardCompactAction(
                title: '网页登录',
                subtitle: '打开完整畅课门户',
                icon: Icons.public_rounded,
                color: TronclassGlassPalette.accentDeep,
                onTap: _openPortal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardCompactAction(
                title: '账号管理',
                subtitle: '切换和维护会话',
                icon: Icons.manage_accounts_rounded,
                color: TronclassGlassPalette.warning,
                onTap: _openAccounts,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractionsCard() {
    return TronclassGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TronclassSectionHeader(
            title: '互动',
            subtitle: '仅展示接口仍返回进行中的课堂测试，并标记可疑旧记录',
            trailing: IconButton(
              tooltip: '刷新互动',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _interactionsLoading ? null : _loadInteractions,
            ),
          ),
          const SizedBox(height: 14),
          if (_interactionsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_interactionsError != null)
            _DashboardMessage(
              icon: Icons.error_outline_rounded,
              title: '互动加载失败',
              message: _interactionsError!,
              actionLabel: '重试',
              onAction: _loadInteractions,
            )
          else if (!_hasAccount)
            _DashboardMessage(
              icon: Icons.lock_outline_rounded,
              title: '尚未登录畅课',
              message: '登录后可查看正在进行中的课堂测试互动。',
              actionLabel: '去登录',
              onAction: _openLogin,
            )
          else if (_interactions.isEmpty)
            const _DashboardMessage(
              icon: Icons.inbox_outlined,
              title: '暂无进行中的互动',
              message: '课堂测试开始后会显示在这里。',
            )
          else
            Column(
              children: _interactions
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InteractionTile(
                        item: item,
                        onTap: () => _openInteraction(item),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _LoginStatusBody extends StatelessWidget {
  const _LoginStatusBody({required this.hasAccount, required this.accountName});

  final bool hasAccount;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
      ),
      child: Row(
        children: [
          TronclassGlassIconOrb(
            icon: hasAccount ? Icons.person_rounded : Icons.person_off_rounded,
            color: hasAccount
                ? TronclassGlassPalette.accent
                : TronclassGlassPalette.warning,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAccount ? accountName : '尚未登录畅课账号',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: TronclassGlassPalette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAccount
                      ? '账号管理、网页登录与签到页面会沿用当前会话。'
                      : '登录后可直接进入签到列表、网页门户和扫码流程。',
                  style: const TextStyle(
                    color: TronclassGlassPalette.mutedText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionTile extends StatelessWidget {
  const _InteractionTile({required this.item, required this.onTap});

  final TronclassInteractionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final startTime = _formatStartTime(item.startAt);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Row(
          children: [
            const TronclassGlassIconOrb(
              icon: Icons.quiz_rounded,
              color: TronclassGlassPalette.accent,
              size: 42,
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
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: TronclassGlassPalette.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _InteractionStatusPill(label: item.stateLabel),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TronclassGlassPalette.mutedText,
                      fontSize: 12,
                    ),
                  ),
                  if (startTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '开始时间：$startTime',
                      style: const TextStyle(
                        color: TronclassGlassPalette.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: TronclassGlassPalette.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatStartTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      return DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }
}

class _InteractionStatusPill extends StatelessWidget {
  const _InteractionStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      '已过截止时间' => TronclassGlassPalette.danger,
      '疑似旧互动' => TronclassGlassPalette.warning,
      '未设置截止' => TronclassGlassPalette.accentDeep,
      _ => TronclassGlassPalette.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: TronclassGlassPalette.mutedText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TronclassGlassPalette.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: TronclassGlassPalette.mutedText,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              style: tronclassGhostButtonStyle(context),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardHeroCard extends StatelessWidget {
  const _DashboardHeroCard({
    required this.greeting,
    required this.accountName,
    required this.isLoggedIn,
  });

  final String greeting;
  final String accountName;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return TronclassGlassCard(
      padding: const EdgeInsets.all(24),
      tintColor: const Color(0xFFF6FDFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: TronclassGlassPalette.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      accountName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: TronclassGlassPalette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              TronclassGlassPill(
                label: isLoggedIn ? '会话已连接' : '等待登录',
                icon: isLoggedIn
                    ? Icons.wifi_tethering_rounded
                    : Icons.hourglass_top_rounded,
                color: isLoggedIn
                    ? TronclassGlassPalette.success
                    : TronclassGlassPalette.warning,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '保留现有畅课 API、签到判断和导航目标，并集中展示正在进行中的课堂互动。',
            style: TextStyle(
              height: 1.6,
              color: TronclassGlassPalette.text,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.title,
    required this.subtitle,
    required this.assetName,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String assetName;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TronclassGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.26),
                    accent.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              ),
              child: Center(
                child: SvgPicture.asset(
                  assetName,
                  width: 26,
                  height: 26,
                  colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                ),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TronclassGlassPalette.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: TronclassGlassPalette.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCompactAction extends StatelessWidget {
  const _DashboardCompactAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TronclassGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          TronclassGlassIconOrb(icon: icon, color: color, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: TronclassGlassPalette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: TronclassGlassPalette.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
