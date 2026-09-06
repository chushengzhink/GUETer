import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum AppButtonVariant { primary, secondary, tertiary, outlined }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final action = isLoading ? null : onPressed;
    final leading = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        : icon == null
        ? null
        : Icon(icon);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: AppSpacing.sm)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final Widget button = Semantics(
      liveRegion: isLoading,
      child: switch (variant) {
        AppButtonVariant.primary => FilledButton(
          onPressed: action,
          child: content,
        ),
        AppButtonVariant.secondary => FilledButton.tonal(
          onPressed: action,
          child: content,
        ),
        AppButtonVariant.tertiary => TextButton(
          onPressed: action,
          child: content,
        ),
        AppButtonVariant.outlined => OutlinedButton(
          onPressed: action,
          child: content,
        ),
      },
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
