import'package:flutter/material.dart';
import'package:flutter_localizations/flutter_localizations.dart';
import'package:package_info_plus/package_info_plus.dart';
import'package:url_launcher/url_launcher.dart';
import'package:dio/dio.dart';

import'./pages/accounts.dart';
import'./pages/courses.dart';
import'./pages/login.dart';
import'./pages/reading.dart';
import'./pages/settings.dart';
import'./api/api_service.dart';
import'./session/cookie.dart';
import'./session/account.dart';
import'./session/app_settings.dart';
import'./session/license_ack.dart';
import'./utils/global_palette.dart';
import'./platform.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.initialize();

  await PlatformManager().initialize();

  await AccountManager.initialize();

  await CookieManager.initialize();

  await AppSettings.initialize();

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
            final palette = resolveGlobalPalette(scheme);
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
              supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(useMaterial3: true, colorScheme: lightScheme),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: darkScheme,
                scaffoldBackgroundColor: scheme == AppSettings.colorSchemeNight
                    ? const Color(0xFF0F1512)
                    : null,
                cardTheme: CardThemeData(
                  color: scheme == AppSettings.colorSchemeNight
                      ? const Color(0xFF17201C)
                      : null,
                ),
              ),
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
      (coursesPageKey.currentState as dynamic)?.onVisibilityChanged(true);
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
      final response = await dio.get('https://api.github.com/repos/AneryCoft/course_helper/releases/latest');
      final data = response.data;
      final latestVersion = data['tag_name']?.toString().replaceAll('v', '') ?? '';

      if (_isNewerVersion(latestVersion, currentVersion)) {
        _showUpdateDialog(
          latestVersion: latestVersion,
          releaseNotes: data['body'] ?? '暂无更新说明',
          downloadUrl: data['html_url'] ?? 'https://github.com/AneryCoft/course_helper/releases/latest',
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
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          CoursesPage(key: coursesPageKey),
          const AccountsPage(),
          const ReadingPage(),
          const SettingsPage(),
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: '课程',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: '账号',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: '阅读',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune),
            label: '设置',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          (coursesPageKey.currentState as dynamic)?.onVisibilityChanged(index == 0);
        },
      ),
    );
  }
}