import 'package:flutter/material.dart';
import '../design_tokens.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget content;
  final List<Widget>? actions;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  const AppDialog({
    super.key,
    required this.title,
    this.icon,
    required this.content,
    this.actions,
    this.iconColor,
    this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackgroundColor ?? theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(
                icon,
                color: iconColor ?? theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: content,
      actions: actions,
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    IconData? icon,
    required Widget content,
    List<Widget>? actions,
    Color? iconColor,
    Color? iconBackgroundColor,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AppDialog(
        title: title,
        icon: icon,
        content: content,
        actions: actions,
        iconColor: iconColor,
        iconBackgroundColor: iconBackgroundColor,
      ),
    );
  }
}
