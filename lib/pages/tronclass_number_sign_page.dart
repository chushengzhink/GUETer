import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import '../api/tronclass_batch_sign_executor.dart';
import '../api/tronclass_sign_api.dart';
import '../models/user.dart';
import '../services/sign_platform_context.dart';
import '../services/sign_run_console.dart';
import '../widgets/sign_run_console_panel.dart';
import '../widgets/tronclass_account_selector.dart';
import 'tronclass_number_input.dart';
import 'widget/tronclass_liquid_glass.dart';

enum _NumberSignState { input, success, failure }

class TronclassNumberSignPage extends StatefulWidget {
  const TronclassNumberSignPage({
    super.key,
    required this.rollcallId,
    this.activityName,
  });

  final String rollcallId;
  final String? activityName;

  @override
  State<TronclassNumberSignPage> createState() =>
      _TronclassNumberSignPageState();
}

class _TronclassNumberSignPageState extends State<TronclassNumberSignPage>
    with TickerProviderStateMixin {
  final FocusNode _codeFocus = FocusNode();

  _NumberSignState _currentState = _NumberSignState.input;
  bool _hasError = false;
  String _errorMessage = '';
  String _successTime = '';
  String _successCode = '';
  bool _isBruteForcing = false;
  int _bruteForceAttempts = 0;
  bool _isBatchSigning = false;
  List<User> _selectedAccounts = <User>[];
  final SignRunConsoleController _consoleController = SignRunConsoleController(
    platformContext: SignPlatformContext.tronclass,
  );

  late final AnimationController _printerAnimationController;
  late final Animation<double> _printerPaperAnimation;

  static const double _slotTopPosition = 108;
  static const double _slotHeight = 58;

  @override
  void initState() {
    super.initState();
    _printerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _printerPaperAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _printerAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _printerAnimationController.value = 0;
  }

  @override
  void dispose() {
    _codeFocus.dispose();
    _printerAnimationController.dispose();
    _consoleController.dispose();
    super.dispose();
  }

  Future<void> _bruteForceSignCodes() async {
    if (_isBruteForcing) return;

    _resetToInputState();
    setState(() {
      _isBruteForcing = true;
      _bruteForceAttempts = 0;
    });

    const maxCode = 10000;
    const workerCount = 100;
    final deviceId = const Uuid().v4();
    var currentIndex = 0;
    var found = false;
    var abort = false;

    Future<void> worker() async {
      while (true) {
        if (found || abort) return;
        final index = currentIndex;
        if (index >= maxCode) return;
        currentIndex++;
        final candidate = index.toString().padLeft(4, '0');

        try {
          final response = await TronclassSignApi.signNumber(
            rollcallId: widget.rollcallId,
            numberCode: candidate,
            deviceId: deviceId,
          );
          if (TronclassSignApi.isSignSuccess(response) && !found) {
            found = true;
            if (mounted) {
              _showSuccessState(candidate);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已自动匹配签到码 $candidate')));
            }
            return;
          }
        } catch (_) {
          abort = true;
          return;
        } finally {
          if (mounted) {
            setState(() {
              _bruteForceAttempts++;
            });
          }
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    if (!mounted) return;
    setState(() {
      _isBruteForcing = false;
    });

    if (!found) {
      final message = abort ? '一键签到失败，请稍后再试' : '一键签到失败，未匹配到正确签到码';
      _showFailureState(message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _submitCodeBatch(String code) async {
    if (_selectedAccounts.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = '请至少选择一个畅课账号';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择一个畅课账号')));
      return;
    }

    if (code.length != 4 || int.tryParse(code) == null) {
      setState(() {
        _hasError = true;
        _errorMessage = '请输入完整的 4 位签到密码';
      });
      return;
    }

    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isBatchSigning = true;
    });
    _consoleController.clear();

    try {
      final result = await TronclassBatchSignExecutor().sign(
        context: context,
        courseName: widget.activityName?.trim().isNotEmpty == true
            ? widget.activityName!.trim()
            : '畅课数字签到',
        console: _consoleController,
        users: _selectedAccounts,
        isContextMounted: () => mounted,
        action: (_, deviceId) => TronclassSignApi.signNumber(
          rollcallId: widget.rollcallId,
          numberCode: code,
          deviceId: deviceId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isBatchSigning = false;
      });
      if (result.successCount > 0) {
        _showSuccessState(code);
      } else {
        _showFailureState(
          '批量签到完成，成功 ${result.successCount}/${result.totalCount}，跳过 ${result.skippedCount}',
        );
      }
      await _showBatchResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBatchSigning = false;
      });
      _showFailureState('签到失败: $e');
    }
  }

  Future<void> _showBatchResult(TronclassBatchSignResult result) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('畅课批量签到结果'),
        content: SingleChildScrollView(
          child: Text(
            '成功: ${result.successCount}/${result.totalCount}\n'
            '跳过: ${result.skippedCount}\n'
            '失败: ${result.failedCount}\n\n'
            '${result.items.map((item) => '${item.user.name}: ${item.skipped
                ? '跳过'
                : item.success
                ? '成功'
                : '失败'} - ${item.message}').join('\n')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSuccessState(String code) {
    final now = DateTime.now();
    setState(() {
      _currentState = _NumberSignState.success;
      _successCode = code;
      _successTime =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    });
    _printerAnimationController.forward(from: 0);
  }

  void _showFailureState(String message) {
    setState(() {
      _currentState = _NumberSignState.failure;
      _errorMessage = message;
      _successCode = '';
    });
    _printerAnimationController.forward(from: 0);
  }

  void _resetToInputState() {
    setState(() {
      _currentState = _NumberSignState.input;
      _hasError = false;
      _errorMessage = '';
      _successTime = '';
      _successCode = '';
    });
    _printerAnimationController.value = 0;
  }

  Future<void> _confirmBruteForce() async {
    if (_isBruteForcing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认一键签到'),
        content: const Text('系统会并发尝试 0000-9999 的所有签到码，请确认真的无法手动获取签到码后再使用。'),
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

  (String, Color, IconData) _stateData() {
    switch (_currentState) {
      case _NumberSignState.success:
        return (
          '签到成功',
          TronclassGlassPalette.success,
          Icons.check_circle_rounded,
        );
      case _NumberSignState.failure:
        return ('签到失败', TronclassGlassPalette.danger, Icons.error_rounded);
      case _NumberSignState.input:
        return (
          _isBruteForcing ? '尝试中' : '等待输入',
          _isBruteForcing
              ? TronclassGlassPalette.warning
              : TronclassGlassPalette.accent,
          _isBruteForcing ? Icons.hourglass_top_rounded : Icons.pin_outlined,
        );
    }
  }

  Widget _buildPrintedPaper(bool success) {
    return Positioned(
      top: _slotTopPosition + _slotHeight / 2,
      left: 18,
      right: 18,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AnimatedBuilder(
          animation: _printerPaperAnimation,
          builder: (context, child) {
            return ClipRect(
              child: SizedBox(
                width: double.infinity,
                height: 190,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          -190 * (1 - _printerPaperAnimation.value),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Stack(
                            children: [
                              Image.asset(
                                'assets/images/number_rollcall_paper.png',
                                width: double.infinity,
                                fit: BoxFit.fitWidth,
                              ),
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    36,
                                    40,
                                    36,
                                    28,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        success
                                            ? 'assets/images/number_rollcall_paper_icon_success.svg'
                                            : 'assets/images/number_rollcall_paper_icon_fail.svg',
                                        width: 46,
                                        height: 46,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        success ? '签到成功' : '签到失败',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        success ? _successTime : _errorMessage,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          height: 1.45,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (success && _successCode.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Text(
                                            '签到码：$_successCode',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
      left: 18,
      right: 18,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AnimatedBuilder(
          animation: _printerPaperAnimation,
          builder: (context, child) {
            return ClipRect(
              child: SizedBox(
                width: double.infinity,
                height: 190,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          -190 * (1 - _printerPaperAnimation.value),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Opacity(
                            opacity: 0.88,
                            child: Image.asset(
                              'assets/images/number_rollcall_paper.png',
                              width: double.infinity,
                              fit: BoxFit.fitWidth,
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

  Widget _buildShowcaseCard() {
    final stateData = _stateData();
    return TronclassGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TronclassGlassPill(
                      label: stateData.$1,
                      icon: stateData.$3,
                      color: stateData.$2,
                    ),
                    const Spacer(),
                    const TronclassGlassPill(
                      label: '4 位密码',
                      icon: Icons.dialpad_rounded,
                      color: TronclassGlassPalette.accentDeep,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '数字签到回执',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: TronclassGlassPalette.text,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '输入签到码后会保留原提交流程，成功或失败结果通过纸片回执反馈。',
                  style: TextStyle(
                    color: TronclassGlassPalette.mutedText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: _slotHeight,
                  child: Image.asset(
                    'assets/images/number_rollcall_paper_slot.png',
                    fit: BoxFit.cover,
                  ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('数字签到')),
      body: TronclassGlassBackground(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TronclassGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const TronclassSectionHeader(
                              title: '输入数字签到码',
                              subtitle: '保留原 4 位数字签到和穷举流程，仅重做展示与反馈层。',
                            ),
                            if (_isBruteForcing || _bruteForceAttempts > 0) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: TronclassGlassPalette.warning
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: TronclassGlassPalette.warning
                                        .withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  _isBruteForcing
                                      ? '窗口并发 100，已尝试 ${_bruteForceAttempts.toString().padLeft(4, '0')}/10000'
                                      : '已尝试 ${_bruteForceAttempts.toString().padLeft(4, '0')} 个签到码',
                                  style: const TextStyle(
                                    color: TronclassGlassPalette.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildShowcaseCard(),
                      const SizedBox(height: 16),
                      TronclassAccountSelector(
                        enabled: !_isBatchSigning && !_isBruteForcing,
                        onSelectionChanged: (users) {
                          setState(() {
                            _selectedAccounts = users;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TronclassGlassCard(
                        child: Column(
                          children: [
                            TronclassNumberInput(
                              codeLength: 4,
                              focusNode: _codeFocus,
                              autofocus: true,
                              hasError: _hasError,
                              errorMessage: _hasError ? _errorMessage : null,
                              backgroundColor: Colors.white,
                              activeColor: TronclassGlassPalette.accent,
                              errorColor: TronclassGlassPalette.danger,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              boxWidth: 78,
                              boxHeight: 88,
                              textStyle: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: TronclassGlassPalette.text,
                              ),
                              onChanged: (_) {
                                if (_hasError) {
                                  setState(() {
                                    _hasError = false;
                                    _errorMessage = '';
                                  });
                                }
                              },
                              onCompleted: _submitCodeBatch,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '若已知道签到码请直接输入并提交，谨慎使用一键签到。',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: TronclassGlassPalette.mutedText,
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: tronclassPrimaryButtonStyle(
                                  context,
                                  color: TronclassGlassPalette.accentDeep,
                                ),
                                onPressed: _isBruteForcing || _isBatchSigning
                                    ? null
                                    : _confirmBruteForce,
                                icon: Icon(
                                  _isBruteForcing
                                      ? Icons.hourglass_top_rounded
                                      : Icons.flash_on_rounded,
                                ),
                                label: Text(
                                  _isBruteForcing ? '一键签到中...' : '一键签到',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SignRunConsolePanel(controller: _consoleController),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
