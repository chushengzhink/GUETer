import 'package:flutter/material.dart';
import '../design_tokens.dart';

enum AppButtonVariant {
  primary,
  secondary,
  tertiary,
  outlined,
}

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

    Widget button;

    if (isLoading) {
      final loadingIndicator = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == AppButtonVariant.primary
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.primary,
          ),
        ),
      );

      button = FilledButton(
        onPressed: null,
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            loadingIndicator,
            const SizedBox(width: AppSpacing.sm),
            Text(label),
          ],
        ),
      );
    } else {
      switch (variant) {
        case AppButtonVariant.primary:
          button = icon != null
              ? FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                )
              : FilledButton(
                  onPressed: onPressed,
                  child: Text(label),
                );
          break;
        case AppButtonVariant.secondary:
          button = icon != null
              ? FilledButton.tonalIcon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                )
              : FilledButton.tonal(
                  onPressed: onPressed,
                  child: Text(label),
                );
          break;
        case AppButtonVariant.tertiary:
          button = icon != null
              ? TextButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                )
              : TextButton(
                  onPressed: onPressed,
                  child: Text(label),
                );
          break;
        case AppButtonVariant.outlined:
          button = icon != null
              ? OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                )
              : OutlinedButton(
                  onPressed: onPressed,
                  child: Text(label),
                );
          break;
      }
    }

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}
