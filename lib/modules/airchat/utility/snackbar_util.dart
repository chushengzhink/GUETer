import 'package:flutter/material.dart';

class SnackbarUtil {
  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.indigo[600],
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
