import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/pages/tronclass_todo_detail_page.dart';
import 'package:course_helper/platform.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ApiService.resetForTests();
    await ApiService.initialize();
    PlatformManager().setPlatformSync(PlatformType.tronclass);
    ApiService.debugCredentialValidatorOverride = (_) async => true;
  });

  tearDown(() {
    ApiService.resetForTests();
    PlatformManager().setPlatformSync(PlatformType.chaoxing);
  });

  testWidgets('file upload homework renders attachment submission controls', (
    tester,
  ) async {
    ApiService.debugSendRequestOverride =
        (
          url, {
          required String method,
          Map<String, String>? params,
          Map<String, String>? headers,
          dynamic body,
          ResponseType responseType = ResponseType.json,
          bool allowRedirects = true,
          bool skipCredentialValidation = false,
        }) async {
          expect(url, '/api/activities/78820');
          return Response<dynamic>(
            requestOptions: RequestOptions(path: url),
            statusCode: 200,
            data: <String, dynamic>{
              'id': 78820,
              'data': <String, dynamic>{
                'homework_type': 'file_upload',
                'description': '<p>upload files</p>',
                'score_percentage': '0.0',
              },
            },
          );
        };

    await tester.pumpWidget(
      MaterialApp(
        home: TronclassTodoDetailPage(
          todo: const <String, dynamic>{
            'id': 78820,
            'type': 'homework',
            'title': 'File homework',
            'course_name': 'Economics',
            'end_time': '2026-06-17T15:59:00Z',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('提交附件'), findsOneWidget);
    expect(find.text('选择文件'), findsOneWidget);
    expect(find.text('选择照片'), findsOneWidget);
    expect(find.text('选择视频'), findsOneWidget);
    expect(find.text('尚未选择附件'), findsOneWidget);
    expect(find.textContaining('暂未实现'), findsNothing);

    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '提交作业'),
    );
    expect(submitButton.onPressed, isNull);
  });
}
