import 'package:flutter/material.dart';

import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';

class TronclassAccountSelector extends StatefulWidget {
  const TronclassAccountSelector({
    super.key,
    required this.onSelectionChanged,
    this.enabled = true,
    this.title = '选择畅课签到账号',
    this.initiallyExpanded = true,
  });

  final ValueChanged<List<User>> onSelectionChanged;
  final bool enabled;
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

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _loadAccounts();
  }

  void _loadAccounts() {
    _accounts = AccountManager.getAccountsForPlatform(PlatformType.tronclass);
    _currentUserId = AccountManager.currentSessionId;

    final currentAccount = _accounts
        .where((user) => user.uid == _currentUserId)
        .cast<User?>()
        .firstOrNull;
    final defaultAccount = currentAccount ?? _accounts.firstOrNull;
    _selectedIds = defaultAccount == null ? <String>{} : {defaultAccount.uid};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSelectionChanged(_selectedUsers());
    });
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
    final next = Set<String>.from(_selectedIds);
    if (selected) {
      next.add(user.uid);
    } else {
      next.remove(user.uid);
    }
    _setSelectedIds(next);
  }

  void _selectAll() {
    _setSelectedIds(_accounts.map((user) => user.uid).toSet());
  }

  void _invertSelection() {
    _setSelectedIds(
      _accounts
          .where((user) => !_selectedIds.contains(user.uid))
          .map((user) => user.uid)
          .toSet(),
    );
  }

  void _clearSelection() {
    _setSelectedIds(<String>{});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.enabled;

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
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            _accounts.isEmpty
                ? '未找到已绑定畅课账号'
                : '已选 ${_selectedIds.length}/${_accounts.length}',
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
              Row(
                children: [
                  TextButton.icon(
                    onPressed: enabled ? _selectAll : null,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('全选'),
                  ),
                  TextButton.icon(
                    onPressed: enabled ? _invertSelection : null,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('反选'),
                  ),
                  TextButton.icon(
                    onPressed: enabled ? _clearSelection : null,
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('清空'),
                  ),
                ],
              ),
              for (final user in _accounts)
                CheckboxListTile(
                  value: _selectedIds.contains(user.uid),
                  onChanged: enabled
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
                            '当前',
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
