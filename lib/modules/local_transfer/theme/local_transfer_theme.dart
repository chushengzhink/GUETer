import 'package:flutter/material.dart';

class LocalTransferThemeData {
  const LocalTransferThemeData({
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.surfaceTint,
    required this.error,
    required this.outline,
  });

  final Color primary;
  final Color secondary;
  final Color surface;
  final Color surfaceTint;
  final Color error;
  final Color outline;

  factory LocalTransferThemeData.resolve(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LocalTransferThemeData(
      primary: colorScheme.primary,
      secondary: colorScheme.secondary,
      surface: colorScheme.surface,
      surfaceTint: colorScheme.primaryContainer,
      error: colorScheme.error,
      outline: colorScheme.outline,
    );
  }
}
