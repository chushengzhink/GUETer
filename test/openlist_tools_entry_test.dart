import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OpenList cloud entry is an independent tools category', () {
    final source = File('lib/pages/tools_page.dart').readAsStringSync();

    expect(source, contains("id: 'cloud'"));
    expect(source, contains("id: 'openlist-cloud'"));
    expect("'openlist-cloud'".allMatches(source), hasLength(1));

    final cloudIndex = source.indexOf("id: 'cloud'");
    final campusIndex = source.indexOf("id: 'campus'");
    final openListIndex = source.indexOf("id: 'openlist-cloud'");

    expect(cloudIndex, isNonNegative);
    expect(campusIndex, isNonNegative);
    expect(openListIndex, greaterThan(cloudIndex));
    expect(openListIndex, lessThan(campusIndex));
  });
}
