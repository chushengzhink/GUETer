import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';

import '../controllers/sign_controller.dart';

/// 课堂派数字签到页面
class KetangpaiNumberSignPage extends StatefulWidget {
  const KetangpaiNumberSignPage({
    super.key,
    this.signId,
    this.directSubmit = false,
    this.signController,
  });

  final String? signId;
  final bool directSubmit;
  final SignController? signController;

  @override
  State<KetangpaiNumberSignPage> createState() =>
      _KetangpaiNumberSignPageState();
}

class _KetangpaiNumberSignPageState extends State<KetangpaiNumberSignPage> {
  final TextEditingController _controller = TextEditingController();
  late final String _signControllerTag;
  late final SignController _signController;

  bool get _isDirectMode =>
      widget.directSubmit || (widget.signId?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _signControllerTag = 'ketangpai-number-${identityHashCode(this)}';
    _signController = Get.put(
      widget.signController ?? SignController(),
      tag: _signControllerTag,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    if (Get.isRegistered<SignController>(tag: _signControllerTag)) {
      Get.delete<SignController>(tag: _signControllerTag);
    }
    super.dispose();
  }

  Future<void> _handleCompleted(String pin) async {
    if (!_isDirectMode) {
      if (mounted) {
        Navigator.of(context).pop(pin);
      }
      return;
    }

    final signId = widget.signId?.trim() ?? '';
    await _signController.numberSign(signId, pin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(
        fontSize: 20,
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: theme.colorScheme.primary),
      borderRadius: BorderRadius.circular(12),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: theme.colorScheme.primaryContainer,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('数字签到')),
      body: Center(
        child: Obx(() {
          final isLoading =
              _signController.signStatus.value == SignStatus.loading;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('请输入四位数字完成签到', style: theme.textTheme.titleLarge),
              const SizedBox(height: 36),
              Pinput(
                length: 4,
                controller: _controller,
                enabled: !isLoading,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                showCursor: !isLoading,
                onCompleted: _handleCompleted,
              ),
              const SizedBox(height: 32),
              if (isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  '正在提交签到',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 160),
            ],
          );
        }),
      ),
    );
  }
}
