import 'package:course_helper/api/tronclass_sign_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TronclassSignApi.normalizeSignResponseData', () {
    test('keeps map responses', () {
      final data = TronclassSignApi.normalizeSignResponseData({
        'status': 'on_call',
      });

      expect(data, isA<Map<String, dynamic>>());
      expect(data['status'], 'on_call');
    });

    test('decodes json string responses', () {
      final data = TronclassSignApi.normalizeSignResponseData(
        '{"message":"wrongNumberCode"}',
      );

      expect(data, isA<Map<String, dynamic>>());
      expect(data['message'], 'wrongNumberCode');
      expect(TronclassSignApi.getSignMessage(data), '签到密码错误，请重试');
    });

    test('maps unknown student business failure', () {
      expect(
        TronclassSignApi.getSignMessage({'message': 'unknown_student'}),
        '您还不是本课学生，请先加入课程',
      );
    });

    test('detects QR code expired response', () {
      expect(
        TronclassSignApi.isQrCodeExpired({'message': 'QR_code_expired'}),
        isTrue,
      );
      expect(
        TronclassSignApi.isQrCodeExpired({'message': 'unknown_student'}),
        isFalse,
      );
    });

    test('turns html string into friendly failure', () {
      final data = TronclassSignApi.normalizeSignResponseData(
        '<html><body>login</body></html>',
      );

      expect(data, isA<Map<String, dynamic>>());
      expect(data['message'], contains('非 JSON'));
      expect(TronclassSignApi.getSignMessage(data), contains('可能登录态失效'));
    });

    test('turns null into friendly failure', () {
      final data = TronclassSignApi.normalizeSignResponseData(null);

      expect(data, isA<Map<String, dynamic>>());
      expect(data['message'], contains('空响应'));
    });
  });
}
