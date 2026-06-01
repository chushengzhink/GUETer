import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widget/tronclass_liquid_glass.dart';

class TronclassNumberInput extends StatefulWidget {
  const TronclassNumberInput({
    super.key,
    this.codeLength = 4,
    this.onCompleted,
    this.onChanged,
    this.focusNode,
    this.hasError = false,
    this.errorMessage,
    this.backgroundColor,
    this.activeColor,
    this.errorColor,
    this.cursorColor,
    this.textStyle,
    this.boxWidth,
    this.boxHeight,
    this.borderRadius,
    this.margin,
    this.enableContextMenu = true,
    this.autofocus = false,
  });

  final int codeLength;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool hasError;
  final String? errorMessage;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? errorColor;
  final Color? cursorColor;
  final TextStyle? textStyle;
  final double? boxWidth;
  final double? boxHeight;
  final double? borderRadius;
  final EdgeInsets? margin;
  final bool enableContextMenu;
  final bool autofocus;

  @override
  State<TronclassNumberInput> createState() => _TronclassNumberInputState();
}

class _TronclassNumberInputState extends State<TronclassNumberInput>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final Timer _cursorTimer;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  bool _showCursor = false;

  Color get _backgroundColor =>
      widget.backgroundColor ?? Colors.white.withValues(alpha: 0.65);
  Color get _activeColor => widget.activeColor ?? TronclassGlassPalette.accent;
  Color get _errorColor => widget.errorColor ?? TronclassGlassPalette.danger;
  Color get _cursorColor => widget.cursorColor ?? _activeColor;
  TextStyle get _textStyle =>
      widget.textStyle ??
      const TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        color: TronclassGlassPalette.text,
      );
  double get _boxWidth => widget.boxWidth ?? 70;
  double get _boxHeight => widget.boxHeight ?? 88;
  double get _borderRadius => widget.borderRadius ?? 24;
  EdgeInsets get _margin =>
      widget.margin ?? const EdgeInsets.symmetric(horizontal: 6);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_handleChanged);
    _focusNode.addListener(_handleFocusChanged);
    _startCursorAnimation();
    _setupShakeAnimation();

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant TronclassNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  void _handleChanged() {
    widget.onChanged?.call(_controller.text);
    if (_controller.text.length == widget.codeLength) {
      widget.onCompleted?.call(_controller.text);
    }
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    setState(() {
      _showCursor = _focusNode.hasFocus;
    });
  }

  void _startCursorAnimation() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_focusNode.hasFocus && mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
      }
    });
  }

  void _setupShakeAnimation() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 520),
      vsync: this,
    );
    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handlePaste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final digits = data?.text?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      if (digits.isEmpty) {
        return;
      }
      final pasted = digits.substring(
        0,
        digits.length > widget.codeLength ? widget.codeLength : digits.length,
      );
      _controller.text = pasted;
      _controller.selection = TextSelection.collapsed(offset: pasted.length);
      if (pasted.length == widget.codeLength) {
        widget.onCompleted?.call(pasted);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('粘贴失败，请重试')));
    }
  }

  void _handleClear() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _showCustomContextMenu() {
    if (!widget.enableContextMenu) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        return;
      }
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy + size.height,
          position.dx + size.width,
          position.dy + size.height * 2,
        ),
        items: [
          const PopupMenuItem<String>(
            value: 'paste',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.paste_rounded, size: 16),
                SizedBox(width: 8),
                Text('粘贴'),
              ],
            ),
          ),
          if (_controller.text.isNotEmpty)
            const PopupMenuItem<String>(
              value: 'clear',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('清空'),
                ],
              ),
            ),
        ],
      ).then((value) {
        if (value == 'paste') {
          _handlePaste();
        } else if (value == 'clear') {
          _handleClear();
        }
      });
    });
  }

  @override
  void dispose() {
    _cursorTimer.cancel();
    _shakeController.dispose();
    _controller.removeListener(_handleChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _focusNode.requestFocus(),
          onLongPress: _showCustomContextMenu,
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final shakeOffset = widget.hasError
                  ? math.sin(_shakeAnimation.value * math.pi * 5) * 10
                  : 0.0;
              return Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: Stack(
                  children: [
                    _buildHiddenTextInput(),
                    _buildVisualCodeDisplay(),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.hasError && widget.errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _errorColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _errorColor.withValues(alpha: 0.2)),
            ),
            child: Text(
              widget.errorMessage!,
              style: TextStyle(color: _errorColor, fontSize: 13.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHiddenTextInput() {
    return Opacity(
      opacity: 0,
      child: EditableText(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(widget.codeLength),
        ],
        style: const TextStyle(color: Colors.transparent),
        cursorColor: Colors.transparent,
        backgroundCursorColor: Colors.transparent,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildVisualCodeDisplay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalMargin = widget.codeLength * _margin.horizontal;
        final available =
            (constraints.maxWidth - totalMargin) / widget.codeLength;
        final resolvedBoxWidth = math
            .max(52.0, math.min(_boxWidth, available))
            .toDouble();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.codeLength, (index) {
            final hasFocus = _focusNode.hasFocus;
            final currentIndex = _controller.selection.extentOffset.clamp(
              0,
              widget.codeLength,
            );
            final hasValue = index < _controller.text.length;
            final showCursor = hasFocus && index == currentIndex && _showCursor;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _focusNode.requestFocus();
                final position = index.clamp(0, _controller.text.length);
                _controller.selection = TextSelection.collapsed(
                  offset: position,
                );
              },
              onLongPress: _showCustomContextMenu,
              child: AnimatedContainer(
                duration: tronclassMotionDuration(context),
                width: resolvedBoxWidth,
                height: _boxHeight,
                margin: _margin,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _backgroundColor.withValues(alpha: 0.92),
                      _backgroundColor.withValues(alpha: 0.72),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_borderRadius),
                  border: Border.all(
                    color: widget.hasError
                        ? _errorColor
                        : (hasFocus && index == currentIndex)
                        ? _activeColor
                        : Colors.white.withValues(alpha: 0.75),
                    width: widget.hasError ? 1.8 : 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.55),
                      blurRadius: 12,
                      offset: const Offset(-3, -3),
                    ),
                    BoxShadow(
                      color:
                          (hasFocus && index == currentIndex
                                  ? _activeColor
                                  : TronclassGlassPalette.accentDeep)
                              .withValues(
                                alpha: hasFocus && index == currentIndex
                                    ? 0.18
                                    : 0.08,
                              ),
                      blurRadius: hasFocus && index == currentIndex ? 22 : 12,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: AnimatedOpacity(
                        opacity: hasValue ? 1 : 0,
                        duration: tronclassMotionDuration(context),
                        child: Text(
                          hasValue ? _controller.text[index] : '',
                          style: _textStyle.copyWith(
                            color: widget.hasError
                                ? _errorColor
                                : _textStyle.color,
                          ),
                        ),
                      ),
                    ),
                    if (showCursor) _buildCursor(),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCursor() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AnimatedContainer(
          duration: tronclassMotionDuration(context),
          width: 26,
          height: 3,
          decoration: BoxDecoration(
            color: _cursorColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
