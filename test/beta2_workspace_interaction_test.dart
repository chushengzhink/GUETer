import 'dart:async';
import 'dart:convert';
import 'package:course_helper/api/api_service.dart';
import 'package:course_helper/controllers/account_context_controller.dart';
import 'package:course_helper/controllers/sign_task_controller.dart';
import 'package:course_helper/features/courses/course_workspace.dart';
import 'package:course_helper/models/course.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/pages/my_page.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/session/cookie.dart';
import 'package:course_helper/session/sign_execution_context.dart';
import 'package:course_helper/theme/app_theme.dart';
import 'package:course_helper/theme/theme_style.dart';
import 'package:course_helper/widgets/account_context_header.dart';
import 'package:course_helper/widgets/sign_task_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

User fixtureUser(String id) => User(
  uid: id,
  name: 'Student $id',
  studentId: '2026$id',
  avatar: '',
  phone: '',
  school: 'GUET',
);
final fixtureCourses = List.generate(
  10,
  (i) => Course(
    courseId: '$i',
    classId: 'class',
    name: 'Course $i',
    teacher: 'Teacher $i',
    image: '',
    state: true,
  ),
);

Widget app(
  Widget page, {
  bool dark = false,
  bool en = false,
  double scale = 1,
}) => MaterialApp(
  locale: Locale(en ? 'en' : 'zh'),
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: buildAppTheme(
    ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: dark ? Brightness.dark : Brightness.light,
    ),
    'default',
    ThemeStyleData.modern,
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);

Widget workspace(
  String id,
  CourseWorkspaceMemory memory, {
  VoidCallback? scan,
  ValueChanged<Course>? open,
  bool refreshing = false,
}) => Scaffold(
  appBar: AppBar(title: const Text('GUETer')),
  body: CourseWorkspace(
    key: ValueKey(id),
    contextId: id,
    memory: memory,
    courses: fixtureCourses,
    refreshing: refreshing,
    header: AccountContextHeader(
      platform: PlatformType.chaoxing,
      account: fixtureUser(id),
      site: '',
      onPlatform: (_) {},
      onAccount: () {},
    ),
    onScan: scan ?? () {},
    onOther: () {},
    onOpen: open ?? (_) {},
    onRefresh: () async {},
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'pins and recently opened courses persist per identity; search survives return',
    (tester) async {
      final a = CourseWorkspaceMemory(), b = CourseWorkspaceMemory();
      String? opened;
      await tester.pumpWidget(
        app(workspace('A', a, open: (c) => opened = c.courseId)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('置顶课程').at(1));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Course 1')).dy,
        lessThan(tester.getTopLeft(find.text('Course 0')).dy),
      );
      await tester.tap(find.text('Course 0'));
      await tester.pumpAndSettle();
      expect(opened, '0');
      await tester.enterText(find.byType(TextField), 'Teacher 1');
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(workspace('B', b)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消置顶'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await tester.pumpWidget(app(workspace('A', a, refreshing: true)));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Teacher 1',
      );
      expect(find.byTooltip('取消置顶'), findsOneWidget);
      expect(find.text('Course 1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(prefs.getString('course_workspace_preferences_v1_A')!)
              as Map;
      expect(saved['recent'], isNotEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'account switch is two taps; platform tap restores its saved account',
    (tester) async {
      await tester.runAsync(() async {
        ApiService.resetForTests();
        CookieManager.resetForTests();
        await ApiService.initialize();
        await PlatformManager().initialize();
        await AccountManager.initialize();
        await CookieManager.initialize();
        for (final user in [fixtureUser('A'), fixtureUser('B')]) {
          await AccountManager.addAccountForPlatformName(
            'chaoxing',
            user,
            notify: false,
            migrateTempCookies: false,
          );
        }
        await AccountManager.addAccountForPlatformName(
          'rainclassroom',
          fixtureUser('R').copyWith(platform: 'rainclassroom'),
          notify: false,
          migrateTempCookies: false,
        );
        await AccountManager.setCurrentSessionForPlatformName(
          'chaoxing',
          'A',
          notify: false,
        );
        await AccountManager.setCurrentSessionForPlatformName(
          'rainclassroom',
          'R',
          notify: false,
        );
      });
      final controller = AccountContextController.instance;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => ListenableBuilder(
                listenable: controller,
                builder: (context, _) => AccountContextHeader(
                  platform:
                      controller.target?.platform ??
                      PlatformManager().currentPlatform,
                  account: AccountManager.currentAccount,
                  site: '',
                  switching: controller.switching,
                  onPlatform: (platform) => controller.select(platform),
                  onAccount: () => selectAccountFromSheet(context),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('current-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student B'));
      await tester.pumpAndSettle();
      expect(AccountManager.currentSessionId, 'B');
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byKey(const ValueKey('platform-rainClassroom')));
      await tester.pumpAndSettle();
      expect(AccountManager.currentAccount?.uid, 'R');
      await tester.tap(find.byKey(const ValueKey('platform-chaoxing')));
      await tester.pumpAndSettle();
      expect(AccountManager.currentAccount?.uid, 'B');
      await tester.pumpWidget(const SizedBox());
      ApiService.resetForTests();
      CookieManager.resetForTests();
    },
  );

  testWidgets(
    'running task survives minimize, route change and reopening once',
    (tester) async {
      final controller = SignTaskController.instance;
      controller.dismissCompleted();
      final gate = Completer<void>();
      var calls = 0;
      final ctx = SignExecutionContext(
        platform: PlatformType.chaoxing,
        account: fixtureUser('A'),
        server: RainClassroomServerType.yuketang,
        tronclassBaseUrl: 'https://school.test',
        ketangpaiBaseUrl: 'https://kt.test',
      );
      final run = controller.run(
        identity: ctx,
        operation: '123',
        label: 'Course 1',
        action: () async {
          calls++;
          await gate.future;
        },
      );
      await tester.pumpWidget(
        app(const Scaffold(bottomNavigationBar: SignTaskDock())),
      );
      await tester.tap(find.text('签到进行中'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Student A'), findsWidgets);
      await tester.tap(find.byTooltip('收起'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(
        app(
          const Scaffold(body: MyPage(), bottomNavigationBar: SignTaskDock()),
        ),
      );
      await tester.pump();
      expect(controller.hasRunning, isTrue);
      gate.complete();
      await run;
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看签到结果'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Student A'), findsWidgets);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dismissCompleted();
    },
  );

  for (final width in [360.0, 412.0, 600.0]) {
    for (final dark in [false, true]) {
      for (final en in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'check-in first screen $width dark=$dark en=$en scale=$scale',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 800);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              var scans = 0;
              await tester.pumpWidget(
                app(
                  workspace('A', CourseWorkspaceMemory(), scan: () => scans++),
                  dark: dark,
                  en: en,
                  scale: scale,
                ),
              );
              await tester.pumpAndSettle();
              final button = find.byKey(const ValueKey('workspace-scan'));
              expect(tester.getBottomRight(button).dy, lessThan(800));
              expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
              await tester.tap(button);
              expect(scans, 1);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(
                app(const MyPage(), dark: dark, en: en, scale: scale),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
