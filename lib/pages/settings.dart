import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../platform.dart';
import '../session/account.dart';
import '../session/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _autoCheckUpdate = true;
  bool _enableHaptics = true;
  bool _autoCloseWebLogin = true;
  bool _strictSecurityMode = false;
  bool _showBeginnerGuide = true;
  ThemeMode _appThemeMode = ThemeMode.system;
  bool _isCheckingPlatformHealth = false;
  String? _lastPlatformHealthReport;

  String _tronclassPortalOpenMode =
      AppSettings.portalOpenModeExternalPreferred;
  String _tronclassReauthMode = AppSettings.reauthModeReuseSessionFirst;

  String _globalColorScheme = AppSettings.colorSchemeAqua;

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
      'id': AppSettings.colorSchemeSunset,
      'name': '暖暮',
      'primary': Color(0xFFEC6D3C),
      'secondary': Color(0xFFB94922),
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
      'id': AppSettings.colorSchemeSlate,
      'name': '石板',
      'primary': Color(0xFF5E6B7A),
      'secondary': Color(0xFF3E4A59),
    },
    {
      'id': AppSettings.colorSchemeNight,
      'name': '护眼夜色',
      'primary': Color(0xFF1F6F78),
      'secondary': Color(0xFF164A51),
    },
    {
      'id': AppSettings.colorSchemeMint,
      'name': '薄荷',
      'primary': Color(0xFF2A9D8F),
      'secondary': Color(0xFF1F746A),
    },
    {
      'id': AppSettings.colorSchemeRose,
      'name': '暖红',
      'primary': Color(0xFFD96C6C),
      'secondary': Color(0xFFA84E4E),
    },
    {
      'id': AppSettings.colorSchemeSky,
      'name': '晴空',
      'primary': Color(0xFF3B82F6),
      'secondary': Color(0xFF2457A6),
    },
    {
      'id': AppSettings.colorSchemeIndigo,
      'name': '靛蓝',
      'primary': Color(0xFF4F46E5),
      'secondary': Color(0xFF3730A3),
    },
    {
      'id': AppSettings.colorSchemeOlive,
      'name': '橄榄',
      'primary': Color(0xFF6B8E23),
      'secondary': Color(0xFF4F6B19),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final autoCheck = prefs.getBool(AppSettings.autoCheckUpdateKey) ?? true;
    final haptics = prefs.getBool(AppSettings.enableHapticsKey) ?? true;
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

    if (!mounted) return;

    setState(() {
      _autoCheckUpdate = autoCheck;
      _enableHaptics = haptics;
      _autoCloseWebLogin = autoClose;
      _strictSecurityMode = strictMode;
      _showBeginnerGuide = showBeginnerGuide;
      _appThemeMode = themeMode;
      _tronclassPortalOpenMode = portalOpenMode;
      _tronclassReauthMode = reauthMode;
      _globalColorScheme = colorScheme;
      _loading = false;
    });
  }

  Future<void> _saveGlobalColorScheme() async {
    await AppSettings.setGlobalColorScheme(_globalColorScheme);
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复为推荐策略')),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复畅课地址为桂电默认地址')),
    );
  }

  Future<void> _resetKetangpaiBaseUrlToDefault() async {
    await PlatformManager().setKetangpaiBaseUrl(
      'https://openapiv5.ketangpai.com',
    );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已恢复课堂派地址为默认地址')),
    );
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('检查报告已复制，可直接转发')),
              );
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

  Future<Map<String, List<Map<String, dynamic>>>> _loadAccountSnapshots() async {
    final prefs = await SharedPreferences.getInstance();
    final platforms = <String>['chaoxing', 'rainclassroom', 'tronclass', 'ketangpai'];
    final snapshots = <String, List<Map<String, dynamic>>>{};

    for (final platform in platforms) {
      final raw = prefs.getString('${platform}_accounts');
      if (raw == null || raw.isEmpty) {
        snapshots[platform] = <Map<String, dynamic>>[];
        continue;
      }
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
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

    final tronclassAccounts = snapshots['tronclass'] ?? <Map<String, dynamic>>[];
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
    final locationPermission = await _permissionLabel(Permission.locationWhenInUse);

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
      ..writeln('- 畅课: ${(snapshots['tronclass'] ?? const []).length} (会话绑定: $tronclassSessionBound)')
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('诊断包已复制，可直接转发同学或反馈')),
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
    await PlatformManager().setKetangpaiBaseUrl('https://openapiv5.ketangpai.com');

    if (!mounted) return;
    setState(() {
      _tronclassPortalOpenMode = AppSettings.portalOpenModeExternalPreferred;
      _tronclassReauthMode = AppSettings.reauthModeReuseSessionFirst;
      _strictSecurityMode = false;
      _autoCloseWebLogin = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('常见问题修复完成（地址/策略/安全模式已重置）')),
    );
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

    for (final platform in <String>['chaoxing', 'rainclassroom', 'tronclass', 'ketangpai']) {
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

    final report = 'GUETer 账号体检\n时间: ${DateTime.now().toLocal()}\n\n${lines.join('\n')}';

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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('账号体检报告已复制')),
              );
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
    final locationPermission = await _permissionLabel(Permission.locationWhenInUse);

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
        lines.add('- ${endpoint['name']}: HTTP $code · ${watch.elapsedMilliseconds} ms');
      } catch (_) {
        watch.stop();
        lines.add('- ${endpoint['name']}: 连接失败 · ${watch.elapsedMilliseconds} ms');
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('预检报告已复制')),
              );
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


  Widget _buildSectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '全局设置中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '统一管理主题、配色和请求安全模式。',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionTitle(Icons.tune, '常用功能'),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _autoCheckUpdate,
            title: const Text('自动检查更新'),
            subtitle: const Text('启动后自动检查是否有新版本'),
            onChanged: (v) async {
              setState(() => _autoCheckUpdate = v);
              await AppSettings.setBool(AppSettings.autoCheckUpdateKey, v);
            },
          ),
          SwitchListTile(
            value: _autoCloseWebLogin,
            title: const Text('网页登录成功后自动返回'),
            subtitle: const Text('畅课网页登录拿到会话后自动关闭页面'),
            onChanged: (v) async {
              setState(() => _autoCloseWebLogin = v);
              await AppSettings.setBool(AppSettings.autoCloseWebLoginKey, v);
            },
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<ThemeMode>(
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
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '畅课门户打开方式（默认推荐）',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _showPortalModeHelpDialog,
                child: const Text('了解详情'),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('portal-mode-$_tronclassPortalOpenMode'),
            initialValue: _tronclassPortalOpenMode,
            decoration: const InputDecoration(
              labelText: '畅课门户打开方式',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: AppSettings.portalOpenModeExternalPreferred,
                child: Text('系统浏览器优先（推荐）'),
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
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _tronclassPortalOpenMode = v);
              await AppSettings.setString(AppSettings.tronclassPortalOpenModeKey, v);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '畅课一键重新认证策略（默认推荐）',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _showReauthModeHelpDialog,
                child: const Text('了解详情'),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('reauth-mode-$_tronclassReauthMode'),
            initialValue: _tronclassReauthMode,
            decoration: const InputDecoration(
              labelText: '畅课一键重新认证策略',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: AppSettings.reauthModeReuseSessionFirst,
                child: Text('优先复用已有会话（少验证码）'),
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
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _tronclassReauthMode = v);
              await AppSettings.setString(AppSettings.tronclassReauthModeKey, v);
            },
          ),
          const SizedBox(height: 14),
          _buildSectionTitle(Icons.bolt_outlined, '畅课轻量功能'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('恢复推荐策略'),
                  subtitle: const Text('门户改为系统浏览器优先，重新认证改为会话复用优先'),
                  onTap: _restoreRecommendedTronclassModes,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.open_in_browser_outlined),
                  title: const Text('快速打开畅课门户'),
                  subtitle: const Text('使用系统浏览器打开当前门户地址'),
                  onTap: _openTronclassPortalQuickly,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('复制当前门户地址'),
                  subtitle: Text(PlatformManager().tronclassBaseUrl),
                  onTap: _copyTronclassPortalUrl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionTitle(Icons.link_outlined, '平台地址工具'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: const Text('检测当前畅课地址'),
                  subtitle: Text(PlatformManager().tronclassBaseUrl),
                  onTap: _checkCurrentTronclassAddress,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('恢复畅课默认地址'),
                  subtitle: const Text('https://courses.guet.edu.cn'),
                  onTap: _resetTronclassBaseUrlToDefault,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('恢复课堂派默认地址'),
                  subtitle: const Text('https://openapiv5.ketangpai.com'),
                  onTap: _resetKetangpaiBaseUrlToDefault,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionTitle(Icons.health_and_safety_outlined, '平台健康检查'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
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
          ),
          const SizedBox(height: 14),
          _buildSectionTitle(Icons.handyman_outlined, '诊断与修复（同学版）'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
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
                SwitchListTile(
                  value: _showBeginnerGuide,
                  title: const Text('启用新手引导'),
                  subtitle: const Text('可在下方随时查看引导说明'),
                  onChanged: (v) async {
                    setState(() => _showBeginnerGuide = v);
                    await AppSettings.setBool(AppSettings.showBeginnerGuideKey, v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('查看新手引导'),
                  subtitle: const Text('首次使用与常见排障建议'),
                  onTap: _showBeginnerGuideDialog,
                ),
              ],
            ),
          ),
          SwitchListTile(
            value: _enableHaptics,
            title: const Text('启用触感反馈'),
            subtitle: const Text('按钮点击时使用轻微触感反馈（后续页面逐步接入）'),
            onChanged: (v) async {
              setState(() => _enableHaptics = v);
              await AppSettings.setBool(AppSettings.enableHapticsKey, v);
            },
          ),
          SwitchListTile(
            value: _strictSecurityMode,
            title: const Text('严格安全模式'),
            subtitle: const Text('觉得可能请求过快的同学可以开启严格安全模式'),
            onChanged: (v) async {
              setState(() => _strictSecurityMode = v);
              await AppSettings.setBool(AppSettings.strictSecurityModeKey, v);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    _strictSecurityMode ? Icons.shield : Icons.shield_outlined,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
            child: Text(
              _strictSecurityMode ? '当前模式：严格安全模式（签到类请求会额外降频）' : '当前模式：标准（默认）',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle(Icons.palette_outlined, '全局配色方案'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
                  width: 150,
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
        ],
      ),
    );
  }
}
