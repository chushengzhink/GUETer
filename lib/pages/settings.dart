import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String _tronclassPortalOpenMode = AppSettings.portalOpenModeExternalPreferred;
  String _tronclassReauthMode = AppSettings.reauthModeReuseSessionFirst;

  String _globalColorScheme = AppSettings.colorSchemeAqua;
  String _themeStyle = AppSettings.themeStyleModern;

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

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
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
              const Expanded(child: Text('设置公告')),
            ],
          ),
          content: const SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Text(
                '欢迎使用 GUETer。\n\n'
                '本项目仅提供本地化的学习辅助能力，不提供账号云端同步、密码代收或后台上传服务。\n\n'
                '账号、会话与相关本地记录采用加密后落盘保存；不会上传到本项目服务器，也不会主动发送你的账号密码。\n\n'
                '本公告为版本化提示，后续条款更新时会再次提示一次。\n\n'
                '如你所在学校、平台方或权利人对相关功能有异议，请以合规方式与我们联系处理。',
                style: TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('稍后再看'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('我已知晓'),
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
    final enableDiagnostic =
        prefs.getBool(AppSettings.enableDiagnosticToolsKey) ?? false;

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
      _enableDiagnosticTools = enableDiagnostic;
      _loading = false;
    });

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

  Future<void> _copyTronclassPortalUrl() async {
    final url = PlatformManager().tronclassBaseUrl;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制门户地址：$url')));
  }

  Future<void> _resetTronclassBaseUrlToDefault() async {
    await PlatformManager().setTronclassBaseUrl('https://courses.guet.edu.cn');
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已恢复畅课地址为桂电默认地址')));
  }

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
        title: const Text('批量签到预检结果'),
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
              ).showSnackBar(const SnackBar(content: Text('预检报告已复制')));
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
        title: const Text('新手引导（可关闭）'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 先选平台再登录，对应平台账号互不影响。\n\n'
            '2. 畅课建议用“系统浏览器优先 + 会话复用优先”。\n\n'
            '3. 签到前先跑一次“批量签到预检”。\n\n'
            '4. 异常时先点“一键修复常见问题”，再生成诊断包反馈。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
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
    final name = picked['name'] as String;

    setState(() {
      _globalColorScheme = id;
    });
    await _saveGlobalColorScheme();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已切换盲盒配色：$name')));
  }

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
    const content =
        '免责声明（请先阅读）\n\n'
        '1. 本应用仅供学习交流与技术研究使用，不得用于任何违法违规用途。\n\n'
        '2. 本应用与学习通、雨课堂、畅课、课堂派、微助教等平台及其所属机构不存在官方合作关系。\n\n'
        '3. 用户应确保本人已获得对应平台账号与课程的合法使用授权，因个人操作导致的账号风险、数据损失或其他后果由用户自行承担。\n\n'
        '4. 本应用不提供账号云端同步、密码代收或后台上传服务；账号、会话与相关本地记录采用加密后落盘保存，不会上传到本项目服务器，也不会主动发送你的账号密码。\n\n'
        '5. 本应用不承诺服务连续可用，不对因网络波动、平台策略调整、接口变更、设备兼容问题导致的功能异常承担责任。\n\n'
        '6. 若你所在学校、平台方或权利人认为相关功能或展示内容存在不当，请及时联系我们处理。\n\n'
        '如有侵权请联系邮箱3177401522a@gmai.com';

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
            const Expanded(child: Text('免责声明')),
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
                  '简要说明：本项目不代收账号密码，不做云端同步，账号数据仅加密保存在本机。',
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
              Clipboard.setData(const ClipboardData(text: content));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('免责声明已复制')));
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('复制全文'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我已知晓'),
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
              child: const Text('关闭'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: generated));
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(const SnackBar(content: Text('密码已复制到剪贴板')));
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('复制'),
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
        ? (brightness == Brightness.dark ? '深色' : '浅色')
        : (_appThemeMode == ThemeMode.dark ? '深色' : '浅色');

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
                final nextName = _colorSchemeItems[nextIndex]['name'] as String;

                setState(() => _globalColorScheme = nextScheme);
                await _saveGlobalColorScheme();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已切换配色：$nextName'),
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
                          '配色方案',
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
                      '长按切换',
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
                      '已切换至${newMode == ThemeMode.light
                          ? '浅色'
                          : newMode == ThemeMode.dark
                          ? '深色'
                          : '跟随系统'}模式',
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
                          color: _appThemeMode == ThemeMode.dark ? Colors.purple : Colors.orange,
                          size: 10,
                          pulsing: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '主题模式',
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
                        color: _appThemeMode == ThemeMode.dark ? Colors.purple : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _appThemeMode == ThemeMode.system
                          ? '跟随系统'
                          : '长按切换',
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
    final item = _colorSchemeItems.firstWhere(
      (item) => item['id'] == scheme,
      orElse: () => _colorSchemeItems.first,
    );
    return item['name'] as String;
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
              const Text(
                '快捷操作',
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
                  label: '平台体检',
                  color: Colors.blue,
                  onTap: _runPlatformHealthCheck,
                  isLoading: _isCheckingPlatformHealth,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.healing_outlined,
                  label: '一键修复',
                  color: Colors.green,
                  onTap: _quickFixCommonIssues,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.casino_outlined,
                  label: '随机配色',
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
                        '免责声明（请先阅读）',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '本地加密存储，不上传服务器',
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
                      const Text(
                        '新手引导',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '首次使用与常见排障建议',
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
                label: const Text('查看引导内容'),
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
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w600)),
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
            title: '外观与主题',
            subtitle: '配色方案、主题风格、主题模式',
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
                  decoration: const InputDecoration(
                    labelText: '主题模式',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('跟随系统'),
                    ),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('深色护眼'),
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
                  key: ValueKey('theme-style-$_themeStyle'),
                  initialValue: _themeStyle,
                  decoration: const InputDecoration(
                    labelText: '主题风格',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AppSettings.themeStyleModern,
                      child: Text('现代（推荐）'),
                    ),
                    DropdownMenuItem(
                      value: AppSettings.themeStyleCompact,
                      child: Text('紧凑'),
                    ),
                    DropdownMenuItem(
                      value: AppSettings.themeStylePlayful,
                      child: Text('趣味'),
                    ),
                    DropdownMenuItem(
                      value: AppSettings.themeStyleMinimal,
                      child: Text('极简'),
                    ),
                    DropdownMenuItem(
                      value: AppSettings.themeStyleBold,
                      child: Text('大胆'),
                    ),
                    DropdownMenuItem(
                      value: AppSettings.themeStyleSoft,
                      child: Text('柔和'),
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
                title: const Text('盲盒随机配色'),
                subtitle: const Text('随机切换到一套不同的全局配色'),
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
                                item['name'] as String,
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
            title: const Text('网页登录成功后自动返回'),
            subtitle: const Text('畅课网页登录拿到会话后自动关闭页面'),
            onChanged: (v) async {
              setState(() => _autoCloseWebLogin = v);
              await AppSettings.setBool(
                AppSettings.autoCloseWebLoginKey,
                v,
              );
            },
          ),
          const SizedBox(height: 16),
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
                            const Text(
                              '检查、诊断与修复工具',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '默认关闭，开启后可使用诊断功能',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              title: '检查、诊断与修复',
              subtitle: '平台体检、报告导出与一键修复',
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
                title: const Text('检查四大平台连通性'),
                subtitle: const Text('学习通、雨课堂、畅课、课堂派'),
                trailing: _lastPlatformHealthReport == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        tooltip: '复制上次报告',
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: () {
                          final text = _lastPlatformHealthReport;
                          if (text == null || text.isEmpty) return;
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('上次检查报告已复制')),
                          );
                        },
                      ),
                enabled: !_isCheckingPlatformHealth,
                onTap: _runPlatformHealthCheck,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('生成诊断包并复制'),
                subtitle: const Text('包含设置快照、账号统计、权限状态'),
                onTap: _copyDiagnosticPack,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.healing_outlined),
                title: const Text('一键修复常见问题'),
                subtitle: const Text('恢复推荐策略与默认平台地址'),
                onTap: _quickFixCommonIssues,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('账号体检'),
                subtitle: const Text('检查四平台账号可用状态'),
                onTap: _runAccountHealthCheck,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.rule_folder_outlined),
                title: const Text('批量签到预检'),
                subtitle: const Text('检查账号、权限、网络是否就绪'),
                onTap: _runBatchSignPrecheck,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_outlined),
                title: const Text('签到记录查询'),
                subtitle: const Text('按时间/平台/课程筛选，支持复制与分享'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignRecordsPage()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.terminal_outlined),
                title: const Text('请求控制台'),
                subtitle: const Text('查看最近请求结果、重试与错误日志'),
                onTap: _openRequestConsole,
              ),
              const Divider(height: 1),
            ],
          ),
          const SizedBox(height: 16),
          _buildFoldSection(
            icon: Icons.shield_outlined,
            title: '安全与请求节奏',
            subtitle: '请求安全级别控制',
            iconColor: Colors.green,
            children: [
              SwitchListTile(
                value: _strictSecurityMode,
                title: const Text('严格安全模式'),
                subtitle: const Text('觉得可能请求过快的同学可以开启严格安全模式'),
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
                      '请求安全级别：',
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
                      label: Text(_strictSecurityMode ? '严格' : '标准'),
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
                      ? '当前模式：严格安全模式（签到类请求会额外降频）'
                      : '当前模式：标准（默认）',
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
