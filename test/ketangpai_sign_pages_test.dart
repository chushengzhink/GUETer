import 'package:course_helper/api/ketangpai_service.dart';
import 'package:course_helper/controllers/sign_controller.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/pages/ketangpai_gps_sign_dialog.dart';
import 'package:course_helper/pages/ketangpai_number_sign_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

User _ketangpaiUser() {
  return User(
    name: '课堂派用户',
    avatar: '',
    phone: '',
    uid: 'kt-user',
    school: '',
    platform: 'ketangpai',
    token: 'token',
  );
}

SignController _fakeSignController({
  void Function(String signId, String code)? onNumberSign,
  void Function(String signId, String latitude, String longitude)? onGpsSign,
}) {
  return SignController(
    accountProvider: () => _ketangpaiUser(),
    recordAppender: (_) async {},
    notifier: (_, _, _) {},
    numberSignRequest:
        ({
          required token,
          required signId,
          required rawQr,
          required code,
          required latitude,
          required longitude,
          required accuracy,
        }) async {
          onNumberSign?.call(signId, code);
          return const KetangpaiServiceResult<Map<String, dynamic>>(
            success: true,
            message: 'ok',
            data: <String, dynamic>{},
          );
        },
    gpsSignRequest:
        ({
          required token,
          required signId,
          required rawQr,
          required code,
          required latitude,
          required longitude,
          required accuracy,
        }) async {
          onGpsSign?.call(signId, latitude, longitude);
          return const KetangpaiServiceResult<Map<String, dynamic>>(
            success: true,
            message: 'ok',
            data: <String, dynamic>{},
          );
        },
  );
}

Future<T?> _pushPage<T>(WidgetTester tester, Widget page) async {
  T? result;
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(
                  context,
                ).push<T>(MaterialPageRoute(builder: (_) => page));
              },
              child: const Text('open'),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  tearDown(() {
    Get.reset();
  });

  group('KetangpaiNumberSignPage', () {
    testWidgets('default mode returns pin to caller', (tester) async {
      String? result;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const KetangpaiNumberSignPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, '1234');
      await tester.pumpAndSettle();

      expect(result, '1234');
    });

    testWidgets('direct mode calls SignController and does not pop', (
      tester,
    ) async {
      String? calledSignId;
      String? calledCode;
      final controller = _fakeSignController(
        onNumberSign: (signId, code) {
          calledSignId = signId;
          calledCode = code;
        },
      );

      await _pushPage<String>(
        tester,
        KetangpaiNumberSignPage(
          signId: 'sign-1',
          directSubmit: true,
          signController: controller,
        ),
      );
      await tester.enterText(find.byType(EditableText).first, '5678');
      await tester.pumpAndSettle();

      expect(calledSignId, 'sign-1');
      expect(calledCode, '5678');
      expect(find.text('数字签到'), findsOneWidget);
    });
  });

  group('KetangpaiGpsSignDialog', () {
    testWidgets('default mode returns GPS config', (tester) async {
      KetangpaiGpsSignConfig? result;
      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await KetangpaiGpsSignDialog.show(context);
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(result?.latitude, '25.3');
      expect(result?.longitude, '110.4');
      expect(result?.accuracy, '100');
    });

    testWidgets('direct mode validates invalid coordinates before request', (
      tester,
    ) async {
      var requested = false;
      final controller = _fakeSignController(
        onGpsSign: (_, _, _) {
          requested = true;
        },
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    KetangpaiGpsSignDialog.show(
                      context,
                      signId: 'sign-1',
                      directSubmit: true,
                      signController: controller,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '25.3'), '120');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(requested, isFalse);
      expect(find.text('请输入有效的经纬度和精度'), findsOneWidget);
    });

    testWidgets('direct mode submits valid coordinates through controller', (
      tester,
    ) async {
      String? calledSignId;
      String? calledLatitude;
      String? calledLongitude;
      final controller = _fakeSignController(
        onGpsSign: (signId, latitude, longitude) {
          calledSignId = signId;
          calledLatitude = latitude;
          calledLongitude = longitude;
        },
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    KetangpaiGpsSignDialog.show(
                      context,
                      signId: 'sign-2',
                      directSubmit: true,
                      signController: controller,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(calledSignId, 'sign-2');
      expect(calledLatitude, '25.3');
      expect(calledLongitude, '110.4');
    });
  });
}
