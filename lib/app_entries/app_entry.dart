import 'package:flutter/material.dart';

class AppEntry {
  const AppEntry({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.icon,
    required this.builder,
    this.subtitleZh = '',
    this.subtitleEn = '',
    this.tags = const <String>[],
    this.badge,
    this.priority = 0,
    this.enabled = true,
  });

  final String id;
  final String titleZh;
  final String titleEn;
  final String subtitleZh;
  final String subtitleEn;
  final IconData icon;
  final WidgetBuilder builder;
  final List<String> tags;
  final String? badge;
  final int priority;
  final bool enabled;

  String titleFor(Locale locale) {
    return locale.languageCode == 'en' ? titleEn : titleZh;
  }

  String subtitleFor(Locale locale) {
    return locale.languageCode == 'en' ? subtitleEn : subtitleZh;
  }
}

class ToolEntry {
  const ToolEntry({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    required this.subtitleZh,
    required this.subtitleEn,
    required this.icon,
    required this.color,
    required this.categoryId,
    required this.categoryZh,
    required this.categoryEn,
    required this.categorySubtitleZh,
    required this.categorySubtitleEn,
    required this.categoryIcon,
    required this.categoryColor,
    required this.onTap,
    this.tags = const <String>[],
    this.badge,
    this.priority = 0,
    this.enabled = true,
  });

  final String id;
  final String titleZh;
  final String titleEn;
  final String subtitleZh;
  final String subtitleEn;
  final IconData icon;
  final Color color;
  final String categoryId;
  final String categoryZh;
  final String categoryEn;
  final String categorySubtitleZh;
  final String categorySubtitleEn;
  final IconData categoryIcon;
  final Color categoryColor;
  final VoidCallback? onTap;
  final List<String> tags;
  final String? badge;
  final int priority;
  final bool enabled;

  String titleFor(Locale locale) {
    return locale.languageCode == 'en' ? titleEn : titleZh;
  }

  String subtitleFor(Locale locale) {
    return locale.languageCode == 'en' ? subtitleEn : subtitleZh;
  }

  String categoryFor(Locale locale) {
    return locale.languageCode == 'en' ? categoryEn : categoryZh;
  }

  String categorySubtitleFor(Locale locale) {
    return locale.languageCode == 'en'
        ? categorySubtitleEn
        : categorySubtitleZh;
  }
}
