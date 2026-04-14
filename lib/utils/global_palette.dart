import 'package:flutter/material.dart';

import '../session/app_settings.dart';

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
    case AppSettings.colorSchemeMint:
      return const GlobalPaletteData(
        primary: Color(0xFF2A9D8F),
        secondary: Color(0xFF1F746A),
        accent: Color(0xFF7ED9AE),
      );
    case AppSettings.colorSchemeRose:
      return const GlobalPaletteData(
        primary: Color(0xFFD96C6C),
        secondary: Color(0xFFA84E4E),
        accent: Color(0xFFF1A28A),
      );
    case AppSettings.colorSchemeSky:
      return const GlobalPaletteData(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF2457A6),
        accent: Color(0xFF73B8FF),
      );
    case AppSettings.colorSchemeIndigo:
      return const GlobalPaletteData(
        primary: Color(0xFF4F46E5),
        secondary: Color(0xFF3730A3),
        accent: Color(0xFF818CF8),
      );
    case AppSettings.colorSchemeOlive:
      return const GlobalPaletteData(
        primary: Color(0xFF6B8E23),
        secondary: Color(0xFF4F6B19),
        accent: Color(0xFFA3BE6C),
      );
    case AppSettings.colorSchemeOcean:
      return const GlobalPaletteData(
        primary: Color(0xFF2962FF),
        secondary: Color(0xFF1E3FA3),
        accent: Color(0xFF00AEEF),
      );
    case AppSettings.colorSchemeSunset:
      return const GlobalPaletteData(
        primary: Color(0xFFEC6D3C),
        secondary: Color(0xFFB94922),
        accent: Color(0xFFF1B24A),
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
    case AppSettings.colorSchemeSlate:
      return const GlobalPaletteData(
        primary: Color(0xFF5E6B7A),
        secondary: Color(0xFF3E4A59),
        accent: Color(0xFF8FA2B8),
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
