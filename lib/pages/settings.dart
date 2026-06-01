import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../utils/encrypt.dart';
import '../widgets/control_panel_widgets.dart';
import 'request_console_page.dart';
import 'sign_records_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _autoCloseWebLogin = true;
  bool _strictSecurityMode = false;
  bool _showBeginnerGuide = true;
  bool _enableDiagnosticTools = false;
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
    _academicApiEmailController = TextEditingController();
    _loadAllSettings();
  }

  @override
  void dispose() {
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
    final academicApiEmail =
        prefs.getString(AppSettings.academicApiEmailKey) ?? '';

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
      _academicApiEmail = academicApiEmail.trim();
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

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        followRedirects: false,
        validateStatus: (_) => true,
      ),
    );

    final targets = <Map<String, String>>[
      {'name': '学习通', 'url': 'https://passport2.chaoxing.com'},
      {'name': '雨课堂', 'url': 'https://www.yuketang.cn'},
      {'name': '畅课', 'url': PlatformManager().tronclassBaseUrl},
      {'name': '课堂派', 'url': PlatformManager().ketangpaiBaseUrl},
    ];

    final results = <Map<String, String>>[];

    for (final target in targets) {
      final name = target['name']!;
      final url = target['url']!;
      final stopwatch = Stopwatch()..start();

      try {
        final response = await dio.get(url);
        stopwatch.stop();
        final code = response.statusCode ?? 0;
        final ok = code > 0 && code < 500;
        results.add({
          'name': name,
          'url': url,
          'status': ok ? '正常' : '异常',
          'detail': 'HTTP $code · ${stopwatch.elapsedMilliseconds} ms',
        });
      } catch (e) {
        stopwatch.stop();
        results.add({
          'name': name,
          'url': url,
          'status': '异常',
          'detail': '连接失败 · ${stopwatch.elapsedMilliseconds} ms',
          'error': e.toString(),
        });
      }
    }

    if (!mounted) return;

    final now = DateTime.now();
    final report = StringBuffer()
      ..writeln('GUETer 四平台健康检查报告')
      ..writeln('时间: ${now.toLocal()}')
      ..writeln('畅课地址: ${PlatformManager().tronclassBaseUrl}')
      ..writeln('课堂派地址: ${PlatformManager().ketangpaiBaseUrl}')
      ..writeln('')
      ..writeln('检查结果:');

    for (final item in results) {
      report.writeln(
        '- ${item['name']}: ${item['status']} (${item['detail']})',
      );
      report.writeln('  ${item['url']}');
    }

    final reportText = report.toString().trim();

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
                const Text(
                  '该检查用于快速验证平台连通性，不代表账号已登录。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                ...results.map((item) {
                  final ok = item['status'] == '正常';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      ok ? Icons.check_circle : Icons.error_outline,
                      color: ok ? Colors.green : Colors.redAccent,
                    ),
                    title: Text(item['name'] ?? ''),
                    subtitle: Text(
                      '${item['detail']}\n${item['url']}',
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

  Widget _buildDashboardStats() {
    final themeColor =
        _colorSchemeItems.firstWhere(
              (item) => item['id'] == _globalColorScheme,
              orElse: () => _colorSchemeItems.first,
            )['primary']
            as Color;

    // 获取当前实际主题模式（考虑跟随系统的情况）
    final brightness = Theme.of(context).brightness;
    final actualThemeMode = _appThemeMode == ThemeMode.system
        ? (brightness == Brightness.dark
              ? l10n.themeModeDark
              : l10n.themeModeLight)
        : (_appThemeMode == ThemeMode.dark
              ? l10n.themeModeDark
              : l10n.themeModeLight);

    return PanelCard(
      accentColor: themeColor,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: () async {
                HapticFeedback.mediumImpact();
                // 切换配色方案：循环切换到下一个
                final currentIndex = _colorSchemeItems.indexWhere(
                  (item) => item['id'] == _globalColorScheme,
                );
                final nextIndex = (currentIndex + 1) % _colorSchemeItems.length;
                final nextScheme = _colorSchemeItems[nextIndex]['id'] as String;
                final nextName = _getColorSchemeName(nextScheme);

                setState(() => _globalColorScheme = nextScheme);
                await _saveGlobalColorScheme();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.colorSchemeSwitched(nextName)),
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const StatusDot(
                          color: Colors.blue,
                          size: 10,
                          pulsing: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.themePaletteLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getColorSchemeName(_globalColorScheme),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.themePaletteLongPress,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onLongPress: () async {
                HapticFeedback.mediumImpact();
                // 切换主题模式：浅色 -> 深色 -> 跟随系统 -> 浅色
                ThemeMode newMode;
                if (_appThemeMode == ThemeMode.light) {
                  newMode = ThemeMode.dark;
                } else if (_appThemeMode == ThemeMode.dark) {
                  newMode = ThemeMode.system;
                } else {
                  newMode = ThemeMode.light;
                }
                setState(() => _appThemeMode = newMode);
                await AppSettings.setThemeMode(newMode);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.themeModeSwitched(_themeModeLabel(newMode)),
                    ),
                    duration: const Duration(milliseconds: 1500),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusDot(
                          color: _appThemeMode == ThemeMode.dark
                              ? Colors.purple
                              : Colors.orange,
                          size: 10,
                          pulsing: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.themeModeStatLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.touch_app_outlined,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      actualThemeMode,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _appThemeMode == ThemeMode.dark
                            ? Colors.purple
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _appThemeMode == ThemeMode.system
                          ? l10n.themeModeSystem
                          : l10n.themePaletteLongPress,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.themeModeLight;
      case ThemeMode.dark:
        return l10n.themeModeDark;
      case ThemeMode.system:
        return l10n.themeModeSystem;
    }
  }

  Widget _buildQuickActionsSection() {
    return PanelCard(
      accentColor: Colors.blue,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.quickActionsTitle,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.monitor_heart_outlined,
                  label: l10n.quickActionPlatformCheck,
                  color: Colors.blue,
                  onTap: _runPlatformHealthCheck,
                  isLoading: _isCheckingPlatformHealth,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.healing_outlined,
                  label: l10n.quickActionFix,
                  color: Colors.green,
                  onTap: _quickFixCommonIssues,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.casino_outlined,
                  label: l10n.quickActionRandomPalette,
                  color: Colors.orange,
                  onTap: _applyRandomColorScheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: color,
                  ),
                )
              else
                Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showDisclaimerDialog,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.red.withValues(alpha: 0.1),
          highlightColor: Colors.red.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.disclaimerCardTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.disclaimerCardSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBeginnerGuideCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.beginnerGuideCardTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        l10n.beginnerGuideCardSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _showBeginnerGuide,
                  onChanged: (v) async {
                    setState(() => _showBeginnerGuide = v);
                    await AppSettings.setBool(
                      AppSettings.showBeginnerGuideKey,
                      v,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showBeginnerGuideDialog,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(l10n.viewGuideButton),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: Colors.blue.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  foregroundColor: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoldSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    Color? iconColor,
  }) {
    final effectiveColor = iconColor ?? Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: effectiveColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 仪表盘统计卡片
          _buildDashboardStats(),
          const SizedBox(height: 20),

          // 快捷操作区
          _buildQuickActionsSection(),
          const SizedBox(height: 20),

          // 免责声明卡片
          _buildDisclaimerCard(),
          const SizedBox(height: 16),

          // 新手引导卡片
          if (_showBeginnerGuide) _buildBeginnerGuideCard(),
          if (_showBeginnerGuide) const SizedBox(height: 16),

          // 外观与主题
          _buildFoldSection(
            icon: Icons.palette_outlined,
            title: l10n.themeAndAppearanceTitle,
            subtitle: l10n.themeAndAppearanceSubtitle,
            iconColor: Colors.orange,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: DropdownButtonFormField<ThemeMode>(
                  key: ValueKey('theme-mode-${_appThemeMode.name}'),
                  initialValue: _appThemeMode,
                  decoration: InputDecoration(
                    labelText: l10n.themeModeLabel,
                    border: OutlineInputBorder(),
                  ),
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
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('app-locale-$_selectedLocaleCode'),
                  initialValue: _selectedLocaleCode,
                  decoration: InputDecoration(
                    labelText: l10n.languageLabel,
                    helperText: l10n.languageRestartHint,
                    border: const OutlineInputBorder(),
                  ),
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
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text(l10n.languageSavedRestart)),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: DropdownButtonFormField<String>(
                  key: ValueKey('theme-style-$_themeStyle'),
                  initialValue: _themeStyle,
                  decoration: InputDecoration(
                    labelText: l10n.themeStyleLabel,
                    border: OutlineInputBorder(),
                  ),
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
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.casino_outlined),
                title: Text(l10n.randomPaletteTitle),
                subtitle: Text(l10n.randomPaletteSubtitle),
                onTap: _applyRandomColorScheme,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.8,
                  children: _colorSchemeItems.map((item) {
                    final id = item['id'] as String;
                    final selected = _globalColorScheme == id;
                    final primary = item['primary'] as Color;
                    final secondary = item['secondary'] as Color;
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        setState(() {
                          _globalColorScheme = id;
                        });
                        await _saveGlobalColorScheme();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
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
                                _getColorSchemeName(id),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: _autoCloseWebLogin,
            title: Text(l10n.autoCloseWebLoginTitle),
            subtitle: Text(l10n.autoCloseWebLoginSubtitle),
            onChanged: (v) async {
              setState(() => _autoCloseWebLogin = v);
              await AppSettings.setBool(AppSettings.autoCloseWebLoginKey, v);
            },
          ),
          const SizedBox(height: 16),
          _buildFoldSection(
            icon: Icons.auto_stories_outlined,
            title: l10n.academicToolsTitle,
            subtitle: l10n.academicToolsSubtitle,
            iconColor: Colors.teal,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _academicApiEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.academicApiEmailLabel,
                    hintText: l10n.academicApiEmailHint,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  l10n.academicApiEmailDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: Text(l10n.saveAcademicEmailTitle),
                subtitle: Text(
                  _academicApiEmail.isEmpty
                      ? l10n.currentEmailUnset
                      : l10n.currentEmailValue(_academicApiEmail),
                ),
                onTap: _saveAcademicApiEmail,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.clear_outlined),
                title: Text(l10n.clearAcademicEmailTitle),
                subtitle: Text(l10n.clearAcademicEmailSubtitle),
                onTap: _clearAcademicApiEmail,
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_outlined,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.diagnosticsToggleTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              l10n.diagnosticsToggleSubtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableDiagnosticTools,
                        onChanged: (v) async {
                          setState(() => _enableDiagnosticTools = v);
                          await AppSettings.setBool(
                            AppSettings.enableDiagnosticToolsKey,
                            v,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_enableDiagnosticTools) const SizedBox(height: 16),
          if (_enableDiagnosticTools)
            _buildFoldSection(
              icon: Icons.health_and_safety_outlined,
              title: l10n.diagnosticsTitle,
              subtitle: l10n.diagnosticsSubtitle,
              iconColor: Colors.green,
              children: [
                ListTile(
                  leading: _isCheckingPlatformHealth
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Icon(Icons.monitor_heart_outlined),
                  title: Text(l10n.checkPlatformsTitle),
                  subtitle: Text(l10n.checkPlatformsSubtitle),
                  trailing: _lastPlatformHealthReport == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: l10n.copyLastReportTooltip,
                          icon: const Icon(Icons.copy_all_outlined),
                          onPressed: () {
                            final text = _lastPlatformHealthReport;
                            if (text == null || text.isEmpty) return;
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.lastReportCopied)),
                            );
                          },
                        ),
                  enabled: !_isCheckingPlatformHealth,
                  onTap: _runPlatformHealthCheck,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(l10n.copyDiagnosticPackTitle),
                  subtitle: Text(l10n.copyDiagnosticPackSubtitle),
                  onTap: _copyDiagnosticPack,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.healing_outlined),
                  title: Text(l10n.fixCommonIssuesTitle),
                  subtitle: Text(l10n.fixCommonIssuesSubtitle),
                  onTap: _quickFixCommonIssues,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(l10n.accountHealthTitle),
                  subtitle: Text(l10n.accountHealthSubtitle),
                  onTap: _runAccountHealthCheck,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.rule_folder_outlined),
                  title: Text(l10n.batchPrecheckTitle),
                  subtitle: Text(l10n.batchPrecheckSubtitle),
                  onTap: _runBatchSignPrecheck,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_toggle_off_outlined),
                  title: Text(l10n.signRecordsTitle),
                  subtitle: Text(l10n.signRecordsSubtitle),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SignRecordsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.terminal_outlined),
                  title: Text(l10n.requestConsoleTitle),
                  subtitle: Text(l10n.requestConsoleSubtitle),
                  onTap: _openRequestConsole,
                ),
                const Divider(height: 1),
              ],
            ),
          const SizedBox(height: 16),
          _buildFoldSection(
            icon: Icons.shield_outlined,
            title: l10n.securityAndPacingTitle,
            subtitle: l10n.securityAndPacingSubtitle,
            iconColor: Colors.green,
            children: [
              SwitchListTile(
                value: _strictSecurityMode,
                title: Text(l10n.strictSecurityModeTitle),
                subtitle: Text(l10n.strictSecurityModeSubtitle),
                onChanged: (v) async {
                  setState(() => _strictSecurityMode = v);
                  await AppSettings.setBool(
                    AppSettings.strictSecurityModeKey,
                    v,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      l10n.securityLevelLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        _strictSecurityMode
                            ? l10n.securityLevelStrict
                            : l10n.securityLevelStandard,
                      ),
                      avatar: Icon(
                        _strictSecurityMode
                            ? Icons.shield
                            : Icons.shield_outlined,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Text(
                  _strictSecurityMode
                      ? l10n.securityModeStrictDescription
                      : l10n.securityModeStandardDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
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
