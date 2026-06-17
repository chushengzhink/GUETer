import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/sign_controller.dart';

/// 课堂派扫码签到页面
class KetangpaiScanSignPage extends StatefulWidget {
  const KetangpaiScanSignPage({
    super.key,
    this.signId,
    this.directSubmit = false,
    this.signController,
  });

  final String? signId;
  final bool directSubmit;
  final SignController? signController;

  @override
  State<KetangpaiScanSignPage> createState() => _KetangpaiScanSignPageState();
}

class _KetangpaiScanSignPageState extends State<KetangpaiScanSignPage> {
  final MobileScannerController controller = MobileScannerController(
    initialZoom: 0.0,
  );
  bool _isFlashOn = false;
  bool _hasScanned = false;
  bool _didResetZoom = false;
  double _currentZoomScale = 0.0;
  double _baseZoomScale = 0.0;
  double _lastZoomScale = 0.0;
  final double _zoomSensitivity = 0.45;
  final double _zoomUpdateThreshold = 0.01;
  late final String _signControllerTag;
  late final SignController _signController;

  bool get _isDirectMode =>
      widget.directSubmit || (widget.signId?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _signControllerTag = 'ketangpai-scan-${identityHashCode(this)}';
    _signController = Get.put(
      widget.signController ?? SignController(),
      tag: _signControllerTag,
    );
    controller.addListener(_syncZoomScaleFromController);
  }

  @override
  void dispose() {
    controller.removeListener(_syncZoomScaleFromController);
    controller.dispose();
    if (Get.isRegistered<SignController>(tag: _signControllerTag)) {
      Get.delete<SignController>(tag: _signControllerTag);
    }
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? code = barcode.rawValue;

    if (code != null && code.isNotEmpty) {
      _hasScanned = true;
      if (!_isDirectMode && mounted) {
        Navigator.of(context).pop(code);
        return;
      }

      await _signController.scanSign(code);
      if (mounted) {
        _hasScanned = false;
      }
    }
  }

  void _toggleFlash() {
    controller.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  void _syncZoomScaleFromController() {
    final state = controller.value;
    if (!state.isInitialized || !state.isRunning) return;

    if (!_didResetZoom) {
      _didResetZoom = true;
      _currentZoomScale = 0.0;
      _baseZoomScale = 0.0;
      _lastZoomScale = 0.0;
      controller.resetZoomScale().catchError((Object error) {
        debugPrint('Failed to reset scanner zoom: $error');
      });
      return;
    }

    final zoomScale = state.zoomScale.clamp(0.0, 1.0).toDouble();
    _currentZoomScale = zoomScale;
    _lastZoomScale = zoomScale;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _syncZoomScaleFromController();
    _baseZoomScale = _currentZoomScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final scaleDelta = details.scale - 1.0;
    if (scaleDelta.abs() <= 0.01) return;

    final nextZoomScale = (_baseZoomScale + scaleDelta * _zoomSensitivity)
        .clamp(0.0, 1.0)
        .toDouble();
    if ((nextZoomScale - _lastZoomScale).abs() <= _zoomUpdateThreshold) return;

    _currentZoomScale = nextZoomScale;
    _lastZoomScale = nextZoomScale;

    controller.setZoomScale(nextZoomScale).catchError((Object error) {
      debugPrint('Failed to set scanner zoom: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = screenSize.width * 0.7;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          '扫码签到',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              _isFlashOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        child: Stack(
          children: [
            MobileScanner(controller: controller, onDetect: _onDetect),
            CustomPaint(
              painter: ScannerOverlayPainter(
                scanAreaSize: scanAreaSize,
                borderColor: Colors.blueAccent,
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '将二维码放入框内扫描',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ),
            Obx(() {
              final isLoading =
                  _signController.signStatus.value == SignStatus.loading;
              if (!isLoading) {
                return const SizedBox.shrink();
              }
              return Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '正在提交签到',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 扫描框绘制
class ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final Color borderColor;

  ScannerOverlayPainter({
    required this.scanAreaSize,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final Rect scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    final Paint backgroundPaint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final double cornerLength = 20;

    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      borderPaint,
    );

    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize - cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      borderPaint,
    );

    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left, top + scanAreaSize - cornerLength),
      borderPaint,
    );

    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize),
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
