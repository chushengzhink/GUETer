import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_all_windows/webview_all_windows.dart';

import '../api/login.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/cookie.dart' as app_cookie;
import '../session/tronclass_auth.dart';

class TronclassWebLoginPage extends StatefulWidget {
  final String accountName;
  final String? accountId;
  final Uri? initialUrl;
  final String? initialMessage;
  final bool autoCloseOnAuthSuccess;

  const TronclassWebLoginPage({
    super.key,
    required this.accountName,
    this.accountId,
    this.initialUrl,
    this.initialMessage,
    this.autoCloseOnAuthSuccess = true,
  });

  @override
  State<TronclassWebLoginPage> createState() => _TronclassWebLoginPageState();
}

class _TronclassWebLoginPageState extends State<TronclassWebLoginPage> {
  late final WebViewController _controller;
  late final WebViewCookieManager _cookieManager;
  bool _controllerReady = false;
  bool _isLoading = true;
  bool _isCompleting = false;
  bool _isMobileMode = true;
  double _progress = 0;
  String _currentUrl = '';
  String? _pageTitle;
  String? _statusMessage;
  bool _isClosing = false;
  String? _portalSessionId;
  bool _cookieSetSupported = true;
  bool _didAttemptMfaRecovery = false;
  bool _didAttemptPortalRecovery = false;
  bool _didAttemptMfaSendClick = false;
  bool _isPortalBootstrapping = false;
  bool _summaryExpanded = false;

  bool get _isWindowsWebView => defaultTargetPlatform == TargetPlatform.windows;

  String get _desktopUserAgent =>
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  String get _mobileUserAgent =>
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  bool get _isPortalMode => widget.initialUrl != null;

  bool _looksLikeMfaUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('reauthcheck') ||
        u.contains('reauthloginview') ||
        u.contains('ismultifactor=true') ||
        u.contains('multifactor');
  }

  bool _looksLikeMfaTitle(String? title) {
    if (title == null) return false;
    return title.contains('多因子') || title.toLowerCase().contains('multifactor');
  }

  bool _looksLikeLoginUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('/authserver/login') ||
        u.contains('/protocol/openid-connect/auth') ||
        u.contains('/broker/cas-client/login');
  }

  bool _looksLikeLoginTitle(String? title) {
    if (title == null) return false;
    final t = title.toLowerCase();
    return t.contains('sign in') ||
        t.contains('登录') ||
        t.contains('we are sorry');
  }

  bool _looksLikeSmsMfaPage(String? url, String? title) {
    final lowerUrl = (url ?? _currentUrl).toLowerCase();
    final lowerTitle = (title ?? _pageTitle ?? '').toLowerCase();
    return lowerUrl.contains('reauthcheck') ||
        lowerUrl.contains('reauthloginview') ||
        lowerUrl.contains('dynamiccode') ||
        lowerUrl.contains('multifactor') ||
        lowerTitle.contains('短信') ||
        lowerTitle.contains('验证码') ||
        lowerTitle.contains('动态码') ||
        lowerTitle.contains('多因子');
  }

  Future<void> _autoClickSmsSendButton() async {
    if (!_controllerReady || _didAttemptMfaSendClick) {
      return;
    }

    _didAttemptMfaSendClick = true;
    if (mounted) {
      setState(() {
        _statusMessage = '正在尝试触发畅课短信验证码发送...';
      });
    }

    const script = '''
(function() {
  const texts = ['发送验证码', '获取验证码', '发送短信验证码', '获取短信验证码', '发送动态码', '获取动态码'];
  const isVisible = (el) => {
    if (!el) return false;
    const style = window.getComputedStyle(el);
    const rect = el.getBoundingClientRect();
    return style && style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  const getText = (el) => ((el && (el.innerText || el.value || el.textContent)) || '').trim();
  const items = Array.from(document.querySelectorAll('button,input[type="button"],input[type="submit"],a,[role="button"]'));
  for (const el of items) {
    const text = getText(el);
    if (!isVisible(el)) continue;
    if (texts.some(t => text.includes(t))) {
      try {
        el.click();
        return 'clicked:' + text;
      } catch (e) {
        return 'click-failed:' + e;
      }
    }
  }
  return 'not-found';
})();
''';

    try {
      await _controller.runJavaScript(script);
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      await _controller.runJavaScript(script);
    } catch (_) {
      // ignore JS injection failures and let the user interact manually
    }
  }

  Uri _buildPortalBootstrapUri(String sessionId) {
    final base = Uri.parse(PlatformManager().tronclassBaseUrl);
    return base.replace(
      path: '/api/login',
      queryParameters: {
        'login': 'session_id',
        'session_id': sessionId,
        'org_id': '1',
      },
    );
  }

  Future<void> _tryRecoverFromMfa({String? url, String? title}) async {
    if (!_isPortalMode || _didAttemptMfaRecovery) {
      return;
    }

    final hitMfa =
        _looksLikeMfaUrl(url ?? _currentUrl) ||
        _looksLikeMfaTitle(title ?? _pageTitle);
    if (!hitMfa) {
      return;
    }

    final sid = _portalSessionId;
    if (sid == null || sid.isEmpty) {
      return;
    }

    _didAttemptMfaRecovery = true;
    if (mounted) {
      setState(() {
        _statusMessage = '检测到多因子认证页面，正在尝试恢复已登录会话...';
        _isLoading = true;
      });
    }

    final ok = await TCLoginApi.bootstrapPortalSession(sessionId: sid);
    if (!_controllerReady || !mounted) {
      return;
    }

    if (ok) {
      await _controller.loadRequest(
        Uri.parse(PlatformManager().tronclassBaseUrl),
      );
      if (mounted) {
        setState(() {
          _statusMessage = '已尝试恢复畅课会话';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _statusMessage = '当前账号被要求进行多因子认证，请完成一次验证后再使用门户';
        _isLoading = false;
      });
    }
  }

  Future<void> _tryRecoverPortalLogin({String? url, String? title}) async {
    if (!_isPortalMode || _didAttemptPortalRecovery || !_controllerReady) {
      return;
    }

    final hitLogin =
        _looksLikeLoginUrl(url ?? _currentUrl) ||
        _looksLikeLoginTitle(title ?? _pageTitle);
    if (!hitLogin) {
      return;
    }

    final sid = _portalSessionId;
    if (sid == null || sid.isEmpty) {
      return;
    }

    _didAttemptPortalRecovery = true;
    if (mounted) {
      setState(() {
        _statusMessage = '检测到门户需要登录，正在自动恢复会话...';
        _isLoading = true;
      });
    }

    final ok = await TCLoginApi.bootstrapPortalSession(sessionId: sid);
    if (!_controllerReady || !mounted) {
      return;
    }

    if (ok) {
      await _reloadPortalWithSessionHeader();
      if (mounted) {
        setState(() {
          _statusMessage = '会话已恢复，正在进入畅课门户...';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _statusMessage = '自动恢复会话失败，请点击右上角“重新登录”';
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      WebViewPlatform.instance = WindowsWebViewPlatform();
    }

    _cookieManager = WebViewCookieManager();
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(Colors.transparent);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (!mounted) return;
          if (!mounted) return;
          setState(() {
            _currentUrl = url;
            _isLoading = true;
            _statusMessage = null;
          });
        },
        onPageFinished: (url) async {
          if (!mounted) return;
          final title = await controller.getTitle();
          setState(() {
            _currentUrl = url;
            _pageTitle = title;
            _isLoading = false;
          });

          if (_isPortalBootstrapping) {
            _isPortalBootstrapping = false;
            await controller.loadRequest(
              widget.initialUrl ??
                  Uri.parse(PlatformManager().tronclassBaseUrl),
            );
            if (mounted) {
              setState(() {
                _statusMessage = '已恢复畅课会话，正在进入门户...';
                _isLoading = true;
              });
            }
            return;
          }

          await _tryRecoverFromMfa(url: url, title: title);
          await _tryRecoverPortalLogin(url: url, title: title);
          if (_looksLikeSmsMfaPage(url, title)) {
            await _autoClickSmsSendButton();
          }
          await _completeIfReady(url);
        },
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress / 100;
          });
        },
        onNavigationRequest: (request) {
          final code = _extractCode(request.url);
          if (code != null) {
            _completeWithCode(code);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (error) {
          if (!mounted) return;
          setState(() {
            _statusMessage = '网页加载失败：${error.description}';
          });
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url == null || !mounted) return;
          setState(() {
            _currentUrl = url;
          });
          _tryRecoverFromMfa(url: url);
          _tryRecoverPortalLogin(url: url);
          if (_looksLikeSmsMfaPage(url, _pageTitle)) {
            _autoClickSmsSendButton();
          }
          _completeIfReady(url);
        },
      ),
    );

    _isMobileMode = !_isPortalMode;
    await _applyUserAgent(controller);

    if (_isPortalMode) {
      await _bootstrapPortalSession();
    }
    await _syncCookiesToWebView();

    if (mounted) {
      setState(() {
        _controller = controller;
        _controllerReady = true;
        _statusMessage = widget.initialMessage;
      });
    }

    await _loadInitialRequest(controller);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _syncCookiesToWebView() async {
    // webview_all_windows does not support setting cookies through the plugin.
    if (_isWindowsWebView) {
      return;
    }

    if (!_cookieSetSupported) {
      return;
    }

    final authUri = TCLoginApi.buildAuthUri();
    final portalUri = Uri.parse(PlatformManager().tronclassBaseUrl);
    final syncTargets = <Uri>{
      authUri,
      portalUri,
      Uri.parse('https://cas.guet.edu.cn'),
      Uri.parse('https://identity.guet.edu.cn'),
    };

    final cookieJars = <CookieJar?>[
      app_cookie.CookieManager.getCurrentUserCookieJar(),
      app_cookie.CookieManager.getTempCookieJar(),
    ];

    for (final cookieJar in cookieJars) {
      if (cookieJar == null) {
        continue;
      }

      for (final target in syncTargets) {
        final cookies = await cookieJar.loadForRequest(target);
        for (final cookie in cookies) {
          final domain = cookie.domain?.isNotEmpty == true
              ? cookie.domain!
              : target.host;
          try {
            await _cookieManager.setCookie(
              WebViewCookie(
                name: cookie.name,
                value: cookie.value,
                domain: domain,
                path: cookie.path ?? '/',
              ),
            );
          } on UnsupportedError {
            _cookieSetSupported = false;
            return;
          } catch (_) {
            // ignore individual cookie sync failures
          }
        }
      }
    }
  }

  Future<void> _bootstrapPortalSession() async {
    final accountId = widget.accountId ?? AccountManager.currentSessionId;
    if (accountId == null || accountId.isEmpty) {
      return;
    }

    final sessionId = await TronclassAuthManager.getSessionIdForUser(accountId);
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }

    _portalSessionId = sessionId;
    await TCLoginApi.bootstrapPortalSession(sessionId: sessionId);
  }

  Future<void> _loadInitialRequest(WebViewController controller) async {
    final target = widget.initialUrl ?? TCLoginApi.buildAuthUri();

    if (_isPortalMode &&
        _portalSessionId != null &&
        _portalSessionId!.isNotEmpty) {
      final sid = _portalSessionId!;

      // Windows WebView often ignores custom headers on initial navigation.
      // Bootstrap via session_id endpoint first so server sets portal cookies.
      if (_isWindowsWebView) {
        _isPortalBootstrapping = true;
        if (mounted) {
          setState(() {
            _statusMessage = '正在恢复畅课会话...';
          });
        }

        await controller.loadRequest(_buildPortalBootstrapUri(sid));
        return;
      }

      try {
        await controller.loadRequest(target, headers: {'x-session-id': sid});
        return;
      } catch (_) {
        // fallback to session bootstrap URL below
      }

      _isPortalBootstrapping = true;
      if (mounted) {
        setState(() {
          _statusMessage = '正在恢复畅课会话...';
        });
      }

      await controller.loadRequest(_buildPortalBootstrapUri(sid));
      return;
    }

    await controller.loadRequest(target);
  }

  Future<void> _reloadPortalWithSessionHeader() async {
    final target =
        widget.initialUrl ?? Uri.parse(PlatformManager().tronclassBaseUrl);
    final sid = _portalSessionId;

    if (sid != null && sid.isNotEmpty) {
      if (_isWindowsWebView) {
        await _controller.loadRequest(_buildPortalBootstrapUri(sid));
        return;
      }

      try {
        await _controller.loadRequest(target, headers: {'x-session-id': sid});
        return;
      } catch (_) {
        // fallback to plain GET below
      }
    }

    await _controller.loadRequest(target);
  }

  Future<void> _applyUserAgent(WebViewController controller) async {
    await controller.setUserAgent(
      _isMobileMode ? _mobileUserAgent : _desktopUserAgent,
    );
  }

  Future<void> _toggleUserAgent() async {
    if (!_controllerReady) {
      return;
    }
    setState(() {
      _isMobileMode = !_isMobileMode;
      _isLoading = true;
      _statusMessage = '正在切换网页模式...';
    });
    await _applyUserAgent(_controller);
    await _controller.reload();
  }

  Future<void> _goBackInWebView() async {
    if (!_controllerReady) {
      return;
    }
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  Future<void> _goForwardInWebView() async {
    if (!_controllerReady) {
      return;
    }
    if (await _controller.canGoForward()) {
      await _controller.goForward();
    }
  }

  Future<void> _copyCurrentUrl() async {
    if (_currentUrl.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _currentUrl));
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = '已复制当前链接';
    });
  }

  Future<void> _clearWebViewCache() async {
    if (!_controllerReady) {
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = '正在清理网页缓存...';
    });
    await _controller.clearCache();
    await _controller.clearLocalStorage();
    await _cookieManager.clearCookies();
    await _syncCookiesToWebView();
    await _controller.reload();
  }

  Future<void> _reloginCurrentAccount() async {
    if (!_controllerReady) {
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = '正在重新登录并刷新会话...';
    });
    await _controller.loadRequest(TCLoginApi.buildAuthUri());
  }

  String? _extractCode(String url) {
    try {
      final uri = Uri.parse(url);
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        return code;
      }
    } catch (_) {
      // ignore parse error
    }
    return null;
  }

  Future<void> _completeIfReady(String url) async {
    final code = _extractCode(url);
    if (code != null) {
      await _completeWithCode(code);
    }
  }

  Future<void> _completeWithCode(String code) async {
    if (_isCompleting) {
      return;
    }
    _isCompleting = true;
    setState(() {
      _statusMessage = '正在完成登录...';
    });

    final result = await TCLoginApi.completeWithAuthCode(code);
    if (!mounted) {
      return;
    }

    if (result['ok'] == true) {
      final sessionId = (result['sessionId'] ?? '').toString();
      final accountId = widget.accountId;
      if (accountId != null && accountId.isNotEmpty && sessionId.isNotEmpty) {
        await TronclassAuthManager.setSessionIdForUser(accountId, sessionId);
        await AccountManager.setCurrentSession(accountId);
        if (!mounted) {
          return;
        }
      }

      if (widget.autoCloseOnAuthSuccess) {
        Navigator.of(context).pop(result);
        return;
      }

      setState(() {
        _statusMessage = '登录状态已刷新，当前账号可继续使用';
        _isCompleting = false;
      });
      _portalSessionId = sessionId.isNotEmpty ? sessionId : _portalSessionId;
      await _reloadPortalWithSessionHeader();
      return;
    }

    setState(() {
      _statusMessage = (result['message'] ?? '畅课登录失败').toString();
      _isCompleting = false;
    });
  }

  bool _forcePopNavigator() {
    try {
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop();
        return true;
      }
    } catch (_) {
      // ignore and fallback
    }

    try {
      final root = Navigator.of(context, rootNavigator: true);
      if (root.canPop()) {
        root.pop();
        return true;
      }
    } catch (_) {
      // ignore
    }

    return false;
  }

  void _closePage() {
    if (!mounted || _isClosing) {
      return;
    }

    _isClosing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final didPop = _forcePopNavigator();
      if (mounted && !didPop) {
        _isClosing = false;
      }
    });
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildPortalSummary(
    BuildContext context,
    bool keyboardVisible,
    bool compactLayout,
  ) {
    if (keyboardVisible) {
      return const SizedBox.shrink();
    }

    final modeText = _isPortalMode ? '门户预览' : '登录认证';
    final uaText = _isMobileMode ? '移动端 UA' : '桌面端 UA';
    final currentPage = _pageTitle?.trim().isNotEmpty == true
        ? _pageTitle!.trim()
        : (_currentUrl.isNotEmpty ? _currentUrl : '等待网页加载');
    final expanded = !compactLayout || _summaryExpanded;

    return Container(
      margin: EdgeInsets.fromLTRB(12, compactLayout ? 8 : 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1DB6C2), Color(0xFF0EA9C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x221DB6C2),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage ??
                          (_isPortalMode
                              ? '可直接浏览畅课门户，必要时可刷新会话。'
                              : '请在网页中完成畅课登录，完成后会自动返回。'),
                      maxLines: keyboardVisible ? 1 : 2,
                      overflow: keyboardVisible
                          ? TextOverflow.ellipsis
                          : TextOverflow.fade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.language_outlined, color: Colors.white),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: expanded ? '收起面板' : '展开面板',
                onPressed: compactLayout
                    ? () {
                        setState(() {
                          _summaryExpanded = !_summaryExpanded;
                        });
                      }
                    : null,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(label: '模式', value: modeText, color: Colors.white),
                _buildInfoChip(label: 'UA', value: uaText, color: Colors.white),
                _buildInfoChip(
                  label: '当前页',
                  value: currentPage,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionButton(
                  label: '返回应用',
                  icon: Icons.arrow_back_ios_new,
                  onPressed: _isClosing ? null : _closePage,
                  filled: true,
                ),
                _buildQuickActionButton(
                  label: '刷新',
                  icon: Icons.refresh,
                  onPressed: _isLoading || !_controllerReady
                      ? null
                      : () => _controller.reload(),
                ),
                _buildQuickActionButton(
                  label: '复制链接',
                  icon: Icons.copy,
                  onPressed: _controllerReady ? _copyCurrentUrl : null,
                ),
                _buildQuickActionButton(
                  label: _isMobileMode ? '切桌面 UA' : '切移动 UA',
                  icon: Icons.web,
                  onPressed: _controllerReady ? _toggleUserAgent : null,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              '已折叠工具面板，点击右侧箭头可展开。',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;
    final size = MediaQuery.of(context).size;
    final compactLayout = size.height < 780 || size.width < 420;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_isClosing) {
          _closePage();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回应用',
            onPressed: _isClosing ? null : _closePage,
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          title: Text(_pageTitle ?? '畅课网页登录'),
          actions: [
            IconButton(
              tooltip: '后退',
              onPressed: _controllerReady ? _goBackInWebView : null,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              tooltip: '前进',
              onPressed: _controllerReady ? _goForwardInWebView : null,
              icon: const Icon(Icons.arrow_forward),
            ),
            IconButton(
              tooltip: '复制链接',
              onPressed: _controllerReady ? _copyCurrentUrl : null,
              icon: const Icon(Icons.link),
            ),
            TextButton(
              onPressed: _controllerReady ? _toggleUserAgent : null,
              child: Text(_isMobileMode ? '移动端' : '桌面端'),
            ),
            IconButton(
              tooltip: '清理缓存',
              onPressed: _controllerReady ? _clearWebViewCache : null,
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: _isLoading || !_controllerReady
                  ? null
                  : () => _controller.reload(),
              icon: const Icon(Icons.refresh),
            ),
            if (_isPortalMode)
              IconButton(
                tooltip: '重新登录',
                onPressed: _controllerReady ? _reloginCurrentAccount : null,
                icon: const Icon(Icons.login),
              ),
            IconButton(
              tooltip: '关闭',
              onPressed: _isClosing ? null : _closePage,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: Column(
            children: [
              if (_progress < 1) LinearProgressIndicator(value: _progress),
              _buildPortalSummary(context, keyboardVisible, compactLayout),
              Expanded(
                child: _isLoading && !_isCompleting
                    ? const Center(child: CircularProgressIndicator())
                    : WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
