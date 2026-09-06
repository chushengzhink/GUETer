import 'package:flutter/material.dart';
import '../widgets/account_context_header.dart';
import 'accounts.dart';
import 'settings.dart';
import 'sign_records_page.dart';
import 'user_manual_page.dart';
import 'update_announcements_page.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});
  @override
  Widget build(BuildContext context) {
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    Widget row(
      IconData icon,
      String zh,
      String en,
      String detailZh,
      String detailEn,
      Widget page,
    ) => ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(contextText(context, zh, en)),
      subtitle: Text(contextText(context, detailZh, detailEn)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => open(page),
    );
    Widget group(List<Widget> rows) => Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.only(left: 56),
                child: Divider(height: 1, thickness: .5),
              ),
            rows[i],
          ],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(contextText(context, '我的', 'Me'))),
      body: ListView(
        key: const PageStorageKey('my-page'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'GUETer',
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            contextText(context, '账号、偏好与帮助', 'Accounts, preferences & help'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          group([
            row(
              Icons.people_outline,
              '账号管理',
              'Accounts',
              '登录、会话与签到模式',
              'Sign-in, sessions and check-in mode',
              const AccountsPage(),
            ),
            row(
              Icons.receipt_long_outlined,
              '签到记录',
              'Attendance records',
              '按平台查看签到结果',
              'Review check-in results by platform',
              const SignRecordsPage(),
            ),
          ]),
          const SizedBox(height: 20),
          group([
            row(
              Icons.tune,
              '设置',
              'Settings',
              '外观、语言、导航与高级设置',
              'Appearance, language, navigation and advanced settings',
              const SettingsPage(),
            ),
            row(
              Icons.help_outline,
              '使用帮助',
              'Help',
              '操作说明与常见问题',
              'Instructions and common questions',
              const UserManualPage(),
            ),
            row(
              Icons.system_update_outlined,
              '更新与公告',
              'Updates',
              '版本记录与更新状态',
              'Release notes and update status',
              const UpdateAnnouncementsPage(),
            ),
          ]),
        ],
      ),
    );
  }
}
