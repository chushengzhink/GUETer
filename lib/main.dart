import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import './pages/accounts.dart';
import './pages/courses.dart';
import './pages/login.dart';
import './pages/reading.dart';
import './pages/settings.dart';
import './pages/tools_page.dart';
import './pages/todos_page.dart';
import './api/api_service.dart';
import './modules/airchat/ui/nearby_room_page.dart';
import './modules/local_transfer/local_transfer.dart';
import './modules/zerotier/ui/zerotier_page.dart';
import './session/cookie.dart';
import './session/account.dart';
import './session/app_settings.dart';
import './session/license_ack.dart';
import './session/startup_recovery_coordinator.dart';
import './services/update_service.dart';
import './utils/global_palette.dart';
import './platform.dart';
import './theme/design_tokens.dart';
import './theme/theme_style.dart';
import './widgets/floating_nav_bar.dart';
import './l10n/app_localizations.dart';

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

  registerCustomAcknowledgementLicenses();

  runApp(const MyApp());
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

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 不在这里调用 onVisibilityChanged，避免重复触发刷新
      _checkUpdate();
    });
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
      final latestVersion = updateInfo.version;

      if (_isNewerVersion(latestVersion, currentVersion)) {
        _showUpdateDialog(
          latestVersion: latestVersion,
          releaseNotes: updateInfo.releaseNotes,
          downloadUrl: updateInfo.apk.downloadUrl,
          forceUpdate: updateInfo.isForcedFor(currentVersion),
        );
      }
    } catch (e) {
      // 忽略更新检查错误
    }
  }

  bool _isNewerVersion(String latest, String current) {
    return UpdateInfo.isNewerVersion(latest, current);
  }

  void _showUpdateDialog({
    required String latestVersion,
    required String releaseNotes,
    required String downloadUrl,
    required bool forceUpdate,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          title: Text(l10n.updateAvailableTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.latestVersionLabel(latestVersion),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.updateNotesLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(releaseNotes),
              ],
            ),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.laterButton),
              ),
            FilledButton(
              onPressed: () {
                if (!forceUpdate) {
                  Navigator.pop(context);
                }
                launchUrl(Uri.parse(downloadUrl));
              },
              child: Text(l10n.downloadButton),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    const floatingNavBarHeight = 80.0;
    final totalBottomPadding = bottomSafeArea + floatingNavBarHeight;

    return Scaffold(
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(bottom: totalBottomPadding),
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            CoursesPage(key: coursesPageKey),
            const AccountsPage(),
            const TodosPage(),
            const ToolsPage(),
            const SettingsPage(),
          ],
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          (coursesPageKey.currentState as dynamic)?.onVisibilityChanged(
            index == 0,
          );
        },
        items: [
          FloatingNavBarItem(
            icon: Icons.school_rounded,
            label: AppLocalizations.of(context)!.appCourses,
          ),
          FloatingNavBarItem(
            icon: Icons.account_circle_rounded,
            label: AppLocalizations.of(context)!.appAccounts,
          ),
          FloatingNavBarItem(
            icon: Icons.check_circle_outline_rounded,
            label: AppLocalizations.of(context)!.appTodos,
          ),
          FloatingNavBarItem(
            icon: Icons.apps_rounded,
            label: AppLocalizations.of(context)!.appTools,
          ),
          FloatingNavBarItem(
            icon: Icons.settings_rounded,
            label: AppLocalizations.of(context)!.appSettings,
          ),
        ],
      ),
    );
  }
}
