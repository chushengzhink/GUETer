import 'package:flutter/material.dart';

import '../models/course.dart';
import 'ketangpai_content_browser.dart';

class KetangpaiCourseWarePage extends StatelessWidget {
  const KetangpaiCourseWarePage({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return KetangpaiContentBrowser(
      course: course,
      kind: KetangpaiContentKind.courseWare,
      title: '课件',
    );
  }
}
