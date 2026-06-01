import 'package:flutter/material.dart';

import '../models/course.dart';
import 'ketangpai_content_browser.dart';

class KetangpaiAnnouncementPage extends StatelessWidget {
  const KetangpaiAnnouncementPage({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return KetangpaiContentBrowser(
      course: course,
      kind: KetangpaiContentKind.announcement,
      title: '公告',
    );
  }
}
