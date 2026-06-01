import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../session/account.dart';

class AccountsSelector extends StatefulWidget {
  final ValueChanged<List<User>> onSelectionChanged;
  final String title;
  final bool initiallyExpanded;
  final List<User>? initialSelected;

  const AccountsSelector({
    super.key,
    required this.onSelectionChanged,
    this.title = '选择参与的账号',
    this.initiallyExpanded = true,
    this.initialSelected,
  });

  @override
  State<AccountsSelector> createState() => _AccountsSelectorState();
}

class _AccountsSelectorState extends State<AccountsSelector> {
  List<User> _allAccounts = [];
  List<User> _selectedAccounts = [];
  User? _currentUser;
  bool _isLoading = true;
  late bool _isExpanded;

  bool get _hasSelectableAccounts =>
      _allAccounts.any((user) => user.uid != _currentUser?.uid);

  int get _selectableCount =>
      _allAccounts.where((user) => user.uid != _currentUser?.uid).length;

  int get _selectedSelectableCount =>
      _selectedAccounts.where((user) => user.uid != _currentUser?.uid).length;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _loadAccounts();
  }

  void _loadAccounts() {
    try {
      _allAccounts = AccountManager.getCurrentPlatformAccounts();

      if (widget.initialSelected != null) {
        _selectedAccounts = List<User>.from(widget.initialSelected!);
      } else {
        _selectedAccounts = List<User>.from(_allAccounts);
      }

      final currentUserId = AccountManager.currentSessionId;
      _currentUser = currentUserId == null
          ? null
          : AccountManager.getAccountById(currentUserId);
    } catch (e) {
      debugPrint('加载账号失败: $e');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        widget.onSelectionChanged(_selectedAccounts);
        _isLoading = false;
      });
    });
  }

  void _toggleSelectAll(bool? value) {
    final selectAll = value ?? false;
    final currentUser = _currentUser;
    final newSelected = <User>[];

    if (currentUser != null) {
      newSelected.add(currentUser);
    }

    if (selectAll) {
      for (final user in _allAccounts) {
        if (user.uid != currentUser?.uid) {
          newSelected.add(user);
        }
      }
    }

    setState(() {
      _selectedAccounts = newSelected;
      widget.onSelectionChanged(_selectedAccounts);
    });
  }

  void _toggleAccountSelection(User user, bool? value) {
    setState(() {
      if (value == true) {
        if (!_selectedAccounts.contains(user)) {
          _selectedAccounts.add(user);
        }
      } else {
        _selectedAccounts.remove(user);
      }

      widget.onSelectionChanged(_selectedAccounts);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('全选'),
              Checkbox(
                tristate: true,
                value: !_hasSelectableAccounts
                    ? false
                    : _selectedSelectableCount == _selectableCount
                    ? true
                    : _selectedSelectableCount == 0
                    ? false
                    : null,
                onChanged: _hasSelectableAccounts ? _toggleSelectAll : null,
                fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Theme.of(context).colorScheme.primary;
                  }
                  return Colors.transparent;
                }),
              ),
              Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey,
              ),
            ],
          ),
          children: [
            if (_allAccounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '没有账号',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _allAccounts.length,
                itemBuilder: (context, index) {
                  final user = _allAccounts[index];
                  final isCurrentUser = user.uid == _currentUser?.uid;
                  final isSelected = _selectedAccounts.contains(user);

                  return CheckboxListTile(
                    title: Row(
                      children: [
                        Text(user.name),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    value: isSelected,
                    onChanged: isCurrentUser
                        ? null
                        : (value) => _toggleAccountSelection(user, value),
                    enabled: !isCurrentUser,
                    checkColor: isCurrentUser ? Colors.white : null,
                    activeColor: Theme.of(context).colorScheme.primary,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
