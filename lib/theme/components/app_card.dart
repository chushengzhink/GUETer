import 'package:flutter/material.dart';
import '../design_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final double? elevation;
  final double? radius;
  final VoidCallback? onTap;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.elevation,
    this.radius,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardTheme = theme.cardTheme;

    final effectiveRadius = radius ??
        (cardTheme.shape as RoundedRectangleBorder?)?.borderRadius.resolve(TextDirection.ltr).topLeft.x ??
        AppRadius.large;

    final effectiveElevation = elevation ?? cardTheme.elevation ?? AppElevation.low;

    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? cardTheme.color ?? theme.colorScheme.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: border,
        boxShadow: effectiveElevation > 0
            ? AppShadows.low(theme.colorScheme.shadow)
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: content,
    );
  }
}
