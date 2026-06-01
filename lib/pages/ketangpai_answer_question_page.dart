import 'package:flutter/material.dart';

import '../models/course.dart';
import 'ketangpai_content_browser.dart';

class KetangpaiAnswerQuestionPage extends StatelessWidget {
  const KetangpaiAnswerQuestionPage({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return KetangpaiContentBrowser(
      course: course,
      kind: KetangpaiContentKind.answerQuestion,
      title: '互动答题',
    );
  }
}
