import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

import '../api/tronclass_sign_api.dart';
import '../utils/tronclass_qr_parser.dart';
import 'widget/tronclass_liquid_glass.dart';

class TronclassQrSignPage extends StatefulWidget {
  const TronclassQrSignPage({
    super.key,
    required this.rollcallId,
    this.activityName,
  });

  final String rollcallId;
  final String? activityName;

  @override
  State<TronclassQrSignPage> createState() => _TronclassQrSignPageState();
}

class _TronclassQrSignPageState extends State<TronclassQrSignPage>
    with WidgetsBindingObserver {
  bool hasCustomVibrationsSupport = false;
  bool isFlash = false;
  MobileScannerController? controller;
  double _currentScale = 1.0;
  double _baseScale = 1.0;
  double _lastScaleUpdate = 1.0;
  final double _scaleThreshold = 0.15;
  final double _zoomFactor = 2.0;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = MobileScannerController(
      cameraResolution: const Size(1080, 1920),
    );
    _initAsync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !isProcessing) {
      controller?.start();
    }
  }

  Future<void> _initAsync() async {
    try {
      final supported = await Vibration.hasCustomVibrationsSupport();
      if (mounted) {
        setState(() {
          hasCustomVibrationsSupport = supported == true;
        });
      }

      final permission = await Permission.camera.request();
      if (!permission.isGranted && mounted) {
        _showErrorAndRestart('请允许相机权限后再扫码');
      }
    } catch (_) {
      if (mounted) {
        _showErrorAndRestart('初始化失败，请重试');
      }
    }
  }

  void _showErrorAndRestart(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    _restartScan();
  }

  void _restartScan() {
    if (!mounted) return;
    setState(() {
      isProcessing = false;
    });
    controller?.start();
  }

  Future<void> _handleCapture(BarcodeCapture capture) async {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) {
      _showErrorAndRestart('未识别到二维码');
      return;
    }

    final parsed = TronclassQrParser.parse(raw);
    if (parsed == null || parsed.isEmpty) {
      _showErrorAndRestart('二维码格式错误');
      return;
    }

    final scannedRollcallId = parsed['rollcallId']?.toString();
    final data = parsed['data']?.toString();
    if (scannedRollcallId == null || data == null) {
      _showErrorAndRestart('二维码格式错误');
      return;
    }

    if (scannedRollcallId != widget.rollcallId) {
      _showErrorAndRestart('该二维码不属于当前签到');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QrSignResultPage(
          rollcallId: widget.rollcallId,
          data: data,
          onBack: _restartScan,
        ),
      ),
    );

    if (mounted) {
      _restartScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.activityName?.trim().isNotEmpty == true
        ? widget.activityName!.trim()
        : '二维码签到';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('二维码签到'),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: isFlash ? '关闭闪光灯' : '打开闪光灯',
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  controller?.toggleTorch();
                  setState(() {
                    isFlash = !isFlash;
                  });
                },
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    isFlash
                        ? Icons.flash_off_outlined
                        : Icons.flash_on_outlined,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onScaleStart: (_) {
          _baseScale = _currentScale;
        },
        onScaleUpdate: (details) {
          final nextScale = (_baseScale * pow(details.scale, _zoomFactor))
              .clamp(1.0, 10.0);
          if ((nextScale - _lastScaleUpdate).abs() > _scaleThreshold) {
            setState(() {
              _currentScale = nextScale;
              final normalizedScale = log(_currentScale) / log(10.0);
              controller?.setZoomScale(normalizedScale);
              _lastScaleUpdate = nextScale;
            });
          }
        },
        child: MobileScanner(
          controller: controller,
          overlayBuilder: (context, _) => _ScannerOverlay(
            title: title,
            isFlashOn: isFlash,
            isProcessing: isProcessing,
          ),
          onDetect: (capture) async {
            if (isProcessing) return;

            controller?.stop();
            setState(() {
              isProcessing = true;
            });

            if (hasCustomVibrationsSupport) {
              await Vibration.vibrate(duration: 100);
            } else {
              await Vibration.vibrate();
            }

            await Future.delayed(const Duration(milliseconds: 100));
            await _handleCapture(capture);
          },
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({
    required this.title,
    required this.isFlashOn,
    required this.isProcessing,
  });

  final String title;
  final bool isFlashOn;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.58),
            Colors.black.withValues(alpha: 0.18),
            Colors.black.withValues(alpha: 0.62),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 86, 16, 24),
          child: Column(
            children: [
              TronclassGlassCard(
                padding: const EdgeInsets.all(18),
                tintColor: const Color(0x33FFFFFF),
                boxShadows: const [],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const TronclassGlassPill(
                          label: '扫码识别',
                          icon: Icons.qr_code_scanner_rounded,
                          color: TronclassGlassPalette.mint,
                          foregroundColor: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        TronclassGlassPill(
                          label: isFlashOn ? '闪光灯已开' : '闪光灯已关',
                          icon: isFlashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: Colors.white,
                          foregroundColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isProcessing
                          ? '正在校验二维码并提交签到结果。'
                          : '将二维码置于扫描框中央，系统会自动识别并提交。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Center(child: _ScannerBox(width: 300, height: 300)),
              const Spacer(),
              TronclassGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                tintColor: const Color(0x26FFFFFF),
                boxShadows: const [],
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.pinch_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '支持双指缩放取景。识别失败时请确认二维码是否属于当前课程签到。',
                        style: TextStyle(color: Colors.white, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerBox extends StatefulWidget {
  const _ScannerBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_ScannerBox> createState() => _ScannerBoxState();
}

class _ScannerBoxState extends State<_ScannerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 18, end: widget.height - 18).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(painter: _ScannerBoxPainter(_animation.value));
        },
      ),
    );
  }
}

class _ScannerBoxPainter extends CustomPainter {
  const _ScannerBoxPainter(this.position);

  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(30));

    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF95F2FF), Color(0xFF2FE1D4), Color(0xFF7AB8FF)],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final sweepPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0x0044F0FF), Color(0xCC8EF8FF), Color(0x0044F0FF)],
      ).createShader(Rect.fromLTWH(0, position - 12, size.width, 24))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(rrect, fillPaint);
    canvas.drawRRect(rrect, borderPaint);
    canvas.drawLine(
      Offset(28, position),
      Offset(size.width - 28, position),
      sweepPaint,
    );

    const cornerLength = 28.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(0, cornerLength),
      const Offset(0, 0),
      cornerPaint,
    );
    canvas.drawLine(
      const Offset(0, 0),
      const Offset(cornerLength, 0),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(size.width - cornerLength, 0),
      Offset(size.width, 0),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(0, size.height - cornerLength),
      Offset(0, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(size.width - cornerLength, size.height),
      Offset(size.width, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - cornerLength),
      Offset(size.width, size.height),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerBoxPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}

enum _QrSignState { loading, success, failure }

class _QrSignResultPage extends StatefulWidget {
  const _QrSignResultPage({
    required this.rollcallId,
    required this.data,
    this.onBack,
  });

  final String rollcallId;
  final String data;
  final VoidCallback? onBack;

  @override
  State<_QrSignResultPage> createState() => _QrSignResultPageState();
}

class _QrSignResultPageState extends State<_QrSignResultPage> {
  _QrSignState currentState = _QrSignState.loading;
  String message = '正在签到中...';

  @override
  void initState() {
    super.initState();
    _performSignIn();
  }

  Future<void> _performSignIn() async {
    try {
      final response =
          await TronclassSignApi.signQr(
            rollcallId: widget.rollcallId,
            data: widget.data,
            deviceId: const Uuid().v4(),
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception('timeout'),
          );

      if (!mounted) return;
      setState(() {
        currentState = TronclassSignApi.isSignSuccess(response)
            ? _QrSignState.success
            : _QrSignState.failure;
        message = TronclassSignApi.getSignMessage(response.data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentState = _QrSignState.failure;
        message = e.toString().contains('timeout')
            ? '网络连接超时，请检查网络后重试'
            : '签到失败，请重试';
      });
    }
  }

  void _handlePrimaryAction(bool success) {
    if (success) {
      Navigator.pop(context);
      return;
    }
    widget.onBack?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (currentState == _QrSignState.loading) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            widget.onBack?.call();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: TronclassGlassBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                    ),
                    const Spacer(),
                    TronclassGlassCard(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 18),
                          const Text(
                            '正在提交二维码签到',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: TronclassGlassPalette.text,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: TronclassGlassPalette.mutedText,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final success = currentState == _QrSignState.success;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('二维码签到结果')),
      body: TronclassGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                const Spacer(),
                TronclassGlassCard(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    children: [
                      TronclassGlassPill(
                        label: success ? '签到成功' : '签到失败',
                        icon: success
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: success
                            ? TronclassGlassPalette.success
                            : TronclassGlassPalette.danger,
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Image.asset(
                          success
                              ? 'assets/images/qr_sign_ok.png'
                              : 'assets/images/qr_sign_failed.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        success ? '签到完成' : '本次签到未通过',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: TronclassGlassPalette.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: TronclassGlassPalette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TronclassGlassCard(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _handlePrimaryAction(success),
                      style: tronclassPrimaryButtonStyle(
                        context,
                        color: success
                            ? TronclassGlassPalette.success
                            : TronclassGlassPalette.danger,
                      ),
                      child: Text(success ? '完成' : '返回重新扫描'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
