import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../api/api_service.dart';
import '../api/tronclass_batch_sign_executor.dart';
import '../api/tronclass_sign_api.dart';
import '../models/user.dart';
import '../services/sign_platform_context.dart';
import '../services/sign_run_console.dart';
import '../utils/tronclass_qr_parser.dart';
import '../widgets/sign_run_console_panel.dart';
import '../widgets/tronclass_account_selector.dart';
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
  bool _didResetZoom = false;
  double _currentZoomScale = 0.0;
  double _baseZoomScale = 0.0;
  double _lastZoomScale = 0.0;
  final double _zoomSensitivity = 0.45;
  final double _zoomUpdateThreshold = 0.01;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = MobileScannerController(
      cameraResolution: const Size(1080, 1920),
      initialZoom: 0.0,
    );
    controller?.addListener(_syncZoomScaleFromController);
    _initAsync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.removeListener(_syncZoomScaleFromController);
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
    ApiService.appendExternalConsoleLog('tronclass', '[TronclassQr] $message');
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

  void _syncZoomScaleFromController() {
    final currentController = controller;
    if (currentController == null) return;

    final state = currentController.value;
    if (!state.isInitialized || !state.isRunning) return;

    if (!_didResetZoom) {
      _didResetZoom = true;
      _currentZoomScale = 0.0;
      _baseZoomScale = 0.0;
      _lastZoomScale = 0.0;
      currentController.resetZoomScale().catchError((Object error) {
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

    controller?.setZoomScale(nextZoomScale).catchError((Object error) {
      debugPrint('Failed to set scanner zoom: $error');
    });
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

    ApiService.appendExternalConsoleLog(
      'tronclass',
      '[TronclassQr] qrcode parsed rollcallId=$scannedRollcallId',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassQrSignConfirmPage(
          rollcallId: widget.rollcallId,
          data: data,
          onBack: _restartScan,
        ),
      ),
    );

    if (mounted) {
      ApiService.appendExternalConsoleLog(
        'tronclass',
        '[TronclassQr] confirm page closed rollcallId=$scannedRollcallId',
      );
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
        behavior: HitTestBehavior.opaque,
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        child: MobileScanner(
          controller: controller,
          overlayBuilder: (context, _) => _ScannerOverlay(
            title: title,
            isFlashOn: isFlash,
            isProcessing: isProcessing,
          ),
          onDetect: (capture) async {
            if (isProcessing) return;

            setState(() {
              isProcessing = true;
            });
            await controller?.stop();

            try {
              if (hasCustomVibrationsSupport) {
                await Vibration.vibrate(duration: 100);
              } else {
                await Vibration.vibrate();
              }

              await Future.delayed(const Duration(milliseconds: 100));
              await _handleCapture(capture);
            } catch (e) {
              ApiService.appendExternalConsoleLog(
                'tronclass',
                '[TronclassQr] handle capture failed: $e',
              );
              if (mounted) {
                _showErrorAndRestart('二维码处理失败：$e');
              }
            }
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
                          ? '正在处理二维码，准备进入账号确认页。'
                          : '将二维码置于扫描框中央，识别后先确认账号再开始签到。',
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

enum _QrSignState { ready, loading, success, failure }

class TronclassQrSignConfirmPage extends StatefulWidget {
  const TronclassQrSignConfirmPage({
    super.key,
    required this.rollcallId,
    required this.data,
    this.onBack,
  });

  final String rollcallId;
  final String data;
  final VoidCallback? onBack;

  @override
  State<TronclassQrSignConfirmPage> createState() =>
      _TronclassQrSignConfirmPageState();
}

class _TronclassQrSignConfirmPageState
    extends State<TronclassQrSignConfirmPage> {
  final SignRunConsoleController _consoleController = SignRunConsoleController(
    platformContext: SignPlatformContext.tronclass,
  );
  _QrSignState currentState = _QrSignState.ready;
  String message = '请选择本次要签到的畅课账号';
  List<User> _selectedAccounts = <User>[];
  TronclassBatchSignResult? _lastResult;
  TronclassBatchNetworkPolicy _networkPolicy =
      TronclassBatchNetworkPolicy.strict;
  late final DateTime _scannedAt;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _scannedAt = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || currentState != _QrSignState.ready) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_scannedAt).inSeconds;
      });
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _consoleController.dispose();
    super.dispose();
  }

  Future<void> _performSignIn() async {
    if (_selectedAccounts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一个畅课账号')));
      return;
    }

    setState(() {
      currentState = _QrSignState.loading;
      message = '正在签到中...';
      _lastResult = null;
    });
    _consoleController.clear();
    _consoleController.add(
      platform: '畅课',
      accountName: '本次二维码签到',
      accountId: widget.rollcallId,
      stage: SignRunStage.queued,
      message: _networkPolicy == TronclassBatchNetworkPolicy.qrFastFirst
          ? '已选择极速防过期模式'
          : '已选择严格换网模式',
      detail: '扫码后已用时 $_elapsedSeconds 秒',
    );

    try {
      final result = await TronclassBatchSignExecutor().sign(
        context: context,
        courseName: '畅课二维码签到',
        console: _consoleController,
        users: _selectedAccounts,
        isContextMounted: () => mounted,
        networkPolicy: _networkPolicy,
        action: (_, deviceId) => TronclassSignApi.signQr(
          rollcallId: widget.rollcallId,
          data: widget.data,
          deviceId: deviceId,
        ),
      );

      if (!mounted) return;
      final failure = result.items.where((item) => !item.success).firstOrNull;
      final hasExpired = result.items.any(
        (item) => item.message.contains('二维码已过期'),
      );
      setState(() {
        _lastResult = result;
        currentState = result.successCount > 0
            ? _QrSignState.success
            : _QrSignState.failure;
        message =
            hasExpired
            ? '签到二维码已过期，请重新扫码'
            : failure?.message ??
            '成功 ${result.successCount}/${result.totalCount}，跳过 ${result.skippedCount}，失败 ${result.failedCount}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        currentState = _QrSignState.failure;
        _lastResult = null;
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
    if (currentState == _QrSignState.ready) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            widget.onBack?.call();
          }
        },
        child: Scaffold(
          backgroundColor: TronclassGlassPalette.surface,
          appBar: AppBar(title: const Text('确认二维码签到账号')),
          body: TronclassGlassBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TronclassGlassCard(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TronclassSectionHeader(
                          title: '二维码已识别',
                          subtitle: '确认本次参与签到的畅课账号后再提交。',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'rollcallId: ${widget.rollcallId}',
                          style: const TextStyle(
                            color: TronclassGlassPalette.mutedText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '扫码后已用时：$_elapsedSeconds 秒',
                          style: TextStyle(
                            color: _elapsedSeconds >= 10
                                ? TronclassGlassPalette.danger
                                : TronclassGlassPalette.mutedText,
                            fontWeight: _elapsedSeconds >= 10
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                        if (_elapsedSeconds >= 10) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '二维码可能即将过期，建议使用极速防过期或重新扫码。',
                            style: TextStyle(
                              color: TronclassGlassPalette.danger,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QrNetworkPolicyCard(
                    policy: _networkPolicy,
                    elapsedSeconds: _elapsedSeconds,
                    onChanged: (policy) {
                      setState(() {
                        _networkPolicy = policy;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TronclassAccountSelector(
                    onSelectionChanged: (users) {
                      setState(() {
                        _selectedAccounts = users;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SignRunConsolePanel(
                    controller: _consoleController,
                    maxHeight: 180,
                  ),
                  const SizedBox(height: 16),
                  TronclassGlassCard(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _selectedAccounts.isEmpty
                            ? null
                            : _performSignIn,
                        style: tronclassPrimaryButtonStyle(context),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          _selectedAccounts.isEmpty
                              ? '请选择账号'
                              : '开始签到 (${_selectedAccounts.length})',
                        ),
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

    if (currentState == _QrSignState.loading) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            widget.onBack?.call();
          }
        },
        child: Scaffold(
          backgroundColor: TronclassGlassPalette.surface,
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
                          const SizedBox(height: 12),
                          SignRunConsolePanel(
                            controller: _consoleController,
                            maxHeight: 180,
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
      backgroundColor: TronclassGlassPalette.surface,
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
                      const SizedBox(height: 14),
                      if (_lastResult != null) ...[
                        _QrAccountResultList(result: _lastResult!),
                        const SizedBox(height: 14),
                      ],
                      SignRunConsolePanel(
                        controller: _consoleController,
                        maxHeight: 220,
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

class _QrNetworkPolicyCard extends StatelessWidget {
  const _QrNetworkPolicyCard({
    required this.policy,
    required this.elapsedSeconds,
    required this.onChanged,
  });

  final TronclassBatchNetworkPolicy policy;
  final int elapsedSeconds;
  final ValueChanged<TronclassBatchNetworkPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    final expiredRisk = elapsedSeconds >= 10;
    return TronclassGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TronclassSectionHeader(
            title: '二维码提交模式',
            subtitle: '严格换网更稳妥，极速防过期会让首账号先提交。',
          ),
          const SizedBox(height: 12),
          SegmentedButton<TronclassBatchNetworkPolicy>(
            segments: const [
              ButtonSegment(
                value: TronclassBatchNetworkPolicy.strict,
                icon: Icon(Icons.network_check_rounded),
                label: Text('严格换网'),
              ),
              ButtonSegment(
                value: TronclassBatchNetworkPolicy.qrFastFirst,
                icon: Icon(Icons.bolt_rounded),
                label: Text('极速防过期'),
              ),
            ],
            selected: {policy},
            onSelectionChanged: (values) => onChanged(values.single),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                policy == TronclassBatchNetworkPolicy.qrFastFirst
                    ? Icons.bolt_rounded
                    : Icons.verified_user_rounded,
                size: 18,
                color: expiredRisk
                    ? TronclassGlassPalette.warning
                    : TronclassGlassPalette.mutedText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  policy == TronclassBatchNetworkPolicy.qrFastFirst
                      ? '第一个选中账号会跳过换网直接提交，后续账号仍逐个换网。'
                      : '每个账号都会先检查会话并重启移动数据，再提交签到。',
                  style: const TextStyle(
                    color: TronclassGlassPalette.mutedText,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrAccountResultList extends StatelessWidget {
  const _QrAccountResultList({required this.result});

  final TronclassBatchSignResult result;

  @override
  Widget build(BuildContext context) {
    final items = result.items;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _QrAccountResultTile(item: items[i]),
            if (i != items.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: TronclassGlassPalette.mutedText.withValues(alpha: 0.12),
              ),
          ],
        ],
      ),
    );
  }
}

class _QrAccountResultTile extends StatelessWidget {
  const _QrAccountResultTile({required this.item});

  final TronclassBatchSignItemResult item;

  @override
  Widget build(BuildContext context) {
    final color = item.success
        ? TronclassGlassPalette.success
        : item.skipped
        ? TronclassGlassPalette.warning
        : TronclassGlassPalette.danger;
    final icon = item.success
        ? Icons.check_circle_rounded
        : item.skipped
        ? Icons.skip_next_rounded
        : Icons.error_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TronclassGlassPalette.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.message,
                  style: const TextStyle(
                    color: TronclassGlassPalette.mutedText,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
