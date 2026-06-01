import 'package:flutter/material.dart';

/// 课堂派 GPS 签到对话框
class KetangpaiGpsSignDialog extends StatelessWidget {
  const KetangpaiGpsSignDialog({super.key});

  /// 显示 GPS 签到对话框
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const KetangpaiGpsSignDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GPS 签到'),
      content: const Text(
        '点击确定即可签到\n'
        '系统将使用模拟位置完成签到',
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
