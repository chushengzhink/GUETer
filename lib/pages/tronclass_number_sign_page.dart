import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../api/tronclass_sign_api.dart';

enum _NumberSignState { input, success, failure }

class TronclassNumberSignPage extends StatefulWidget {
  final String rollcallId;
  final String? activityName;

  const TronclassNumberSignPage({super.key, required this.rollcallId, this.activityName});

  @override
  State<TronclassNumberSignPage> createState() => _TronclassNumberSignPageState();
}

class _TronclassNumberSignPageState extends State<TronclassNumberSignPage>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  _NumberSignState _currentState = _NumberSignState.input;
  bool _hasError = false;
  String _errorMessage = '';
  String _successTime = '';
  String _successCode = '';
  bool _isBruteForcing = false;
  int _bruteForceAttempts = 0;

  late AnimationController _printerAnimationController;
  late Animation<double> _printerPaperAnimation;

  static const double _slotTopPosition = 40.0;
  static const double _slotHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _printerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _printerPaperAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _printerAnimationController, curve: Curves.easeInOut),
    );

    _printerAnimationController.value = 0.0;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    _printerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();

    if (code.length != 4 || int.tryParse(code) == null) {
      setState(() {
        _hasError = true;
        _errorMessage = '请输入完整的4位数字签到码';
      });
      return;
    }

    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final success = await _performSignRequest(code);
      if (success) {
        _showSuccessState(code: code);
      } else {
        _showFailureState('签到失败，点名已结束');
      }
    } catch (e) {
      _showFailureState('签到失败，请稍后再试');
    }
  }

  Future<bool> _performSignRequest(String code) async {
    final deviceId = const Uuid().v4();

    final response = await TronclassSignApi.signNumber(
      rollcallId: widget.rollcallId,
      numberCode: code,
      deviceId: deviceId,
    );

    return TronclassSignApi.isSignSuccess(response.data);
  }

  Future<void> _bruteForceSignCodes() async {
    if (_isBruteForcing) return;

    _resetToInputState();
    setState(() {
      _isBruteForcing = true;
      _bruteForceAttempts = 0;
    });

    const int maxCode = 10000;
    const int windowSize = 100;
    int currentIndex = 0;
    bool found = false;
    bool abort = false;
    final deviceId = const Uuid().v4();

    Future<void> worker() async {
      while (true) {
        if (found || abort) break;
        final int index = currentIndex;
        if (index >= maxCode) break;
        currentIndex++;
        final candidate = index.toString().padLeft(4, '0');

        bool attemptSuccess = false;
        try {
          final response = await TronclassSignApi.signNumber(
            rollcallId: widget.rollcallId,
            numberCode: candidate,
            deviceId: deviceId,
          );
          attemptSuccess = TronclassSignApi.isSignSuccess(response.data);
        } catch (e) {
          abort = true;
          break;
        } finally {
          if (mounted) {
            setState(() {
              _bruteForceAttempts++;
            });
          }
        }

        if (attemptSuccess && !found) {
          found = true;
          if (mounted) {
            _showSuccessState(code: candidate);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已自动匹配签到码 $candidate')),
            );
          }
          break;
        }
      }
    }

    await Future.wait(List.generate(windowSize, (_) => worker()));

    if (mounted) {
      setState(() {
        _isBruteForcing = false;
      });

      if (!found) {
        final message = abort ? '一键签到失败，请稍后再试' : '一键签到失败，未匹配到正确签到码';
        _showFailureState(message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _showSuccessState({String? code}) {
    setState(() {
      _hasError = false;
      _currentState = _NumberSignState.success;
      _successCode = code ?? '';
      final now = DateTime.now();
      _successTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
    _printerAnimationController.forward();
  }

  void _showFailureState(String message) {
    setState(() {
      _errorMessage = message;
      _currentState = _NumberSignState.failure;
      _successCode = '';
    });
    _printerAnimationController.forward();
  }

  void _resetToInputState() {
    setState(() {
      _currentState = _NumberSignState.input;
      _hasError = false;
      _errorMessage = '';
      _codeController.clear();
      _successTime = '';
      _successCode = '';
    });
    _printerAnimationController.value = 0.0;
  }

  Future<void> _confirmBruteForce() async {
    if (_isBruteForcing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认一键签到'),
        content: const Text('系统会并发尝试全部 0000-9999 签到码。请确保无法自行获取签到码再使用，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _bruteForceSignCodes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数字签到', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00A9C0),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF00A9C0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00A9C0), Color(0xFF0086A3)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: double.infinity,
                      height: _slotHeight,
                      constraints: const BoxConstraints(maxWidth: 400),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '签到纸条出口',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('请输入签到密码', style: TextStyle(fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _codeController,
                        focusNode: _codeFocus,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                          errorText: _hasError ? _errorMessage : null,
                        ),
                        onChanged: (value) {
                          if (_hasError) {
                            setState(() {
                              _hasError = false;
                              _errorMessage = '';
                            });
                          }
                          if (value.length == 4) {
                            _submitCode();
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '若已知道签到码请直接输入并提交，勿频繁使用一键签到。',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF00A9C0),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _isBruteForcing ? null : _confirmBruteForce,
                        icon: Icon(_isBruteForcing ? Icons.hourglass_top : Icons.flash_on),
                        label: Text(_isBruteForcing ? '一键签到中...' : '一键签到'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isBruteForcing || _bruteForceAttempts > 0)
                      Text(
                        _isBruteForcing
                            ? '窗口并发 100，已尝试 ${_bruteForceAttempts.toString().padLeft(4, '0')}/10000'
                            : '已尝试 ${_bruteForceAttempts.toString().padLeft(4, '0')} 个签到码',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                  ],
                ),
                if (_currentState == _NumberSignState.success)
                  _buildPrintedPaper(true)
                else if (_currentState == _NumberSignState.failure)
                  _buildPrintedPaper(false)
                else
                  _buildEmptyPaper(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrintedPaper(bool isSuccess) {
    return Positioned(
      top: _slotTopPosition + _slotHeight / 2,
      left: 20,
      right: 20,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        child: AnimatedBuilder(
          animation: _printerPaperAnimation,
          builder: (context, child) {
            return ClipRect(
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: Offset(0, -180 * (1 - _printerPaperAnimation.value)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSuccess ? Icons.check_circle : Icons.error,
                                  size: 48,
                                  color: isSuccess ? Colors.green : Colors.red,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isSuccess ? '签到成功' : '签到失败',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isSuccess ? _successTime : _errorMessage,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  textAlign: TextAlign.center,
                                ),
                                if (isSuccess && _successCode.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '签到码：$_successCode',
                                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyPaper() {
    return Positioned(
      top: _slotTopPosition + _slotHeight / 2,
      left: 20,
      right: 20,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        child: AnimatedBuilder(
          animation: _printerPaperAnimation,
          builder: (context, child) {
            return ClipRect(
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: Offset(0, -180 * (1 - _printerPaperAnimation.value)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
