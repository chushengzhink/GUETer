import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/performance/app_performance.dart';
import '../layout/layout_preferences.dart';
import '../plugins/plugin_store.dart';

class AppSettings {
  static const String autoCheckUpdateKey = 'app_auto_check_update';
  static const String autoCloseWebLoginKey = 'app_auto_close_web_login';
  static const String showBeginnerGuideKey = 'app_show_beginner_guide';
  static const String enableDiagnosticToolsKey = 'app_enable_diagnostic_tools';
  static const String settingsAnnouncementSeenKey =
      'app_settings_announcement_seen';
  static const String settingsAnnouncementVersionKey =
      'app_settings_announcement_version';
  static const int settingsAnnouncementCurrentVersion = 2;
  static const String tronclassPortalOpenModeKey =
      'app_tronclass_portal_open_mode';
  static const String tronclassReauthModeKey = 'app_tronclass_reauth_mode';
  static const String strictSecurityModeKey = 'app_strict_security_mode';
  static const String globalColorSchemeKey = 'app_global_color_scheme';
  static const String appThemeModeKey = 'app_theme_mode';
  static const String readingLastPageKey = 'app_reading_last_page';
  static const String readingLastOpenAtKey = 'app_reading_last_open_at';
  static const String readingNightModeKey = 'app_reading_night_mode';
  static const String academicApiEmailKey = 'app_academic_api_email';
  static const String appLocaleKey = 'app_locale';
  static const String smartOrganizerEnabledKey = 'app_smart_organizer_enabled';

  static const String portalOpenModeExternalPreferred = 'external_preferred';
  static const String portalOpenModeEmbeddedPreferred = 'embedded_preferred';
  static const String portalOpenModeAskEveryTime = 'ask_every_time';

  static const String reauthModeReuseSessionFirst = 'reuse_session_first';
  static const String reauthModeForceWebReauth = 'force_web_reauth';
  static const String reauthModeExternalBrowserOnly = 'external_browser_only';

  static const String themeModeSystem = 'system';
  static const String themeModeLight = 'light';
  static const String themeModeDark = 'dark';

  static const String colorSchemeAqua = 'aqua';
  static const String colorSchemeOcean = 'ocean';
  static const String colorSchemeForest = 'forest';
  static const String colorSchemeAmber = 'amber';
  static const String colorSchemeNight = 'night';
  static const String colorSchemeRose = 'rose';
  static const String colorSchemePurple = 'purple';
  static const String colorSchemeCyan = 'cyan';
  static const String colorSchemeOrange = 'orange';

  static const String themeStyleModern = 'modern';
  static const String themeStyleCompact = 'compact';
  static const String themeStylePlayful = 'playful';
  static const String themeStyleMinimal = 'minimal';
  static const String themeStyleBold = 'bold';
  static const String themeStyleSoft = 'soft';
  static const String themeStyleKey = 'app_theme_style';
  static const String localeCodeZh = 'zh';
  static const String localeCodeEn = 'en';

  static final ValueNotifier<String> globalColorSchemeNotifier =
      ValueNotifier<String>(colorSchemeAqua);
  static final ValueNotifier<ThemeMode> appThemeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  static final ValueNotifier<bool> strictSecurityModeNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<String> themeStyleNotifier = ValueNotifier<String>(
    themeStyleModern,
  );
  static final PerformanceSettingsStore performanceSettingsStore =
      PerformanceSettingsStore();
  static final ValueNotifier<PerformanceSettings> performanceSettingsNotifier =
      ValueNotifier<PerformanceSettings>(const PerformanceSettings());
  static final FrameJankMonitor frameJankMonitor = FrameJankMonitor();
  static Locale _currentLocale = const Locale(localeCodeZh);
  static final LayoutPreferencesStore layoutPreferencesStore =
      LayoutPreferencesStore();
  static final PluginStore pluginStore = PluginStore();

  static Future<void> initialize() async {
    globalColorSchemeNotifier.value = await getGlobalColorScheme();
    appThemeModeNotifier.value = await getThemeMode();
    strictSecurityModeNotifier.value = await getBool(
      strictSecurityModeKey,
      false,
    );
    themeStyleNotifier.value = await getThemeStyle();
    performanceSettingsNotifier.value = await performanceSettingsStore.load();
    _syncFrameJankMonitor(performanceSettingsNotifier.value);
    _currentLocale = await getLocale();
    await layoutPreferencesStore.load();
    await pluginStore.scan();
  }

  static Locale get currentLocale => _currentLocale;

  static Future<bool> getBool(String key, bool defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (key == strictSecurityModeKey) {
      strictSecurityModeNotifier.value = value;
    }
  }

  static Future<String> getString(String key, String defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    if (value == null || value.isEmpty) {
      return defaultValue;
    }
    return value;
  }

  static Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(appThemeModeKey) ?? themeModeSystem;
    switch (raw) {
      case themeModeLight:
        return ThemeMode.light;
      case themeModeDark:
        return ThemeMode.dark;
      case themeModeSystem:
      default:
        return ThemeMode.system;
    }
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    String raw = themeModeSystem;
    if (mode == ThemeMode.light) {
      raw = themeModeLight;
    } else if (mode == ThemeMode.dark) {
      raw = themeModeDark;
    }
    await prefs.setString(appThemeModeKey, raw);
    appThemeModeNotifier.value = mode;
  }

  static Future<String> getGlobalColorScheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(globalColorSchemeKey);
    if (value == null || value.isEmpty) {
      return colorSchemeAqua;
    }
    return value;
  }

  static Future<void> setGlobalColorScheme(String scheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(globalColorSchemeKey, scheme);
    globalColorSchemeNotifier.value = scheme;
  }

  static Future<String> getThemeStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(themeStyleKey);
    if (value == null || value.isEmpty) {
      return themeStyleModern;
    }
    return value;
  }

  static Future<void> setThemeStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeStyleKey, style);
    themeStyleNotifier.value = style;
  }

  static Future<Locale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(appLocaleKey) ?? localeCodeZh;
    return Locale(code == localeCodeEn ? localeCodeEn : localeCodeZh);
  }

  static Future<String> getLocaleCode() async {
    final locale = await getLocale();
    return locale.languageCode;
  }

  static Future<void> setLocaleCode(String code) async {
    final normalized = code == localeCodeEn ? localeCodeEn : localeCodeZh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appLocaleKey, normalized);
    _currentLocale = Locale(normalized);
  }

  static PerformanceSettings get performanceSettings =>
      performanceSettingsNotifier.value;

  static AppPerformanceMode get performanceMode =>
      performanceSettingsNotifier.value.mode;

  static bool get lowPowerMode =>
      performanceMode == AppPerformanceMode.lowPower;

  static Future<void> setPerformanceSettings(
    PerformanceSettings settings,
  ) async {
    await performanceSettingsStore.save(settings);
    performanceSettingsNotifier.value = settings;
    _syncFrameJankMonitor(settings);
  }

  static Future<void> setPerformanceMode(AppPerformanceMode mode) async {
    await performanceSettingsStore.setMode(mode);
    performanceSettingsNotifier.value = await performanceSettingsStore.load();
    _syncFrameJankMonitor(performanceSettingsNotifier.value);
  }

  static void _syncFrameJankMonitor(PerformanceSettings settings) {
    if (settings.showDiagnostics) {
      frameJankMonitor.start();
    } else {
      frameJankMonitor.stop();
    }
  }
}
