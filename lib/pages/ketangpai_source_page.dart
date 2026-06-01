import 'package:flutter/material.dart';

import '../models/course.dart';
import 'ketangpai_content_browser.dart';

class KetangpaiSourcePage extends StatelessWidget {
  const KetangpaiSourcePage({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return KetangpaiContentBrowser(
      course: course,
      kind: KetangpaiContentKind.source,
      title: '资料',
    );
  }
}
