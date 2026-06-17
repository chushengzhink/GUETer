import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:async';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';
import '../api/login.dart';
import '../session/account.dart';
import '../session/account_events.dart';
import '../session/app_settings.dart';
import '../session/cookie.dart';
import '../session/tronclass_auth.dart';
import '../models/user.dart';
import '../platform.dart';
import '../utils/global_palette.dart';
import '../theme/animations.dart';
import '../theme/design_tokens.dart';
import '../theme/components/dashboard_components.dart';
import '../services/update_service.dart';
import 'widget/avatar.dart';
import 'login.dart';
import 'tronclass_web_login.dart';
import 'ketangpai_main_struct.dart';
import 'update_announcements_page.dart';
import 'user_manual_page.dart';

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
  UpdateCheckStatus? _updateStatus;

  @override
  void initState() {
    super.initState();
    AppSettings.globalColorSchemeNotifier.addListener(_onGlobalSchemeChanged);
    _loadGlobalPalette();
    _loadUpdateStatus();
    _loadAccounts();
    _platformChangeSubscription = PlatformManager().platformChanges.listen((
      platform,
    ) {
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
    _accountChangeSubscription = AccountChangeNotifier().accountStateChanges
        .listen((snapshot) {
          if (!mounted) {
            return;
          }
          if (snapshot.platform == PlatformManager().currentPlatform) {
            _applyAccountSnapshot(snapshot);
            return;
          }
          _loadAccounts();
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

  Future<void> _loadUpdateStatus() async {
    final status = await UpdateCheckStatusStore().load();
    if (!mounted) return;
    setState(() {
      _updateStatus = status;
    });
  }

  void _applyAccountSnapshot(AccountStateSnapshot snapshot) {
    if (snapshot.platform != PlatformManager().currentPlatform) {
      return;
    }

    _applyVisibleAccounts(
      snapshot.accounts,
      snapshot.currentAccountId,
      snapshot.platform,
      clearLoginState: snapshot.accounts.isEmpty,
    );
    ApiService.appendExternalConsoleLog(
      '通用',
      '[AccountsPage] snapshotApplied platform=${snapshot.platform.name} '
          'count=${snapshot.accounts.length} current=${snapshot.currentAccountId ?? '-'} '
          'visibleCurrentAccount=${snapshot.accounts.any((account) => account.uid == snapshot.currentAccountId)}',
    );
    unawaited(
      _refreshLoginStateForVisibleAccounts(
        snapshot.accounts,
        snapshot.platform,
      ),
    );
  }

  Future<void> _loadAccounts() async {
    final targetPlatform = PlatformManager().currentPlatform;
    final filteredAccounts =
        await AccountManager.refreshAccountsForPlatformName(
          PlatformManager().currentPlatformName,
        );
    final current = AccountManager.currentSessionId;

    if (!mounted || PlatformManager().currentPlatform != targetPlatform) {
      return;
    }
    _applyVisibleAccounts(
      filteredAccounts,
      current,
      targetPlatform,
      clearLoginState: filteredAccounts.isEmpty,
    );
    ApiService.appendExternalConsoleLog(
      '通用',
      '[AccountsPage] loadAccounts platform=${PlatformManager().currentPlatformName} '
          'storageCount=${filteredAccounts.length} current=${current ?? '-'} applied=true',
    );

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

      // 只探测当前平台的登录状态，避免无意义的跨平台探活
      var chaoxingState = <String, bool>{};
      var rainClassroomState = <String, bool>{};
      var tronclassState = <String, bool>{};
      var ketangpaiState = <String, bool>{};

      switch (targetPlatform) {
        case PlatformType.chaoxing:
          chaoxingState = await _refreshChaoxingLoginState(filteredAccounts)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => <String, bool>{},
              );
          break;
        case PlatformType.rainClassroom:
          rainClassroomState =
              await _refreshRainClassroomLoginState(filteredAccounts).timeout(
                const Duration(seconds: 5),
                onTimeout: () => <String, bool>{},
              );
          break;
        case PlatformType.tronclass:
          tronclassState = await _refreshTronclassLoginState(filteredAccounts)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => <String, bool>{},
              );
          break;
        case PlatformType.ketangpai:
          ketangpaiState = await _refreshKetangpaiLoginState(filteredAccounts)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => <String, bool>{},
              );
          break;
        case PlatformType.weizhuojiao:
          break;
      }

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
      ApiService.appendExternalConsoleLog(
        '通用',
        '[AccountsPage] loginStateRefreshDone platform=${targetPlatform.name} '
            'count=${filteredAccounts.length}',
      );
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

  void _applyVisibleAccounts(
    List<User> accounts,
    String? currentAccountId,
    PlatformType platform, {
    bool clearLoginState = false,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _accounts = List<User>.of(accounts);
      _currentAccountId = currentAccountId;
      _selectedPlatform = platform;
      _isPlatformSwitching = false;
      if (clearLoginState) {
        _chaoxingLoginState.clear();
        _rainClassroomLoginState.clear();
        _tronclassLoginState.clear();
        _ketangpaiLoginState.clear();
      }
    });
  }

  Future<void> _refreshLoginStateForVisibleAccounts(
    List<User> accounts,
    PlatformType platform,
  ) async {
    if (accounts.isEmpty) {
      return;
    }

    try {
      if (platform == PlatformType.chaoxing) {
        final state = await _refreshChaoxingLoginState(accounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        );
        if (!mounted || PlatformManager().currentPlatform != platform) return;
        setState(() {
          _chaoxingLoginState
            ..clear()
            ..addAll(state);
        });
      } else if (platform == PlatformType.rainClassroom) {
        final state = await _refreshRainClassroomLoginState(accounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        );
        if (!mounted || PlatformManager().currentPlatform != platform) return;
        setState(() {
          _rainClassroomLoginState
            ..clear()
            ..addAll(state);
        });
      } else if (platform == PlatformType.tronclass) {
        final state = await _refreshTronclassLoginState(accounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        );
        if (!mounted || PlatformManager().currentPlatform != platform) return;
        setState(() {
          _tronclassLoginState
            ..clear()
            ..addAll(state);
        });
      } else if (platform == PlatformType.ketangpai) {
        final state = await _refreshKetangpaiLoginState(accounts).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, bool>{},
        );
        if (!mounted || PlatformManager().currentPlatform != platform) return;
        setState(() {
          _ketangpaiLoginState
            ..clear()
            ..addAll(state);
        });
      }

      ApiService.appendExternalConsoleLog(
        '通用',
        '[AccountsPage] loginStateRefreshDone platform=${platform.name} '
            'count=${accounts.length}',
      );
    } catch (e) {
      debugPrint('[AccountsPage] 鍒锋柊璐︽埛鐘舵€佸け璐? $e');
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
      state[user.uid] = await AccountManager.hasValidTronclassSession(user);
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
    final switched = await AccountManager.switchAccount(user.uid);
    if (!switched) {
      return;
    }

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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppAnimations.fadeSlideIn(
        begin: const Offset(0, 0.08),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadius.xlarge),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: AppShadows.low(Theme.of(context).colorScheme.shadow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _globalPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: _globalPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '平台快捷切换',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '这里切平台，课程页会同步刷新。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
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
                      borderRadius: BorderRadius.circular(AppRadius.pill),
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
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: entries.map((entry) {
                  final platform = entry['platform'] as PlatformType;
                  final label = entry['label'] as String;
                  final subtitle = entry['subtitle'] as String;
                  final icon = entry['icon'] as IconData;
                  final selected = currentPlatform == platform;

                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _handlePlatformTap(platform, currentPlatform),
                    child: _PlatformSwitcherChip(
                      label: label,
                      subtitle: subtitle,
                      icon: icon,
                      selected: selected,
                      primary: _globalPrimary,
                      secondary: _globalSecondary,
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

  Future<void> _handlePlatformTap(
    PlatformType platform,
    PlatformType currentPlatform,
  ) async {
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
      await PlatformManager()
          .setPlatform(platform, userInitiated: true)
          .timeout(
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
  }

  Future<void> _logoutAccount(User user) async {
    final isLoggedIn = user.isTronclass
        ? await AccountManager.hasValidTronclassSession(user)
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

    await AccountManager.logoutAccount(user);
    CookieManager.clearTempCookies();

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
                Navigator.pop(
                  context,
                  AppSettings.portalOpenModeEmbeddedPreferred,
                );
              },
              child: const Text('内置门户'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  AppSettings.portalOpenModeExternalPreferred,
                );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Windows 下已自动改为系统浏览器打开')));
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
          final refreshed = await TCLoginApi.getUserInfo(
            fallbackUid: account.uid,
          );
          if (refreshed != null) {
            await AccountManager.addAccount(refreshed);
          }
          await _loadAccounts();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('会话复用成功，无需再次输入验证码')));
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
      await AccountManager.setCurrentSession(account.uid, notify: false);
      if (sessionId != null && sessionId.isNotEmpty) {
        await TronclassAuthManager.setSessionIdForUser(account.uid, sessionId);
        await TCLoginApi.bootstrapPortalSession(sessionId: sessionId);
      } else {
        await TronclassAuthManager.clearSessionIdForUser(account.uid);
      }
      final refreshed = await TCLoginApi.getUserInfo(fallbackUid: account.uid);
      if (refreshed != null) {
        await AccountManager.addAccount(
          refreshed.copyWith(password: account.password),
          notify: false,
        );
      }
      AccountManager.notifyStateChanged();
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

    return _AccountCard(
      user: user,
      platformLabel: _platformLabel(user),
      platformStatus: platformStatus ?? '未知状态',
      isLoggedIn: platformStatus == '已登录' || platformStatus == '工具页',
      canLogout: canLogout,
      isCurrentAccount: isCurrentAccount,
      isSelected: isSelected,
      isMultiSelectMode: _isMultiSelectMode,
      primary: _globalPrimary,
      secondary: _globalSecondary,
      onTap: _isMultiSelectMode ? null : () => _switchToAccount(user),
      onLongPress: () {
        _toggleMultiSelect();
        _toggleSelection(user.uid);
      },
      onLogout: () => _logoutAccount(user),
      onSelectedChanged: (value) {
        if (value != null) _toggleSelection(user.uid);
      },
      avatar: AvatarWidget(key: ValueKey(user.avatar), imageUrl: user.avatar),
    );
  }

  Widget _buildAccountListSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AppAnimations.fadeSlideIn(
        begin: const Offset(0, 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isMultiSelectMode ? '选择账号' : '账号列表',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: AppDuration.fast,
                  child: _isMultiSelectMode
                      ? _StatusBadge(
                          key: const ValueKey('selecting'),
                          label: '已选 ${_selectedAccounts.length}',
                          icon: Icons.checklist_rounded,
                          foreground: _globalPrimary,
                          background: _globalPrimary.withValues(alpha: 0.10),
                        )
                      : _StatusBadge(
                          key: const ValueKey('normal'),
                          label: '${_accounts.length} 个账号',
                          icon: Icons.people_alt_outlined,
                          foreground: Theme.of(context).colorScheme.primary,
                          background: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.10),
                        ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isMultiSelectMode ? '勾选后可使用顶部删除按钮批量移除账号。' : '点按切换当前账号，长按进入多选模式。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (var index = 0; index < _accounts.length; index++) ...[
              _StaggeredListItem(
                index: index,
                child: Builder(
                  builder: (context) {
                    final user = _accounts[index];
                    final isSelected = _selectedAccounts.contains(user.uid);
                    final isCurrent =
                        user.uid == _currentAccountId &&
                        _isAccountLoggedIn(user);
                    return _buildListItemContent(
                      context,
                      user,
                      isSelected,
                      isCurrent,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAccountsState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 96),
      child: AppAnimations.fadeSlideIn(
        begin: const Offset(0, 0.08),
        child: DashboardEmptyState(
          title: '暂无账号',
          subtitle: '点击右下角添加账号，或切换平台查看其他账号。',
          icon: Icons.person_add_alt_1_outlined,
          color: _globalPrimary,
          action: FilledButton.tonalIcon(
            onPressed: () {
              if (_selectedPlatform == PlatformType.tronclass) {
                _navigateToPasswordLogin();
                return;
              }
              if (_selectedPlatform == PlatformType.weizhuojiao) {
                _showWeizhuojiaoComingSoonNotice();
                return;
              }
              _navigateToPasswordLogin();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加账号'),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAccountsState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: AppAnimations.fadeSlideIn(
        begin: const Offset(0, 0.06),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xlarge),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _globalPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '正在同步 ${_selectedPlatformLabel()} 的账号状态...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final currentUser = _currentAccountId != null
        ? _accounts.firstWhere(
            (u) => u.uid == _currentAccountId,
            orElse: () => _accounts.isNotEmpty
                ? _accounts.first
                : User(
                    uid: '',
                    name: '',
                    avatar: '',
                    phone: '',
                    school: '',
                    platform: '',
                  ),
          )
        : null;
    final loggedInCount = _accounts.where(_isAccountLoggedIn).length;

    if (_isPlatformSwitching) {
      return DashboardHeader(
        eyebrow: 'ACCOUNT CENTER',
        title: '账户管理',
        subtitle: '正在读取当前平台账号和登录状态。',
        icon: Icons.manage_accounts_outlined,
        primary: _globalPrimary,
        secondary: _globalSecondary,
        children: const [
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
              SizedBox(width: AppSpacing.sm),
              Text('加载中...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      );
    }

    return DashboardHeader(
      eyebrow: 'ACCOUNT CENTER',
      title: '账户管理',
      subtitle: currentUser != null && currentUser.uid.isNotEmpty
          ? '当前账户：${currentUser.name} (${currentUser.uid})'
          : '当前平台：${_selectedPlatformLabel()}',
      icon: Icons.manage_accounts_outlined,
      primary: _globalPrimary,
      secondary: _globalSecondary,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildOverviewMetric('当前平台', _selectedPlatformLabel()),
            _buildOverviewMetric('已绑定', '${_accounts.length} 个'),
            _buildOverviewMetric('已登录', '$loggedInCount 个'),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewMetric(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
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

  Widget _buildVersionHelpPanel() {
    final status = _updateStatus;
    if (status != null && status.hasUpdate) {
      return _buildUpdateAvailableCard(status);
    }
    return _buildHelpShortcutsCard(status);
  }

  Widget _buildUpdateAvailableCard(UpdateCheckStatus status) {
    final colors = Theme.of(context).colorScheme;
    final notes = status.releaseNotes.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: colors.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                child: Icon(
                  Icons.system_update_alt_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '版本可更新',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${status.currentVersion} -> ${status.latestVersion}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton.tonalIcon(
                onPressed: _openUpdateAnnouncements,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('查看更新公告'),
              ),
              OutlinedButton.icon(
                onPressed: status.downloadUrl.isEmpty
                    ? null
                    : () => launchUrl(
                        Uri.parse(status.downloadUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('前往下载'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpShortcutsCard(UpdateCheckStatus? status) {
    final subtitle = status == null
        ? '暂未获取到版本信息'
        : '当前已是最新版本 ${status.currentVersion}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildHelpShortcutTile(
                  icon: Icons.menu_book_outlined,
                  label: '使用手册',
                  onTap: () => _openUserManual(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildHelpShortcutTile(
                  icon: Icons.help_outline_rounded,
                  label: '常见问题',
                  onTap: () => _openUserManual(initialSectionId: 'faq'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildHelpShortcutTile(
                  icon: Icons.campaign_outlined,
                  label: '更新公告',
                  onTap: _openUpdateAnnouncements,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpShortcutTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      onTap: onTap,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _globalPrimary),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _openUserManual({String? initialSectionId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserManualPage(initialSectionId: initialSectionId),
      ),
    );
  }

  void _openUpdateAnnouncements() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UpdateAnnouncementsPage()));
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
                  SnackBar(
                    content: Text('已切换到 ${PlatformManager().serverName} 服务器'),
                  ),
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
                                  SnackBar(
                                    content: Text(
                                      '已切换到 ${PlatformManager().serverName} 服务器',
                                    ),
                                  ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: AppAnimations.fadeSlideIn(
                begin: const Offset(0, 0.06),
                child: _buildVersionHelpPanel(),
              ),
            ),
            _buildPlatformSwitcherPanel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: AppAnimations.fadeSlideIn(
                begin: const Offset(0, 0.08),
                child: _buildOverviewCard(),
              ),
            ),
            if (_isPlatformSwitching)
              _buildLoadingAccountsState()
            else if (_accounts.isEmpty)
              _buildEmptyAccountsState()
            else
              _buildAccountListSection(),
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

class _PlatformSwitcherChip extends StatelessWidget {
  const _PlatformSwitcherChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.secondary,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? Colors.white : scheme.onSurface;
    final muted = selected
        ? Colors.white.withValues(alpha: 0.82)
        : scheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: AppDuration.normal,
      curve: AppCurves.emphasized,
      constraints: const BoxConstraints(minWidth: 102),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [primary, secondary.withValues(alpha: 0.94)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selected ? null : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: selected ? primary : scheme.outlineVariant),
        boxShadow: selected ? AppShadows.low(primary) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppDuration.normal,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.16)
                  : primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.platformLabel,
    required this.platformStatus,
    required this.isLoggedIn,
    required this.canLogout,
    required this.isCurrentAccount,
    required this.isSelected,
    required this.isMultiSelectMode,
    required this.primary,
    required this.secondary,
    required this.avatar,
    required this.onTap,
    required this.onLongPress,
    required this.onLogout,
    required this.onSelectedChanged,
  });

  final User user;
  final String platformLabel;
  final String platformStatus;
  final bool isLoggedIn;
  final bool canLogout;
  final bool isCurrentAccount;
  final bool isSelected;
  final bool isMultiSelectMode;
  final Color primary;
  final Color secondary;
  final Widget avatar;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final VoidCallback onLogout;
  final ValueChanged<bool?> onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = isLoggedIn
        ? const Color(0xFF16A34A)
        : const Color(0xFFF97316);
    final surface = isCurrentAccount
        ? Color.alphaBlend(primary.withValues(alpha: 0.10), scheme.surface)
        : scheme.surface;

    return Semantics(
      button: true,
      selected: isCurrentAccount || isSelected,
      label: '${user.name}，$platformLabel，$platformStatus',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.xlarge),
          child: AnimatedContainer(
            duration: AppDuration.normal,
            curve: AppCurves.emphasized,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadius.xlarge),
              border: Border.all(
                color: isSelected
                    ? secondary
                    : isCurrentAccount
                    ? primary.withValues(alpha: 0.45)
                    : scheme.outlineVariant,
                width: isSelected || isCurrentAccount ? 1.5 : 1,
              ),
              boxShadow: isCurrentAccount
                  ? AppShadows.medium(primary)
                  : AppShadows.low(scheme.shadow),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'account-avatar-${user.platform}-${user.uid}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        child: avatar,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user.name.isEmpty ? '未命名账号' : user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isCurrentAccount)
                                _StatusBadge(
                                  label: '当前',
                                  icon: Icons.check_circle_rounded,
                                  foreground: primary,
                                  background: primary.withValues(alpha: 0.12),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              _StatusBadge(
                                label: platformLabel,
                                icon: Icons.layers_outlined,
                                foreground: secondary,
                                background: secondary.withValues(alpha: 0.12),
                              ),
                              _StatusBadge(
                                label: platformStatus,
                                icon: isLoggedIn
                                    ? Icons.verified_user_outlined
                                    : Icons.error_outline_rounded,
                                foreground: statusColor,
                                background: statusColor.withValues(alpha: 0.12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AnimatedSwitcher(
                      duration: AppDuration.fast,
                      child: isMultiSelectMode
                          ? Checkbox(
                              key: const ValueKey('checkbox'),
                              value: isSelected,
                              onChanged: onSelectedChanged,
                            )
                          : canLogout
                          ? IconButton(
                              key: const ValueKey('logout'),
                              tooltip: '退出登录',
                              icon: const Icon(Icons.logout_rounded),
                              onPressed: onLogout,
                            )
                          : Icon(
                              key: const ValueKey('chevron'),
                              Icons.chevron_right_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 440;
                    final uid = _AccountInfoPill(
                      icon: Icons.badge_outlined,
                      label: 'UID',
                      value: user.uid.isEmpty ? '-' : user.uid,
                    );
                    final phone = _AccountInfoPill(
                      icon: Icons.phone_iphone_outlined,
                      label: '手机号',
                      value: user.phone.isEmpty ? '未填写' : user.phone,
                    );
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(child: uid),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: phone),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        uid,
                        const SizedBox(height: AppSpacing.sm),
                        phone,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountInfoPill extends StatelessWidget {
  const _AccountInfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label：',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredListItem extends StatelessWidget {
  const _StaggeredListItem({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: (index.clamp(0, 6)) * 28);

    return FutureBuilder<void>(
      future: Future<void>.delayed(delay),
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        return AnimatedOpacity(
          duration: AppDuration.normal,
          curve: AppCurves.emphasized,
          opacity: ready ? 1 : 0,
          child: AnimatedSlide(
            duration: AppDuration.normal,
            curve: AppCurves.emphasized,
            offset: ready ? Offset.zero : const Offset(0, 0.06),
            child: child,
          ),
        );
      },
    );
  }
}
