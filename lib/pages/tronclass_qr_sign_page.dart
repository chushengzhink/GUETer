import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:uuid/uuid.dart';

import '../api/tronclass_sign_api.dart';
import '../utils/tronclass_qr_parser.dart';

class TronclassQrSignPage extends StatefulWidget {
  final String rollcallId;
  final String? activityName;

  const TronclassQrSignPage({super.key, required this.rollcallId, this.activityName});

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
  final double _scaleThreshold = 0.15;
  double _lastScaleUpdate = 1.0;
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
    if (state == AppLifecycleState.resumed) {
      if (mounted && !isProcessing) {
        _ensureCameraRunning();
      }
    }
  }

  void _ensureCameraRunning() {
    if (controller != null && mounted) {
      controller?.start();
    }
  }

  Future<void> _initAsync() async {
    try {
      final hasVibration = await Vibration.hasCustomVibrationsSupport();
      if (mounted) {
        setState(() {
          hasCustomVibrationsSupport = hasVibration == true;
        });
      }

      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          _showResultAndExit(false, '请允许相机权限才能进行扫描二维码');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        _showResultAndExit(false, '初始化失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () {
                controller?.toggleTorch();
                setState(() {
                  isFlash = !isFlash;
                });
              },
              icon: Icon(
                isFlash ? Icons.flash_off_outlined : Icons.flash_on_outlined,
              ),
            ),
          ],
          title: const Text('二维码签到'),
        ),
        body: GestureDetector(
          onScaleStart: (details) {
            _baseScale = _currentScale;
          },
          onScaleUpdate: (details) {
            double newScale =
                (_baseScale * pow(details.scale, _zoomFactor)).clamp(1.0, 10.0);
            if ((newScale - _lastScaleUpdate).abs() > _scaleThreshold) {
              setState(() {
                _currentScale = newScale;
                double normalizedScale = log(_currentScale) / log(10.0);
                controller?.setZoomScale(normalizedScale);
                _lastScaleUpdate = newScale;
              });
            }
          },
          child: MobileScanner(
            controller: controller,
            onDetect: (capture) async {
              if (isProcessing) return;

              controller?.stop();
              setState(() {
                isProcessing = true;
              });

              if (hasCustomVibrationsSupport) {
                Vibration.vibrate(duration: 100);
              } else {
                Vibration.vibrate();
              }

              await Future.delayed(const Duration(milliseconds: 100));
              _handleScanResult(capture);
            },
            overlayBuilder: (context, constraints) => Center(
              child: _ScannerBox(width: 300, height: 300),
            ),
          ),
        ),
      );
  }

  void _handleScanResult(BarcodeCapture capture) {
    try {
      final code = capture.barcodes.firstOrNull?.rawValue;
      if (code == null) {
        _showResultAndRestart(false, '未识别到二维码');
        return;
      }

      final parsed = TronclassQrParser.parse(code);
      if (parsed == null || parsed.isEmpty) {
        _showResultAndRestart(false, '二维码格式错误');
        return;
      }

      final scannedRollcallId = parsed['rollcallId']?.toString();
      final data = parsed['data']?.toString();

      if (scannedRollcallId == null || data == null) {
        _showResultAndRestart(false, '二维码格式错误');
        return;
      }

      if (scannedRollcallId != widget.rollcallId) {
        _showResultAndRestart(false, '该二维码不属于当前签到会话');
        return;
      }

      _navigateToSignResult(data);
    } catch (e) {
      _showResultAndRestart(false, '处理扫描结果时出错');
    }
  }

  void _navigateToSignResult(String data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QrSignResultPage(
          rollcallId: widget.rollcallId,
          data: data,
          onBack: _restartScan,
        ),
      ),
    ).then((_) {
      if (mounted) _restartScan();
    });
  }

  void _restartScan() {
    if (mounted) {
      setState(() {
        isProcessing = false;
      });
      controller?.start();
    }
  }

  void _showResultAndRestart(bool success, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    _restartScan();
  }

  void _showResultAndExit(bool success, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }
}

class _ScannerBox extends StatefulWidget {
  final double width;
  final double height;

  const _ScannerBox({required this.width, required this.height});

  @override
  State<_ScannerBox> createState() => _ScannerBoxState();
}

class _ScannerBoxState extends State<_ScannerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: widget.height)
        .animate(_animationController);
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
          return CustomPaint(
            painter: _ScannerBoxPainter(_animation.value),
          );
        },
      ),
    );
  }
}

class _ScannerBoxPainter extends CustomPainter {
  final double position;

  _ScannerBoxPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = const LinearGradient(
      colors: [Colors.blue, Colors.lightBlueAccent],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8.0));

    final borderPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, borderPaint);

    final linePaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(0, position),
      Offset(size.width, position),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

enum _QrSignState { loading, success, failure }

class _QrSignResultPage extends StatefulWidget {
  final String rollcallId;
  final String data;
  final VoidCallback? onBack;

  const _QrSignResultPage({
    required this.rollcallId,
    required this.data,
    this.onBack,
  });

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
      final deviceId = const Uuid().v4();

      final response = await TronclassSignApi.signQr(
        rollcallId: widget.rollcallId,
        data: widget.data,
        deviceId: deviceId,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('网络请求超时'),
      );

      final responseData = response.data;
      final isSuccessful = TronclassSignApi.isSignSuccess(responseData);

      if (mounted) {
        setState(() {
          currentState = isSuccessful ? _QrSignState.success : _QrSignState.failure;
          message = TronclassSignApi.getSignMessage(responseData, success: isSuccessful);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentState = _QrSignState.failure;
          message = e.toString().contains('超时') ? '网络连接超时，请检查网络' : '签到失败，请重试';
        });
      }
    }
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
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF01b9bb), Color(0xFF29cbcd)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 60,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => widget.onBack?.call(),
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              '二维码签到',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text('正在签到', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(message, style: const TextStyle(fontSize: 14, color: Colors.white), textAlign: TextAlign.center),
                        ],
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

    return Scaffold(
      appBar: AppBar(title: const Text('二维码签到')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 64.0, vertical: 32),
                      child: Icon(
                        currentState == _QrSignState.success ? Icons.check_circle : Icons.error,
                        size: 120,
                        color: currentState == _QrSignState.success ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      currentState == _QrSignState.success ? '签到成功' : '签到失败',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(message),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: () {
                  if (currentState == _QrSignState.success) {
                    Navigator.pop(context);
                  } else {
                    widget.onBack?.call();
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    currentState == _QrSignState.success ? const Color(0xff1DB6C2) : const Color(0xffff4853),
                  ),
                  elevation: WidgetStateProperty.all(0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    currentState == _QrSignState.success ? '完成' : '重试',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
