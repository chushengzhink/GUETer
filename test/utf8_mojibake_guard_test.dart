import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib source does not contain known Chinese mojibake fragments', () {
    final roots = <Directory>[
      Directory('lib'),
      Directory('lib/l10n'),
    ];
    final blockedFragments = <String>[
      '瀛︿範',
      '浠诲姟',
      '浣滀笟',
      '娲诲姩',
      '绔犺妭',
      '婢惰精',
      '濠㈡儼',
      '濞戞搩',
      '宸插彂',
      '瀹告彃',
      '寮傚父锛',
      '澶辫触',
      '璐﹀彿',
      '璋冭瘯',
      '淇℃伅',
      '杈撳嚭',
      '鏂囦欢',
      '浜戠洏',
      '绱㈠紩',
    ];
    final offenders = <String>[];

    for (final root in roots) {
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (!path.endsWith('.dart') && !path.endsWith('.arb')) continue;
        final text = entity.readAsStringSync();
        for (final fragment in blockedFragments) {
          if (text.contains(fragment)) {
            offenders.add('$path contains $fragment');
          }
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
