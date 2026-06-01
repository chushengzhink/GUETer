import 'dart:ui';

import 'package:flutter/material.dart';

import 'ketangpai_course_tokens.dart';

class KetangpaiShowcaseBackground extends StatelessWidget {
  const KetangpaiShowcaseBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(decoration: BoxDecoration(color: palette.background)),
          Positioned(
            top: -90,
            right: -40,
            child: _GlowOrb(
              size: 220,
              colors: [palette.glowA, Colors.transparent],
            ),
          ),
          Positioned(
            top: 260,
            left: -50,
            child: _GlowOrb(
              size: 180,
              colors: [palette.glowB, Colors.transparent],
            ),
          ),
          Positioned(
            bottom: -80,
            right: -10,
            child: _GlowOrb(
              size: 210,
              colors: [palette.accentSoft, Colors.transparent],
            ),
          ),
          Positioned.fill(child: Padding(padding: padding, child: child)),
        ],
      ),
    );
  }
}

class KetangpaiHeroPanel extends StatelessWidget {
  const KetangpaiHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.badges = const <Widget>[],
    this.stats = const <Widget>[],
    this.primaryAction,
    this.secondaryAction,
    this.trailing,
    this.backgroundImageUrl,
    this.minHeight = 250,
    this.padding = const EdgeInsets.all(24),
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> badges;
  final List<Widget> stats;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? trailing;
  final String? backgroundImageUrl;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return Container(
      height: minHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KetangpaiCourseTokens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KetangpaiCourseTokens.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(gradient: palette.heroGradient),
            ),
            if ((backgroundImageUrl ?? '').isNotEmpty)
              Image.network(
                backgroundImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -28,
              right: -18,
              child: _GlowOrb(
                size: 130,
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.transparent,
                ],
              ),
            ),
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          eyebrow,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      // ignore: use_null_aware_elements
                      if (trailing case final trailing?) trailing,
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 0.96,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 10, runSpacing: 10, children: badges),
                  ],
                  if (primaryAction != null || secondaryAction != null) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        // ignore: use_null_aware_elements
                        if (primaryAction case final primaryAction?)
                          primaryAction,
                        // ignore: use_null_aware_elements
                        if (secondaryAction case final secondaryAction?)
                          secondaryAction,
                      ],
                    ),
                  ],
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(spacing: 12, runSpacing: 12, children: stats),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KetangpaiStatBadge extends StatelessWidget {
  const KetangpaiStatBadge({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    final accent = highlight ? palette.accent : Colors.white;
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: highlight ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: highlight ? 0.3 : 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: accent),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class KetangpaiActionButton extends StatelessWidget {
  const KetangpaiActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    final foregroundColor = filled ? Colors.white : palette.textPrimary;
    final backgroundColor = filled
        ? palette.accent
        : Colors.white.withValues(alpha: 0.82);
    final borderColor = filled
        ? palette.accent
        : Colors.white.withValues(alpha: 0.4);

    return _KetangpaiPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: ketangpaiMotionDuration(context),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foregroundColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KetangpaiToolTile extends StatelessWidget {
  const KetangpaiToolTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.kicker,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? kicker;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return _KetangpaiPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KetangpaiCourseTokens.panelRadius),
      child: AnimatedContainer(
        duration: ketangpaiMotionDuration(context),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: palette.panelGradient,
          borderRadius: BorderRadius.circular(
            KetangpaiCourseTokens.panelRadius,
          ),
          border: Border.all(color: palette.stroke),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor.withValues(alpha: 0.6),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.strokeStrong),
              ),
              child: Icon(icon, color: palette.accent),
            ),
            const Spacer(),
            if ((kicker ?? '').isNotEmpty) ...[
              Text(
                kicker!,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KetangpaiCoursePanel extends StatelessWidget {
  const KetangpaiCoursePanel({
    super.key,
    required this.title,
    required this.teacher,
    required this.subtitle,
    required this.onTap,
    this.meta = const <String>[],
    this.imageUrl,
    this.badge,
    this.stateLabel,
  });

  final String title;
  final String teacher;
  final String subtitle;
  final VoidCallback onTap;
  final List<String> meta;
  final String? imageUrl;
  final String? badge;
  final String? stateLabel;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return _KetangpaiPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KetangpaiCourseTokens.cardRadius),
      child: AnimatedContainer(
        duration: ketangpaiMotionDuration(context),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: palette.panelGradient,
          borderRadius: BorderRadius.circular(KetangpaiCourseTokens.cardRadius),
          border: Border.all(color: palette.stroke),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor.withValues(alpha: 0.56),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CourseCover(title: title, imageUrl: imageUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((badge ?? '').isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 2, right: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: palette.accentStrong,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.02,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    teacher,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final item in meta)
                          _InlineTag(
                            label: item,
                            color: palette.textMuted,
                            backgroundColor: palette.surfaceMuted,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((stateLabel ?? '').isNotEmpty)
                  _InlineTag(
                    label: stateLabel!,
                    color: palette.success,
                    backgroundColor: palette.success.withValues(alpha: 0.12),
                  ),
                const SizedBox(height: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: palette.textMuted,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class KetangpaiSegmentedNav extends StatelessWidget {
  const KetangpaiSegmentedNav({
    super.key,
    required this.titles,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<String> titles;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: titles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = index == currentIndex;
          return _KetangpaiPressable(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: ketangpaiMotionDuration(context),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? palette.textPrimary : palette.surfaceStrong,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? palette.textPrimary : palette.stroke,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: palette.shadowColor.withValues(alpha: 0.42),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  titles[index],
                  style: TextStyle(
                    color: selected ? palette.surfaceStrong : palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class KetangpaiEmptyStage extends StatelessWidget {
  const KetangpaiEmptyStage({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: palette.stageGradient,
        borderRadius: BorderRadius.circular(KetangpaiCourseTokens.cardRadius),
        border: Border.all(color: palette.stroke),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(alpha: 0.56),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: palette.strokeStrong),
            ),
            child: Icon(icon, size: 32, color: palette.accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          KetangpaiActionButton(
            label: actionLabel,
            icon: Icons.refresh_rounded,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class KetangpaiContentStage extends StatelessWidget {
  const KetangpaiContentStage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: palette.stageGradient,
        borderRadius: BorderRadius.circular(KetangpaiCourseTokens.stageRadius),
        border: Border.all(color: palette.stroke),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor.withValues(alpha: 0.52),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KetangpaiCourseTokens.stageRadius),
        child: child,
      ),
    );
  }
}

class KetangpaiStatementActionTile extends StatelessWidget {
  const KetangpaiStatementActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    return _KetangpaiPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KetangpaiCourseTokens.panelRadius),
      child: AnimatedContainer(
        duration: ketangpaiMotionDuration(context),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surfaceStrong.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(
            KetangpaiCourseTokens.panelRadius,
          ),
          border: Border.all(color: palette.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: palette.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_outward_rounded,
              color: palette.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class KetangpaiGhostIconButton extends StatelessWidget {
  const KetangpaiGhostIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = _KetangpaiPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );

    if ((tooltip ?? '').isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }
}

class _CourseCover extends StatelessWidget {
  const _CourseCover({required this.title, required this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = KetangpaiCoursePalette.of(context);
    final normalized = (imageUrl ?? '').trim();
    final fallback = title.isEmpty ? '课' : title.substring(0, 1);

    return Container(
      width: 88,
      height: 116,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.textPrimary,
            palette.textPrimary.withValues(alpha: 0.72),
            palette.accentStrong,
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (normalized.isNotEmpty)
              Image.network(
                normalized,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(
                      alpha: normalized.isNotEmpty ? 0.34 : 0.0,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                normalized.isNotEmpty ? title : fallback,
                maxLines: normalized.isNotEmpty ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  const _InlineTag({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class _KetangpaiPressable extends StatefulWidget {
  const _KetangpaiPressable({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  @override
  State<_KetangpaiPressable> createState() => _KetangpaiPressableState();
}

class _KetangpaiPressableState extends State<_KetangpaiPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final duration = ketangpaiMotionDuration(context);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: AnimatedScale(
          duration: duration,
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.985 : 1,
          child: AnimatedOpacity(
            duration: duration,
            curve: Curves.easeOutCubic,
            opacity: _pressed ? 0.94 : 1,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.colors});

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
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
