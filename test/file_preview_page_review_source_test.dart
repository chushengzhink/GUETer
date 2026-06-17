import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file preview exposes split-to-review-card action', () {
    final source = File('lib/pages/file_preview_page.dart').readAsStringSync();

    expect(source, contains('onCreateStudyCards'));
    expect(source, contains('拆分成复习卡'));
    expect(source, contains('_createStudyCardsFromText'));
  });
}
