import 'package:course_helper/utils/tronclass_qr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TronclassQrParser', () {
    test('parses direct query with rollcallId and data', () {
      final parsed = TronclassQrParser.parse(
        'https://courses.guet.edu.cn/j?rollcallId=123&data=abc',
      );

      expect(parsed, isNotNull);
      expect(parsed!['rollcallId'], '123');
      expect(parsed['data'], 'abc');
    });

    test('normalizes rcode as data', () {
      final parsed = TronclassQrParser.parse(
        'https://courses.guet.edu.cn/j?rollcallId=123&rcode=payload',
      );

      expect(parsed, isNotNull);
      expect(parsed!['rollcallId'], '123');
      expect(parsed['data'], 'payload');
    });

    test('parses but exposes missing data for caller validation', () {
      final parsed = TronclassQrParser.parse(
        'https://courses.guet.edu.cn/j?rollcallId=123',
      );

      expect(parsed, isNotNull);
      expect(parsed!['rollcallId'], '123');
      expect(parsed['data'], isNull);
    });

    test('returns null for non-tronclass text', () {
      expect(TronclassQrParser.parse('not a tronclass qr'), isNull);
    });
  });
}
