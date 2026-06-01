import 'package:flutter/material.dart';

class AirChatThreadPage extends StatelessWidget {
  const AirChatThreadPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('旧入口兼容页')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '该页面已被“附近房间”近场配对流程替代，不再提供聊天线程能力。\nuserId: $userId',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
