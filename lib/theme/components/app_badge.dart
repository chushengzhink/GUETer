import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum AppBadgeType {
  success,
  warning,
  error,
  info,
  neutral,
}

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeType type;
  final IconData? icon;
  final bool isSmall;

  const AppBadge({
    super.key,
    required this.label,
    this.type = AppBadgeType.neutral,
    this.icon,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors(theme);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? AppSpacing.sm : AppSpacing.md,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: colors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: isSmall ? 12 : 14,
              color: colors.foreground,
            ),
            SizedBox(width: isSmall ? 2 : 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _getColors(ThemeData theme) {
    switch (type) {
      case AppBadgeType.success:
        return _BadgeColors(
          background: const Color(0xFF4CAF50).withValues(alpha: 0.12),
          foreground: const Color(0xFF2E7D32),
          border: const Color(0xFF4CAF50).withValues(alpha: 0.3),
        );
      case AppBadgeType.warning:
        return _BadgeColors(
          background: const Color(0xFFFFC107).withValues(alpha: 0.12),
          foreground: const Color(0xFFF57C00),
          border: const Color(0xFFFFC107).withValues(alpha: 0.3),
        );
      case AppBadgeType.error:
        return _BadgeColors(
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.error,
          border: theme.colorScheme.error.withValues(alpha: 0.3),
        );
      case AppBadgeType.info:
        return _BadgeColors(
          background: theme.colorScheme.primaryContainer,
          foreground: theme.colorScheme.primary,
          border: theme.colorScheme.primary.withValues(alpha: 0.3),
        );
      case AppBadgeType.neutral:
        return _BadgeColors(
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurface,
          border: theme.colorScheme.outline.withValues(alpha: 0.3),
        );
    }
  }
}

class _BadgeColors {
  final Color background;
  final Color foreground;
  final Color border;

  _BadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });
}
