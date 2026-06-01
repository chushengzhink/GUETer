import 'dart:ui';

import 'package:flutter/material.dart';

class TronclassGlassPalette {
  static const Color accent = Color(0xFF149FD2);
  static const Color accentDeep = Color(0xFF0B73B6);
  static const Color mint = Color(0xFF57D7D0);
  static const Color text = Color(0xFF0F2A43);
  static const Color mutedText = Color(0xFF56738D);
  static const Color success = Color(0xFF199C73);
  static const Color warning = Color(0xFFFFA84D);
  static const Color danger = Color(0xFFF25E76);
  static const Color surface = Color(0xFFF5FBFF);
  static const Color glass = Color(0x66FFFFFF);
  static const Color glassStrong = Color(0xCCFFFFFF);
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6FCFF), Color(0xFFE8F8FF), Color(0xFFF4FFFE)],
  );

  static List<BoxShadow> shadows({double opacity = 0.12}) => [
    BoxShadow(
      color: accentDeep.withValues(alpha: opacity),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: opacity * 0.85),
      blurRadius: 18,
      offset: const Offset(-4, -4),
    ),
  ];
}

Duration tronclassMotionDuration(
  BuildContext context, {
  Duration fallback = const Duration(milliseconds: 220),
}) {
  final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations;
  return disableAnimations == true ? Duration.zero : fallback;
}

class TronclassGlassBackground extends StatelessWidget {
  const TronclassGlassBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TronclassGlassPalette.pageGradient,
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -110,
            left: -40,
            child: _GlowBubble(
              size: 230,
              colors: [Color(0x88B5F0FF), Color(0x00B5F0FF)],
            ),
          ),
          const Positioned(
            top: 160,
            right: -70,
            child: _GlowBubble(
              size: 250,
              colors: [Color(0x6682E4FF), Color(0x00A7F3D0)],
            ),
          ),
          const Positioned(
            bottom: -60,
            left: -30,
            child: _GlowBubble(
              size: 220,
              colors: [Color(0x66C4FFF0), Color(0x00C4FFF0)],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class TronclassGlassCard extends StatelessWidget {
  const TronclassGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.onTap,
    this.tintColor,
    this.blurSigma = 18,
    this.boxShadows,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final Color? tintColor;
  final double blurSigma;
  final List<BoxShadow>? boxShadows;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tintColor ?? TronclassGlassPalette.glassStrong).withValues(
                    alpha: 0.92,
                  ),
                  (tintColor ?? TronclassGlassPalette.glass).withValues(
                    alpha: 0.68,
                  ),
                ],
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadows ?? TronclassGlassPalette.shadows(),
      ),
      child: card,
    );
  }
}

class TronclassGlassPill extends StatelessWidget {
  const TronclassGlassPill({
    super.key,
    required this.label,
    this.icon,
    this.color = TronclassGlassPalette.accent,
    this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = foregroundColor ?? color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effectiveForeground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: effectiveForeground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class TronclassSectionHeader extends StatelessWidget {
  const TronclassSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: TronclassGlassPalette.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: TronclassGlassPalette.mutedText,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class TronclassGlassIconOrb extends StatelessWidget {
  const TronclassGlassIconOrb({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Icon(icon, color: color),
    );
  }
}

ButtonStyle tronclassPrimaryButtonStyle(
  BuildContext context, {
  Color color = TronclassGlassPalette.accent,
  Color foregroundColor = Colors.white,
}) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: foregroundColor,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}

ButtonStyle tronclassGhostButtonStyle(
  BuildContext context, {
  Color foregroundColor = TronclassGlassPalette.text,
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: foregroundColor,
    side: BorderSide(
      color: TronclassGlassPalette.accent.withValues(alpha: 0.18),
    ),
    backgroundColor: Colors.white.withValues(alpha: 0.4),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }
}
