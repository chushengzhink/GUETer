import 'package:flutter/material.dart';

import '../pages/accounts.dart';
import '../pages/courses.dart';
import '../pages/settings.dart';
import '../pages/todos_page.dart';
import '../pages/tools_page.dart';
import 'app_entry.dart';

List<AppEntry> buildBuiltinAppEntries() {
  return <AppEntry>[
    AppEntry(
      id: 'courses',
      titleZh: '课程',
      titleEn: 'Courses',
      icon: Icons.school_rounded,
      builder: (_) => CoursesPage(key: coursesPageKey),
    ),
    const AppEntry(
      id: 'accounts',
      titleZh: '账号',
      titleEn: 'Accounts',
      icon: Icons.account_circle_rounded,
      builder: _buildAccountsPage,
    ),
    const AppEntry(
      id: 'todos',
      titleZh: '待办',
      titleEn: 'Todos',
      icon: Icons.check_circle_outline_rounded,
      builder: _buildTodosPage,
    ),
    const AppEntry(
      id: 'tools',
      titleZh: '工具',
      titleEn: 'Tools',
      icon: Icons.apps_rounded,
      builder: _buildToolsPage,
    ),
    const AppEntry(
      id: 'settings',
      titleZh: '设置',
      titleEn: 'Settings',
      icon: Icons.settings_rounded,
      builder: _buildSettingsPage,
    ),
  ];
}

Widget _buildAccountsPage(BuildContext context) => const AccountsPage();
Widget _buildTodosPage(BuildContext context) => const TodosPage();
Widget _buildToolsPage(BuildContext context) => const ToolsPage();
Widget _buildSettingsPage(BuildContext context) => const SettingsPage();
