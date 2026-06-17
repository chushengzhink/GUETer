import 'package:course_helper/smart/smart_tagger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suggests stable local tags from common study signals', () {
    const tagger = SmartTagger();

    final tags = tagger.suggestTags(
      title: '期末考试重点公式.pdf',
      text: '作业、定理证明和积分公式总结',
      path: 'C:/docs/final.pdf',
    );

    expect(tags, containsAll(<String>['考试', '作业', '公式', '重点', 'PDF']));
  });

  test('recognizes web, OCR, code and output sources', () {
    const tagger = SmartTagger();

    final tags = tagger.suggestTags(
      title: 'GitHub Dart 代码说明',
      path: 'https://github.com/example/repo',
      sourceLabel: 'OCR 输出',
      isWebArchive: true,
      isOcr: true,
      isOutput: true,
    );

    expect(tags, containsAll(<String>['代码', '网页资料', 'OCR', '输出']));
  });
}
