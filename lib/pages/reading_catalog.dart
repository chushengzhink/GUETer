import 'package:flutter/material.dart';

class ReadingBookEntry {
  const ReadingBookEntry({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final String assetPath;
  final IconData icon;
  final List<Color> colors;
}

const List<ReadingBookEntry> readingBooks = <ReadingBookEntry>[
  ReadingBookEntry(
    title: '上海交通大学生存手册',
    subtitle: '随安装包内置的 PDF',
    assetPath: 'pdf/上海交通大学生存手册.pdf',
    icon: Icons.menu_book_rounded,
    colors: <Color>[Color(0xFF2D7C90), Color(0xFF58A39A)],
  ),
];