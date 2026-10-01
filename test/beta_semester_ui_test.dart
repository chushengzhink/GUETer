import 'package:flutter/services.dart';
import 'package:course_helper/theme/app_theme.dart';
import 'package:course_helper/theme/theme_style.dart';
import 'dart:async';
import 'package:course_helper/session/account.dart';
import 'package:course_helper/pages/tronclass_number_sign_page.dart';
import 'package:course_helper/pages/ketangpai_private_sign_page.dart';
import 'package:course_helper/pages/ketangpai_course_detail.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:course_helper/api/platform_read_exception.dart';
import 'package:course_helper/features/courses/course_workspace.dart';
import 'package:course_helper/models/course.dart';
import 'package:course_helper/models/tronclass_rollcalls.dart';
import 'package:course_helper/models/user.dart';
import 'package:course_helper/pages/tronclass_sign_in_list_page.dart';
import 'package:course_helper/platform.dart';
import 'package:course_helper/session/ketangpai_semester.dart';
import 'package:course_helper/widgets/account_context_header.dart';
import 'package:course_helper/widgets/ketangpai_semester_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final course = Course(
  courseId: 'c1',
  classId: '',
  name: '高等数学与应用 · Mathematics',
  teacher: '张老师',
  image: '',
  state: true,
);
final repaintKey = GlobalKey();
Widget app(
  Widget page, {
  bool dark = false,
  bool en = false,
  double scale = 1,
  List<NavigatorObserver> observers = const [],
}) => MaterialApp(
  navigatorObservers: observers,
  locale: Locale(en ? 'en' : 'zh'),
  supportedLocales: const [Locale('zh'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme:
      buildAppTheme(
        ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        'default',
        ThemeStyleData.modern,
      ).copyWith(
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: const bool.fromEnvironment('CAPTURE_BETA_UI')
                ? 'BetaUI'
                : null,
            color: dark ? Colors.white : const Color(0xff172b2a),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: ThemeData().textTheme.apply(
          fontFamily: const bool.fromEnvironment('CAPTURE_BETA_UI')
              ? 'BetaUI'
              : null,
          bodyColor: dark ? Colors.white : const Color(0xff172b2a),
          displayColor: dark ? Colors.white : const Color(0xff172b2a),
        ),
      ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: RepaintBoundary(key: repaintKey, child: child!),
  ),
  home: page,
);

Widget workspace({
  List<Course>? courses,
  bool failed = false,
  bool loading = false,
  String? message,
  Future<void> Function()? refresh,
}) => Scaffold(
  appBar: AppBar(title: const Text('签到与课程')),
  body: CourseWorkspace(
    contextId: 'fixture:2026-2027:1',
    memory: CourseWorkspaceMemory(),
    courses: courses ?? [course],
    failed: failed,
    loading: loading,
    message: message,
    semesterLabel: '2026-2027 学年 · 第一学期',
    onChangeSemester: () {},
    onRefresh: refresh ?? () async {},
    onOpen: (_) {},
    onScan: () {},
    onOther: () {},
    header: AccountContextHeader(
      platform: PlatformType.ketangpai,
      account: User(
        uid: 'MDAwMDAwMDAwMDAwLONG-ACCOUNT-IDENTIFIER-1234567890',
        studentId: '',
        name: '课堂派同学',
        avatar: '',
        phone: '',
        school: '',
      ),
      site: 'openapiv5.ketangpai.com',
      onPlatform: (_) {},
      onAccount: () {},
    ),
  ),
);

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_BETA_UI')) return;
  final boundary =
      repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('output/beta-validation');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_BETA_UI')) return;
    for (final item in [
      ('BetaUI', 'C:/Windows/Fonts/msyh.ttc'),
      (
        'MaterialIcons',
        'E:/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      final font = File(item.$2);
      if (await font.exists()) {
        await (FontLoader(item.$1)..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes())),
            ))
            .load();
      }
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AccountManager.initialize();
  });

  for (final page in <String, Widget>{
    'private attendance': const KetangpaiPrivateSignPage(),
    'course detail': KetangpaiCourseDetailPage(course: course),
  }.entries) {
    testWidgets('${page.key} exposes load failure and retry without hanging', (
      tester,
    ) async {
      await tester.pumpWidget(app(page.value));
      await tester.pumpAndSettle();
      expect(find.text('签到信息加载失败'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('签到信息加载失败'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('search count and clearing an empty match restore courses', (
    tester,
  ) async {
    await tester.pumpWidget(app(workspace()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('匹配 0 / 共 1 门'), findsOneWidget);
    expect(find.text('未找到匹配课程'), findsOneWidget);
    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();
    expect(find.text(course.name), findsOneWidget);
  });

  testWidgets(
    'failed first load is distinct from empty and refresh remains busy',
    (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        app(
          workspace(
            courses: [],
            failed: true,
            message: '网络连接失败，请检查网络后重试',
            refresh: () {
              calls++;
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('课程加载失败'), findsOneWidget);
      expect(find.text('本学期暂无课程'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('workspace-refresh')));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('workspace-refresh')))
            .onPressed,
        isNull,
      );
      final indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final duplicate = indicator.onRefresh();
      expect(calls, 1);
      gate.complete();
      await duplicate;
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'semester sheet validates input, applies once and cancels without changes',
    (tester) async {
      KetangpaiSemester? result;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await showKetangpaiSemesterPicker(
                    context,
                    const KetangpaiSemester(2026, 1),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('semester-year')), '');
      await tester.tap(find.byKey(const ValueKey('semester-apply')));
      await tester.pumpAndSettle();
      expect(find.text('请输入有效的四位年份'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('semester-year')),
        '2025',
      );
      await tester.tap(find.text('第二学期'));
      await tester.tap(find.byKey(const ValueKey('semester-apply')));
      await tester.pumpAndSettle();
      expect(result, const KetangpaiSemester(2025, 2));
      result = null;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );

  testWidgets(
    'Tronclass errors are actionable and refresh preserves existing activities',
    (tester) async {
      var calls = 0;
      final gate = Completer<RollcallsResponse>();
      final ended = Rollcalls.fromJson({
        'rollcall_id': 9,
        'course_title': '已结束课程',
        'rollcall_status': 'finished',
        'is_expired': true,
      });
      await tester.pumpWidget(
        app(
          TronclassSignInListPage(
            loadRollcalls: () async {
              calls++;
              if (calls == 1) {
                throw const PlatformReadException(PlatformReadFailure.format);
              }
              if (calls == 2) return RollcallsResponse(rollcalls: [ended]);
              return gate.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('签到列表加载失败'), findsOneWidget);
      expect(find.text('暂无签到'), findsNothing);
      await capture(tester, 'tronclass-error');
      await tester.tap(find.byTooltip('刷新签到列表'));
      await tester.pumpAndSettle();
      expect(find.text('已结束课程'), findsOneWidget);
      await tester.tap(find.text('已结束课程'));
      await tester.pumpAndSettle();
      expect(find.byType(TronclassSignInListPage), findsOneWidget);
      expect(calls, 2);
      await tester.tap(find.byTooltip('刷新签到列表'));
      await tester.pump();
      expect(find.text('已结束课程'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final duplicate = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      expect(calls, 3);
      gate.completeError(
        const PlatformReadException(PlatformReadFailure.network),
      );
      await duplicate;
      await tester.pumpAndSettle();
      expect(find.text('已结束课程'), findsOneWidget);
      expect(find.text('刷新失败，已保留原有签到列表'), findsOneWidget);
    },
  );

  testWidgets(
    'double tapping an active check-in opens one route and refreshes on return',
    (tester) async {
      final observer = _RouteCounter();
      var loads = 0;
      await tester.pumpWidget(
        app(
          TronclassSignInListPage(
            loadRollcalls: () async {
              loads++;
              return RollcallsResponse(
                rollcalls: [
                  Rollcalls.fromJson({
                    'rollcall_id': 123,
                    'course_title': 'Active math',
                    'is_number': true,
                    'rollcall_status': 'in_progress',
                  }),
                ],
              );
            },
          ),
          observers: [observer],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Active math'));
      await tester.tap(find.text('Active math'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(observer.pushes, 2);
      expect(find.byType(TronclassNumberSignPage), findsOneWidget);
      observer.navigator!.pop();
      await tester.pumpAndSettle();
      expect(loads, 2);
    },
  );

  for (final width in [360.0, 390.0, 600.0]) {
    for (final dark in [false, true]) {
      for (final en in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'course and semester UI $width dark=$dark en=$en scale=$scale',
            (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(width, 900);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              await tester.pumpWidget(
                app(workspace(), dark: dark, en: en, scale: scale),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              if (width == 390 && !en && scale == 1) {
                await capture(tester, 'courses-${dark ? 'dark' : 'light'}');
              }
              await tester.pumpWidget(
                app(
                  const Scaffold(
                    body: KetangpaiSemesterPicker(
                      selected: KetangpaiSemester(2026, 1),
                    ),
                  ),
                  dark: dark,
                  en: en,
                  scale: scale,
                ),
              );
              tester.view.viewInsets = const FakeViewPadding(bottom: 280);
              addTearDown(tester.view.resetViewInsets);
              await tester.pumpAndSettle();
              await tester.ensureVisible(
                find.byKey(const ValueKey('semester-apply')),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              expect(
                find.byKey(const ValueKey('semester-apply')).hitTestable(),
                findsOneWidget,
              );
              if (width == 390 && !dark && !en && scale == 1) {
                await capture(tester, 'semester-picker');
              }
              tester.view.resetViewInsets();
              await tester.pumpWidget(
                app(
                  TronclassSignInListPage(
                    loadRollcalls: () async => RollcallsResponse(
                      rollcalls: [
                        Rollcalls.fromJson({
                          'rollcall_id': 12,
                          'course_title': '线性代数与空间几何 · Linear algebra',
                          'is_number': true,
                          'rollcall_status': 'in_progress',
                          'created_by_name': '王老师',
                          'class_name': '2026 级计算机科学与技术',
                        }),
                      ],
                    ),
                  ),
                  dark: dark,
                  en: en,
                  scale: scale,
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              if (width == 390 && !en && scale == 1) {
                await capture(
                  tester,
                  'tronclass-list-${dark ? 'dark' : 'light'}',
                );
              }
            },
          );
        }
      }
    }
  }
}

class _RouteCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}
