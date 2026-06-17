import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/pages/request_console_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(ApiService.resetForTests);
  tearDown(ApiService.resetForTests);

  testWidgets('opens on logs tab and shows compact log list', (tester) async {
    ApiService.appendExternalConsoleLog(
      'openlist',
      'connection timeout while listing a very long directory payload with '
          '${'token'}=secret, ${'sessionId'}=hidden, '
          '${['10', '1', '2', '3'].join('.')}:${'52'}45',
    );

    await tester.pumpWidget(const MaterialApp(home: RequestConsolePage()));
    await tester.pump();

    expect(find.widgetWithText(Tab, '日志'), findsOneWidget);
    expect(find.widgetWithText(Tab, '诊断'), findsOneWidget);
    expect(find.text('共 1 条'), findsOneWidget);
    expect(find.text('失败 1'), findsOneWidget);
    expect(find.textContaining('<private-host>'), findsOneWidget);
    expect(find.textContaining('token=<redacted>'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    expect(find.text('日志详情'), findsNothing);
  });

  testWidgets('opens readable log detail sheet and copies single log', (
    tester,
  ) async {
    ApiService.appendExternalConsoleLog(
      'tronclass',
      '登录失败 ${'cookie'}=abc, ${'token'}=def, ${'sessionId'}=ghi, '
          '${'25005'}${'20215'} repeated detail repeated detail repeated detail',
    );

    await tester.pumpWidget(const MaterialApp(home: RequestConsolePage()));
    await tester.pump();

    await tester.tap(find.textContaining('登录失败'));
    await tester.pumpAndSettle();

    expect(find.text('日志详情'), findsOneWidget);
    expect(find.text('复制本条'), findsOneWidget);
    expect(find.text('关闭'), findsWidgets);
    expect(find.textContaining('cookie=<redacted>'), findsWidgets);
    expect(find.textContaining('abc'), findsNothing);
    expect(find.textContaining('def'), findsNothing);
    expect(find.textContaining('<id>'), findsWidgets);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  test('keeps QQ login diagnostic fields while redacting token values', () {
    final sanitized = ApiService.sanitizeConsoleLogText(
      '[qqLogin] authCodeComplete identityExchangeOk=true '
      'portalLoginOk=true sessionPersistable=true access_token=secret',
    );

    expect(sanitized, contains('identityExchangeOk=true'));
    expect(sanitized, contains('portalLoginOk=true'));
    expect(sanitized, contains('sessionPersistable=true'));
    expect(sanitized, contains('token=<redacted>'));
    expect(sanitized, isNot(contains('access_token=secret')));
  });

  testWidgets('diagnostics tab contains health and repair sections', (
    tester,
  ) async {
    ApiService.appendExternalConsoleLog('openlist', 'OpenList request failed');

    await tester.pumpWidget(const MaterialApp(home: RequestConsolePage()));
    await tester.pump();

    await tester.tap(find.widgetWithText(Tab, '诊断'));
    await tester.pumpAndSettle();

    expect(find.text('日志'), findsWidgets);
    expect(find.text('处理建议'), findsAny);
    expect(find.text('重新检测'), findsAny);
  });

  testWidgets('platform filter changes visible log summary', (tester) async {
    ApiService.appendExternalConsoleLog('openlist', 'OpenList request failed');
    ApiService.appendExternalConsoleLog('tronclass', 'Tronclass request ok');

    await tester.pumpWidget(const MaterialApp(home: RequestConsolePage()));
    await tester.pump();

    expect(find.text('共 2 条'), findsOneWidget);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is FilterChip &&
            widget.label is Text &&
            (widget.label as Text).data == 'OpenList',
      ),
    );
    await tester.pump();

    expect(find.text('共 1 条'), findsOneWidget);
    expect(find.textContaining('OpenList request failed'), findsOneWidget);
    expect(find.textContaining('Tronclass request ok'), findsNothing);
  });
}
