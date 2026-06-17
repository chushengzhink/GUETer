import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import './pages/accounts.dart';
import './pages/login.dart';
import './pages/reading.dart';
import './pages/settings.dart';
import './api/api_service.dart';
import './api/login.dart';
import './app_entries/app_entry.dart';
import './app_entries/app_entry_registry.dart';
import './features/openlist/openlist_repository.dart';
import './layout/layout_preferences.dart';
import './modules/airchat/ui/nearby_room_page.dart';
import './modules/local_transfer/local_transfer.dart';
import './modules/zerotier/ui/zerotier_page.dart';
import './models/course.dart';
import './models/user.dart';
import './session/cookie.dart';
import './session/account.dart';
import './session/account_events.dart';
import './session/app_settings.dart';
import './session/license_ack.dart';
import './session/startup_recovery_coordinator.dart';
import './session/tronclass_auth.dart';
import './services/update_service.dart';
import './services/home_widget_summary_service.dart';
import './services/session_health_service.dart';
import './utils/global_palette.dart';
import './platform.dart';
import './theme/design_tokens.dart';
import './theme/theme_style.dart';
import './widgets/floating_nav_bar.dart';
import './widgets/session_health_banner.dart';
import './l10n/app_localizations.dart';
import './pages/courses.dart';
import './pages/ketangpai_exam_page_v2.dart';
import './pages/ketangpai_exam_question_page_v2.dart';
import './pages/tronclass_web_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 在 release 模式下将 debugPrint 重定向到请求控制台
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      ApiService.appendExternalConsoleLog('Debug', message);
    }
  };

  // Initialize settings and api in parallel, then run platform/account/cookie chain.
  await Future.wait<void>([ApiService.initialize(), AppSettings.initialize()]);
  await ApiService.beginStartupRecoverySession(reason: 'app_launch');

  ApiService.logStartupRecovery('[Main] PlatformManager.initialize start');
  await PlatformManager().initialize();
  ApiService.logStartupRecovery('[Main] PlatformManager.initialize done');
  ApiService.logStartupRecovery('[Main] AccountManager.initialize start');
  await AccountManager.initialize();
  ApiService.logStartupRecovery('[Main] AccountManager.initialize done');
  ApiService.logStartupRecovery('[Main] CookieManager.initialize start');
  await CookieManager.initialize();
  ApiService.logStartupRecovery('[Main] CookieManager.initialize done');
  await LocalTransferModule.initialize(const LocalTransferConfig());
  unawaited(
    OpenListRepository().warmUp().then<void>((_) {}).catchError((Object error) {
      ApiService.appendExternalConsoleLog(
        'openlist',
        'startup warm-up failed: $error',
      );
    }),
  );

  registerCustomAcknowledgementLicenses();

  runApp(const MyApp());
  unawaited(HomeWidgetSummaryService().updateWidget());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(StartupRecoveryCoordinator.runAfterLaunch());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppSettings.globalColorSchemeNotifier,
      builder: (context, scheme, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettings.appThemeModeNotifier,
          builder: (context, mode, child) {
            return ValueListenableBuilder<String>(
              valueListenable: AppSettings.themeStyleNotifier,
              builder: (context, styleKey, _) {
                final palette = resolveGlobalPalette(scheme);
                final themeStyle = _getThemeStyle(styleKey);

                final lightScheme = ColorScheme.fromSeed(
                  seedColor: palette.primary,
                  primary: palette.primary,
                  secondary: palette.secondary,
                  brightness: Brightness.light,
                );
                final baseDarkScheme = ColorScheme.fromSeed(
                  seedColor: palette.primary,
                  primary: palette.primary,
                  secondary: palette.secondary,
                  brightness: Brightness.dark,
                );
                final darkScheme = scheme == AppSettings.colorSchemeNight
                    ? baseDarkScheme.copyWith(
                        primary: const Color(0xFF8FB8A8),
                        secondary: const Color(0xFF73998D),
                        surface: const Color(0xFF131A17),
                        onSurface: const Color(0xFFE3EEE8),
                        outline: const Color(0xFF385046),
                      )
                    : baseDarkScheme;

                return MaterialApp(
                  navigatorKey: LocalTransferModule.navigatorKey,
                  title: 'GUETer',
                  locale: AppSettings.currentLocale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  theme: _buildThemeData(lightScheme, scheme, themeStyle),
                  darkTheme: _buildThemeData(darkScheme, scheme, themeStyle),
                  themeMode: mode,
                  home: const MyHomePage(),
                  onGenerateRoute: _onGenerateRoute,
                  routes: {
                    '/accounts': (context) => const AccountsPage(),
                    '/anonymous-chat': (context) => const NearbyRoomPage(),
                    '/nearby-room': (context) => const NearbyRoomPage(),
                    '/login': (context) => const LoginPage(),
                    '/local-transfer': (context) => const LocalTransferPage(),
                    '/reading': (context) => const ReadingPage(),
                    '/settings': (context) => const SettingsPage(),
                    '/virtual-lan': (context) => const ZeroTierPage(),
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/exam_v2':
        final course = _courseFromArguments(settings.arguments);
        if (course == null) {
          return _invalidRoute(settings.name ?? '', '缺少课程参数 course');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => KetangpaiExamPageV2(course: course),
        );
      case '/exam_question_v2':
        final args = settings.arguments;
        if (args is! Map) {
          return _invalidRoute(settings.name ?? '', '缺少答题页参数');
        }
        final courseId = args['courseId']?.toString().trim() ?? '';
        final paperId = args['paperId']?.toString().trim() ?? '';
        if (courseId.isEmpty || paperId.isEmpty) {
          return _invalidRoute(settings.name ?? '', 'courseId 或 paperId 为空');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => KetangpaiExamQuestionPageV2(
            courseId: courseId,
            paperId: paperId,
            title: args['title']?.toString() ?? '考试作答',
            readOnly: args['readOnly'] == true,
          ),
        );
    }
    return null;
  }

  Course? _courseFromArguments(Object? arguments) {
    if (arguments is Course) {
      return arguments;
    }
    if (arguments is Map && arguments['course'] is Course) {
      return arguments['course'] as Course;
    }
    return null;
  }

  Route<dynamic> _invalidRoute(String routeName, String message) {
    return MaterialPageRoute<void>(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(title: const Text('路由参数错误')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('$routeName\n$message', textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }

  ThemeStyleData _getThemeStyle(String styleKey) {
    switch (styleKey) {
      case AppSettings.themeStyleCompact:
        return ThemeStyleData.compact;
      case AppSettings.themeStylePlayful:
        return ThemeStyleData.playful;
      case AppSettings.themeStyleMinimal:
        return ThemeStyleData.minimal;
      case AppSettings.themeStyleBold:
        return ThemeStyleData.bold;
      case AppSettings.themeStyleSoft:
        return ThemeStyleData.soft;
      case AppSettings.themeStyleModern:
      default:
        return ThemeStyleData.modern;
    }
  }

  ThemeData _buildThemeData(
    ColorScheme colorScheme,
    String scheme,
    ThemeStyleData style,
  ) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          scheme == AppSettings.colorSchemeNight &&
              colorScheme.brightness == Brightness.dark
          ? const Color(0xFF0F1512)
          : null,
      cardTheme: CardThemeData(
        elevation: style.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.cardRadius),
        ),
        color:
            scheme == AppSettings.colorSchemeNight &&
                colorScheme.brightness == Brightness.dark
            ? const Color(0xFF17201C)
            : null,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.buttonRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(style.buttonRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.inputRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.inputRadius),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(style.inputRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.chipRadius),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style.dialogRadius),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return const MainPage();
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late final SessionHealthController _sessionHealthController;
  StreamSubscription<PlatformType>? _platformSubscription;
  StreamSubscription<AccountStateSnapshot>? _accountSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionHealthController = SessionHealthController();
    _platformSubscription = PlatformManager().platformChanges.listen((
      platform,
    ) {
      unawaited(
        _sessionHealthController.checkCurrentPlatform(platform: platform),
      );
    });
    _accountSubscription = AccountChangeNotifier().accountStateChanges.listen((
      snapshot,
    ) {
      unawaited(
        _sessionHealthController.checkCurrentPlatform(
          platform: snapshot.platform,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 不在这里调用 onVisibilityChanged，避免重复触发刷新
      _checkUpdate();
      unawaited(_sessionHealthController.checkCurrentPlatform());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_platformSubscription?.cancel());
    unawaited(_accountSubscription?.cancel());
    _sessionHealthController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sessionHealthController.checkCurrentPlatform());
    }
  }

  Future<void> _checkUpdate() async {
    try {
      final shouldCheck = await AppSettings.getBool(
        AppSettings.autoCheckUpdateKey,
        true,
      );
      if (!shouldCheck) {
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final updateInfo = await UpdateService().fetchLatest();
      await UpdateAnnouncementStore().save(updateInfo.announcements);
      await UpdateCheckStatusStore().save(
        UpdateCheckStatus.fromInfo(
          currentVersion: currentVersion,
          info: updateInfo,
        ),
      );
    } catch (e) {
      // 忽略更新检查错误
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    const floatingNavBarHeight = 80.0;
    final totalBottomPadding = bottomSafeArea + floatingNavBarHeight;
    final locale = Localizations.localeOf(context);

    return ValueListenableBuilder<LayoutPreferences>(
      valueListenable: AppSettings.layoutPreferencesStore.notifier,
      builder: (context, preferences, _) {
        final allEntries = buildBuiltinAppEntries()
            .where((entry) => entry.enabled)
            .toList();
        final entryById = {for (final entry in allEntries) entry.id: entry};
        final visibleIds = preferences.visibleNavOrder(entryById.keys.toList());
        final selectedIds = visibleIds.take(5).toList();
        if (selectedIds.isEmpty) {
          selectedIds.addAll(LayoutPreferences.defaultNavOrder.take(1));
        }
        final entries = selectedIds
            .map((id) => entryById[id])
            .whereType<AppEntry>()
            .toList();
        final selectedIndex = _selectedIndex >= entries.length
            ? entries.length - 1
            : _selectedIndex;

        return Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: totalBottomPadding),
                child: IndexedStack(
                  index: selectedIndex,
                  children: entries
                      .map((entry) => entry.builder(context))
                      .toList(),
                ),
              ),
              AnimatedBuilder(
                animation: _sessionHealthController,
                builder: (context, _) {
                  final issue = _sessionHealthController.visibleIssue;
                  if (issue == null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: totalBottomPadding,
                    child: SessionHealthBanner(
                      issue: issue,
                      totalCount: _sessionHealthController.visibleIssueCount,
                      onReLogin: () => _handleReLogin(issue),
                      onDismiss: () => _sessionHealthController.dismiss(issue),
                    ),
                  );
                },
              ),
            ],
          ),
          bottomNavigationBar: FloatingNavBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
              final entryId = entries[index].id;
              (coursesPageKey.currentState as dynamic)?.onVisibilityChanged(
                entryId == 'courses',
              );
            },
            items: entries
                .map(
                  (entry) => FloatingNavBarItem(
                    icon: entry.icon,
                    label: _localizedNavLabel(entry, locale),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  String _localizedNavLabel(AppEntry entry, Locale locale) {
    final l10n = AppLocalizations.of(context)!;
    return switch (entry.id) {
      'courses' => l10n.appCourses,
      'accounts' => l10n.appAccounts,
      'todos' => l10n.appTodos,
      'material-search' => locale.languageCode == 'en' ? 'Materials' : '资料',
      'tools' => l10n.appTools,
      'settings' => l10n.appSettings,
      _ => entry.titleFor(locale),
    };
  }

  Future<void> _handleReLogin(SessionHealthIssue issue) async {
    final user = AccountManager.getAccountsForPlatform(issue.platform)
        .where((account) => account.uid == issue.accountId)
        .cast<User?>()
        .firstWhere((account) => account != null, orElse: () => null);
    if (user == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamed('/accounts');
      return;
    }

    if (issue.platform != PlatformType.tronclass) {
      if (!mounted) return;
      Navigator.of(context).pushNamed('/accounts');
      return;
    }

    await AccountManager.setCurrentSession(user.uid, notify: false);
    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassWebLoginPage(
          accountName: user.name,
          accountId: user.uid,
          initialMessage: '正在为当前账号重新认证，成功后自动返回',
          autoCloseOnAuthSuccess: true,
        ),
      ),
    );

    if (result?['ok'] == true) {
      final sessionId = result?['sessionId']?.toString().trim();
      if (sessionId != null && sessionId.isNotEmpty) {
        await TronclassAuthManager.setSessionIdForUser(user.uid, sessionId);
        await TCLoginApi.bootstrapPortalSession(sessionId: sessionId);
      } else {
        await TronclassAuthManager.clearSessionIdForUser(user.uid);
      }
      _sessionHealthController.clearForAccount(issue.platform, issue.accountId);
      unawaited(
        _sessionHealthController.checkCurrentPlatform(platform: issue.platform),
      );
    }
  }
}
