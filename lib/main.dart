import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

import './pages/accounts.dart';
import './pages/courses.dart';
import './pages/login.dart';
import './pages/reading.dart';
import './pages/settings.dart';
import './pages/tools_page.dart';
import './pages/todos_page.dart';
import './api/api_service.dart';
import './session/cookie.dart';
import './session/account.dart';
import './session/app_settings.dart';
import './session/license_ack.dart';
import './utils/global_palette.dart';
import './platform.dart';
import './theme/theme_style.dart';
import './widgets/floating_nav_bar.dart';

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

  await PlatformManager().initialize();
  await AccountManager.initialize();
  await CookieManager.initialize();

  registerCustomAcknowledgementLicenses();

  runApp(const MyApp());
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
                  title: 'GUETer',
                  locale: const Locale('zh', 'CN'),
                  supportedLocales: const [
                    Locale('zh', 'CN'),
                    Locale('en', 'US'),
                  ],
                  localizationsDelegates: const [
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
                    '/login': (context) => const LoginPage(),
                    '/reading': (context) => const ReadingPage(),
                    '/settings': (context) => const SettingsPage(),
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

      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/chushengzhink/GUETer/releases/latest',
      );
      final data = response.data;
      final latestVersion =
          data['tag_name']?.toString().replaceAll('v', '') ?? '';

      if (_isNewerVersion(latestVersion, currentVersion)) {
        _showUpdateDialog(
          latestVersion: latestVersion,
          releaseNotes: data['body'] ?? '暂无更新说明',
          downloadUrl:
              data['html_url'] ??
              'https://github.com/chushengzhink/GUETer/releases/latest',
        );
      }
    } catch (e) {
      // 忽略更新检查错误
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final latestNum = i < latestParts.length ? latestParts[i] : 0;
        final currentNum = i < currentParts.length ? currentParts[i] : 0;

        if (latestNum > currentNum) return true;
        if (latestNum < currentNum) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showUpdateDialog({
    required String latestVersion,
    required String releaseNotes,
    required String downloadUrl,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现新版本'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最新版本: v$latestVersion',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '更新内容:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(releaseNotes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              launchUrl(Uri.parse(downloadUrl));
            },
            child: const Text('前往下载'),
          ),
        ],
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
        items: const [
          FloatingNavBarItem(icon: Icons.school_rounded, label: '课程'),
          FloatingNavBarItem(icon: Icons.account_circle_rounded, label: '账号'),
          FloatingNavBarItem(
            icon: Icons.check_circle_outline_rounded,
            label: '待办',
          ),
          FloatingNavBarItem(icon: Icons.apps_rounded, label: '工具'),
          FloatingNavBarItem(icon: Icons.settings_rounded, label: '设置'),
        ],
      ),
    );
  }
}
