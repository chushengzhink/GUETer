import 'package:flutter/material.dart';

import '../models/course.dart';
import 'ketangpai_content_browser.dart';

class KetangpaiTopicPage extends StatelessWidget {
  const KetangpaiTopicPage({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return KetangpaiContentBrowser(
      course: course,
      kind: KetangpaiContentKind.topic,
      title: '话题',
    );
  }
}
