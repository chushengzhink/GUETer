import 'package:flutter/material.dart';

class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? backgroundColor;
  final Color? selectedColor;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.onDelete,
    this.backgroundColor,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (onTap != null) {
      return FilterChip(
        label: Text(label),
        avatar: icon != null ? Icon(icon, size: 18) : null,
        selected: isSelected,
        onSelected: (_) => onTap?.call(),
        backgroundColor: backgroundColor,
        selectedColor: selectedColor ?? theme.colorScheme.primaryContainer,
      );
    }

    if (onDelete != null) {
      return Chip(
        label: Text(label),
        avatar: icon != null ? Icon(icon, size: 18) : null,
        onDeleted: onDelete,
        backgroundColor: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
      );
    }

    return Chip(
      label: Text(label),
      avatar: icon != null ? Icon(icon, size: 18) : null,
      backgroundColor: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
    );
  }
}
