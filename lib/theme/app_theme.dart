import 'package:flutter/material.dart';
import '../session/app_settings.dart';
import 'design_tokens.dart';
import 'theme_style.dart';

ThemeData buildAppTheme(
  ColorScheme colorScheme,
  String scheme,
  ThemeStyleData style,
) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: .65),
      thickness: .5,
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
    ),
    scaffoldBackgroundColor:
        scheme == AppSettings.colorSchemeNight &&
            colorScheme.brightness == Brightness.dark
        ? const Color(0xFF0F1512)
        : colorScheme.brightness == Brightness.dark
        ? const Color(0xFF101114)
        : const Color(0xFFF3F4F6),
    cardTheme: CardThemeData(
      elevation: style.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(style.cardRadius),
      ),
      color:
          scheme == AppSettings.colorSchemeNight &&
              colorScheme.brightness == Brightness.dark
          ? const Color(0xFF17201C)
          : null,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.buttonRadius),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.buttonRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.buttonRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.buttonRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorMaxLines: 3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(style.inputRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(style.inputRadius),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(style.inputRadius),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(style.chipRadius),
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(style.dialogRadius),
      ),
    ),
  );
}
