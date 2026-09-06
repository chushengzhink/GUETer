import '../session/sign_execution_context.dart';
import 'account_context_header.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/sign_mode_settings.dart';

class TronclassAccountSelector extends StatefulWidget {
  const TronclassAccountSelector({
    super.key,
    required this.onSelectionChanged,
    this.enabled = true,
    this.identity,
    this.title = '选择畅课签到账号',
    this.initiallyExpanded = true,
  });

  final ValueChanged<List<User>> onSelectionChanged;
  final bool enabled;
  final SignExecutionContext? identity;
  final String title;
  final bool initiallyExpanded;

  @override
  State<TronclassAccountSelector> createState() =>
      _TronclassAccountSelectorState();
}

class _TronclassAccountSelectorState extends State<TronclassAccountSelector> {
  late bool _isExpanded;
  List<User> _accounts = <User>[];
  Set<String> _selectedIds = <String>{};
  String? _currentUserId;
  SignAccountMode _mode = SignAccountMode.perRunSelection;
  String? _lockedMessage;

  bool get _isLockedMode => _mode != SignAccountMode.perRunSelection;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    _accounts = AccountManager.getAccountsForPlatform(PlatformType.tronclass);
    _currentUserId =
        widget.identity?.account?.uid ?? AccountManager.currentSessionId;
    _mode = await SignModeSettings.getMode(PlatformType.tronclass);

    final currentAccount = _accounts
        .where((user) => user.uid == _currentUserId)
        .cast<User?>()
        .firstOrNull;
    if (_mode == SignAccountMode.manualCurrent) {
      _selectedIds = currentAccount == null ? <String>{} : {currentAccount.uid};
      _lockedMessage = currentAccount == null
          ? '模式一：请先在账号页切换到当前畅课账号'
          : '模式一：仅使用当前畅课账号签到';
    } else if (_mode == SignAccountMode.savedPlatformSelection) {
      _selectedIds = await SignModeSettings.getSelectedAccountIds(
        PlatformType.tronclass,
      );
      _lockedMessage = _selectedIds.isEmpty
          ? '模式二：暂无签到账号，请到账号页勾选下方账号后保存'
          : '模式二：使用账号页保存的畅课签到账号';
    } else {
      final defaultAccount = currentAccount ?? _accounts.firstOrNull;
      _selectedIds = defaultAccount == null ? <String>{} : {defaultAccount.uid};
      _lockedMessage = null;
    }

    if (!mounted) return;
    setState(() {});
    widget.onSelectionChanged(_selectedUsers());
  }

  List<User> _selectedUsers() {
    return _accounts
        .where((user) => _selectedIds.contains(user.uid))
        .toList(growable: false);
  }

  void _notify() {
    widget.onSelectionChanged(_selectedUsers());
  }

  void _setSelectedIds(Set<String> ids) {
    setState(() {
      _selectedIds = ids;
    });
    _notify();
  }

  void _toggleUser(User user, bool selected) {
    if (_isLockedMode) return;
    final next = Set<String>.from(_selectedIds);
    if (selected) {
      next.add(user.uid);
    } else {
      next.remove(user.uid);
    }
    _setSelectedIds(next);
  }

  void _selectAll() {
    if (_isLockedMode) return;
    _setSelectedIds(_accounts.map((user) => user.uid).toSet());
  }

  void _invertSelection() {
    if (_isLockedMode) return;
    _setSelectedIds(
      _accounts
          .where((user) => !_selectedIds.contains(user.uid))
          .map((user) => user.uid)
          .toSet(),
    );
  }

  void _clearSelection() {
    if (_isLockedMode) return;
    _setSelectedIds(<String>{});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.enabled;
    final en = Localizations.localeOf(context).languageCode == 'en';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          title: Text(
            en && widget.title == '选择畅课签到账号'
                ? 'Check-in accounts'
                : widget.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            en
                ? '${_selectedIds.length} / ${_accounts.length} accounts · ${_isLockedMode ? (_mode == SignAccountMode.manualCurrent ? "Current account" : "Saved selection") : "Choose for this check-in"}'
                : _lockedMessage ??
                      (_accounts.isEmpty
                          ? '未找到已绑定畅课账号'
                          : '已选 ${_selectedIds.length}/${_accounts.length}'),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [
            if (_accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('请先在账号页绑定畅课账号'),
                ),
              )
            else ...[
              if (!_isLockedMode)
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: enabled && !_isLockedMode ? _selectAll : null,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: Text(contextText(context, '全选', 'All')),
                    ),
                    TextButton.icon(
                      onPressed: enabled && !_isLockedMode
                          ? _invertSelection
                          : null,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(contextText(context, '反选', 'Invert')),
                    ),
                    TextButton.icon(
                      onPressed: enabled && !_isLockedMode
                          ? _clearSelection
                          : null,
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: Text(contextText(context, '清空', 'Clear')),
                    ),
                  ],
                ),
              for (final user in _accounts)
                CheckboxListTile(
                  value: _selectedIds.contains(user.uid),
                  onChanged: enabled && !_isLockedMode
                      ? (value) => _toggleUser(user, value == true)
                      : null,
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(user.name, overflow: TextOverflow.ellipsis),
                      ),
                      if (user.uid == _currentUserId) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            contextText(context, '当前', 'Current'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    user.studentId?.trim().isNotEmpty == true
                        ? '学号 ${user.studentId}'
                        : user.uid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
