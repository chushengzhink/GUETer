import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// 现代化卡片组件 - 支持渐变边框、毛玻璃效果、Hero 动画
class ModernCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool showGradientBorder;
  final bool enableHero;
  final String? heroTag;
  final Color? backgroundColor;
  final List<Color>? gradientColors;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.showGradientBorder = false,
    this.enableHero = false,
    this.heroTag,
    this.backgroundColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget card = Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? colorScheme.surface,
            border: showGradientBorder
                ? Border.all(width: 1.5, color: Colors.transparent)
                : null,
          ),
          foregroundDecoration: showGradientBorder
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(width: 1.5, color: Colors.transparent),
                  gradient: LinearGradient(
                    colors:
                        gradientColors ??
                        [
                          colorScheme.primary.withValues(alpha: 0.3),
                          colorScheme.secondary.withValues(alpha: 0.1),
                        ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: Padding(
                padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (enableHero && heroTag != null) {
      card = Hero(tag: heroTag!, child: card);
    }

    return card;
  }
}

/// 课程卡片组件 - 专门为课程列表设计
class CourseCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? teacher;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isActive;

  const CourseCard({
    super.key,
    required this.title,
    this.subtitle,
    this.teacher,
    this.trailing,
    this.onTap,
    this.accentColor,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveAccentColor = accentColor ?? colorScheme.primary;

    return ModernCard(
      onTap: onTap,
      showGradientBorder: isActive,
      gradientColors: isActive
          ? [
              effectiveAccentColor.withValues(alpha: 0.5),
              effectiveAccentColor.withValues(alpha: 0.2),
            ]
          : null,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  effectiveAccentColor,
                  effectiveAccentColor.withValues(alpha: 0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (teacher != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          teacher!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
