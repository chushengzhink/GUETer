import 'package:flutter/material.dart';

import '../models/user.dart';
import '../session/account.dart';
import 'widget/avatar.dart';

class KetangpaiProfilePage extends StatelessWidget {
  const KetangpaiProfilePage({super.key});

  User? get _currentAccount {
    final currentId = AccountManager.currentSessionId;
    if (currentId == null || currentId.isEmpty) {
      return null;
    }
    return AccountManager.getAccountById(currentId);
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = _currentAccount;
    if (account == null) {
      return const Center(
        child: Text(
          '暂无当前课堂派账号',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height / 4,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[300]!, Colors.blue[200]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AvatarWidget(
                  imageUrl: account.avatar,
                  size: 96,
                  borderRadius: 48,
                  iconSize: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  account.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '课堂派',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _line('姓名', account.name),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _line('账号ID', account.uid),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _line('电话', account.phone),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _line('学校', account.school),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _line('登录状态', account.token.isNotEmpty ? '已登录' : '未登录'),
        ],
      ),
    );
  }
}
