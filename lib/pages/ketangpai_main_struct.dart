import 'package:flutter/material.dart';

import '../session/account.dart';
import 'ketangpai_private_sign_page.dart';
import 'ketangpai_profile_page.dart';
import 'ketangpai_room_list_page.dart';
import 'ketangpai_shared_room_page.dart';
import 'ketangpai_suggestions_page.dart';

class KetangpaiMainStructPage extends StatefulWidget {
  const KetangpaiMainStructPage({super.key});

  @override
  State<KetangpaiMainStructPage> createState() => _KetangpaiMainStructPageState();
}

class _KetangpaiMainStructPageState extends State<KetangpaiMainStructPage> {
  final PageController _pageController = PageController(initialPage: 1);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _drawerItem({required IconData icon, required String title, required int index}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        _pageController.jumpToPage(index);
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height / 5,
                color: Colors.lightBlueAccent[100],
                padding: const EdgeInsets.all(15),
                alignment: Alignment.bottomLeft,
                child: const Text('课堂派', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _drawerItem(icon: Icons.person_outlined, title: '个人信息', index: 0),
              const SizedBox(height: 8),
              _drawerItem(icon: Icons.house_outlined, title: '共享房间', index: 1),
              const SizedBox(height: 8),
              _drawerItem(icon: Icons.house_outlined, title: '本地房间签到', index: 2),
              const SizedBox(height: 8),
              _drawerItem(icon: Icons.class_outlined, title: '我的课程', index: 3),
              const SizedBox(height: 8),
              _drawerItem(icon: Icons.email_outlined, title: '意见反馈', index: 4),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.exit_to_app_outlined),
                title: const Text('退出登录'),
                onTap: () async {
                  await AccountManager.clearCurrentSession();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leadingWidth: 65,
        title: const Text('课堂派', style: TextStyle(color: Colors.white, fontSize: 25)),
        backgroundColor: Colors.blue[200],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            iconSize: 35,
          ),
        ],
        leading: Builder(
          builder: (context) {
            return InkWell(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () => Scaffold.of(context).openDrawer(),
              child: const Icon(Icons.menu, color: Colors.white),
            );
          },
        ),
      ),
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageController,
        children: const [
          KetangpaiProfilePage(),
          KetangpaiSharedRoomPage(),
          KetangpaiPrivateSignPage(),
          KetangpaiRoomListPage(),
          KetangpaiSuggestionsPage(),
        ],
      ),
    );
  }
}
