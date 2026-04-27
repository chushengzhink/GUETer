import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppAnimations {
  // Fade transitions
  static Widget fadeIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? AppDuration.normal,
      curve: curve ?? AppCurves.standard,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Slide transitions
  static Widget slideIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    Offset begin = const Offset(0, 0.1),
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: begin, end: Offset.zero),
      duration: duration ?? AppDuration.normal,
      curve: curve ?? AppCurves.emphasized,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value * 50,
          child: child,
        );
      },
      child: child,
    );
  }

  // Scale transitions
  static Widget scaleIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double begin = 0.8,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: begin, end: 1.0),
      duration: duration ?? AppDuration.normal,
      curve: curve ?? AppCurves.emphasized,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Combined fade + slide
  static Widget fadeSlideIn({
    required Widget child,
    Duration? duration,
    Curve? curve,
    Offset begin = const Offset(0, 0.1),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration ?? AppDuration.normal,
      curve: curve ?? AppCurves.emphasized,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // Page route transitions
  static PageRouteBuilder<T> createRoute<T>({
    required Widget page,
    RouteTransitionType type = RouteTransitionType.fade,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        switch (type) {
          case RouteTransitionType.fade:
            return FadeTransition(opacity: animation, child: child);
          case RouteTransitionType.slide:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: AppCurves.emphasized,
              )),
              child: child,
            );
          case RouteTransitionType.scale:
            return ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: AppCurves.emphasized,
                ),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
        }
      },
      transitionDuration: AppDuration.normal,
    );
  }
}

enum RouteTransitionType {
  fade,
  slide,
  scale,
}

// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = widget.highlightColor ??
        Theme.of(context).colorScheme.surface;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

// Ripple effect widget
class RippleEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? rippleColor;

  const RippleEffect({
    super.key,
    required this.child,
    this.onTap,
    this.rippleColor,
  });

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: (widget.rippleColor ??
                      Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.1 * (1 - _controller.value)),
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
