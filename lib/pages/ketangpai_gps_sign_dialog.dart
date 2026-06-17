import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/sign_controller.dart';
import '../models/ketangpai_sign.dart';

class KetangpaiGpsSignConfig {
  const KetangpaiGpsSignConfig({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final String latitude;
  final String longitude;
  final String accuracy;
}

class KetangpaiGpsSignDialog extends StatefulWidget {
  const KetangpaiGpsSignDialog({
    super.key,
    this.signId,
    this.directSubmit = false,
    this.signController,
  });

  final String? signId;
  final bool directSubmit;
  final SignController? signController;

  static Future<KetangpaiGpsSignConfig?> show(
    BuildContext context, {
    String? signId,
    bool directSubmit = false,
    SignController? signController,
  }) {
    return showDialog<KetangpaiGpsSignConfig>(
      context: context,
      builder: (context) => KetangpaiGpsSignDialog(
        signId: signId,
        directSubmit: directSubmit,
        signController: signController,
      ),
    );
  }

  @override
  State<KetangpaiGpsSignDialog> createState() => _KetangpaiGpsSignDialogState();
}

class _KetangpaiGpsSignDialogState extends State<KetangpaiGpsSignDialog> {
  final TextEditingController _latitudeController = TextEditingController(
    text: '25.3',
  );
  final TextEditingController _longitudeController = TextEditingController(
    text: '110.4',
  );
  final TextEditingController _accuracyController = TextEditingController(
    text: '100',
  );
  String? _error;
  late final String _signControllerTag;
  late final SignController _signController;

  bool get _isDirectMode =>
      widget.directSubmit || (widget.signId?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _signControllerTag = 'ketangpai-gps-${identityHashCode(this)}';
    _signController = Get.put(
      widget.signController ?? SignController(),
      tag: _signControllerTag,
    );
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _accuracyController.dispose();
    if (Get.isRegistered<SignController>(tag: _signControllerTag)) {
      Get.delete<SignController>(tag: _signControllerTag);
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final latitude = _latitudeController.text.trim();
    final longitude = _longitudeController.text.trim();
    final accuracy = _accuracyController.text.trim().isEmpty
        ? '100'
        : _accuracyController.text.trim();
    final latValue = double.tryParse(latitude);
    final lngValue = double.tryParse(longitude);
    final accuracyValue = double.tryParse(accuracy);
    if (latValue == null ||
        latValue < -90 ||
        latValue > 90 ||
        lngValue == null ||
        lngValue < -180 ||
        lngValue > 180 ||
        accuracyValue == null ||
        accuracyValue <= 0) {
      setState(() {
        _error = '请输入有效的经纬度和精度';
      });
      return;
    }
    if (_isDirectMode) {
      _signController.setLocation(
        KetangpaiLocationPayload(
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
        ),
      );
      await _signController.gpsSign(widget.signId?.trim() ?? '');
      return;
    }
    Navigator.of(context).pop(
      KetangpaiGpsSignConfig(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = _signController.signStatus.value == SignStatus.loading;
      return AlertDialog(
        title: const Text('GPS 签到'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _latitudeController,
              enabled: !isLoading,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '纬度'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _longitudeController,
              enabled: !isLoading,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '经度'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _accuracyController,
              enabled: !isLoading,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '精度（米）'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (isLoading) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: isLoading ? null : _submit,
            child: const Text('确认'),
          ),
        ],
      );
    });
  }
}
