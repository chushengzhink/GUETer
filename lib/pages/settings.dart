import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/sign_request_profile.dart';
import '../api/platform_request_stability.dart';
import '../api/platform_functional_request_profile.dart';
import '../core/performance/app_performance.dart';
import '../l10n/app_localizations.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../services/platform_health_check_service.dart';
import '../services/platform_network_warmup_service.dart';
import '../services/platform_page_snapshot_store.dart';
import '../smart/smart_models.dart';
import '../theme/animations.dart';
import '../theme/design_tokens.dart';
import '../widgets/context_help.dart';
import '../widgets/smart_inline_panel.dart';
import '../utils/encrypt.dart';
import 'request_console_page.dart';
import 'sign_records_page.dart';
import 'layout_customization_page.dart';
import 'plugin_management_page.dart';
import 'update_announcements_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const String _sectionAll = 'all';
  static const String _sectionAppearance = 'appearance';
  static const String _sectionSecurity = 'security';
  static const String _sectionAcademic = 'academic';
  static const String _sectionTools = 'tools';
  static const String _sectionTronclass = 'tronclass';
  static const String _sectionDiagnostics = 'diagnostics';

  bool _loading = true;
  bool _autoCloseWebLogin = true;
  bool _strictSecurityMode = false;
  bool _showBeginnerGuide = true;
  bool _enableDiagnosticTools = false;
  bool _smartOrganizerEnabled = true;
  PerformanceSettings _performanceSettings = const PerformanceSettings();
  ThemeMode _appThemeMode = ThemeMode.system;
  bool _isCheckingPlatformHealth = false;
  String? _lastPlatformHealthReport;
  String _academicApiEmail = '';
  late final TextEditingController _academicApiEmailController;

  String _tronclassPortalOpenMode = AppSettings.portalOpenModeExternalPreferred;
  String _tronclassReauthMode = AppSettings.reauthModeReuseSessionFirst;

  String _globalColorScheme = AppSettings.colorSchemeAqua;
  String _themeStyle = AppSettings.themeStyleModern;
  String _selectedLocaleCode = AppSettings.localeCodeZh;
  String _settingsSearchQuery = '';
  String _selectedSettingsSection = _sectionAll;

  late final TextEditingController _settingsSearchController;
  final GlobalKey _settingsTopKey = GlobalKey();
  final GlobalKey _appearanceSectionKey = GlobalKey();
  final GlobalKey _securitySectionKey = GlobalKey();
  final GlobalKey _academicSectionKey = GlobalKey();
  final GlobalKey _toolsSectionKey = GlobalKey();
  final GlobalKey _tronclassSectionKey = GlobalKey();
  final GlobalKey _diagnosticsSectionKey = GlobalKey();

  final List<Map<String, dynamic>> _colorSchemeItems = const [
    {
      'id': AppSettings.colorSchemeAqua,
      'name': '青碧',
      'primary': Color(0xFF1F9EA8),
      'secondary': Color(0xFF157B88),
    },
    {
      'id': AppSettings.colorSchemeOcean,
      'name': '海蓝',
      'primary': Color(0xFF2962FF),
      'secondary': Color(0xFF1E3FA3),
    },
    {
      'id': AppSettings.colorSchemeForest,
      'name': '松绿',
      'primary': Color(0xFF2E8B57),
      'secondary': Color(0xFF1F6B41),
    },
    {
      'id': AppSettings.colorSchemeAmber,
      'name': '琥珀',
      'primary': Color(0xFFC58A00),
      'secondary': Color(0xFF8E6400),
    },
    {
      'id': AppSettings.colorSchemeNight,
      'name': '护眼夜色',
      'primary': Color(0xFF1F6F78),
      'secondary': Color(0xFF164A51),
    },
    {
      'id': AppSettings.colorSchemeRose,
      'name': '暖红',
      'primary': Color(0xFFD96C6C),
      'secondary': Color(0xFFA84E4E),
    },
    {
      'id': AppSettings.colorSchemePurple,
      'name': '紫罗兰',
      'primary': Color(0xFF9C27B0),
      'secondary': Color(0xFF7B1FA2),
    },
    {
      'id': AppSettings.colorSchemeCyan,
      'name': '青色',
      'primary': Color(0xFF00BCD4),
      'secondary': Color(0xFF0097A7),
    },
    {
      'id': AppSettings.colorSchemeOrange,
      'name': '活力橙',
      'primary': Color(0xFFFF6F00),
      'secondary': Color(0xFFE65100),
    },
  ];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _settingsSearchController = TextEditingController();
    _academicApiEmailController = TextEditingController();
    _loadAllSettings();
  }

  @override
  void dispose() {
    _settingsSearchController.dispose();
    _academicApiEmailController.dispose();
    super.dispose();
  }

  Future<void> _maybeShowSettingsAnnouncement() async {
    final prefs = await SharedPreferences.getInstance();
    final seen =
        prefs.getBool(AppSettings.settingsAnnouncementSeenKey) ?? false;
    final version =
        prefs.getInt(AppSettings.settingsAnnouncementVersionKey) ?? 0;
    final shouldShow =
        !seen || version < AppSettings.settingsAnnouncementCurrentVersion;
    if (!shouldShow || !mounted) {
      return;
    }

    await prefs.setBool(AppSettings.settingsAnnouncementSeenKey, true);
    await prefs.setInt(
      AppSettings.settingsAnnouncementVersionKey,
      AppSettings.settingsAnnouncementCurrentVersion,
    );
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.campaign_outlined,
                  color: Theme.of(dialogContext).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.settingsAnnouncementTitle)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Text(
                l10n.settingsAnnouncementContent,
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.reviewLaterButton),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.gotItButton),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final autoClose = prefs.getBool(AppSettings.autoCloseWebLoginKey) ?? true;
    final strictMode =
        prefs.getBool(AppSettings.strictSecurityModeKey) ?? false;
    final showBeginnerGuide =
        prefs.getBool(AppSettings.showBeginnerGuideKey) ?? true;
    final portalOpenMode =
        prefs.getString(AppSettings.tronclassPortalOpenModeKey) ??
        AppSettings.portalOpenModeExternalPreferred;
    final reauthMode =
        prefs.getString(AppSettings.tronclassReauthModeKey) ??
        AppSettings.reauthModeReuseSessionFirst;
    final themeMode = await AppSettings.getThemeMode();
    final colorScheme =
        prefs.getString(AppSettings.globalColorSchemeKey) ??
        AppSettings.colorSchemeAqua;
    final themeStyle =
        prefs.getString(AppSettings.themeStyleKey) ??
        AppSettings.themeStyleModern;
    final localeCode =
        prefs.getString(AppSettings.appLocaleKey) ?? AppSettings.localeCodeZh;
    final enableDiagnostic =
        prefs.getBool(AppSettings.enableDiagnosticToolsKey) ?? false;
    final smartOrganizerEnabled =
        prefs.getBool(AppSettings.smartOrganizerEnabledKey) ?? true;
    final academicApiEmail =
        prefs.getString(AppSettings.academicApiEmailKey) ?? '';
    final performanceSettings = await AppSettings.performanceSettingsStore
        .load();

    if (!mounted) return;

    setState(() {
      _autoCloseWebLogin = autoClose;
      _strictSecurityMode = strictMode;
      _showBeginnerGuide = showBeginnerGuide;
      _appThemeMode = themeMode;
      _tronclassPortalOpenMode = portalOpenMode;
      _tronclassReauthMode = reauthMode;
      _globalColorScheme = colorScheme;
      _themeStyle = themeStyle;
      _selectedLocaleCode = localeCode;
      _enableDiagnosticTools = enableDiagnostic;
      _smartOrganizerEnabled = smartOrganizerEnabled;
      _academicApiEmail = academicApiEmail.trim();
      _performanceSettings = performanceSettings;
      _loading = false;
    });
    _academicApiEmailController.text = _academicApiEmail;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShowSettingsAnnouncement();
      }
    });
  }

  Future<void> _saveGlobalColorScheme() async {
    await AppSettings.setGlobalColorScheme(_globalColorScheme);
  }

  Future<void> _saveThemeStyle() async {
    await AppSettings.setThemeStyle(_themeStyle);
  }

  Future<void> _saveAcademicApiEmail() async {
    final trimmed = _academicApiEmailController.text.trim();
    await AppSettings.setString(AppSettings.academicApiEmailKey, trimmed);
    if (!mounted) return;

    setState(() {
      _academicApiEmail = trimmed;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsSavedEmail)));
  }

  Future<void> _clearAcademicApiEmail() async {
    _academicApiEmailController.clear();
    await AppSettings.setString(AppSettings.academicApiEmailKey, '');
    if (!mounted) return;

    setState(() {
      _academicApiEmail = '';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsClearedEmail)));
  }

  // ignore: unused_element
  Future<void> _showPortalModeHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('畅课门户打开方式说明'),
        content: const Text(
          '推荐默认：系统浏览器优先（兼容性最好，Windows/手机更稳定）。\n\n'
          '内置门户优先：适合需要在应用内连续操作的场景。\n\n'
          '每次打开都询问：每次进入门户前手动选择打开方式。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showReauthModeHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('一键重新认证策略说明'),
        content: const Text(
          '推荐默认：优先复用已有会话（通常更少验证码）。\n\n'
          '每次强制网页重新认证：每次都走完整认证流程。\n\n'
          '直接系统浏览器认证：不走内置网页，适合兼容性优先。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _restoreRecommendedTronclassModes() async {
    await AppSettings.setString(
      AppSettings.tronclassPortalOpenModeKey,
      AppSettings.portalOpenModeExternalPreferred,
    );
    await AppSettings.setString(
      AppSettings.tronclassReauthModeKey,
      AppSettings.reauthModeReuseSessionFirst,
    );

    if (!mounted) return;
    setState(() {
      _tronclassPortalOpenMode = AppSettings.portalOpenModeExternalPreferred;
      _tronclassReauthMode = AppSettings.reauthModeReuseSessionFirst;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复为推荐策略')));
  }

  // ignore: unused_element
  Future<void> _openTronclassPortalQuickly() async {
    final opened = await launchUrl(
      Uri.parse(PlatformManager().tronclassBaseUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('系统浏览器打开失败')));
    }
  }

  // ignore: unused_element
  Future<void> _copyTronclassPortalUrl() async {
    final url = PlatformManager().tronclassBaseUrl;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制门户地址：$url')));
  }

  // ignore: unused_element
  Future<void> _resetTronclassBaseUrlToDefault() async {
    await PlatformManager().setTronclassBaseUrl('https://courses.guet.edu.cn');
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复畅课地址为桂电默认地址')));
  }

  // ignore: unused_element
  Future<void> _resetKetangpaiBaseUrlToDefault() async {
    await PlatformManager().setKetangpaiBaseUrl(
      'https://openapiv5.ketangpai.com',
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复课堂派地址为默认地址')));
  }

  // ignore: unused_element
  Future<void> _checkCurrentTronclassAddress() async {
    final url = PlatformManager().tronclassBaseUrl;
    final stopwatch = Stopwatch()..start();
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          followRedirects: false,
          validateStatus: (_) => true,
        ),
      );
      final response = await dio.get(url);
      stopwatch.stop();
      final code = response.statusCode ?? 0;
      final ok = code > 0 && code < 500;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '畅课地址可用：HTTP $code · ${stopwatch.elapsedMilliseconds} ms'
                : '畅课地址异常：HTTP $code · ${stopwatch.elapsedMilliseconds} ms',
          ),
        ),
      );
    } catch (_) {
      stopwatch.stop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('畅课地址连接失败 · ${stopwatch.elapsedMilliseconds} ms'),
        ),
      );
    }
  }

  Future<void> _runPlatformHealthCheck() async {
    if (_isCheckingPlatformHealth) {
      return;
    }

    setState(() {
      _isCheckingPlatformHealth = true;
    });

    final report = await PlatformHealthCheckService().checkDefaultTargets(
      tronclassBaseUrl: PlatformManager().tronclassBaseUrl,
      ketangpaiBaseUrl: PlatformManager().ketangpaiBaseUrl,
    );
    unawaited(_diagnosePlatformEndpoints(report.results));

    if (!mounted) return;

    final reportText = report.toPlainText();

    setState(() {
      _isCheckingPlatformHealth = false;
      _lastPlatformHealthReport = reportText;
    });

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('四平台健康检查'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '该检查会并发验证平台连通性，不代表账号已登录。\n'
                  '并发总耗时：${report.totalElapsed.inMilliseconds} ms',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                ...report.results.map((item) {
                  final ok = item.isOk;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      ok ? Icons.check_circle : Icons.error_outline,
                      color: ok ? Colors.green : Colors.redAccent,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.statusLabel} · ${item.detail}\n${item.url}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              final text = _lastPlatformHealthReport ?? reportText;
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('检查报告已复制，可直接转发')));
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('复制报告'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _diagnosePlatformEndpoints(
    List<PlatformHealthCheckResult> results,
  ) async {
    final service = PlatformNetworkWarmupService();
    for (final item in results) {
      await service.diagnoseEndpoint(platform: item.platform, url: item.url);
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>>
  _loadAccountSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    final platforms = <String>[
      'chaoxing',
      'rainclassroom',
      'tronclass',
      'ketangpai',
    ];
    final snapshots = <String, List<Map<String, dynamic>>>{};

    for (final platform in platforms) {
      final raw = prefs.getString('${platform}_accounts');
      if (raw == null || raw.isEmpty) {
        snapshots[platform] = <Map<String, dynamic>>[];
        continue;
      }
      try {
        final decodedPayload = decodeAccountsPayload(raw);
        if (decodedPayload == null || decodedPayload.isEmpty) {
          snapshots[platform] = <Map<String, dynamic>>[];
          continue;
        }
        final decoded = jsonDecode(decodedPayload) as List<dynamic>;
        snapshots[platform] = decoded
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      } catch (_) {
        snapshots[platform] = <Map<String, dynamic>>[];
      }
    }

    return snapshots;
  }

  String? decodeAccountsPayload(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.startsWith('enc:')) {
      final encrypted = value.substring(4);
      return EncryptionUtil.aesCbcDecrypt(
        encrypted,
        Constant.localAccountStoreKey,
      );
    }
    return value;
  }

  Future<String> _permissionLabel(Permission permission) async {
    try {
      final status = await permission.status;
      if (status.isGranted) return '已授权';
      if (status.isDenied) return '未授权';
      if (status.isPermanentlyDenied) return '永久拒绝';
      if (status.isRestricted) return '受限';
      if (status.isLimited) return '受限授权';
      return '未知';
    } catch (_) {
      return '不支持';
    }
  }

  Future<String> _buildDiagnosticPack() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshots = await _loadAccountSnapshots();

    final tronclassAccounts =
        snapshots['tronclass'] ?? <Map<String, dynamic>>[];
    var tronclassSessionBound = 0;
    for (final item in tronclassAccounts) {
      final uid = (item['uid'] ?? '').toString();
      if (uid.isEmpty) continue;
      final sid = prefs.getString('tronclass_auth_session_$uid');
      if (sid != null && sid.isNotEmpty) {
        tronclassSessionBound += 1;
      }
    }

    final cameraPermission = await _permissionLabel(Permission.camera);
    final locationPermission = await _permissionLabel(
      Permission.locationWhenInUse,
    );

    final buffer = StringBuffer()
      ..writeln('GUETer 诊断包')
      ..writeln('时间: ${DateTime.now().toLocal()}')
      ..writeln('当前平台: ${PlatformManager().currentPlatformName}')
      ..writeln('当前会话: ${AccountManager.currentSessionId ?? '无'}')
      ..writeln('')
      ..writeln('设置快照:')
      ..writeln('- 主题模式: ${_appThemeMode.name}')
      ..writeln('- 全局配色: $_globalColorScheme')
      ..writeln('- 畅课门户策略: $_tronclassPortalOpenMode')
      ..writeln('- 畅课重认证策略: $_tronclassReauthMode')
      ..writeln('- 严格安全模式: ${_strictSecurityMode ? '开启' : '关闭'}')
      ..writeln('- 新手引导: ${_showBeginnerGuide ? '开启' : '关闭'}')
      ..writeln('')
      ..writeln('地址配置:')
      ..writeln('- 畅课: ${PlatformManager().tronclassBaseUrl}')
      ..writeln('- 课堂派: ${PlatformManager().ketangpaiBaseUrl}')
      ..writeln('')
      ..writeln('账号统计:')
      ..writeln('- 学习通: ${(snapshots['chaoxing'] ?? const []).length}')
      ..writeln('- 雨课堂: ${(snapshots['rainclassroom'] ?? const []).length}')
      ..writeln(
        '- 畅课: ${(snapshots['tronclass'] ?? const []).length} (会话绑定: $tronclassSessionBound)',
      )
      ..writeln('- 课堂派: ${(snapshots['ketangpai'] ?? const []).length}')
      ..writeln('')
      ..writeln('权限状态:')
      ..writeln('- 相机: $cameraPermission')
      ..writeln('- 位置: $locationPermission');

    return buffer.toString().trim();
  }

  Future<void> _copyDiagnosticPack() async {
    final report = await _buildDiagnosticPack();
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('诊断包已复制，可直接转发同学或反馈')));
  }

  Future<void> _setLowPowerMode(bool enabled) async {
    final mode = enabled
        ? AppPerformanceMode.lowPower
        : AppPerformanceMode.balanced;
    await AppSettings.setPerformanceMode(mode);
    if (!mounted) return;
    setState(() {
      _performanceSettings = AppSettings.performanceSettings;
    });
  }

  Future<void> _setPerformanceDiagnostics(bool enabled) async {
    final nextSettings = _performanceSettings.copyWith(
      showDiagnostics: enabled,
    );
    await AppSettings.setPerformanceSettings(nextSettings);
    if (!mounted) return;
    setState(() {
      _performanceSettings = AppSettings.performanceSettings;
    });
  }

  Future<String> _buildPerformanceReport() async {
    final settings = _performanceSettings;
    final jank = AppSettings.frameJankMonitor.snapshot();
    final endpointDiagnostics = await PlatformNetworkWarmupService()
        .loadLastDiagnostics();
    final modeLabel = settings.lowPower ? '低算力流畅模式' : '均衡模式';
    final currentPlatform = PlatformManager().currentPlatformName;
    final currentPlatformType = PlatformManager().currentPlatform;
    final userId = AccountManager.currentSessionId ?? '';
    final snapshotStore = PlatformPageSnapshotStore();
    final courseSnapshotStatus = userId.isEmpty
        ? PlatformSnapshotStatus.missing
        : await snapshotStore.status(
            platform: currentPlatformType,
            userId: userId,
            page: 'courses',
          );
    final todoSnapshotStatus = userId.isEmpty
        ? PlatformSnapshotStatus.missing
        : await snapshotStore.status(
            platform: currentPlatformType,
            userId: userId,
            page: 'todos',
          );
    final throttleState = PlatformRequestStability.throttle.stateFor(
      platform: currentPlatform,
      userId: userId,
    );
    String snapshotStatusLabel(PlatformSnapshotStatus status) {
      return switch (status) {
        PlatformSnapshotStatus.fresh => '命中，30 分钟内',
        PlatformSnapshotStatus.stale => '命中但较旧',
        PlatformSnapshotStatus.missing => '未命中',
      };
    }

    final buffer = StringBuffer()
      ..writeln('GUETer 流畅度与平台速度报告')
      ..writeln('时间: ${DateTime.now().toLocal()}')
      ..writeln('性能模式: $modeLabel')
      ..writeln('缩略图延迟加载: ${settings.deferredThumbnails ? '开启' : '关闭'}')
      ..writeln('批处理分片大小: ${settings.batchSize}')
      ..writeln('性能诊断显示: ${settings.showDiagnostics ? '开启' : '关闭'}')
      ..writeln('最近采样帧数: ${jank.totalFrames}')
      ..writeln('UI 卡顿帧: ${jank.uiJankFrames}')
      ..writeln('Raster 卡顿帧: ${jank.rasterJankFrames}')
      ..writeln('最差帧耗时: ${jank.worstFrameMs.toStringAsFixed(1)} ms')
      ..writeln('')
      ..writeln('平台请求速度策略:')
      ..writeln('- GET 读取请求使用受控并发：同账号最多 2，同平台最多 3')
      ..writeln('- 签到、登录、验证码、提交类 POST 保持串行')
      ..writeln('- 遇到 401/403/429/503/504 或连接超时会临时降级串行')
      ..writeln('- DNS/IP 只做诊断，不改写正式请求 URL')
      ..writeln('当前平台: $currentPlatform')
      ..writeln('当前账号: ${userId.isEmpty ? '未登录' : userId}')
      ..writeln('当前 throttle: ${throttleState.isDegraded ? '已降级串行' : '正常'}')
      ..writeln('最近队列等待: ${throttleState.lastQueueWaitMs} ms')
      ..writeln('降级原因: ${throttleState.lastDegradeReason ?? '-'}')
      ..writeln('课程快照: ${snapshotStatusLabel(courseSnapshotStatus)}')
      ..writeln('待办快照: ${snapshotStatusLabel(todoSnapshotStatus)}')
      ..writeln('功能读取画像:')
      ..writeln(
        '- 学习通: ${PlatformFunctionalRequestProfiles.diagnosticSummary(PlatformType.chaoxing)}',
      )
      ..writeln(
        '- 雨课堂: ${PlatformFunctionalRequestProfiles.diagnosticSummary(PlatformType.rainClassroom)}',
      )
      ..writeln(
        '- 畅课: ${PlatformFunctionalRequestProfiles.diagnosticSummary(PlatformType.tronclass)}',
      )
      ..writeln(
        '- 课堂派: ${PlatformFunctionalRequestProfiles.diagnosticSummary(PlatformType.ketangpai)}',
      )
      ..writeln('')
      ..writeln('DNS/IP 诊断记录:')
      ..writeln(
        endpointDiagnostics.isEmpty
            ? '- 暂无记录'
            : endpointDiagnostics
                  .map(
                    (item) =>
                        '- ${item.host}: DNS ${item.dnsElapsedMs} ms, TCP ${item.tcpElapsedMs} ms, IP ${item.addresses.take(3).join(', ')}${item.ok ? '' : ', ${item.error}'}',
                  )
                  .join('\n'),
      )
      ..writeln('')
      ..writeln('优化策略:')
      ..writeln('- 课程、待办优先读取页面快照，后台再刷新并写回快照')
      ..writeln('- 章节、作业/考试列表继续使用稳定 GET 缓存和 staleIfError')
      ..writeln('- 畅课课程内待办按低风险 GET 做受控并发')
      ..writeln('- 学习通课程内待办使用保守 worker 队列：均衡最多 2，低算力最多 1')
      ..writeln('- 大任务按批次让出 UI 线程，低算力模式进一步降低并发');
    return buffer.toString().trim();
  }

  Future<void> _showPerformanceReport() async {
    final report = await _buildPerformanceReport();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('\u6d41\u7545\u5ea6\u62a5\u544a'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Text(report, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '\u6d41\u7545\u5ea6\u62a5\u544a\u5df2\u590d\u5236',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('\u590d\u5236\u62a5\u544a'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('\u5173\u95ed'),
          ),
        ],
      ),
    );
  }

  Future<void> _quickFixCommonIssues() async {
    await AppSettings.setString(
      AppSettings.tronclassPortalOpenModeKey,
      AppSettings.portalOpenModeExternalPreferred,
    );
    await AppSettings.setString(
      AppSettings.tronclassReauthModeKey,
      AppSettings.reauthModeReuseSessionFirst,
    );
    await AppSettings.setBool(AppSettings.strictSecurityModeKey, false);
    await AppSettings.setBool(AppSettings.autoCloseWebLoginKey, true);
    await PlatformManager().setTronclassBaseUrl('https://courses.guet.edu.cn');
    await PlatformManager().setKetangpaiBaseUrl(
      'https://openapiv5.ketangpai.com',
    );

    if (!mounted) return;
    setState(() {
      _tronclassPortalOpenMode = AppSettings.portalOpenModeExternalPreferred;
      _tronclassReauthMode = AppSettings.reauthModeReuseSessionFirst;
      _strictSecurityMode = false;
      _autoCloseWebLogin = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('常见问题修复完成（地址/策略/安全模式已重置）')));
  }

  Future<void> _runAccountHealthCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshots = await _loadAccountSnapshots();
    final lines = <String>[];

    String statusFor(String platform, Map<String, dynamic> account) {
      final uid = (account['uid'] ?? '').toString();
      if (uid.isEmpty) return '异常';
      if (platform == 'tronclass') {
        final sid = prefs.getString('tronclass_auth_session_$uid');
        return (sid != null && sid.isNotEmpty) ? '可用' : '需重新认证';
      }
      if (platform == 'ketangpai') {
        final token = (account['token'] ?? '').toString();
        return token.isNotEmpty ? '可用' : '需重新登录';
      }
      final currentUid = prefs.getString('${platform}_current_session');
      return currentUid == uid ? '当前会话' : '已绑定(待验证)';
    }

    for (final platform in <String>[
      'chaoxing',
      'rainclassroom',
      'tronclass',
      'ketangpai',
    ]) {
      final list = snapshots[platform] ?? <Map<String, dynamic>>[];
      if (list.isEmpty) {
        lines.add('[$platform] 无绑定账号');
        continue;
      }
      for (final item in list) {
        final name = (item['name'] ?? item['uid'] ?? '未知').toString();
        lines.add('[$platform] $name -> ${statusFor(platform, item)}');
      }
    }

    final report =
        'GUETer 账号体检\n时间: ${DateTime.now().toLocal()}\n\n${lines.join('\n')}';

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('账号体检结果'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Text(report, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('账号体检报告已复制')));
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('复制报告'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _runBatchSignPrecheck() async {
    final snapshots = await _loadAccountSnapshots();
    final cameraPermission = await _permissionLabel(Permission.camera);
    final locationPermission = await _permissionLabel(
      Permission.locationWhenInUse,
    );

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );

    final endpoints = <Map<String, String>>[
      {'name': '学习通签到域名', 'url': 'https://mobilelearn.chaoxing.com'},
      {'name': '雨课堂域名', 'url': 'https://www.yuketang.cn'},
      {'name': '畅课域名', 'url': PlatformManager().tronclassBaseUrl},
      {'name': '课堂派域名', 'url': PlatformManager().ketangpaiBaseUrl},
    ];

    final lines = <String>[
      'GUETer 批量签到预检',
      '时间: ${DateTime.now().toLocal()}',
      '',
      '账号准备:',
      '- 学习通: ${(snapshots['chaoxing'] ?? const []).length}',
      '- 雨课堂: ${(snapshots['rainclassroom'] ?? const []).length}',
      '- 畅课: ${(snapshots['tronclass'] ?? const []).length}',
      '- 课堂派: ${(snapshots['ketangpai'] ?? const []).length}',
      '',
      '权限状态:',
      '- 相机: $cameraPermission',
      '- 位置: $locationPermission',
      '',
      '请求画像检查:',
      '- 学习通: ${SignRequestProfiles.diagnosticSummary(PlatformType.chaoxing)}',
      '- 雨课堂: ${SignRequestProfiles.diagnosticSummary(PlatformType.rainClassroom)}',
      '- 畅课: ${SignRequestProfiles.diagnosticSummary(PlatformType.tronclass)}',
      '- 课堂派: ${SignRequestProfiles.diagnosticSummary(PlatformType.ketangpai)}',
      '- 微助教: ${SignRequestProfiles.diagnosticSummary(PlatformType.weizhuojiao)}',
      '- 失败回退: 开启，增强画像失败时使用旧请求重试一次',
      '',
      '网络预检:',
    ];

    for (final endpoint in endpoints) {
      final watch = Stopwatch()..start();
      try {
        final resp = await dio.get(endpoint['url']!);
        watch.stop();
        final code = resp.statusCode ?? 0;
        lines.add(
          '- ${endpoint['name']}: HTTP $code · ${watch.elapsedMilliseconds} ms',
        );
      } catch (_) {
        watch.stop();
        lines.add(
          '- ${endpoint['name']}: 连接失败 · ${watch.elapsedMilliseconds} ms',
        );
      }
    }

    final report = lines.join('\n');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.batchPrecheckResultTitle),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Text(report, style: const TextStyle(fontSize: 12)),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.precheckReportCopied)),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l10n.copyReportButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _openRequestConsole() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RequestConsolePage()),
    );
  }

  Future<void> _showBeginnerGuideDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.beginnerGuideDialogTitle),
        content: SingleChildScrollView(
          child: Text(l10n.beginnerGuideDialogContent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.closeButton),
          ),
        ],
      ),
    );
  }

  Future<void> _applyRandomColorScheme() async {
    if (_colorSchemeItems.length <= 1) {
      return;
    }

    final candidates = _colorSchemeItems
        .where((item) => item['id'] != _globalColorScheme)
        .toList();
    final picked = candidates[Random().nextInt(candidates.length)];
    final id = picked['id'] as String;
    final name = _getColorSchemeName(id);

    setState(() {
      _globalColorScheme = id;
    });
    await _saveGlobalColorScheme();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.randomPaletteSwitched(name))));
  }

  // ignore: unused_element
  Future<void> _copySetupSummary() async {
    final summary = StringBuffer()
      ..writeln('GUETer 设置摘要')
      ..writeln('- 主题: ${_appThemeMode.name}')
      ..writeln('- 配色: $_globalColorScheme')
      ..writeln('- 畅课门户策略: $_tronclassPortalOpenMode')
      ..writeln('- 畅课重认证策略: $_tronclassReauthMode')
      ..writeln('- 严格安全模式: ${_strictSecurityMode ? '开启' : '关闭'}')
      ..writeln('- 网页登录自动返回: ${_autoCloseWebLogin ? '开启' : '关闭'}')
      ..writeln('- 触感反馈: 已移除');

    await Clipboard.setData(ClipboardData(text: summary.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('设置摘要已复制')));
  }

  Future<void> _showDisclaimerDialog() async {
    final content = l10n.disclaimerDialogContent;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.disclaimerDialogTitle)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.disclaimerDialogSummary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(fontSize: 13, height: 1.55),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.disclaimerCopied)));
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l10n.copyFullTextButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.gotItButton),
          ),
        ],
      ),
    );
  }

  String _generateRandomPassword({int length = 16}) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^&*_+-=';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
  }

  // ignore: unused_element
  Future<void> _showPasswordGeneratorDialog() async {
    String generated = _generateRandomPassword(length: 16);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: const Text('随机密码生成器'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('通用小工具：可用于网站、论坛、邮箱等密码草案。'),
              const SizedBox(height: 10),
              SelectableText(
                generated,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setInnerState(() {
                        generated = _generateRandomPassword(length: 12);
                      });
                    },
                    child: const Text('12位'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setInnerState(() {
                        generated = _generateRandomPassword(length: 16);
                      });
                    },
                    child: const Text('16位'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      setInnerState(() {
                        generated = _generateRandomPassword(length: 24);
                      });
                    },
                    child: const Text('24位'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.closeButton),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: generated));
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(l10n.passwordCopied)));
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: Text(l10n.copyButton),
            ),
          ],
        ),
      ),
    );
  }

  Color get _activeThemeColor {
    return _colorSchemeItems.firstWhere(
          (item) => item['id'] == _globalColorScheme,
          orElse: () => _colorSchemeItems.first,
        )['primary']
        as Color;
  }

  String get _actualThemeModeLabel {
    final brightness = Theme.of(context).brightness;
    if (_appThemeMode == ThemeMode.system) {
      return brightness == Brightness.dark
          ? l10n.themeModeDark
          : l10n.themeModeLight;
    }
    return _appThemeMode == ThemeMode.dark
        ? l10n.themeModeDark
        : l10n.themeModeLight;
  }

  String get _localeLabel {
    return _selectedLocaleCode == AppSettings.localeCodeEn
        ? l10n.languageEnglish
        : l10n.languageChinese;
  }

  String get _themeStyleLabel {
    switch (_themeStyle) {
      case AppSettings.themeStyleCompact:
        return l10n.themeStyleCompact;
      case AppSettings.themeStylePlayful:
        return l10n.themeStylePlayful;
      case AppSettings.themeStyleMinimal:
        return l10n.themeStyleMinimal;
      case AppSettings.themeStyleBold:
        return l10n.themeStyleBold;
      case AppSettings.themeStyleSoft:
        return l10n.themeStyleSoft;
      case AppSettings.themeStyleModern:
      default:
        return l10n.themeStyleModern;
    }
  }

  String _portalModeLabel(String value) {
    switch (value) {
      case AppSettings.portalOpenModeEmbeddedPreferred:
        return '内置门户优先';
      case AppSettings.portalOpenModeAskEveryTime:
        return '每次询问';
      case AppSettings.portalOpenModeExternalPreferred:
      default:
        return '系统浏览器优先';
    }
  }

  String _reauthModeLabel(String value) {
    switch (value) {
      case AppSettings.reauthModeForceWebReauth:
        return '强制网页认证';
      case AppSettings.reauthModeExternalBrowserOnly:
        return '仅系统浏览器';
      case AppSettings.reauthModeReuseSessionFirst:
      default:
        return '会话复用优先';
    }
  }

  String _getColorSchemeName(String scheme) {
    switch (scheme) {
      case AppSettings.colorSchemeOcean:
        return l10n.colorSchemeOcean;
      case AppSettings.colorSchemeForest:
        return l10n.colorSchemeForest;
      case AppSettings.colorSchemeAmber:
        return l10n.colorSchemeAmber;
      case AppSettings.colorSchemeNight:
        return l10n.colorSchemeNight;
      case AppSettings.colorSchemeRose:
        return l10n.colorSchemeRose;
      case AppSettings.colorSchemePurple:
        return l10n.colorSchemePurple;
      case AppSettings.colorSchemeCyan:
        return l10n.colorSchemeCyan;
      case AppSettings.colorSchemeOrange:
        return l10n.colorSchemeOrange;
      case AppSettings.colorSchemeAqua:
      default:
        return l10n.colorSchemeAqua;
    }
  }

  List<_SettingsSectionSpec> get _settingsSections {
    return [
      const _SettingsSectionSpec(
        id: _sectionAll,
        label: '全部',
        icon: Icons.grid_view_rounded,
        color: Colors.blueGrey,
      ),
      _SettingsSectionSpec(
        id: _sectionAppearance,
        label: '外观',
        icon: Icons.palette_outlined,
        color: _activeThemeColor,
      ),
      const _SettingsSectionSpec(
        id: _sectionSecurity,
        label: '安全',
        icon: Icons.shield_outlined,
        color: Colors.green,
      ),
      const _SettingsSectionSpec(
        id: _sectionAcademic,
        label: '学术',
        icon: Icons.auto_stories_outlined,
        color: Colors.teal,
      ),
      const _SettingsSectionSpec(
        id: _sectionTools,
        label: '工具',
        icon: Icons.apps_outlined,
        color: Colors.indigo,
      ),
      const _SettingsSectionSpec(
        id: _sectionTronclass,
        label: '畅课',
        icon: Icons.school_outlined,
        color: Colors.blueGrey,
      ),
      const _SettingsSectionSpec(
        id: _sectionDiagnostics,
        label: '诊断',
        icon: Icons.health_and_safety_outlined,
        color: Colors.green,
      ),
    ];
  }

  List<_SettingsCommandSpec> get _settingsCommands {
    return [
      _selectCommand<ThemeMode>(
        sectionId: _sectionAppearance,
        title: l10n.themeModeLabel,
        subtitle: '切换浅色、深色或跟随系统',
        keywords: ['主题', '深色', '浅色', '夜间', '模式'],
        icon: Icons.dark_mode_outlined,
        color: Colors.orange,
        value: _appThemeMode,
        options: [
          _SettingsCommandOption(
            value: ThemeMode.system,
            label: l10n.themeModeSystem,
          ),
          _SettingsCommandOption(
            value: ThemeMode.light,
            label: l10n.themeModeLight,
          ),
          _SettingsCommandOption(
            value: ThemeMode.dark,
            label: l10n.themeModeDark,
          ),
        ],
        onChanged: (mode) async {
          setState(() => _appThemeMode = mode);
          await AppSettings.setThemeMode(mode);
        },
      ),
      _selectCommand<String>(
        sectionId: _sectionAppearance,
        title: l10n.languageLabel,
        subtitle: '切换中文或 English',
        keywords: ['语言', '中文', '英文', 'locale'],
        icon: Icons.translate_outlined,
        color: Colors.teal,
        value: _selectedLocaleCode,
        options: [
          _SettingsCommandOption(
            value: AppSettings.localeCodeZh,
            label: l10n.languageChinese,
          ),
          _SettingsCommandOption(
            value: AppSettings.localeCodeEn,
            label: l10n.languageEnglish,
          ),
        ],
        onChanged: (code) async {
          setState(() => _selectedLocaleCode = code);
          await AppSettings.setLocaleCode(code);
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.languageSavedRestart)));
        },
      ),
      _selectCommand<String>(
        sectionId: _sectionAppearance,
        title: l10n.themeStyleLabel,
        subtitle: '切换现代、紧凑、柔和等界面风格',
        keywords: ['风格', '样式', 'style'],
        icon: Icons.style_outlined,
        color: _activeThemeColor,
        value: _themeStyle,
        options: [
          _SettingsCommandOption(
            value: AppSettings.themeStyleModern,
            label: l10n.themeStyleModern,
          ),
          _SettingsCommandOption(
            value: AppSettings.themeStyleCompact,
            label: l10n.themeStyleCompact,
          ),
          _SettingsCommandOption(
            value: AppSettings.themeStylePlayful,
            label: l10n.themeStylePlayful,
          ),
          _SettingsCommandOption(
            value: AppSettings.themeStyleMinimal,
            label: l10n.themeStyleMinimal,
          ),
          _SettingsCommandOption(
            value: AppSettings.themeStyleBold,
            label: l10n.themeStyleBold,
          ),
          _SettingsCommandOption(
            value: AppSettings.themeStyleSoft,
            label: l10n.themeStyleSoft,
          ),
        ],
        onChanged: (style) async {
          setState(() => _themeStyle = style);
          await _saveThemeStyle();
        },
      ),
      _paletteCommand(
        sectionId: _sectionAppearance,
        title: '配色方案',
        subtitle: '选择全局强调色或随机配色',
        keywords: ['配色', '颜色', '色板', '随机配色', 'palette'],
        icon: Icons.color_lens_outlined,
        color: _activeThemeColor,
      ),
      _toggleCommand(
        sectionId: _sectionSecurity,
        title: l10n.autoCloseWebLoginTitle,
        subtitle: '网页登录完成后自动关闭页面',
        keywords: ['网页登录', '自动关闭', 'web', 'login'],
        icon: Icons.web_asset_off_outlined,
        color: Colors.blue,
        value: _autoCloseWebLogin,
        onChanged: (v) async {
          setState(() => _autoCloseWebLogin = v);
          await AppSettings.setBool(AppSettings.autoCloseWebLoginKey, v);
        },
      ),
      _toggleCommand(
        sectionId: _sectionSecurity,
        title: '低算力流畅模式',
        subtitle: '降低批处理负载，减少低端设备卡顿',
        keywords: ['低算力', '性能', '流畅', '卡顿', '省电'],
        icon: Icons.battery_saver_outlined,
        color: Colors.green,
        value: _performanceSettings.lowPower,
        onChanged: _setLowPowerMode,
      ),
      _toggleCommand(
        sectionId: _sectionSecurity,
        title: '显示性能诊断',
        subtitle: '采集帧耗时并生成流畅度报告',
        keywords: ['性能诊断', '流畅度', '报告', '帧率'],
        icon: Icons.speed_outlined,
        color: Colors.indigo,
        value: _performanceSettings.showDiagnostics,
        onChanged: _setPerformanceDiagnostics,
      ),
      _toggleCommand(
        sectionId: _sectionSecurity,
        title: '本地智能整理',
        subtitle: '使用本地规则生成资料、待办、复习和诊断建议',
        keywords: ['智能整理', '本地', '建议', '资料', '待办'],
        icon: Icons.tips_and_updates_outlined,
        color: Colors.teal,
        value: _smartOrganizerEnabled,
        onChanged: (v) async {
          setState(() => _smartOrganizerEnabled = v);
          await AppSettings.setBool(AppSettings.smartOrganizerEnabledKey, v);
        },
      ),
      _toggleCommand(
        sectionId: _sectionSecurity,
        title: l10n.strictSecurityModeTitle,
        subtitle: '启用更严格的安全策略',
        keywords: ['安全', '严格', '保护'],
        icon: Icons.security_outlined,
        color: _strictSecurityMode ? Colors.redAccent : Colors.green,
        value: _strictSecurityMode,
        onChanged: (v) async {
          setState(() => _strictSecurityMode = v);
          await AppSettings.setBool(AppSettings.strictSecurityModeKey, v);
        },
      ),
      _emailCommand(
        sectionId: _sectionAcademic,
        title: l10n.academicApiEmailLabel,
        subtitle: '保存或清空学术 API 邮箱',
        keywords: ['学术', '邮箱', 'api', 'email'],
        icon: Icons.alternate_email_outlined,
        color: Colors.teal,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: l10n.quickActionPlatformCheck,
        subtitle: '检查四个平台连通性',
        keywords: ['平台体检', '健康检查', '连通性', '检测'],
        icon: Icons.monitor_heart_outlined,
        color: Colors.blue,
        isLoading: _isCheckingPlatformHealth,
        onTap: _runPlatformHealthCheck,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: l10n.quickActionFix,
        subtitle: '恢复常用策略和地址配置',
        keywords: ['修复', '一键修复', '恢复', '问题'],
        icon: Icons.healing_outlined,
        color: Colors.green,
        onTap: _quickFixCommonIssues,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: l10n.quickActionRandomPalette,
        subtitle: '随机切换全局配色',
        keywords: ['随机配色', '换色', '颜色'],
        icon: Icons.casino_outlined,
        color: Colors.orange,
        onTap: _applyRandomColorScheme,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: '界面布局',
        subtitle: '定制首页和入口布局',
        keywords: ['布局', '界面', '定制', '首页'],
        icon: Icons.dashboard_customize_outlined,
        color: Colors.indigo,
        onTap: _openLayoutCustomization,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: '插件管理',
        subtitle: '管理扩展插件入口',
        keywords: ['插件', '扩展', 'plugin'],
        icon: Icons.extension_outlined,
        color: Colors.purple,
        onTap: _openPluginManagement,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: '更新公告',
        subtitle: '查看版本更新与说明',
        keywords: ['公告', '更新', '版本'],
        icon: Icons.campaign_outlined,
        color: Colors.orange,
        onTap: _openUpdateAnnouncements,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: '随机密码',
        subtitle: '生成论坛、网站、邮箱密码草案',
        keywords: ['密码', '随机密码', '生成器'],
        icon: Icons.password_outlined,
        color: Colors.blueGrey,
        onTap: _showPasswordGeneratorDialog,
      ),
      _sectionCommand(
        sectionId: _sectionTronclass,
        title: '畅课高级登录策略',
        subtitle: '门户打开、重新认证、地址检测与重置',
        keywords: ['畅课', '门户', '认证', '地址', '重置'],
        icon: Icons.school_outlined,
        color: Colors.blueGrey,
      ),
      _selectCommand<String>(
        sectionId: _sectionTronclass,
        title: '门户打开方式',
        subtitle: _portalModeLabel(_tronclassPortalOpenMode),
        keywords: ['畅课', '门户', '打开方式', '浏览器'],
        icon: Icons.open_in_browser_outlined,
        color: Colors.blueGrey,
        value: _tronclassPortalOpenMode,
        options: const [
          _SettingsCommandOption(
            value: AppSettings.portalOpenModeExternalPreferred,
            label: '系统浏览器优先',
          ),
          _SettingsCommandOption(
            value: AppSettings.portalOpenModeEmbeddedPreferred,
            label: '内置门户优先',
          ),
          _SettingsCommandOption(
            value: AppSettings.portalOpenModeAskEveryTime,
            label: '每次询问',
          ),
        ],
        onChanged: (value) async {
          setState(() => _tronclassPortalOpenMode = value);
          await AppSettings.setString(
            AppSettings.tronclassPortalOpenModeKey,
            value,
          );
        },
      ),
      _selectCommand<String>(
        sectionId: _sectionTronclass,
        title: '重新认证策略',
        subtitle: _reauthModeLabel(_tronclassReauthMode),
        keywords: ['畅课', '重新认证', '认证', '会话'],
        icon: Icons.verified_user_outlined,
        color: Colors.blueGrey,
        value: _tronclassReauthMode,
        options: const [
          _SettingsCommandOption(
            value: AppSettings.reauthModeReuseSessionFirst,
            label: '复用会话',
          ),
          _SettingsCommandOption(
            value: AppSettings.reauthModeForceWebReauth,
            label: '强制认证',
          ),
          _SettingsCommandOption(
            value: AppSettings.reauthModeExternalBrowserOnly,
            label: '系统浏览器',
          ),
        ],
        onChanged: (value) async {
          setState(() => _tronclassReauthMode = value);
          await AppSettings.setString(
            AppSettings.tronclassReauthModeKey,
            value,
          );
        },
      ),
      _toggleCommand(
        sectionId: _sectionDiagnostics,
        title: l10n.diagnosticsToggleTitle,
        subtitle: '开启后显示完整诊断工具',
        keywords: ['诊断', '高级诊断', '排查'],
        icon: Icons.health_and_safety_outlined,
        color: Colors.green,
        value: _enableDiagnosticTools,
        onChanged: (v) async {
          setState(() => _enableDiagnosticTools = v);
          await AppSettings.setBool(AppSettings.enableDiagnosticToolsKey, v);
        },
      ),
      _actionCommand(
        sectionId: _sectionDiagnostics,
        title: l10n.copyDiagnosticPackTitle,
        subtitle: '复制诊断包用于反馈',
        keywords: ['诊断包', '复制', '反馈'],
        icon: Icons.assignment_outlined,
        color: Colors.green,
        onTap: _copyDiagnosticPack,
      ),
      _actionCommand(
        sectionId: _sectionDiagnostics,
        title: '流畅度报告',
        subtitle: '查看性能采样和平台速度策略',
        keywords: ['流畅度', '性能报告', '报告'],
        icon: Icons.speed_outlined,
        color: Colors.indigo,
        onTap: _showPerformanceReport,
      ),
      _actionCommand(
        sectionId: _sectionDiagnostics,
        title: l10n.accountHealthTitle,
        subtitle: l10n.accountHealthSubtitle,
        keywords: ['账号体检', '账号健康', '登录状态'],
        icon: Icons.fact_check_outlined,
        color: Colors.teal,
        onTap: _runAccountHealthCheck,
      ),
      _actionCommand(
        sectionId: _sectionDiagnostics,
        title: l10n.batchPrecheckTitle,
        subtitle: l10n.batchPrecheckSubtitle,
        keywords: ['批量预检', '签到', '预检'],
        icon: Icons.rule_folder_outlined,
        color: Colors.orange,
        onTap: _runBatchSignPrecheck,
      ),
      _actionCommand(
        sectionId: _sectionDiagnostics,
        title: l10n.signRecordsTitle,
        subtitle: l10n.signRecordsSubtitle,
        keywords: ['签到记录', '记录', '历史'],
        icon: Icons.history_toggle_off_outlined,
        color: Colors.blueGrey,
        onTap: _openSignRecords,
      ),
      _actionCommand(
        sectionId: _sectionDiagnostics,
        title: l10n.requestConsoleTitle,
        subtitle: l10n.requestConsoleSubtitle,
        keywords: ['请求控制台', '控制台', '请求', '日志'],
        icon: Icons.terminal_outlined,
        color: Colors.deepPurple,
        onTap: _openRequestConsole,
      ),
    ];
  }

  _SettingsCommandSpec _sectionCommand({
    required String sectionId,
    required String title,
    required String subtitle,
    required List<String> keywords,
    required IconData icon,
    required Color color,
  }) {
    return _SettingsCommandSpec(
      sectionId: sectionId,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      icon: icon,
      color: color,
      onTap: () => _selectSection(sectionId, scrollToSection: true),
    );
  }

  _SettingsCommandSpec _toggleCommand({
    required String sectionId,
    required String title,
    required String subtitle,
    required List<String> keywords,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _SettingsCommandSpec(
      sectionId: sectionId,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      icon: icon,
      color: color,
      onTap: () => onChanged(!value),
      type: _SettingsCommandType.toggle,
      boolValue: value,
      onBoolChanged: onChanged,
    );
  }

  _SettingsCommandSpec _selectCommand<T>({
    required String sectionId,
    required String title,
    required String subtitle,
    required List<String> keywords,
    required IconData icon,
    required Color color,
    required T value,
    required List<_SettingsCommandOption<T>> options,
    required ValueChanged<T> onChanged,
  }) {
    return _SettingsCommandSpec(
      sectionId: sectionId,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      icon: icon,
      color: color,
      onTap: () => _selectSection(sectionId, scrollToSection: true),
      type: _SettingsCommandType.select,
      selectValue: value,
      selectOptions: options,
      onSelectChanged: (next) {
        final typed = next;
        if (typed is T) {
          onChanged(typed);
        }
      },
    );
  }

  _SettingsCommandSpec _paletteCommand({
    required String sectionId,
    required String title,
    required String subtitle,
    required List<String> keywords,
    required IconData icon,
    required Color color,
  }) {
    return _SettingsCommandSpec(
      sectionId: sectionId,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      icon: icon,
      color: color,
      onTap: () => _selectSection(sectionId, scrollToSection: true),
      type: _SettingsCommandType.palette,
      paletteItems: _colorSchemeItems,
      selectedPaletteId: _globalColorScheme,
      onPaletteSelected: (id) async {
        setState(() => _globalColorScheme = id);
        await _saveGlobalColorScheme();
      },
      paletteLabelBuilder: _getColorSchemeName,
    );
  }

  _SettingsCommandSpec _emailCommand({
    required String sectionId,
    required String title,
    required String subtitle,
    required List<String> keywords,
    required IconData icon,
    required Color color,
  }) {
    return _SettingsCommandSpec(
      sectionId: sectionId,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      icon: icon,
      color: color,
      onTap: () => _selectSection(sectionId, scrollToSection: true),
      type: _SettingsCommandType.textInput,
      textController: _academicApiEmailController,
      currentText: _academicApiEmail.isEmpty
          ? l10n.currentEmailUnset
          : l10n.currentEmailValue(_academicApiEmail),
      onTextSave: _saveAcademicApiEmail,
      onTextClear: _clearAcademicApiEmail,
    );
  }

  _SettingsCommandSpec _actionCommand({
    Key? key,
    required String sectionId,
    required String title,
    required String subtitle,
    required List<String> keywords,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return _SettingsCommandSpec(
      key: key,
      sectionId: sectionId,
      title: title,
      subtitle: subtitle,
      keywords: keywords,
      icon: icon,
      color: color,
      onTap: onTap,
      type: _SettingsCommandType.action,
      isAction: true,
      isLoading: isLoading,
    );
  }

  List<_SettingsCommandSpec> get _filteredSettingsCommands {
    final query = _settingsSearchQuery.trim().toLowerCase();
    final commands = _settingsCommands;
    if (query.isEmpty) {
      const preferredTitles = <String>{
        '主题模式',
        '低算力流畅模式',
        '严格安全模式',
        '随机切换全局配色',
        '插件管理',
        '请求控制台',
      };
      return commands
          .where((command) {
            return preferredTitles.contains(command.title) ||
                command.title == l10n.themeModeLabel ||
                command.title == l10n.strictSecurityModeTitle ||
                command.title == l10n.requestConsoleTitle;
          })
          .take(6)
          .toList();
    }
    return commands.where((command) => command.matches(query)).toList();
  }

  List<String> get _settingsSearchSuggestions {
    return const ['低算力', '主题', '配色', '邮箱', '畅课', '插件', '诊断', '请求控制台'];
  }

  void _applySearchSuggestion(String text) {
    _settingsSearchController.text = text;
    _settingsSearchController.selection = TextSelection.collapsed(
      offset: text.length,
    );
    _onSearchChanged(text);
  }

  GlobalKey _keyForSection(String sectionId) {
    return switch (sectionId) {
      _sectionAppearance => _appearanceSectionKey,
      _sectionSecurity => _securitySectionKey,
      _sectionAcademic => _academicSectionKey,
      _sectionTools => _toolsSectionKey,
      _sectionTronclass => _tronclassSectionKey,
      _sectionDiagnostics => _diagnosticsSectionKey,
      _ => _settingsTopKey,
    };
  }

  void _selectSection(String sectionId, {bool scrollToSection = false}) {
    setState(() {
      _selectedSettingsSection = sectionId;
    });
    if (scrollToSection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _keyForSection(sectionId).currentContext;
        if (context == null) return;
        Scrollable.ensureVisible(
          context,
          duration: AppDuration.normal,
          curve: AppCurves.emphasized,
          alignment: 0.08,
        );
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _settingsSearchQuery = value;
      if (value.trim().isNotEmpty) {
        _selectedSettingsSection = _sectionAll;
      }
    });
  }

  void _clearSettingsSearch() {
    _settingsSearchController.clear();
    _onSearchChanged('');
  }

  void _openLayoutCustomization() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LayoutCustomizationPage()));
  }

  void _openPluginManagement() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PluginManagementPage()));
  }

  void _openUpdateAnnouncements() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UpdateAnnouncementsPage()));
  }

  void _openSignRecords() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignRecordsPage()));
  }

  Widget _buildNoticePanel() {
    return _SettingsControlPanel(
      title: '说明与引导',
      subtitle: '保留必要提醒，避免误操作。',
      icon: Icons.info_outline,
      color: Colors.blueGrey,
      children: [
        _SettingsNoticeCard(
          icon: Icons.verified_user_outlined,
          title: l10n.disclaimerCardTitle,
          subtitle: l10n.disclaimerCardSubtitle,
          color: Colors.redAccent,
          onTap: _showDisclaimerDialog,
        ),
        if (_showBeginnerGuide)
          _SettingsNoticeCard(
            icon: Icons.school_outlined,
            title: l10n.beginnerGuideCardTitle,
            subtitle: l10n.beginnerGuideCardSubtitle,
            color: Colors.blue,
            trailing: Switch(
              value: _showBeginnerGuide,
              onChanged: (v) async {
                setState(() => _showBeginnerGuide = v);
                await AppSettings.setBool(AppSettings.showBeginnerGuideKey, v);
              },
            ),
            onTap: _showBeginnerGuideDialog,
          ),
      ],
    );
  }

  List<_SettingsCommandSpec> get _quickActionCommands {
    return [
      _actionCommand(
        sectionId: _sectionTools,
        title: l10n.quickActionPlatformCheck,
        subtitle: '并发检测学习通、雨课堂、畅课、课堂派',
        keywords: const ['平台体检', '健康检查', '连通性'],
        icon: Icons.monitor_heart_outlined,
        color: Colors.blue,
        isLoading: _isCheckingPlatformHealth,
        onTap: _runPlatformHealthCheck,
      ),
      _actionCommand(
        sectionId: _sectionTools,
        title: l10n.quickActionFix,
        subtitle: '恢复常用策略和安全默认值',
        keywords: const ['一键修复', '恢复', '问题'],
        icon: Icons.healing_outlined,
        color: Colors.green,
        onTap: _quickFixCommonIssues,
      ),
      _actionCommand(
        sectionId: _sectionAppearance,
        title: l10n.quickActionRandomPalette,
        subtitle: '换一套全局强调色',
        keywords: const ['随机配色', '颜色', '色板'],
        icon: Icons.casino_outlined,
        color: Colors.orange,
        onTap: _applyRandomColorScheme,
      ),
    ];
  }

  Widget _buildCommandCenter({required bool compact}) {
    return KeyedSubtree(
      key: _settingsTopKey,
      child: _SettingsCommandCenter(
        controller: _settingsSearchController,
        title: '设置命令中心',
        subtitle: '直接搜索设置、工具和诊断入口',
        summary:
            '${_getColorSchemeName(_globalColorScheme)} · $_actualThemeModeLabel · $_localeLabel',
        securityLabel: _strictSecurityMode
            ? l10n.securityLevelStrict
            : l10n.securityLevelStandard,
        diagnosticsLabel: _enableDiagnosticTools ? '诊断已开启' : '日常模式',
        accentColor: _activeThemeColor,
        query: _settingsSearchQuery,
        commands: _filteredSettingsCommands,
        quickActions: _quickActionCommands,
        suggestions: _settingsSearchSuggestions,
        onQueryChanged: _onSearchChanged,
        onClearQuery: _clearSettingsSearch,
        onSuggestionSelected: _applySearchSuggestion,
        compact: compact,
      ),
    );
  }

  Widget _buildSectionNavigator({required bool compact}) {
    return _SettingsSectionNavigator(
      sections: _settingsSections,
      selectedId: _selectedSettingsSection,
      compact: compact,
      onSelected: (id) => _selectSection(id, scrollToSection: true),
    );
  }

  Widget _buildToolBoardSection() {
    return KeyedSubtree(
      key: _toolsSectionKey,
      child: _SettingsToolBoard(
        title: '工具入口',
        subtitle: '把低频入口集中到这里，搜索也能直接打开。',
        icon: Icons.apps_outlined,
        color: Colors.indigo,
        commands: [
          _actionCommand(
            sectionId: _sectionTools,
            title: l10n.quickActionPlatformCheck,
            subtitle: '检查平台连通性',
            keywords: const ['平台体检'],
            icon: Icons.monitor_heart_outlined,
            color: Colors.blue,
            isLoading: _isCheckingPlatformHealth,
            onTap: _runPlatformHealthCheck,
          ),
          _actionCommand(
            sectionId: _sectionTools,
            title: l10n.quickActionFix,
            subtitle: '恢复推荐设置',
            keywords: const ['一键修复'],
            icon: Icons.healing_outlined,
            color: Colors.green,
            onTap: _quickFixCommonIssues,
          ),
          _actionCommand(
            sectionId: _sectionAppearance,
            title: l10n.quickActionRandomPalette,
            subtitle: '随机切换配色',
            keywords: const ['随机配色'],
            icon: Icons.casino_outlined,
            color: Colors.orange,
            onTap: _applyRandomColorScheme,
          ),
          _actionCommand(
            sectionId: _sectionTools,
            title: '界面布局',
            subtitle: '调整主入口布局',
            keywords: const ['布局'],
            icon: Icons.dashboard_customize_outlined,
            color: Colors.indigo,
            onTap: _openLayoutCustomization,
          ),
          _actionCommand(
            sectionId: _sectionTools,
            title: '插件管理',
            subtitle: '管理扩展能力',
            keywords: const ['插件'],
            icon: Icons.extension_outlined,
            color: Colors.purple,
            onTap: _openPluginManagement,
          ),
          _actionCommand(
            sectionId: _sectionTools,
            title: '更新公告',
            subtitle: '版本变化说明',
            keywords: const ['公告'],
            icon: Icons.campaign_outlined,
            color: Colors.orange,
            onTap: _openUpdateAnnouncements,
          ),
          _actionCommand(
            sectionId: _sectionTools,
            title: '随机密码',
            subtitle: '生成密码草案',
            keywords: const ['密码'],
            icon: Icons.password_outlined,
            color: Colors.blueGrey,
            onTap: _showPasswordGeneratorDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildTronclassSection() {
    return KeyedSubtree(
      key: _tronclassSectionKey,
      child: _SettingsControlPanel(
        title: '畅课高级策略',
        subtitle: '门户打开、重新认证和地址维护集中管理。',
        icon: Icons.school_outlined,
        color: Colors.blueGrey,
        children: [
          _buildSelectRow<String>(
            icon: Icons.open_in_browser_outlined,
            title: '门户打开方式',
            subtitle: _portalModeLabel(_tronclassPortalOpenMode),
            value: _tronclassPortalOpenMode,
            color: Colors.blueGrey,
            items: const [
              DropdownMenuItem(
                value: AppSettings.portalOpenModeExternalPreferred,
                child: Text('系统浏览器优先'),
              ),
              DropdownMenuItem(
                value: AppSettings.portalOpenModeEmbeddedPreferred,
                child: Text('内置门户优先'),
              ),
              DropdownMenuItem(
                value: AppSettings.portalOpenModeAskEveryTime,
                child: Text('每次打开都询问'),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _tronclassPortalOpenMode = value);
              await AppSettings.setString(
                AppSettings.tronclassPortalOpenModeKey,
                value,
              );
            },
          ),
          _buildSelectRow<String>(
            icon: Icons.verified_user_outlined,
            title: '重新认证策略',
            subtitle: _reauthModeLabel(_tronclassReauthMode),
            value: _tronclassReauthMode,
            color: Colors.blueGrey,
            items: const [
              DropdownMenuItem(
                value: AppSettings.reauthModeReuseSessionFirst,
                child: Text('优先复用已有会话'),
              ),
              DropdownMenuItem(
                value: AppSettings.reauthModeForceWebReauth,
                child: Text('每次强制网页重新认证'),
              ),
              DropdownMenuItem(
                value: AppSettings.reauthModeExternalBrowserOnly,
                child: Text('直接系统浏览器认证'),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _tronclassReauthMode = value);
              await AppSettings.setString(
                AppSettings.tronclassReauthModeKey,
                value,
              );
            },
          ),
          _SettingsInlineBlock(
            icon: Icons.link_outlined,
            title: '门户与地址工具',
            subtitle: '说明、恢复推荐、打开/复制/检测/重置地址',
            color: Colors.blueGrey,
            child: _buildCompactActions(
              minTileWidth: 150,
              spacing: AppSpacing.sm,
              children: [
                _SettingsCompactAction(
                  icon: Icons.help_outline,
                  label: '门户说明',
                  color: Colors.blueGrey,
                  onTap: _showPortalModeHelpDialog,
                ),
                _SettingsCompactAction(
                  icon: Icons.help_center_outlined,
                  label: '认证说明',
                  color: Colors.blueGrey,
                  onTap: _showReauthModeHelpDialog,
                ),
                _SettingsCompactAction(
                  icon: Icons.restore_outlined,
                  label: '恢复推荐',
                  color: Colors.green,
                  onTap: _restoreRecommendedTronclassModes,
                ),
                _SettingsCompactAction(
                  icon: Icons.open_in_new_outlined,
                  label: '打开门户',
                  color: Colors.indigo,
                  onTap: _openTronclassPortalQuickly,
                ),
                _SettingsCompactAction(
                  icon: Icons.copy_all_outlined,
                  label: '复制地址',
                  color: Colors.indigo,
                  onTap: _copyTronclassPortalUrl,
                ),
                _SettingsCompactAction(
                  icon: Icons.wifi_find_outlined,
                  label: '检测地址',
                  color: Colors.orange,
                  onTap: _checkCurrentTronclassAddress,
                ),
                _SettingsCompactAction(
                  icon: Icons.restart_alt_outlined,
                  label: '重置畅课',
                  color: Colors.redAccent,
                  onTap: _resetTronclassBaseUrlToDefault,
                ),
                _SettingsCompactAction(
                  icon: Icons.restart_alt_outlined,
                  label: '重置课堂派',
                  color: Colors.redAccent,
                  onTap: _resetKetangpaiBaseUrlToDefault,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNoticePanel() {
    return _SettingsRailPanel(
      title: '说明',
      children: [
        _SettingsNoticeCard(
          icon: Icons.verified_user_outlined,
          title: l10n.disclaimerCardTitle,
          subtitle: l10n.disclaimerCardSubtitle,
          color: Colors.redAccent,
          onTap: _showDisclaimerDialog,
        ),
        if (_showBeginnerGuide)
          _SettingsNoticeCard(
            icon: Icons.school_outlined,
            title: l10n.beginnerGuideCardTitle,
            subtitle: l10n.beginnerGuideCardSubtitle,
            color: Colors.blue,
            trailing: Switch(
              value: _showBeginnerGuide,
              onChanged: (v) async {
                setState(() => _showBeginnerGuide = v);
                await AppSettings.setBool(AppSettings.showBeginnerGuideKey, v);
              },
            ),
            onTap: _showBeginnerGuideDialog,
          ),
      ],
    );
  }

  List<Widget> _buildPrimarySettingsSections() {
    final sections = <Widget>[
      const SmartInlinePanel(
        title: '设置与诊断智能建议',
        types: {SmartInsightType.accountNetwork, SmartInsightType.pluginSystem},
      ),
      const ContextHelpHint(
        title: '设置页帮助',
        tips: [
          '登录、签到、验证码和提交链路不会被智能建议自动改动。',
          '平台健康检查只做连通性诊断，不携带账号 Cookie。',
          '低算力流畅模式会降低批处理和缩略图压力，不改变功能结果。',
          '插件异常会在本地提示，避免影响主功能入口。',
        ],
      ),
      _buildAppearanceSection(),
      _buildSecuritySection(),
      _buildAcademicSection(),
      _buildToolBoardSection(),
      _buildTronclassSection(),
      _buildNoticePanel(),
      _buildDiagnosticsArea(),
    ];
    return _spacedSections(sections);
  }

  List<Widget> _buildMobileSettingsSections() {
    return [
      _buildCommandCenter(compact: false),
      const SizedBox(height: AppSpacing.md),
      _buildSectionNavigator(compact: true),
      const SizedBox(height: AppSpacing.md),
      Column(children: _buildPrimarySettingsSections()),
    ];
  }

  List<Widget> _spacedSections(List<Widget> sections) {
    if (sections.isEmpty) {
      return [
        _SettingsEmptyPanel(
          icon: Icons.search_off_outlined,
          title: '没有匹配的设置',
          subtitle: '换个关键词，或者切回“全部”查看完整设置中心。',
          onReset: () {
            _clearSettingsSearch();
            _selectSection(_sectionAll);
          },
        ),
      ];
    }
    return [
      for (var i = 0; i < sections.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        sections[i],
      ],
    ];
  }

  Widget _buildCompactActions({
    required List<Widget> children,
    double minTileWidth = 132,
    double spacing = AppSpacing.md,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final count = max(1, width ~/ minTileWidth);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((child) {
            final tileWidth = (width - spacing * (count - 1)) / count;
            return SizedBox(width: tileWidth, child: child);
          }).toList(),
        );
      },
    );
  }

  Widget _buildSwitchRow({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? color,
    String? badge,
  }) {
    return _SettingsSwitchRow(
      key: key,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
      color: color ?? Theme.of(context).colorScheme.primary,
      badge: badge,
    );
  }

  Widget _buildSelectRow<T>({
    required IconData icon,
    required String title,
    required String subtitle,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    Color? color,
    Key? key,
    String? helperText,
  }) {
    return _SettingsSelectRow<T>(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color ?? Theme.of(context).colorScheme.primary,
      value: value,
      items: items,
      onChanged: onChanged,
      fieldKey: key,
      helperText: helperText,
    );
  }

  Widget _buildAppearanceSection() {
    return KeyedSubtree(
      key: _appearanceSectionKey,
      child: _SettingsControlPanel(
        title: l10n.themeAndAppearanceTitle,
        subtitle: l10n.themeAndAppearanceSubtitle,
        icon: Icons.palette_outlined,
        color: _activeThemeColor,
        children: [
          _buildSelectRow<ThemeMode>(
            icon: Icons.dark_mode_outlined,
            title: l10n.themeModeLabel,
            subtitle: '当前显示：$_actualThemeModeLabel',
            value: _appThemeMode,
            color: Colors.orange,
            key: ValueKey('theme-mode-${_appThemeMode.name}'),
            items: [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text(l10n.themeModeSystem),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text(l10n.themeModeLight),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text(l10n.themeModeDark),
              ),
            ],
            onChanged: (mode) async {
              if (mode == null) return;
              setState(() => _appThemeMode = mode);
              await AppSettings.setThemeMode(mode);
            },
          ),
          _buildSelectRow<String>(
            icon: Icons.translate_outlined,
            title: l10n.languageLabel,
            subtitle: l10n.languageRestartHint,
            value: _selectedLocaleCode,
            color: Colors.teal,
            key: ValueKey('app-locale-$_selectedLocaleCode'),
            helperText: l10n.languageRestartHint,
            items: [
              DropdownMenuItem(
                value: AppSettings.localeCodeZh,
                child: Text(l10n.languageChinese),
              ),
              DropdownMenuItem(
                value: AppSettings.localeCodeEn,
                child: Text(l10n.languageEnglish),
              ),
            ],
            onChanged: (code) async {
              if (code == null) return;
              setState(() => _selectedLocaleCode = code);
              await AppSettings.setLocaleCode(code);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.languageSavedRestart)),
              );
            },
          ),
          _buildSelectRow<String>(
            icon: Icons.style_outlined,
            title: l10n.themeStyleLabel,
            subtitle: '当前风格：$_themeStyleLabel',
            value: _themeStyle,
            color: _activeThemeColor,
            key: ValueKey('theme-style-$_themeStyle'),
            items: [
              DropdownMenuItem(
                value: AppSettings.themeStyleModern,
                child: Text(l10n.themeStyleModern),
              ),
              DropdownMenuItem(
                value: AppSettings.themeStyleCompact,
                child: Text(l10n.themeStyleCompact),
              ),
              DropdownMenuItem(
                value: AppSettings.themeStylePlayful,
                child: Text(l10n.themeStylePlayful),
              ),
              DropdownMenuItem(
                value: AppSettings.themeStyleMinimal,
                child: Text(l10n.themeStyleMinimal),
              ),
              DropdownMenuItem(
                value: AppSettings.themeStyleBold,
                child: Text(l10n.themeStyleBold),
              ),
              DropdownMenuItem(
                value: AppSettings.themeStyleSoft,
                child: Text(l10n.themeStyleSoft),
              ),
            ],
            onChanged: (style) async {
              if (style == null) return;
              setState(() => _themeStyle = style);
              await _saveThemeStyle();
            },
          ),
          _SettingsInlineBlock(
            icon: Icons.color_lens_outlined,
            title: '配色方案',
            subtitle: '选择全局强调色，保留平台状态色用于提示',
            color: _activeThemeColor,
            child: _buildColorSchemeGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSchemeGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final crossAxisCount = width >= 720
            ? 4
            : width >= 500
            ? 3
            : 2;
        return GridView.builder(
          itemCount: _colorSchemeItems.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.45,
          ),
          itemBuilder: (context, index) {
            final item = _colorSchemeItems[index];
            final id = item['id'] as String;
            final selected = _globalColorScheme == id;
            final primary = item['primary'] as Color;
            final secondary = item['secondary'] as Color;
            return _SettingsColorSwatch(
              label: _getColorSchemeName(id),
              primary: primary,
              secondary: secondary,
              selected: selected,
              onTap: () async {
                setState(() {
                  _globalColorScheme = id;
                });
                await _saveGlobalColorScheme();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAcademicSection() {
    return KeyedSubtree(
      key: _academicSectionKey,
      child: _SettingsControlPanel(
        title: l10n.academicToolsTitle,
        subtitle: l10n.academicToolsSubtitle,
        icon: Icons.auto_stories_outlined,
        color: Colors.teal,
        children: [
          _SettingsInlineBlock(
            icon: Icons.alternate_email_outlined,
            title: l10n.academicApiEmailLabel,
            subtitle: l10n.academicApiEmailDescription,
            color: Colors.teal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _academicApiEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: l10n.academicApiEmailHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildCompactActions(
                  minTileWidth: 190,
                  spacing: AppSpacing.sm,
                  children: [
                    _SettingsCompactAction(
                      icon: Icons.save_outlined,
                      label: l10n.saveAcademicEmailTitle,
                      color: Colors.teal,
                      onTap: _saveAcademicApiEmail,
                    ),
                    _SettingsCompactAction(
                      icon: Icons.clear_outlined,
                      label: l10n.clearAcademicEmailTitle,
                      color: Colors.redAccent,
                      onTap: _clearAcademicApiEmail,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _academicApiEmail.isEmpty
                      ? l10n.currentEmailUnset
                      : l10n.currentEmailValue(_academicApiEmail),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return KeyedSubtree(
      key: _securitySectionKey,
      child: _SettingsControlPanel(
        title: l10n.securityAndPacingTitle,
        subtitle: l10n.securityAndPacingSubtitle,
        icon: Icons.shield_outlined,
        color: Colors.green,
        children: [
          _buildSwitchRow(
            key: const ValueKey('autoCloseWebLoginSwitch'),
            icon: Icons.web_asset_off_outlined,
            title: l10n.autoCloseWebLoginTitle,
            subtitle: l10n.autoCloseWebLoginSubtitle,
            value: _autoCloseWebLogin,
            color: Colors.blue,
            badge: _autoCloseWebLogin ? '已开启' : '手动返回',
            onChanged: (v) async {
              setState(() => _autoCloseWebLogin = v);
              await AppSettings.setBool(AppSettings.autoCloseWebLoginKey, v);
            },
          ),
          _buildSwitchRow(
            key: const ValueKey('lowPowerPerformanceSwitch'),
            icon: Icons.battery_saver_outlined,
            title: '低算力流畅模式',
            subtitle: '降低批处理分片、延迟缩略图和目录统计，减少低端设备卡顿。',
            value: _performanceSettings.lowPower,
            color: Colors.green,
            badge: _performanceSettings.lowPower ? '省资源' : '均衡',
            onChanged: _setLowPowerMode,
          ),
          _buildSwitchRow(
            key: const ValueKey('performanceDiagnosticsSwitch'),
            icon: Icons.speed_outlined,
            title: '显示性能诊断',
            subtitle: '记录最近帧耗时，用于流畅度报告；数据只保存在本机内存中。',
            value: _performanceSettings.showDiagnostics,
            color: Colors.indigo,
            badge: _performanceSettings.showDiagnostics ? '采样中' : '关闭',
            onChanged: _setPerformanceDiagnostics,
          ),
          _buildSwitchRow(
            key: const ValueKey('smartOrganizerSwitch'),
            icon: Icons.tips_and_updates_outlined,
            title: '本地智能整理',
            subtitle: '使用本地规则生成资料、待办、复习和诊断建议，不调用外部 AI。',
            value: _smartOrganizerEnabled,
            color: Colors.teal,
            badge: _smartOrganizerEnabled ? '开启' : '关闭',
            onChanged: (v) async {
              setState(() => _smartOrganizerEnabled = v);
              await AppSettings.setBool(
                AppSettings.smartOrganizerEnabledKey,
                v,
              );
            },
          ),
          _buildSwitchRow(
            icon: Icons.security_outlined,
            title: l10n.strictSecurityModeTitle,
            subtitle: l10n.strictSecurityModeSubtitle,
            value: _strictSecurityMode,
            color: _strictSecurityMode ? Colors.redAccent : Colors.green,
            badge: _strictSecurityMode
                ? l10n.securityLevelStrict
                : l10n.securityLevelStandard,
            onChanged: (v) async {
              setState(() => _strictSecurityMode = v);
              await AppSettings.setBool(AppSettings.strictSecurityModeKey, v);
            },
          ),
          AnimatedSwitcher(
            duration: AppDuration.normal,
            child: _SettingsInfoNote(
              key: ValueKey(_strictSecurityMode),
              icon: _strictSecurityMode ? Icons.lock_outline : Icons.lock_open,
              text: _strictSecurityMode
                  ? l10n.securityModeStrictDescription
                  : l10n.securityModeStandardDescription,
              color: _strictSecurityMode ? Colors.redAccent : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsArea() {
    return KeyedSubtree(
      key: _diagnosticsSectionKey,
      child: Column(
        children: [
          _SettingsSection(
            title: '诊断工具',
            subtitle: '默认隐藏低频排查入口，需要时再开启。',
            children: [_buildDiagnosticsToggleCard()],
          ),
          AnimatedSwitcher(
            duration: AppDuration.normal,
            switchInCurve: AppCurves.emphasized,
            switchOutCurve: AppCurves.accelerate,
            child: _enableDiagnosticTools
                ? Padding(
                    key: const ValueKey('diagnostics-section'),
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: _buildDiagnosticsSection(),
                  )
                : const SizedBox.shrink(key: ValueKey('diagnostics-hidden')),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsToggleCard() {
    return _buildSwitchRow(
      icon: Icons.health_and_safety_outlined,
      title: l10n.diagnosticsToggleTitle,
      subtitle: l10n.diagnosticsToggleSubtitle,
      value: _enableDiagnosticTools,
      color: Colors.green,
      badge: _enableDiagnosticTools ? '高级诊断' : '隐藏',
      onChanged: (v) async {
        setState(() => _enableDiagnosticTools = v);
        await AppSettings.setBool(AppSettings.enableDiagnosticToolsKey, v);
      },
    );
  }

  Widget _buildDiagnosticsSection() {
    return _SettingsToolBoard(
      icon: Icons.health_and_safety_outlined,
      title: l10n.diagnosticsTitle,
      subtitle: l10n.diagnosticsSubtitle,
      color: Colors.green,
      commands: [
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.checkPlatformsTitle,
          subtitle: l10n.checkPlatformsSubtitle,
          keywords: const ['平台检查'],
          icon: Icons.monitor_heart_outlined,
          color: Colors.blue,
          isLoading: _isCheckingPlatformHealth,
          onTap: _runPlatformHealthCheck,
        ),
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.copyLastReportTooltip,
          subtitle: _lastPlatformHealthReport == null ? '暂无报告' : '复制最近一次平台体检报告',
          keywords: const ['复制报告'],
          icon: Icons.copy_all_outlined,
          color: Colors.blueGrey,
          onTap: () {
            final text = _lastPlatformHealthReport;
            if (text == null || text.isEmpty) return;
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.lastReportCopied)));
          },
        ),
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.copyDiagnosticPackTitle,
          subtitle: l10n.copyDiagnosticPackSubtitle,
          keywords: const ['诊断包'],
          icon: Icons.assignment_outlined,
          color: Colors.green,
          onTap: _copyDiagnosticPack,
        ),
        _actionCommand(
          key: const ValueKey('performanceReportTile'),
          sectionId: _sectionDiagnostics,
          title: '流畅度报告',
          subtitle: '查看帧耗时与平台请求策略',
          keywords: const ['流畅度'],
          icon: Icons.speed_outlined,
          color: Colors.indigo,
          onTap: _showPerformanceReport,
        ),
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.fixCommonIssuesTitle,
          subtitle: l10n.fixCommonIssuesSubtitle,
          keywords: const ['修复'],
          icon: Icons.healing_outlined,
          color: Colors.green,
          onTap: _quickFixCommonIssues,
        ),
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.accountHealthTitle,
          subtitle: l10n.accountHealthSubtitle,
          keywords: const ['账号体检'],
          icon: Icons.fact_check_outlined,
          color: Colors.teal,
          onTap: _runAccountHealthCheck,
        ),
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.batchPrecheckTitle,
          subtitle: l10n.batchPrecheckSubtitle,
          keywords: const ['批量预检'],
          icon: Icons.rule_folder_outlined,
          color: Colors.orange,
          onTap: _runBatchSignPrecheck,
        ),
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.signRecordsTitle,
          subtitle: l10n.signRecordsSubtitle,
          keywords: const ['签到记录'],
          icon: Icons.history_toggle_off_outlined,
          color: Colors.blueGrey,
          onTap: _openSignRecords,
        ),
        _actionCommand(
          sectionId: _sectionDiagnostics,
          title: l10n.requestConsoleTitle,
          subtitle: l10n.requestConsoleSubtitle,
          keywords: const ['请求控制台'],
          icon: Icons.terminal_outlined,
          color: Colors.deepPurple,
          onTap: _openRequestConsole,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _activeThemeColor),
              const SizedBox(height: AppSpacing.md),
              Text(
                '正在加载设置',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.appSettings,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;

          if (!isWide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  children: _buildMobileSettingsSections(),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: ListView(
                        children: [
                          _buildCommandCenter(compact: true),
                          const SizedBox(height: AppSpacing.md),
                          _buildSectionNavigator(compact: false),
                          const SizedBox(height: AppSpacing.md),
                          _buildSidebarNoticePanel(),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: ListView(
                        children: [
                          Column(children: _buildPrimarySettingsSections()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSectionSpec {
  const _SettingsSectionSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

enum _SettingsCommandType {
  action,
  navigate,
  toggle,
  select,
  palette,
  textInput,
}

class _SettingsCommandOption<T> {
  const _SettingsCommandOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _SettingsCommandSpec {
  const _SettingsCommandSpec({
    this.key,
    required this.sectionId,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.icon,
    required this.color,
    required this.onTap,
    this.type = _SettingsCommandType.navigate,
    this.isAction = false,
    this.isLoading = false,
    this.boolValue,
    this.onBoolChanged,
    this.selectValue,
    this.selectOptions = const [],
    this.onSelectChanged,
    this.paletteItems = const [],
    this.selectedPaletteId,
    this.onPaletteSelected,
    this.paletteLabelBuilder,
    this.textController,
    this.currentText,
    this.onTextSave,
    this.onTextClear,
  });

  final Key? key;
  final String sectionId;
  final String title;
  final String subtitle;
  final List<String> keywords;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final _SettingsCommandType type;
  final bool isAction;
  final bool isLoading;
  final bool? boolValue;
  final ValueChanged<bool>? onBoolChanged;
  final Object? selectValue;
  final List<_SettingsCommandOption<Object?>> selectOptions;
  final ValueChanged<Object?>? onSelectChanged;
  final List<Map<String, dynamic>> paletteItems;
  final String? selectedPaletteId;
  final ValueChanged<String>? onPaletteSelected;
  final String Function(String id)? paletteLabelBuilder;
  final TextEditingController? textController;
  final String? currentText;
  final Future<void> Function()? onTextSave;
  final Future<void> Function()? onTextClear;

  bool matches(String query) {
    final text = <String>[
      title,
      subtitle,
      ...keywords,
      sectionId,
    ].join(' ').toLowerCase();
    return text.contains(query);
  }
}

class _SettingsCommandCenter extends StatelessWidget {
  const _SettingsCommandCenter({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.securityLabel,
    required this.diagnosticsLabel,
    required this.accentColor,
    required this.query,
    required this.commands,
    required this.quickActions,
    required this.suggestions,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onSuggestionSelected,
    required this.compact,
  });

  final TextEditingController controller;
  final String title;
  final String subtitle;
  final String summary;
  final String securityLabel;
  final String diagnosticsLabel;
  final Color accentColor;
  final String query;
  final List<_SettingsCommandSpec> commands;
  final List<_SettingsCommandSpec> quickActions;
  final List<String> suggestions;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onSuggestionSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppAnimations.fadeSlideIn(
      duration: AppDuration.normal,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(scheme.surfaceContainerLow, accentColor, 0.08)!,
              scheme.surfaceContainerLowest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xlarge),
          border: Border.all(color: accentColor.withValues(alpha: 0.22)),
          boxShadow: AppShadows.low(scheme.shadow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xlarge),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.manage_search_outlined,
                    color: accentColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '输入关键词，直接修改设置',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: onClearQuery,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: scheme.surface.withValues(alpha: 0.92),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xlarge),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xlarge),
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xlarge),
                  borderSide: BorderSide(color: accentColor, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SettingsSearchSuggestions(
              suggestions: suggestions,
              selected: query,
              accentColor: accentColor,
              onSelected: onSuggestionSelected,
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsStatusLine(
              items: [
                _SettingsStatusText(
                  icon: Icons.palette_outlined,
                  text: summary,
                ),
                _SettingsStatusText(
                  icon: Icons.shield_outlined,
                  text: securityLabel,
                ),
                _SettingsStatusText(
                  icon: Icons.health_and_safety_outlined,
                  text: diagnosticsLabel,
                ),
              ],
              accentColor: accentColor,
            ),
            const SizedBox(height: AppSpacing.md),
            _SettingsCommandResults(
              title: query.isEmpty ? '常用控制' : '最佳匹配',
              commands: commands,
              emptyText: '没有找到相关设置',
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.md),
              _SettingsCommandResults(
                title: '快捷操作',
                commands: quickActions,
                emptyText: '',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsStatusText {
  const _SettingsStatusText({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _SettingsSearchSuggestions extends StatelessWidget {
  const _SettingsSearchSuggestions({
    required this.suggestions,
    required this.selected,
    required this.accentColor,
    required this.onSelected,
  });

  final List<String> suggestions;
  final String selected;
  final Color accentColor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: suggestions.map((text) {
        final active = selected.trim() == text;
        return Material(
          color: active
              ? accentColor.withValues(alpha: 0.14)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            onTap: () => onSelected(text),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text(
                text,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active ? accentColor : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsStatusLine extends StatelessWidget {
  const _SettingsStatusLine({required this.items, required this.accentColor});

  final List<_SettingsStatusText> items;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                item.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsCommandResults extends StatelessWidget {
  const _SettingsCommandResults({
    required this.title,
    required this.commands,
    required this.emptyText,
  });

  final String title;
  final List<_SettingsCommandSpec> commands;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSwitcher(
          duration: AppDuration.fast,
          child: commands.isEmpty
              ? _SettingsEmptyResult(text: emptyText)
              : Column(
                  key: ValueKey('commands-${commands.length}-$title'),
                  children: commands
                      .map((command) => _SettingsCommandTile(command: command))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _SettingsEmptyResult extends StatelessWidget {
  const _SettingsEmptyResult({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCommandTile extends StatelessWidget {
  const _SettingsCommandTile({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      key: command.key,
      duration: AppDuration.fast,
      curve: AppCurves.emphasized,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Color.lerp(scheme.surface, command.color, 0.035),
        borderRadius: BorderRadius.circular(AppRadius.xlarge),
        border: Border.all(color: command.color.withValues(alpha: 0.16)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: command.isLoading ? null : command.onTap,
          borderRadius: BorderRadius.circular(AppRadius.xlarge),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 420;
                final header = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: command.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                      child: command.isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: command.color,
                              ),
                            )
                          : Icon(command.icon, color: command.color, size: 21),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            command.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            command.subtitle,
                            maxLines: narrow ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final control = _SettingsCommandControl(command: command);
                if (narrow ||
                    command.type == _SettingsCommandType.palette ||
                    command.type == _SettingsCommandType.textInput) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: AppSpacing.md),
                      control,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: header),
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: control,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCommandControl extends StatelessWidget {
  const _SettingsCommandControl({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    return switch (command.type) {
      _SettingsCommandType.toggle => _CommandToggle(command: command),
      _SettingsCommandType.select => _CommandSelect(command: command),
      _SettingsCommandType.palette => _CommandPalette(command: command),
      _SettingsCommandType.textInput => _CommandTextInput(command: command),
      _SettingsCommandType.action ||
      _SettingsCommandType.navigate => _CommandActionButton(command: command),
    };
  }
}

class _CommandToggle extends StatelessWidget {
  const _CommandToggle({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    final value = command.boolValue ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value ? '已开启' : '已关闭',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Switch(
          value: value,
          onChanged: command.onBoolChanged,
          activeThumbColor: command.color,
        ),
      ],
    );
  }
}

class _CommandSelect extends StatelessWidget {
  const _CommandSelect({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: DropdownButtonFormField<Object?>(
        initialValue: command.selectValue,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
        items: command.selectOptions.map((option) {
          return DropdownMenuItem<Object?>(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: command.onSelectChanged,
      ),
    );
  }
}

class _CommandPalette extends StatelessWidget {
  const _CommandPalette({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    final labelBuilder = command.paletteLabelBuilder;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: command.paletteItems.map((item) {
        final id = item['id'] as String;
        final primary = item['primary'] as Color;
        final secondary = item['secondary'] as Color;
        final selected = command.selectedPaletteId == id;
        return Tooltip(
          message: labelBuilder == null ? id : labelBuilder(id),
          child: InkWell(
            onTap: () => command.onPaletteSelected?.call(id),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: AnimatedContainer(
              duration: AppDuration.fast,
              width: 38,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, secondary]),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: selected ? 2 : 1,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CommandTextInput extends StatelessWidget {
  const _CommandTextInput({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    final controller = command.textController;
    if (controller == null) return _CommandActionButton(command: command);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'name@example.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton.icon(
              onPressed: command.onTextSave,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('保存'),
            ),
            OutlinedButton.icon(
              onPressed: command.onTextClear,
              icon: const Icon(Icons.clear_outlined, size: 18),
              label: const Text('清空'),
            ),
          ],
        ),
        if (command.currentText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            command.currentText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _CommandActionButton extends StatelessWidget {
  const _CommandActionButton({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    final isAction = command.type == _SettingsCommandType.action;
    return OutlinedButton.icon(
      onPressed: command.isLoading ? null : command.onTap,
      icon: command.isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: command.color,
              ),
            )
          : Icon(
              isAction ? Icons.north_east_rounded : Icons.near_me_outlined,
              size: 17,
            ),
      label: Text(isAction ? '打开' : '定位'),
      style: OutlinedButton.styleFrom(
        foregroundColor: command.color,
        side: BorderSide(color: command.color.withValues(alpha: 0.35)),
      ),
    );
  }
}

class _SettingsSectionNavigator extends StatelessWidget {
  const _SettingsSectionNavigator({
    required this.sections,
    required this.selectedId,
    required this.compact,
    required this.onSelected,
  });

  final List<_SettingsSectionSpec> sections;
  final String selectedId;
  final bool compact;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = compact
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _buildItems(context)),
          )
        : Column(children: _buildItems(context));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xlarge),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    return sections.map((section) {
      final selected = section.id == selectedId;
      return Padding(
        padding: EdgeInsets.only(
          right: compact ? AppSpacing.xs : 0,
          bottom: compact ? 0 : AppSpacing.xs,
        ),
        child: _SettingsSectionNavItem(
          section: section,
          selected: selected,
          compact: compact,
          onTap: () => onSelected(section.id),
        ),
      );
    }).toList();
  }
}

class _SettingsSectionNavItem extends StatelessWidget {
  const _SettingsSectionNavItem({
    required this.section,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final _SettingsSectionSpec section;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.emphasized,
      width: compact ? null : double.infinity,
      decoration: BoxDecoration(
        color: selected
            ? section.color.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: selected
              ? section.color.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(
                  section.icon,
                  color: selected ? section.color : scheme.onSurfaceVariant,
                  size: 19,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? section.color : scheme.onSurface,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsToolBoard extends StatelessWidget {
  const _SettingsToolBoard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.commands,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_SettingsCommandSpec> commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xlarge),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: AppShadows.low(scheme.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final columns = width >= 820
                  ? 3
                  : width >= 520
                  ? 2
                  : 1;
              const spacing = AppSpacing.sm;
              final tileWidth = (width - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: commands
                    .map(
                      (command) => SizedBox(
                        width: tileWidth,
                        child: _SettingsToolTile(command: command),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsToolTile extends StatelessWidget {
  const _SettingsToolTile({required this.command});

  final _SettingsCommandSpec command;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.emphasized,
      decoration: BoxDecoration(
        color: command.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: command.color.withValues(alpha: 0.18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: command.isLoading ? null : command.onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (command.isLoading)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: command.color,
                        ),
                      )
                    else
                      Icon(command.icon, color: command.color, size: 24),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  command.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  command.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsRailPanel extends StatelessWidget {
  const _SettingsRailPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xlarge),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsEmptyPanel extends StatelessWidget {
  const _SettingsEmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onReset,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xlarge),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant, size: 38),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('查看全部'),
          ),
        ],
      ),
    );
  }
}

class _SettingsControlPanel extends StatelessWidget {
  const _SettingsControlPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xlarge),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: AppShadows.low(scheme.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _SettingsDivider(),
          ..._withDividers(children),
        ],
      ),
    );
  }
}

class _SettingsNoticeCard extends StatelessWidget {
  const _SettingsNoticeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing ??
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          _SettingsDivider(),
          ..._withDividers(children),
        ],
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.color,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = value
        ? color
        : Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.emphasized,
      color: value ? color.withValues(alpha: 0.05) : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: _SettingsRowContent(
            icon: icon,
            title: title,
            subtitle: badge == null ? subtitle : '$subtitle · $badge',
            color: effectiveColor,
            trailing: Switch(value: value, onChanged: onChanged),
          ),
        ),
      ),
    );
  }
}

class _SettingsSelectRow<T> extends StatelessWidget {
  const _SettingsSelectRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.value,
    required this.items,
    required this.onChanged,
    this.fieldKey,
    this.helperText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Key? fieldKey;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          _SettingsRowContent(
            icon: icon,
            title: title,
            subtitle: subtitle,
            color: color,
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: DropdownButtonFormField<T>(
                key: fieldKey,
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(
                  helperText: helperText,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsColorSwatch extends StatelessWidget {
  const _SettingsColorSwatch({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color primary;
  final Color secondary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDuration.fast,
          curve: AppCurves.emphasized,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: selected ? primary : Colors.black26,
              width: selected ? 2 : 1,
            ),
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.95),
                secondary.withValues(alpha: 0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: AppDuration.fast,
                child: selected
                    ? const Icon(
                        Icons.check_circle,
                        key: ValueKey('selected'),
                        color: Colors.white,
                        size: 18,
                      )
                    : const SizedBox(
                        key: ValueKey('unselected'),
                        width: 18,
                        height: 18,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsInlineBlock extends StatelessWidget {
  const _SettingsInlineBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsRowContent(
            icon: icon,
            title: title,
            subtitle: subtitle,
            color: color,
            trailing: const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SettingsCompactAction extends StatelessWidget {
  const _SettingsCompactAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsRowContent extends StatelessWidget {
  const _SettingsRowContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final label = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: narrow ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: narrow ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              if (trailing is! SizedBox) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: min(300, constraints.maxWidth),
                    ),
                    child: trailing,
                  ),
                ),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: label),
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
        );
      },
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

List<Widget> _withDividers(List<Widget> children) {
  if (children.isEmpty) return const [];
  return [
    for (var i = 0; i < children.length; i++) ...[
      children[i],
      if (i != children.length - 1) _SettingsDivider(),
    ],
  ];
}

class _SettingsInfoNote extends StatelessWidget {
  const _SettingsInfoNote({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _SettingsPill extends StatelessWidget {
  const _SettingsPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
