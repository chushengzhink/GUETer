import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

/// 课堂派数字签到页面
class KetangpaiNumberSignPage extends StatefulWidget {
  const KetangpaiNumberSignPage({super.key});

  @override
  State<KetangpaiNumberSignPage> createState() =>
      _KetangpaiNumberSignPageState();
}

class _KetangpaiNumberSignPageState extends State<KetangpaiNumberSignPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 20,
        color: Color.fromRGBO(30, 60, 87, 1),
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(212, 192, 251, 1.0),
        border: Border.all(color: const Color.fromRGBO(234, 239, 243, 1)),
        borderRadius: BorderRadius.circular(20),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color.fromRGBO(18, 119, 214, 1.0)),
      borderRadius: BorderRadius.circular(8),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: const Color.fromRGBO(233, 220, 244, 1.0),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('数字签到'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '请输入四位数字完成签到',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 36),
            Pinput(
              length: 4,
              controller: _controller,
              defaultPinTheme: defaultPinTheme,
              focusedPinTheme: focusedPinTheme,
              submittedPinTheme: submittedPinTheme,
              pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
              showCursor: true,
              onCompleted: (pin) {
                if (mounted) {
                  Navigator.of(context).pop(pin);
                }
              },
            ),
            const SizedBox(height: 200),
          ],
        ),
      ),
    );
  }
}
