import 'package:flutter/material.dart';
import 'design_tokens.dart';

enum ThemeStyleType {
  modern,
  compact,
  playful,
  minimal,
  bold,
  soft,
}

class ThemeStyleData {
  final double cardRadius;
  final double buttonRadius;
  final double inputRadius;
  final double chipRadius;
  final double dialogRadius;

  final double spacingMultiplier;
  final double cardElevation;
  final double shadowIntensity;

  final Curve animationCurve;
  final Duration animationDuration;

  final bool useGradients;
  final double gradientIntensity;

  const ThemeStyleData({
    required this.cardRadius,
    required this.buttonRadius,
    required this.inputRadius,
    required this.chipRadius,
    required this.dialogRadius,
    required this.spacingMultiplier,
    required this.cardElevation,
    required this.shadowIntensity,
    required this.animationCurve,
    required this.animationDuration,
    required this.useGradients,
    required this.gradientIntensity,
  });

  static const ThemeStyleData modern = ThemeStyleData(
    cardRadius: AppRadius.large,
    buttonRadius: AppRadius.medium,
    inputRadius: AppRadius.medium,
    chipRadius: AppRadius.medium,
    dialogRadius: AppRadius.xlarge,
    spacingMultiplier: 1.0,
    cardElevation: AppElevation.low,
    shadowIntensity: 0.12,
    animationCurve: AppCurves.standard,
    animationDuration: AppDuration.normal,
    useGradients: true,
    gradientIntensity: 0.15,
  );

  static const ThemeStyleData compact = ThemeStyleData(
    cardRadius: AppRadius.small,
    buttonRadius: AppRadius.small,
    inputRadius: AppRadius.small,
    chipRadius: AppRadius.small,
    dialogRadius: AppRadius.medium,
    spacingMultiplier: 0.75,
    cardElevation: AppElevation.none,
    shadowIntensity: 0.08,
    animationCurve: AppCurves.decelerate,
    animationDuration: AppDuration.fast,
    useGradients: false,
    gradientIntensity: 0.0,
  );

  static const ThemeStyleData playful = ThemeStyleData(
    cardRadius: AppRadius.xxlarge,
    buttonRadius: AppRadius.large,
    inputRadius: AppRadius.large,
    chipRadius: AppRadius.pill,
    dialogRadius: AppRadius.xxlarge,
    spacingMultiplier: 1.25,
    cardElevation: AppElevation.medium,
    shadowIntensity: 0.18,
    animationCurve: AppCurves.bounce,
    animationDuration: AppDuration.slow,
    useGradients: true,
    gradientIntensity: 0.25,
  );

  static const ThemeStyleData minimal = ThemeStyleData(
    cardRadius: AppRadius.small,
    buttonRadius: AppRadius.small,
    inputRadius: AppRadius.small,
    chipRadius: AppRadius.small,
    dialogRadius: AppRadius.medium,
    spacingMultiplier: 1.0,
    cardElevation: AppElevation.none,
    shadowIntensity: 0.0,
    animationCurve: AppCurves.decelerate,
    animationDuration: AppDuration.fast,
    useGradients: false,
    gradientIntensity: 0.0,
  );

  static const ThemeStyleData bold = ThemeStyleData(
    cardRadius: AppRadius.medium,
    buttonRadius: AppRadius.medium,
    inputRadius: AppRadius.medium,
    chipRadius: AppRadius.large,
    dialogRadius: AppRadius.large,
    spacingMultiplier: 1.15,
    cardElevation: AppElevation.high,
    shadowIntensity: 0.22,
    animationCurve: AppCurves.emphasized,
    animationDuration: AppDuration.normal,
    useGradients: true,
    gradientIntensity: 0.35,
  );

  static const ThemeStyleData soft = ThemeStyleData(
    cardRadius: AppRadius.xlarge,
    buttonRadius: AppRadius.xlarge,
    inputRadius: AppRadius.large,
    chipRadius: AppRadius.pill,
    dialogRadius: AppRadius.xlarge,
    spacingMultiplier: 1.1,
    cardElevation: AppElevation.low,
    shadowIntensity: 0.08,
    animationCurve: AppCurves.standard,
    animationDuration: AppDuration.slow,
    useGradients: true,
    gradientIntensity: 0.12,
  );

  static ThemeStyleData fromType(ThemeStyleType type) {
    switch (type) {
      case ThemeStyleType.modern:
        return modern;
      case ThemeStyleType.compact:
        return compact;
      case ThemeStyleType.playful:
        return playful;
      case ThemeStyleType.minimal:
        return minimal;
      case ThemeStyleType.bold:
        return bold;
      case ThemeStyleType.soft:
        return soft;
    }
  }

  EdgeInsets scaledPadding(EdgeInsets base) {
    return EdgeInsets.only(
      left: base.left * spacingMultiplier,
      top: base.top * spacingMultiplier,
      right: base.right * spacingMultiplier,
      bottom: base.bottom * spacingMultiplier,
    );
  }

  double scaledSpacing(double base) {
    return base * spacingMultiplier;
  }

  BoxShadow createShadow(Color color) {
    return BoxShadow(
      color: color.withValues(alpha: shadowIntensity),
      blurRadius: cardElevation * 2,
      offset: Offset(0, cardElevation / 2),
    );
  }

  LinearGradient? createGradient(Color primary, Color secondary) {
    if (!useGradients) return null;

    return LinearGradient(
      colors: [
        primary,
        Color.lerp(primary, secondary, gradientIntensity)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
