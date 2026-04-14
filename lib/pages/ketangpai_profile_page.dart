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
    return ListTile(
      title: Text(label),
      trailing: Text(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = _currentAccount;
    if (account == null) {
      return const Center(
        child: Text('暂无当前课堂派账号', style: TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: MediaQuery.of(context).size.height / 4,
            width: double.infinity,
            color: Colors.blue[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AvatarWidget(imageUrl: account.avatar, size: 96, borderRadius: 48, iconSize: 40),
                const SizedBox(height: 16),
                Text(account.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(account.isKetangpai ? '课堂派' : account.platform, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _line('姓名', account.name),
          _line('账号ID', account.uid),
          _line('电话', account.phone),
          _line('学校', account.school),
          _line('Token状态', account.token.isNotEmpty ? '已登录' : '未登录'),
        ],
      ),
    );
  }
}
