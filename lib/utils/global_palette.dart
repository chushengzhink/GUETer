import 'package:flutter/material.dart';

import '../session/app_settings.dart';
import '../platform.dart';

class GlobalPaletteData {
  final Color primary;
  final Color secondary;
  final Color accent;

  const GlobalPaletteData({
    required this.primary,
    required this.secondary,
    required this.accent,
  });
}

GlobalPaletteData resolveGlobalPalette(String scheme) {
  switch (scheme) {
    case AppSettings.colorSchemeNight:
      return const GlobalPaletteData(
        primary: Color(0xFF1F6F78),
        secondary: Color(0xFF164A51),
        accent: Color(0xFF8FC9B4),
      );
    case AppSettings.colorSchemeRose:
      return const GlobalPaletteData(
        primary: Color(0xFFD96C6C),
        secondary: Color(0xFFA84E4E),
        accent: Color(0xFFF1A28A),
      );
    case AppSettings.colorSchemeOcean:
      return const GlobalPaletteData(
        primary: Color(0xFF2962FF),
        secondary: Color(0xFF1E3FA3),
        accent: Color(0xFF00AEEF),
      );
    case AppSettings.colorSchemeForest:
      return const GlobalPaletteData(
        primary: Color(0xFF2E8B57),
        secondary: Color(0xFF1F6B41),
        accent: Color(0xFF7BC96F),
      );
    case AppSettings.colorSchemeAmber:
      return const GlobalPaletteData(
        primary: Color(0xFFC58A00),
        secondary: Color(0xFF8E6400),
        accent: Color(0xFFFFB347),
      );
    case AppSettings.colorSchemePurple:
      return const GlobalPaletteData(
        primary: Color(0xFF9C27B0),
        secondary: Color(0xFF7B1FA2),
        accent: Color(0xFFBA68C8),
      );
    case AppSettings.colorSchemeCyan:
      return const GlobalPaletteData(
        primary: Color(0xFF00BCD4),
        secondary: Color(0xFF0097A7),
        accent: Color(0xFF4DD0E1),
      );
    case AppSettings.colorSchemeOrange:
      return const GlobalPaletteData(
        primary: Color(0xFFFF6F00),
        secondary: Color(0xFFE65100),
        accent: Color(0xFFFFB74D),
      );
    case AppSettings.colorSchemeAqua:
    default:
      return const GlobalPaletteData(
        primary: Color(0xFF1F9EA8),
        secondary: Color(0xFF157B88),
        accent: Color(0xFF59BE30),
      );
  }
}


GlobalPaletteData resolvePlatformPalette(
  PlatformType platform, {
  required GlobalPaletteData fallback,
}) {
  switch (platform) {
    case PlatformType.chaoxing:
      return const GlobalPaletteData(
        primary: Color(0xFFD94B4B),
        secondary: Color(0xFFB53737),
        accent: Color(0xFFF08A24),
      );
    case PlatformType.rainClassroom:
      return const GlobalPaletteData(
        primary: Color(0xFF2F73E0),
        secondary: Color(0xFF1F5EC4),
        accent: Color(0xFF4BA3FF),
      );
    case PlatformType.tronclass:
      return const GlobalPaletteData(
        primary: Color(0xFF1F9EA8),
        secondary: Color(0xFF157B88),
        accent: Color(0xFF59BE30),
      );
    case PlatformType.ketangpai:
      return const GlobalPaletteData(
        primary: Color(0xFFE07B2F),
        secondary: Color(0xFFAF5A1F),
        accent: Color(0xFFF0B04B),
      );
    case PlatformType.weizhuojiao:
      return const GlobalPaletteData(
        primary: Color(0xFF5E6B7A),
        secondary: Color(0xFF3E4A59),
        accent: Color(0xFF8FA2B8),
      );
  }
}
