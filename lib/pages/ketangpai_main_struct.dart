import 'package:flutter/material.dart';

import 'ketangpai_private_sign_page.dart';
import 'ketangpai_profile_page.dart';
import 'ketangpai_room_list_page.dart';
import 'ketangpai_shared_room_page.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          _pageController.jumpToPage(index);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
              const SizedBox(height: 24),
              const Text(
                '课堂派功能',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _drawerItem(icon: Icons.person_outlined, title: '个人信息', index: 0)),
                  Expanded(child: _drawerItem(icon: Icons.house_outlined, title: '共享房间', index: 1)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: _drawerItem(icon: Icons.edit_note_outlined, title: '本地签到', index: 2)),
                  Expanded(child: _drawerItem(icon: Icons.class_outlined, title: '课程列表', index: 3)),
                ],
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
        ],
      ),
    );
  }
}
