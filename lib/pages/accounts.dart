import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/login.dart';
import '../api/platform_dio_manager.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../session/cookie.dart';
import '../session/tronclass_auth.dart';
import '../models/user.dart';
import '../platform.dart';
import '../utils/global_palette.dart';
import 'widget/avatar.dart';
import 'login.dart';
import 'tronclass_web_login.dart';
import 'ketangpai_main_struct.dart';

class AccountChangeNotifier {
  static final AccountChangeNotifier _instance =
      AccountChangeNotifier._internal();
  factory AccountChangeNotifier() => _instance;
  AccountChangeNotifier._internal();

  final StreamController<String?> _controller = StreamController.broadcast();

  Stream<String?> get accountChanges => _controller.stream;

  void notifyAccountChanged(String? accountId) {
    _controller.add(accountId);
  }

  void dispose() {
    _controller.close();
  }
}

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage>
    with TickerProviderStateMixin {
  List<User> _accounts = [];
  final Set<String> _selectedAccounts = <String>{};
  final Map<String, bool> _chaoxingLoginState = <String, bool>{};
  final Map<String, bool> _rainClassroomLoginState = <String, bool>{};
  final Map<String, bool> _tronclassLoginState = <String, bool>{};
  final Map<String, bool> _ketangpaiLoginState = <String, bool>{};
  bool _isMultiSelectMode = false;
  String? _currentAccountId;
  PlatformType _selectedPlatform = PlatformManager().currentPlatform;
  bool _isPlatformSwitching = false;
  StreamSubscription? _accountChangeSubscription;
  StreamSubscription? _platformChangeSubscription;
  Color _globalPrimary = const Color(0xFF1F9EA8);
  Color _globalSecondary = const Color(0xFF157B88);

  @override
  void initState() {
    super.initState();
    AppSettings.globalColorSchemeNotifier.addListener(_onGlobalSchemeChanged);
    _loadGlobalPalette();
    _loadAccounts();
    _platformChangeSubscription = PlatformManager().platformChanges.listen((platform) {
      if (!mounted) return;
      // 立即清空旧数据并显示加载态，避免 UI 残留
      setState(() {
        _selectedPlatform = platform;
        _accounts = [];
        _currentAccountId = null;
        _chaoxingLoginState.clear();
        _rainClassroomLoginState.clear();
        _tronclassLoginState.clear();
        _ketangpaiLoginState.clear();
        _isPlatformSwitching = false;
      });
      _loadGlobalPalette();
      _loadAccounts();
    });

    // 监听账户变更事件
    _accountChangeSubscription = AccountChangeNotifier().accountChanges.listen((
      accountId,
    ) {
      if (mounted) {
        _loadAccounts();
      }
    });
  }

  @override
  void dispose() {
    AppSettings.globalColorSchemeNotifier.removeListener(
      _onGlobalSchemeChanged,
    );
    _accountChangeSubscription?.cancel();
    _platformChangeSubscription?.cancel();
    super.dispose();
  }

  void _onGlobalSchemeChanged() {
    _loadGlobalPalette();
  }

  void _loadGlobalPalette() {
    final scheme = AppSettings.globalColorSchemeNotifier.value;
    final palette = resolveGlobalPalette(scheme);
    final platformPalette = resolvePlatformPalette(
      PlatformManager().currentPlatform,
      fallback: palette,
    );
    if (!mounted) return;
    setState(() {
      _globalPrimary = platformPalette.primary;
      _globalSecondary = platformPalette.secondary;
    });
  }

  Future<void> _loadAccounts() async {
    final targetPlatform = PlatformManager().currentPlatform;
    final current = AccountManager.currentSessionId;
    final allAccounts = AccountManager.getAllAccounts();

    final platformName = PlatformManager().currentPlatformName.toLowerCase();
    final filteredAccounts = allAccounts.where((user) {
      return user.platform.toLowerCase() == platformName;
    }).toList();

    try {
      if (filteredAccounts.isEmpty) {
        if (!mounted || PlatformManager().currentPlatform != targetPlatform) {
          return;
        }
        setState(() {
          _accounts = [];
          _currentAccountId = null;
          _selectedPlatform = targetPlatform;
          _chaoxingLoginState.clear();
          _rainClassroomLoginState.clear();
          _tronclassLoginState.clear();
          _ketangpaiLoginState.clear();
        });
        return;
      }

      // 并行执行所有平台的登录状态检查
      final results = await Future.wait([
        _refreshChaoxingLoginState(allAccounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        ),
        _refreshRainClassroomLoginState(allAccounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        ),
        _refreshTronclassLoginState(allAccounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        ),
        _refreshKetangpaiLoginState(allAccounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        ),
      ]);

      final chaoxingState = results[0];
      final rainClassroomState = results[1];
      final tronclassState = results[2];
      final ketangpaiState = results[3];

      if (!mounted || PlatformManager().currentPlatform != targetPlatform) {
        return;
      }

      setState(() {
        _accounts = filteredAccounts;
        _currentAccountId = current;
        _selectedPlatform = targetPlatform;
        _chaoxingLoginState
          ..clear()
          ..addAll(chaoxingState);
        _rainClassroomLoginState
          ..clear()
          ..addAll(rainClassroomState);
        _tronclassLoginState
          ..clear()
          ..addAll(tronclassState);
        _ketangpaiLoginState
          ..clear()
          ..addAll(ketangpaiState);
      });
    } catch (e) {
      debugPrint('[AccountsPage] 加载账户状态失败: $e');
      if (!mounted || PlatformManager().currentPlatform != targetPlatform) {
        return;
      }
      setState(() {
        _accounts = filteredAccounts;
        _currentAccountId = current;
        _selectedPlatform = targetPlatform;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPlatformSwitching = false;
        });
      }
    }
  }

  Future<Map<String, bool>> _refreshKetangpaiLoginState(
    List<User> accounts,
  ) async {
    final state = <String, bool>{};
    for (final user in accounts) {
      if (!user.isKetangpai) {
        continue;
      }
      final token = user.token.trim();
      if (token.isEmpty) {
        state[user.uid] = false;
        continue;
      }
      state[user.uid] = await KTLoginApi.checkTokenStatus(token);
    }
    return state;
  }

  Future<Map<String, bool>> _refreshChaoxingLoginState(
    List<User> accounts,
  ) async {
    final state = <String, bool>{};
    for (final user in accounts) {
      if (!user.isChaoxing) {
        continue;
      }
      // Reference project approach: if account exists, it's logged in
      state[user.uid] = true;
    }
    return state;
  }

  Future<Map<String, bool>> _refreshRainClassroomLoginState(
    List<User> accounts,
  ) async {
    final state = <String, bool>{};
    const probeUris = <String>[
      'https://www.yuketang.cn/',
      'https://pro.yuketang.cn/',
    ];

    bool hasAuthCookies(List<dynamic> cookies) {
      if (cookies.isEmpty) {
        return false;
      }
      final names = cookies
          .map((c) => c?.name?.toString().toLowerCase() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();
      return names.contains('sessionid') ||
          names.contains('university_id') ||
          names.contains('csrftoken') ||
          names.contains('xtbz');
    }

    for (final user in accounts) {
      if (!user.isRainClassroom) {
        continue;
      }

      var loggedIn = false;

      // 优化：仅检查 Cookie，不调用 API
      final jar = await CookieManager.getCookieJarForUser(user.uid);
      for (final uri in probeUris) {
        final cookies = await jar.loadForRequest(Uri.parse(uri));
        if (hasAuthCookies(cookies)) {
          loggedIn = true;
          break;
        }
      }

      state[user.uid] = loggedIn;
    }

    return state;
  }

  Future<Map<String, bool>> _refreshTronclassLoginState(
    List<User> accounts,
  ) async {
    final state = <String, bool>{};
    for (final user in accounts) {
      if (!user.isTronclass) {
        continue;
      }
      final sessionId = await TronclassAuthManager.getSessionIdForUser(
        user.uid,
      );
      state[user.uid] = sessionId != null && sessionId.isNotEmpty;
    }
    return state;
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedAccounts.contains(userId)) {
        _selectedAccounts.remove(userId);
      } else {
        _selectedAccounts.add(userId);
      }
      if (_selectedAccounts.isEmpty) _isMultiSelectMode = false;
    });
  }

  void _toggleMultiSelect() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) _selectedAccounts.clear();
    });
  }

  Future<void> _deleteSelectedAccounts() async {
    if (_selectedAccounts.isNotEmpty) {
      await AccountManager.removeAccounts(_selectedAccounts.toList());
      await _loadAccounts();
      _toggleMultiSelect();
    }
  }

  Future<void> _switchToAccount(User user) async {
    if (user.uid == _currentAccountId) {
      return;
    }
    await AccountManager.setCurrentSession(user.uid);
    AccountChangeNotifier().notifyAccountChanged(user.uid);

    setState(() {
      _currentAccountId = user.uid;
      _accounts.remove(user);
      _accounts.insert(0, user);
    });
  }

  Widget _buildPlatformSwitcherPanel() {
    final currentPlatform = PlatformManager().currentPlatform;
    final currentPlatformName = switch (currentPlatform) {
      PlatformType.chaoxing => '学习通',
      PlatformType.rainClassroom => '雨课堂',
      PlatformType.tronclass => '畅课',
      PlatformType.ketangpai => '课堂派',
      PlatformType.weizhuojiao => '微助教',
    };

    final entries = <Map<String, Object>>[
      {
        'platform': PlatformType.chaoxing,
        'label': '学习通',
        'subtitle': '课程与签到',
        'icon': Icons.school_outlined,
      },
      {
        'platform': PlatformType.rainClassroom,
        'label': '雨课堂',
        'subtitle': '在线课堂',
        'icon': Icons.cloud_outlined,
      },
      {
        'platform': PlatformType.tronclass,
        'label': '畅课',
        'subtitle': '签到工作台',
        'icon': Icons.dashboard_customize_outlined,
      },
      {
        'platform': PlatformType.ketangpai,
        'label': '课堂派',
        'subtitle': '答题与考试',
        'icon': Icons.quiz_outlined,
      },
      {
        'platform': PlatformType.weizhuojiao,
        'label': '微助教',
        'subtitle': '功能待完善',
        'icon': Icons.construction_outlined,
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Card(
        elevation: 0,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _globalPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.swap_horiz, color: _globalPrimary),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '平台快捷切换',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '这里切平台，课程页会同步刷新。',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _globalPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '当前：$currentPlatformName',
                      style: TextStyle(
                        color: _globalPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: entries.map((entry) {
                  final platform = entry['platform'] as PlatformType;
                  final label = entry['label'] as String;
                  final subtitle = entry['subtitle'] as String;
                  final icon = entry['icon'] as IconData;
                  final selected = currentPlatform == platform;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      if (platform == PlatformType.weizhuojiao) {
                        _showWeizhuojiaoComingSoonNotice();
                        return;
                      }

                      debugPrint('[PlatformSwitch] 从 $currentPlatform 切换到 $platform');

                      // 立即清空旧平台账户详情，显示切换中
                      setState(() {
                        _isPlatformSwitching = true;
                        _accounts = [];
                        _currentAccountId = null;
                        _chaoxingLoginState.clear();
                        _rainClassroomLoginState.clear();
                        _tronclassLoginState.clear();
                        _ketangpaiLoginState.clear();
                      });

                      try {
                        // 用户主动点击平台切换按钮，设置 2 秒超时
                        await PlatformManager().setPlatform(platform, userInitiated: true).timeout(
                          const Duration(seconds: 2),
                          onTimeout: () {
                            debugPrint('[PlatformSwitch] 切换超时，强制完成 UI 更新');
                          },
                        );
                      } catch (e) {
                        debugPrint('[PlatformSwitch] 切换失败: $e');
                      } finally {
                        if (mounted) {
                          setState(() => _isPlatformSwitching = false);
                        }
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 108,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? LinearGradient(
                                colors: [
                                  _globalPrimary,
                                  _globalSecondary.withValues(alpha: 0.92),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: selected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? _globalPrimary
                              : Colors.grey.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            icon,
                            color: selected ? Colors.white : _globalPrimary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logoutAccount(User user) async {
    final isLoggedIn = user.isTronclass
        ? (await TronclassAuthManager.getSessionIdForUser(
                user.uid,
              ))?.isNotEmpty ==
              true
        : user.isKetangpai
        ? user.token.isNotEmpty
        : true;

    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该账号当前未登录')));
      return;
    }

    if (!mounted) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('确认退出登录'),
          content: Text('确定要退出 ${user.name} 的${_platformLabel(user)}登录状态吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    if (user.uid == _currentAccountId) {
      await AccountManager.clearCurrentSession();
      AccountChangeNotifier().notifyAccountChanged(null);
    } else {
      await CookieManager.clearCookiesForUser(user.uid);
      await TronclassAuthManager.clearSessionIdForUser(user.uid);
    }
    CookieManager.clearTempCookies();

    // 清理该用户的独立 Dio 实例
    PlatformDioManager.clearDioForUser(
      platform: PlatformType.values.firstWhere(
        (p) => p.toString().split('.').last == user.platform,
        orElse: () => PlatformType.tronclass,
      ),
      userId: user.uid,
    );

    if (user.isKetangpai) {
      await AccountManager.addAccount(
        User(
          uid: user.uid,
          name: user.name,
          avatar: user.avatar,
          phone: user.phone,
          school: user.school,
          platform: user.platform,
          token: '',
        ),
      );
    }

    await _loadAccounts();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${user.name} 已退出登录')));
  }

  Future<void> _openTronclassPortal() async {
    if (!PlatformManager().isTronclass) {
      return;
    }

    var mode = await AppSettings.getString(
      AppSettings.tronclassPortalOpenModeKey,
      AppSettings.portalOpenModeExternalPreferred,
    );

    if (mode == AppSettings.portalOpenModeAskEveryTime && mounted) {
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('选择打开方式'),
          content: const Text('本次如何打开畅课门户？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, AppSettings.portalOpenModeEmbeddedPreferred);
              },
              child: const Text('内置门户'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, AppSettings.portalOpenModeExternalPreferred);
              },
              child: const Text('系统浏览器'),
            ),
          ],
        ),
      );
      mode = selected ?? AppSettings.portalOpenModeExternalPreferred;
    }

    if (defaultTargetPlatform == TargetPlatform.windows &&
        mode == AppSettings.portalOpenModeEmbeddedPreferred) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Windows 下已自动改为系统浏览器打开')),
        );
      }
      mode = AppSettings.portalOpenModeExternalPreferred;
    }

    if (mode == AppSettings.portalOpenModeExternalPreferred) {
      final opened = await launchUrl(
        Uri.parse(PlatformManager().tronclassBaseUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('系统浏览器打开失败')));
      }
      return;
    }

    final currentUserId = _currentAccountId;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录畅课账号')));
      await _navigateToPasswordLogin();
      return;
    }

    final account = AccountManager.getAccountById(currentUserId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassWebLoginPage(
          accountName: account?.name ?? currentUserId,
          accountId: currentUserId,
          initialUrl: Uri.parse(PlatformManager().tronclassBaseUrl),
          initialMessage: '已进入畅课门户，可直接查看课程、公告和作业',
          autoCloseOnAuthSuccess: false,
        ),
      ),
    );
    await _loadAccounts();
  }

  Future<void> _quickReauthTronclass() async {
    if (!PlatformManager().isTronclass) {
      return;
    }

    final reauthMode = await AppSettings.getString(
      AppSettings.tronclassReauthModeKey,
      AppSettings.reauthModeReuseSessionFirst,
    );

    if (reauthMode == AppSettings.reauthModeExternalBrowserOnly) {
      final opened = await launchUrl(
        Uri.parse(PlatformManager().tronclassBaseUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('系统浏览器打开失败')));
      }
      return;
    }

    final currentUserId = _currentAccountId;
    if (currentUserId == null || currentUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择畅课账号')));
      return;
    }

    final account = AccountManager.getAccountById(currentUserId);
    if (account == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未找到当前账号信息')));
      return;
    }

    if (reauthMode == AppSettings.reauthModeReuseSessionFirst) {
      final savedSessionId = await TronclassAuthManager.getSessionIdForUser(
        account.uid,
      );
      if (savedSessionId != null && savedSessionId.isNotEmpty) {
        final reused = await TCLoginApi.bootstrapPortalSession(
          sessionId: savedSessionId,
        );
        if (reused) {
          final refreshed = await TCLoginApi.getUserInfo(fallbackUid: account.uid);
          if (refreshed != null) {
            await AccountManager.addAccount(refreshed);
          }
          await _loadAccounts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('会话复用成功，无需再次输入验证码')),
            );
          }
          return;
        }
      }
    }

    final autoCloseWebLogin = await AppSettings.getBool(
      AppSettings.autoCloseWebLoginKey,
      true,
    );

    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassWebLoginPage(
          accountName: account.name,
          accountId: account.uid,
          initialMessage: '正在为当前账号重新认证，成功后自动返回',
          autoCloseOnAuthSuccess: autoCloseWebLogin,
        ),
      ),
    );

    if (result?['ok'] == true) {
      final sessionId = result?['sessionId']?.toString().trim();
      await AccountManager.setCurrentSession(account.uid);
      if (sessionId != null && sessionId.isNotEmpty) {
        await TronclassAuthManager.setSessionIdForUser(account.uid, sessionId);
        await TCLoginApi.bootstrapPortalSession(sessionId: sessionId);
      }
      final refreshed = await TCLoginApi.getUserInfo(fallbackUid: account.uid);
      if (refreshed != null) {
        await AccountManager.addAccount(
          refreshed.copyWith(password: account.password),
        );
      }
      AccountChangeNotifier().notifyAccountChanged(account.uid);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重新认证成功')));
      }
    }
    await _loadAccounts();
  }

  bool _isAccountLoggedIn(User user) {
    if (user.isChaoxing) {
      return _chaoxingLoginState[user.uid] ?? false;
    }
    if (user.isRainClassroom) {
      return _rainClassroomLoginState[user.uid] ?? false;
    }
    if (user.isTronclass) {
      return _tronclassLoginState[user.uid] ?? false;
    }
    if (user.isKetangpai) {
      return _ketangpaiLoginState[user.uid] ?? false;
    }
    return false;
  }

  Future<void> _navigateToPasswordLogin() async {
    final currentAccount = _currentAccountId == null
        ? null
        : AccountManager.getAccountById(_currentAccountId!);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(
          initialLoginType: 'password',
          initialUsername: currentAccount?.uid,
          initialPassword: currentAccount?.password,
        ),
      ),
    );
    if (result == true) {
      await _loadAccounts();
    }
  }

  Future<void> _navigateToCaptchaLogin() async {
    if (PlatformManager().isTronclass) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('畅课统一走网页登录流程，可在网页里使用验证码/扫码登录')),
        );
      }
      await _navigateToPasswordLogin();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(initialLoginType: 'captcha'),
      ),
    );
    if (result == true) {
      await _loadAccounts();
    }
  }

  Future<void> _showQRCodeLoginDialog() async {
    if (PlatformManager().isTronclass) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('畅课二维码登录已并入网页登录，请在网页中扫码')));
      }
      await _navigateToPasswordLogin();
      return;
    }

    if (PlatformManager().isKetangpai) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('课堂派暂未提供独立扫码登录，已切换到验证码登录')),
        );
      }
      await _navigateToCaptchaLogin();
      return;
    }

    final qrState = QRCodeLoginState();

    if (!await qrState.initialize()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('获取二维码失败')));
      }
      qrState.dispose();
      return;
    }

    qrState.startPolling((bool success) async {
      if (!mounted) {
        qrState.dispose();
        return;
      }
      if (success) {
        qrState.isLoginActive = false;
        final loginSuccess = await handleLoginSuccess(context);
        qrState.dispose();
        if (!mounted) {
          return;
        }
        if (loginSuccess) {
          Navigator.of(context, rootNavigator: true).pop(true);
          await Future.delayed(const Duration(milliseconds: 100));
          await _loadAccounts();
        }
      }
    });

    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) {
                  qrState.isLoginActive = false;
                  qrState.dispose();
                }
              },
              child: AlertDialog(
                title: const Text('二维码登录'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: qrState.qrImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                qrState.qrImageUrl!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            )
                          : qrState.isLoading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text(
                                    '生成中...',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '二维码加载失败',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      PlatformManager().isChaoxing
                          ? '使用学习通APP扫码登录'
                          : '使用微信扫码登录',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '二维码失效时会自动刷新',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      qrState.isLoginActive = false;
                      qrState.dispose();
                      Navigator.pop(context);
                    },
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: qrState.isRefreshing || qrState.isLoading
                        ? null
                        : () async {
                            setState(() => qrState.isRefreshing = true);
                            await qrState.refreshQRCode();
                            if (!mounted) return;
                            setState(() => qrState.isRefreshing = false);
                          },
                    child: qrState.isRefreshing
                        ? const Text('刷新中...')
                        : const Text('刷新'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    qrState.dispose();
  }

  void _showWeizhuojiaoComingSoonNotice() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('微助教功能正在完善中，敬请期待')));
  }

  String _platformLabel(User user) {
    if (user.isTronclass) return '畅课';
    if (user.isKetangpai) return '课堂派';
    if (user.isRainClassroom) return '雨课堂';
    if (user.isWeizhuojiao) return '微助教';
    return '学习通';
  }

  String _selectedPlatformLabel() {
    switch (_selectedPlatform) {
      case PlatformType.chaoxing:
        return '学习通';
      case PlatformType.rainClassroom:
        return '雨课堂';
      case PlatformType.tronclass:
        return '畅课';
      case PlatformType.ketangpai:
        return '课堂派';
      case PlatformType.weizhuojiao:
        return '微助教';
    }
  }

  Widget _buildTitle(String name, bool isCurrentAccount, User user) {
    return Row(
      children: [
        Expanded(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _platformLabel(user),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isCurrentAccount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: _globalPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '当前',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildListItemContent(
    BuildContext context,
    User user,
    bool isSelected,
    bool isCurrentAccount,
  ) {
    final canLogout =
      (user.isChaoxing && (_chaoxingLoginState[user.uid] ?? false)) ||
      (user.isRainClassroom &&
        (_rainClassroomLoginState[user.uid] ?? false)) ||
      (user.isTronclass && (_tronclassLoginState[user.uid] ?? false)) ||
      (user.isKetangpai && (_ketangpaiLoginState[user.uid] ?? false));
    final chaoxingStatus = user.isChaoxing
      ? ((_chaoxingLoginState[user.uid] ?? false) ? '已登录' : '未登录')
      : null;
    final rainClassroomStatus = user.isRainClassroom
      ? ((_rainClassroomLoginState[user.uid] ?? false) ? '已登录' : '未登录')
      : null;
    final tronclassStatus = user.isTronclass
        ? ((_tronclassLoginState[user.uid] ?? false) ? '已登录' : '未登录')
        : null;
    final ketangpaiStatus = user.isKetangpai
        ? ((_ketangpaiLoginState[user.uid] ?? false) ? '已登录' : '未登录')
        : null;
    final weizhuojiaoStatus = user.isWeizhuojiao ? '工具页' : null;

    final platformStatus =
      chaoxingStatus ??
      rainClassroomStatus ??
      tronclassStatus ??
      ketangpaiStatus ??
      weizhuojiaoStatus;
    final subtitle = platformStatus == null
        ? 'ID: ${user.uid}\n手机号: ${user.phone}'
        : 'ID: ${user.uid}\n手机号: ${user.phone}\n平台状态: $platformStatus';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: AvatarWidget(key: ValueKey(user.avatar), imageUrl: user.avatar),
      title: _buildTitle(user.name, isCurrentAccount, user),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canLogout && !_isMultiSelectMode)
            IconButton(
              tooltip: '退出登录',
              icon: const Icon(Icons.logout),
              onPressed: () => _logoutAccount(user),
            ),
          if (_isMultiSelectMode)
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                if (value != null) _toggleSelection(user.uid);
              },
            ),
        ],
      ),
      onTap: _isMultiSelectMode ? null : () => _switchToAccount(user),
      onLongPress: () {
        _toggleMultiSelect();
        _toggleSelection(user.uid);
      },
    );
  }

  Widget _buildOverviewCard() {
    final currentUser = _currentAccountId != null
        ? _accounts.firstWhere((u) => u.uid == _currentAccountId, orElse: () => _accounts.isNotEmpty ? _accounts.first : User(uid: '', name: '', avatar: '', phone: '', school: '', platform: ''))
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_globalPrimary, _globalSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: (_isPlatformSwitching || (_accounts.isEmpty && _currentAccountId == null))
          ? const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '账户管理',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '加载中...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '账户管理',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前平台：${_selectedPlatformLabel()}  ·  已绑定 ${_accounts.length} 个账号',
                  style: const TextStyle(color: Colors.white),
                ),
                if (currentUser != null && currentUser.uid.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '当前账户：${currentUser.name} (${currentUser.uid})',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
    );
  }

  void _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final appIcon = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _globalPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.school_rounded, size: 34, color: _globalPrimary),
    );

    showAboutDialog(
      context: context,
      applicationName: 'GUETer',
      applicationVersion: packageInfo.version,
      applicationIcon: appIcon,
      // applicationLegalese: '',
      children: [
        const Text('一个管理学习通、雨课堂课程的应用。'),
        const Text('支持多账号管理、课程查看、活动签到等功能。'),
        const SizedBox(height: 10),
        const Text('平台源码致谢', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _buildThanksLinkRow(
          label: '学习通/雨课堂平台感谢：',
          linkText: 'AneryCoft 源码',
          url: 'https://github.com/AneryCoft',
        ),
        const SizedBox(height: 4),
        _buildThanksLinkRow(
          label: '畅课平台感谢：',
          linkText: 'wilinz/tronclass_plus 源码',
          url: 'https://github.com/wilinz/tronclass_plus',
        ),
        const SizedBox(height: 4),
        _buildThanksLinkRow(
          label: '畅课平台登录美化接口感谢：',
          linkText: 'chongzi/guethub 源码',
          url: 'https://github.com/chongzi/guethub',
        ),
        const SizedBox(height: 4),
        _buildThanksLinkRow(
          label: '课堂派平台感谢：',
          linkText: 'roselle-luo/fuckketangpai_app 源码',
          url: 'https://github.com/roselle-luo/fuckketangpai_app',
        ),
        const SizedBox(height: 4),
        _buildThanksLinkRow(
          label: '微助教平台感谢：',
          linkText: 'zn-cn/wzj-sign-in-weixin 源码',
          url: 'https://github.com/zn-cn/wzj-sign-in-weixin',
        ),
      ],
    );
  }

  Widget _buildThanksLinkRow({
    required String label,
    required String linkText,
    required String url,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              linkText,
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                color: _globalPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTronclassBaseUrlDialog() async {
    final controller = TextEditingController(
      text: PlatformManager().tronclassBaseUrl,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('畅课服务器地址'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '例如：https://courses.guet.edu.cn',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;
    await PlatformManager().setTronclassBaseUrl(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换畅课服务器为：${PlatformManager().tronclassBaseUrl}'),
      ),
    );
  }

  Future<void> _showKetangpaiBaseUrlDialog() async {
    final controller = TextEditingController(
      text: PlatformManager().ketangpaiBaseUrl,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('课堂派服务器地址'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '例如：https://openapiv5.ketangpai.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;
    await PlatformManager().setKetangpaiBaseUrl(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换课堂派服务器为：${PlatformManager().ketangpaiBaseUrl}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号'),
        backgroundColor: _globalPrimary,
        foregroundColor: Colors.white,
        actions: [
          if (_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedAccounts,
              tooltip: '删除选中账号',
            ),
          if (_selectedPlatform == PlatformType.rainClassroom)
            PopupMenuButton<RainClassroomServerType>(
              icon: const Icon(Icons.dns),
              tooltip: '切换服务器',
              onSelected: (RainClassroomServerType server) async {
                await PlatformManager().setServer(server);
                if (!mounted) return;
                await _loadAccounts();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('已切换到 ${PlatformManager().serverName} 服务器')),
                );
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<RainClassroomServerType>(
                  enabled: true,
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setPopupState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RadioGroup<RainClassroomServerType>(
                            groupValue: PlatformManager().currentServer,
                            onChanged: (RainClassroomServerType? value) async {
                              if (value != null) {
                                setPopupState(() {});
                                Navigator.pop(context);
                                await PlatformManager().setServer(value);
                                if (!mounted) return;
                                await _loadAccounts();
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text('已切换到 ${PlatformManager().serverName} 服务器')),
                                );
                              }
                            },
                            child: Column(
                              children: [
                                RadioListTile<RainClassroomServerType>(
                                  title: const Text('雨课堂'),
                                  value: RainClassroomServerType.yuketang,
                                  dense: true,
                                ),
                                RadioListTile<RainClassroomServerType>(
                                  title: const Text('荷塘 · 雨课堂'),
                                  value: RainClassroomServerType.pro,
                                  dense: true,
                                ),
                                RadioListTile<RainClassroomServerType>(
                                  title: const Text('长江 · 雨课堂'),
                                  value: RainClassroomServerType.changjiang,
                                  dense: true,
                                ),
                                RadioListTile<RainClassroomServerType>(
                                  title: const Text('黄河 · 雨课堂'),
                                  value: RainClassroomServerType.huanghe,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          if (_selectedPlatform == PlatformType.tronclass)
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: '设置畅课服务器',
              onPressed: _showTronclassBaseUrlDialog,
            ),
          if (_selectedPlatform == PlatformType.ketangpai)
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: '设置课堂派服务器',
              onPressed: _showKetangpaiBaseUrlDialog,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (String result) {
              if (result == 'about') {
                _showAboutDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              // 平台切换菜单项
              // 关于菜单项
              const PopupMenuItem<String>(
                value: 'about',
                child: Row(children: [Text('关于')]),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _globalPrimary.withValues(alpha: 0.08),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildPlatformSwitcherPanel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _buildOverviewCard(),
            ),
            if (_accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 120, 24, 96),
                child: Column(
                  children: [
                    Text(
                      '暂无账号',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '点击右下角添加账号',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                itemCount: _accounts.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final user = _accounts[index];
                  final isSelected = _selectedAccounts.contains(user.uid);
                  final isCurrent =
                      user.uid == _currentAccountId && _isAccountLoggedIn(user);
                  return Card(
                    elevation: isCurrent ? 3 : 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isCurrent
                            ? _globalPrimary.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                    ),
                    child: _buildListItemContent(
                      context,
                      user,
                      isSelected,
                      isCurrent,
                    ),
                  );
                },
              ),
            const SizedBox(height: 96),
          ],
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        spacing: 5,
        spaceBetweenChildren: 2,
        overlayColor: Colors.transparent,
        overlayOpacity: 0.3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        children: [
          if (_selectedPlatform == PlatformType.weizhuojiao)
            SpeedDialChild(
              child: const Icon(Icons.block_outlined),
              label: '微助教功能正在完善中',
              onTap: _showWeizhuojiaoComingSoonNotice,
            ),
          if (_selectedPlatform == PlatformType.tronclass)
            SpeedDialChild(
              child: const Icon(Icons.verified_user),
              label: '一键重新认证',
              onTap: _quickReauthTronclass,
            ),
          if (_selectedPlatform == PlatformType.tronclass)
            SpeedDialChild(
              child: const Icon(Icons.public),
              label: '畅课入口',
              onTap: _openTronclassPortal,
            ),
          if (_selectedPlatform == PlatformType.ketangpai)
            SpeedDialChild(
              child: const Icon(Icons.link),
              label: '课堂派服务器',
              onTap: _showKetangpaiBaseUrlDialog,
            ),
          if (_selectedPlatform == PlatformType.ketangpai)
            SpeedDialChild(
              child: const Icon(Icons.dashboard_outlined),
              label: '课堂派主页',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KetangpaiMainStructPage(),
                  ),
                );
              },
            ),
          if (_selectedPlatform != PlatformType.tronclass &&
              _selectedPlatform != PlatformType.weizhuojiao)
            SpeedDialChild(
              child: const Icon(Icons.qr_code),
              label: '二维码登录',
              onTap: _showQRCodeLoginDialog,
            ),
          if (_selectedPlatform != PlatformType.tronclass &&
              _selectedPlatform != PlatformType.weizhuojiao)
            SpeedDialChild(
              child: const Icon(Icons.sms),
              label: '验证码登录',
              onTap: _navigateToCaptchaLogin,
            ),
          if (_selectedPlatform != PlatformType.weizhuojiao)
          SpeedDialChild(
            child: const Icon(Icons.password),
            label: _selectedPlatform == PlatformType.tronclass
                ? '账号密码登录'
                : '密码登录',
            onTap: _navigateToPasswordLogin,
          ),
        ],
      ),
    );
  }
}
