import 'package:flutter/material.dart';

class KetangpaiCoursePalette {
  const KetangpaiCoursePalette({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.surfaceMuted,
    required this.stroke,
    required this.strokeStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.heroGradient,
    required this.panelGradient,
    required this.stageGradient,
    required this.shadowColor,
    required this.glowA,
    required this.glowB,
  });

  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color surfaceMuted;
  final Color stroke;
  final Color strokeStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final LinearGradient heroGradient;
  final LinearGradient panelGradient;
  final LinearGradient stageGradient;
  final Color shadowColor;
  final Color glowA;
  final Color glowB;

  static KetangpaiCoursePalette of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return const KetangpaiCoursePalette(
        background: Color(0xFF0D0D10),
        surface: Color(0xFF17171B),
        surfaceStrong: Color(0xFF212127),
        surfaceMuted: Color(0xFF15151A),
        stroke: Color(0x33FFFFFF),
        strokeStrong: Color(0x4DFFFFFF),
        textPrimary: Color(0xFFF6F3EE),
        textSecondary: Color(0xFFE4D9D3),
        textMuted: Color(0xFFB3A7A1),
        accent: Color(0xFFFF4F8B),
        accentStrong: Color(0xFFFF2D55),
        accentSoft: Color(0x33FF4F8B),
        success: Color(0xFF63D39C),
        warning: Color(0xFFFFB15C),
        heroGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16161A), Color(0xFF101014), Color(0xFF1B1220)],
        ),
        panelGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1C22), Color(0xFF131318)],
        ),
        stageGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF18181D), Color(0xFF111116)],
        ),
        shadowColor: Color(0x73000000),
        glowA: Color(0x55FF4F8B),
        glowB: Color(0x33FFB366),
      );
    }

    return const KetangpaiCoursePalette(
      background: Color(0xFFF5F1EA),
      surface: Color(0xFFFFFCF7),
      surfaceStrong: Color(0xFFFFFFFF),
      surfaceMuted: Color(0xFFF0E8DE),
      stroke: Color(0x1409090B),
      strokeStrong: Color(0x2909090B),
      textPrimary: Color(0xFF09090B),
      textSecondary: Color(0xFF25252B),
      textMuted: Color(0xFF6A645F),
      accent: Color(0xFFFF3D6E),
      accentStrong: Color(0xFFD91B54),
      accentSoft: Color(0x1FFF3D6E),
      success: Color(0xFF1E9E68),
      warning: Color(0xFFF28C2A),
      heroGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF111214), Color(0xFF1B1B20), Color(0xFF2A1320)],
      ),
      panelGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFCF7), Color(0xFFF3ECE3)],
      ),
      stageGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFF7F0E7)],
      ),
      shadowColor: Color(0x2409090B),
      glowA: Color(0x3DFF4F8B),
      glowB: Color(0x22FFB15C),
    );
  }
}

class KetangpaiCourseTokens {
  static const double pageInset = 18;
  static const double sectionGap = 18;
  static const double cardRadius = 28;
  static const double panelRadius = 24;
  static const double pillRadius = 999;
  static const double stageRadius = 30;
}

Duration ketangpaiMotionDuration(
  BuildContext context, {
  Duration fallback = const Duration(milliseconds: 180),
}) {
  final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations;
  return disableAnimations == true ? Duration.zero : fallback;
}
