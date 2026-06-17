import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_all_windows/webview_all_windows.dart';

import '../api/api_service.dart';
import '../api/login.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/cookie.dart' as app_cookie;
import '../session/tronclass_auth.dart';
import '../services/tronclass_qq_auth_callback_bridge.dart';

bool isTronclassCasQqLoginUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  if (host == 'cas.guet.edu.cn' &&
      path.endsWith('/authserver/combinedlogin.do') &&
      uri.queryParameters['type']?.toLowerCase() == 'qq') {
    return true;
  }
  if ((host == 'graph.qq.com' && path == '/oauth2.0/authorize') ||
      host.endsWith('ptlogin2.qq.com')) {
    return true;
  }
  if (host == 'cas.guet.edu.cn' && path.endsWith('/authserver/callback')) {
    return true;
  }
  return false;
}

List<Uri> buildTronclassQqExternalBootstrapUris({String? redirectUriOverride}) {
  return <Uri>[
    TCLoginApi.buildAuthUri(redirectUriOverride: redirectUriOverride),
  ];
}

bool isQqQrAuthorizePage(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  return uri.host.toLowerCase() == 'graph.qq.com' &&
      uri.path.toLowerCase() == '/oauth2.0/show';
}

bool isQqJumpUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  return uri.host.toLowerCase() == 'ssl.ptlogin2.qq.com' &&
      uri.path.toLowerCase() == '/jump';
}

Uri? buildQqClientXloginUrl(String authorizeOrShowUrl) {
  final uri = Uri.tryParse(authorizeOrShowUrl);
  if (uri == null || uri.host.toLowerCase() != 'graph.qq.com') {
    return null;
  }
  final path = uri.path.toLowerCase();
  if (path != '/oauth2.0/authorize' && path != '/oauth2.0/show') {
    return null;
  }

  final query = uri.queryParameters;
  final clientId = query['client_id'];
  final redirectUri = query['redirect_uri'];
  final responseType = query['response_type'] ?? 'code';
  final state = query['state'];
  if (clientId == null ||
      clientId.isEmpty ||
      redirectUri == null ||
      redirectUri.isEmpty ||
      state == null ||
      state.isEmpty) {
    return null;
  }

  return Uri.https('xui.ptlogin2.qq.com', '/cgi-bin/xlogin', {
    'appid': '716027609',
    'pt_3rd_aid': clientId,
    'daid': '383',
    'pt_skey_valid': '0',
    'style': '35',
    's_url': 'https://connect.qq.com',
    'refer_cgi': 'authorize',
    'which': '',
    'sdkp': 'pcweb',
    'sdkv': 'v1.0',
    'time': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
    'loginty': '3',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': responseType,
    'state': state,
    if (query['scope']?.isNotEmpty == true) 'scope': query['scope']!,
    if (query['h5sig']?.isNotEmpty == true) 'h5sig': query['h5sig']!,
    if (query['pt_flex']?.isNotEmpty == true) 'pt_flex': query['pt_flex']!,
    if (query['loginfrom']?.isNotEmpty == true)
      'loginfrom': query['loginfrom']!,
  });
}

bool isTronclassExternalQqScheme(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  return scheme == 'mqqapi' ||
      scheme == 'mqq' ||
      scheme == 'tencent' ||
      scheme == 'wtloginmqq';
}

bool isTronclassPortalCallbackWithoutAuthCode(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  return host == 'portal.guet.edu.cn' &&
      path == '/ywtbcallback' &&
      uri.queryParameters['code']?.isNotEmpty == true;
}

String? extractTronclassExactAuthCodeFromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isTronclassCallback =
        host == 'mobile.guet.edu.cn' && path == '/cas-callback';
    final isIdentityCallback =
        host == 'identity.guet.edu.cn' &&
        path.contains('/broker/cas-client/endpoint');
    if (!isTronclassCallback && !isIdentityCallback) {
      return null;
    }
    final code = uri.queryParameters['code'];
    return code == null || code.isEmpty ? null : code;
  } catch (_) {
    return null;
  }
}

String? extractCasQqCode(String url) {
  try {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host != 'cas.guet.edu.cn' || !path.endsWith('/authserver/callback')) {
      return null;
    }
    final code = uri.queryParameters['code'];
    return code == null || code.isEmpty ? null : code;
  } catch (_) {
    return null;
  }
}

class QqExternalLaunchState {
  String? lastAuthorizeUrl;
  String? lastShowUrl;
  String? lastXloginUrl;
  String? lastSchemeUrl;
  DateTime? launchedAt;
  int recoveryAttempts = 0;

  bool get hasLaunch => launchedAt != null;

  bool rememberAuthorizationUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (host == 'graph.qq.com' && path == '/oauth2.0/authorize') {
      lastAuthorizeUrl = url;
      return true;
    }
    if (host == 'graph.qq.com' && path == '/oauth2.0/show') {
      lastShowUrl = url;
      return true;
    }
    if (host == 'xui.ptlogin2.qq.com' && path == '/cgi-bin/xlogin') {
      lastXloginUrl = url;
      return true;
    }
    return false;
  }

  bool shouldLaunchScheme(String url) {
    if (lastSchemeUrl == url) {
      return false;
    }
    return true;
  }

  void markLaunched(String url) {
    lastSchemeUrl = url;
    launchedAt = DateTime.now();
    recoveryAttempts = 0;
  }

  String? nextReplayUrl() {
    if (!hasLaunch || recoveryAttempts >= 2) {
      return null;
    }
    recoveryAttempts += 1;
    return lastXloginUrl ?? lastAuthorizeUrl ?? lastShowUrl;
  }

  void clearLaunch() {
    launchedAt = null;
    recoveryAttempts = 0;
  }
}

class TronclassWebLoginPage extends StatefulWidget {
  final String accountName;
  final String? accountId;
  final Uri? initialUrl;
  final String? initialMessage;
  final bool autoCloseOnAuthSuccess;
  final bool qqLoginMode;
  final bool qqExternalRecoveryOnly;
  final QqOAuthBrowserChoice? qqOAuthBrowser;

  const TronclassWebLoginPage({
    super.key,
    required this.accountName,
    this.accountId,
    this.initialUrl,
    this.initialMessage,
    this.autoCloseOnAuthSuccess = true,
    this.qqLoginMode = false,
    this.qqExternalRecoveryOnly = false,
    this.qqOAuthBrowser,
  });

  @override
  State<TronclassWebLoginPage> createState() => _TronclassWebLoginPageState();
}

class _TronclassWebLoginPageState extends State<TronclassWebLoginPage>
    with WidgetsBindingObserver {
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
  bool _didShowPortalOnlyCallbackTip = false;
  String? _lastExternalQqLaunchUrl;
  QqLoginStrategy _qqLoginStrategy = QqLoginStrategy.browserReturnRequired;
  bool _qqLoginStrategyResolved = false;
  QqOAuthBrowserChoice _qqOAuthBrowser = QqOAuthBrowserChoice.systemDefault;
  bool _qqOAuthBrowserResolved = false;
  final QqExternalLaunchState _qqExternalLaunchState = QqExternalLaunchState();
  StreamSubscription<String>? _qqCallbackSubscription;
  final Set<String> _handledQqClientUrls = <String>{};
  final Set<String> _handledQqXloginUrls = <String>{};
  final Set<String> _handledReturnedBrowserUrls = <String>{};

  bool get _isWindowsWebView => defaultTargetPlatform == TargetPlatform.windows;

  String get _desktopUserAgent =>
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  String get _mobileUserAgent =>
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  String get _qqBrowserUserAgent =>
      'Mozilla/5.0 (Linux; U; Android 15; zh-cn; PJD110 Build/AP3A.240617.008) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/121.0.6167.71 MQQBrowser/15.9 Mobile Safari/537.36 COVC/048801';

  bool get _isPortalMode => widget.initialUrl != null && !widget.qqLoginMode;

  bool get _isQqExternalRecoveryOnly =>
      widget.qqLoginMode && widget.qqExternalRecoveryOnly;

  Uri get _casQqLoginUri =>
      Uri.parse('https://cas.guet.edu.cn/authserver/combinedLogin.do?type=qq');

  bool get _shouldShowQqAction => widget.qqLoginMode;

  String get _qqStrategyName => _qqLoginStrategy.name;

  String get _qqOAuthBrowserName => _qqOAuthBrowser.displayName;

  Future<QqOAuthBrowserChoice> _resolveQqOAuthBrowser() async {
    if (_qqOAuthBrowserResolved) {
      return _qqOAuthBrowser;
    }
    final provided = widget.qqOAuthBrowser;
    if (provided != null && provided.isInstalled) {
      _qqOAuthBrowser = provided;
      _qqOAuthBrowserResolved = true;
      return _qqOAuthBrowser;
    }
    final installed =
        await TronclassQqAuthCallbackBridge.getInstalledQqOAuthBrowsers();
    _qqOAuthBrowser = resolvePreferredQqOAuthBrowser(installed);
    _qqOAuthBrowserResolved = true;
    return _qqOAuthBrowser;
  }

  String get _qqDefaultStatusMessage {
    if (!widget.qqLoginMode) {
      return _isPortalMode ? '可直接浏览畅课门户，必要时可刷新会话。' : '请在网页中完成畅课登录，完成后会自动返回。';
    }
    if (_isQqExternalRecoveryOnly) {
      return '已在系统浏览器先打开畅课 OAuth，再进入 QQ 授权。请在同一浏览器完成授权；最终出现 mobile.guet.edu.cn/cas-callback 或 identity 回调后，分享给 GUETer 或复制后粘贴。';
    }
    return switch (_qqLoginStrategy) {
      QqLoginStrategy.nativeRedirectSupported ||
      QqLoginStrategy.verifiedHttpsSupported =>
        'QQ 登录使用学校统一身份认证，授权完成后会尝试回到 GUETer。',
      QqLoginStrategy.browserReturnRequired =>
        '请在系统浏览器中完成 QQ 授权；最终出现 mobile.guet.edu.cn/cas-callback 或 identity 回调后，分享给 GUETer 或复制后粘贴。',
    };
  }

  Future<void> _resolveQqLoginStrategy() async {
    if (!widget.qqLoginMode) {
      return;
    }
    await _resolveQqOAuthBrowser();
    final verified =
        await TronclassQqAuthCallbackBridge.isHttpsCallbackAppLinkVerified();
    final strategy = resolveQqLoginStrategy(appLinkVerified: verified);
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] strategy=${strategy.name} appLinkVerified=$verified customRedirect=false',
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _qqLoginStrategy = strategy;
      _qqLoginStrategyResolved = true;
      _statusMessage = _qqRecoveryInstructionMessage();
    });
  }

  String _qqRecoveryInstructionMessage() {
    if (_qqOAuthBrowser.isSystemDefault) {
      return '已使用系统默认浏览器处理 QQ 授权。授权完成后如果停在浏览器，请点浏览器分享给 GUETer，或复制地址后点“我已复制浏览器地址，完成登录”。';
    }
    return '本次使用：$_qqOAuthBrowserName。授权完成后如果停在 $_qqOAuthBrowserName，请点浏览器分享给 GUETer，或复制地址后点“我已复制浏览器地址，完成登录”。';
  }

  Future<void> _startQqAuthorization() async {
    if (!_controllerReady) {
      return;
    }
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] start strategy=$_qqStrategyName externalBrowserOnly=true',
    );
    if (mounted) {
      setState(() {
        _statusMessage = _qqDefaultStatusMessage;
        _isLoading = true;
      });
    }
    await _startQqAuthorizationInSystemBrowser();
  }

  Future<void> _startQqAuthorizationInWebView() async {
    if (!_controllerReady) {
      return;
    }
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] webviewFallback strategy=$_qqStrategyName',
    );
    if (mounted) {
      setState(() {
        _statusMessage = '正在用内置网页进入 QQ 联合登录；此模式可能导致 CAS 回调会话不一致，仅作为诊断兜底。';
        _isLoading = true;
      });
    }
    await _controller.loadRequest(_casQqLoginUri);
  }

  Future<void> _startQqAuthorizationInSystemBrowser() async {
    final browser = await _resolveQqOAuthBrowser();
    final capability = await _probeQqRedirectCapability();
    final redirectOverride =
        capability == QqRedirectCapability.customRedirectAccepted
        ? tronclassQqCustomRedirectUri
        : null;
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] reopenExternalFromRecovery=true qqExternalBootstrap=true openIdentityAuthFirst=true',
    );
    if (mounted) {
      setState(() {
        _statusMessage = '正在先打开畅课 OAuth，再进入 QQ 授权...';
        _isLoading = true;
      });
    }
    final bootstrapUris = buildTronclassQqExternalBootstrapUris(
      redirectUriOverride: redirectOverride,
    );
    TronclassQqAuthCallbackBridge.beginQqLoginAttempt(
      browserPackage: browser.packageName,
      launchSource: 'recoveryPage',
    );
    final identityOpened = await _openExternalAuthTarget(
      bootstrapUris.first,
      browser: browser,
    );
    if (!identityOpened) {
      TronclassQqAuthCallbackBridge.cancelQqLoginAttempt();
    }
    if (redirectOverride != null) {
      ApiService.appendExternalConsoleLog(
        '畅课',
        '[qqLogin] customRedirectAuthOpened=$identityOpened redirectCapability=${capability.name}',
      );
      if (mounted) {
        setState(() {
          _statusMessage = identityOpened
              ? '已使用自有回调打开 QQ 授权。授权完成后如果浏览器未自动回到 GUETer，再使用分享/复制最终回调兜底。'
              : '无法打开 QQ 授权，请检查浏览器/QQ 安装状态，或改用 Web 认证。';
          _isLoading = false;
        });
      }
      return;
    }
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] openCasQqAfterBootstrap=false reason=preserveTronclassOAuthService',
    );
    if (mounted) {
      setState(() {
        _statusMessage = identityOpened
            ? '已在系统浏览器继续。请留在同一浏览器完成跳转，最终复制或分享 mobile.guet.edu.cn/cas-callback 或 identity 回调。'
            : '无法打开系统浏览器或 QQ，请检查默认浏览器/QQ 安装状态，或改用内置网页兜底。';
        _isLoading = false;
      });
    }
    if (mounted && identityOpened) {
      setState(() {
        _statusMessage = _qqRecoveryInstructionMessage();
      });
    }
  }

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
      await Future<void>.delayed(const Duration(milliseconds: 3600));
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
    WidgetsBinding.instance.addObserver(this);
    if (widget.qqLoginMode) {
      _qqCallbackSubscription = TronclassQqAuthCallbackBridge.onCallbackStream
          .listen((url) => _handleReturnedBrowserUrl(url, source: 'native'));
      unawaited(_checkPendingQqAuthCallback());
      unawaited(_resolveQqLoginStrategy());
    }
    _initWebView();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _qqCallbackSubscription?.cancel();
    if (widget.qqLoginMode && !_isCompleting) {
      TronclassQqAuthCallbackBridge.cancelQqLoginAttempt();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.qqLoginMode) {
      unawaited(_recoverQqReturnedBrowserState());
    }
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
          _recordQqNavigation(url);
          unawaited(_applyQqStageUserAgentIfNeeded(url));
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
          if (await _tryRedirectQqQrPage(url)) {
            return;
          }
          await _scanQqAuthorizationTargets();
          _handlePortalOnlyCallback(url);
          await _completeIfReady(url);
        },
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress / 100;
          });
        },
        onNavigationRequest: (request) {
          _recordQqNavigation(request.url);
          if (isQqQrAuthorizePage(request.url)) {
            unawaited(_tryRedirectQqQrPage(request.url));
            return NavigationDecision.prevent;
          }
          if (isQqJumpUrl(request.url)) {
            _recordQqStage(request.url, stage: 'jumpSeen');
            unawaited(_applyQqStageUserAgentIfNeeded(request.url));
            return NavigationDecision.navigate;
          }
          final casQqCode = extractCasQqCode(request.url);
          if (casQqCode != null) {
            _recordQqStage(
              request.url,
              stage: 'casCodeSeen',
              extra: 'hasCode=true',
            );
            return NavigationDecision.navigate;
          }
          if (isTronclassExternalQqScheme(request.url)) {
            unawaited(_launchExternalQqAuthorization(request.url));
            return NavigationDecision.prevent;
          }
          final code = _extractCode(request.url);
          if (code != null) {
            _completeWithCode(code);
            return NavigationDecision.prevent;
          }
          _handlePortalOnlyCallback(request.url);
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
          _recordQqNavigation(url);
          if (isQqQrAuthorizePage(url)) {
            unawaited(_tryRedirectQqQrPage(url));
            return;
          }
          if (isQqJumpUrl(url)) {
            _recordQqStage(url, stage: 'jumpSeen');
            unawaited(_applyQqStageUserAgentIfNeeded(url));
          }
          final casQqCode = extractCasQqCode(url);
          if (casQqCode != null) {
            _recordQqStage(url, stage: 'casCodeSeen', extra: 'hasCode=true');
          }
          if (isTronclassExternalQqScheme(url)) {
            unawaited(_launchExternalQqAuthorization(url));
            return;
          }
          _handlePortalOnlyCallback(url);
          _completeIfReady(url);
        },
      ),
    );

    _isMobileMode = widget.qqLoginMode ? false : !_isPortalMode;
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
    if (_isQqExternalRecoveryOnly) {
      if (mounted) {
        setState(() {
          _currentUrl = '';
          _pageTitle = '等待 QQ 授权回调';
          _statusMessage =
              widget.initialMessage ?? _qqRecoveryInstructionMessage();
        });
      }
      return;
    }

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

  void _recordQqNavigation(String url) {
    if (!widget.qqLoginMode && !isTronclassCasQqLoginUrl(url)) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    _qqExternalLaunchState.rememberAuthorizationUrl(url);
    final marker = isTronclassCasQqLoginUrl(url) ? 'qqRelated=true' : '';
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] nav host=${uri.host} path=${uri.path} $marker',
    );
  }

  void _recordQqStage(String url, {required String stage, String extra = ''}) {
    if (!widget.qqLoginMode) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    final uaMode = _qqPreferredMobileStage(url)
        ? 'qqBrowser'
        : (_isMobileMode ? 'mobile' : 'desktop');
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] stage=$stage host=${uri.host} path=${uri.path} uaMode=$uaMode $extra',
    );
  }

  bool _qqPreferredMobileStage(String url) {
    if (!widget.qqLoginMode) {
      return false;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == 'graph.qq.com' || host.endsWith('ptlogin2.qq.com');
  }

  Future<void> _applyQqStageUserAgentIfNeeded(String url) async {
    if (!widget.qqLoginMode || !_controllerReady) {
      return;
    }
    final targetUa = _qqPreferredMobileStage(url)
        ? _qqBrowserUserAgent
        : _desktopUserAgent;
    try {
      await _controller.setUserAgent(targetUa);
    } catch (_) {
      // UA switching is best effort; navigation should continue.
    }
  }

  Future<void> _launchExternalQqAuthorization(String url) async {
    if (!widget.qqLoginMode) {
      return;
    }
    if (_lastExternalQqLaunchUrl == url ||
        !_qqExternalLaunchState.shouldLaunchScheme(url)) {
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !isTronclassExternalQqScheme(url)) {
      return;
    }
    _lastExternalQqLaunchUrl = url;
    _qqExternalLaunchState.markLaunched(url);
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] external scheme=${uri.scheme} host=${uri.host} path=${uri.path}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _qqExternalLaunchState.clearLaunch();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = opened
          ? '已尝试拉起手机 QQ，请完成授权后返回本页。'
          : '无法拉起手机 QQ，可使用系统浏览器/QQ 继续。';
    });
  }

  Future<void> _recoverQqAfterExternalAuthorization() async {
    if (!widget.qqLoginMode ||
        !_controllerReady ||
        _isCompleting ||
        !mounted ||
        !_qqExternalLaunchState.hasLaunch) {
      return;
    }
    final replayUrl = _qqExternalLaunchState.nextReplayUrl();
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] appResumed replay=${replayUrl != null} attempts=${_qqExternalLaunchState.recoveryAttempts}',
    );
    if (replayUrl == null) {
      setState(() {
        _statusMessage = 'QQ 已授权，但学校回调未回到畅课会话。请重新发起 QQ 登录或改用 Web 认证。';
      });
      return;
    }
    setState(() {
      _statusMessage = '已从 QQ 返回，正在回收授权结果...';
      _isLoading = true;
    });
    final stage = replayUrl == _qqExternalLaunchState.lastXloginUrl
        ? 'replayXlogin'
        : 'replayAuthorize';
    _recordQqStage(replayUrl, stage: stage);
    await _applyQqStageUserAgentIfNeeded(replayUrl);
    await _controller.loadRequest(Uri.parse(replayUrl));
  }

  Future<bool> _recoverQqReturnedBrowserState() async {
    if (!widget.qqLoginMode || _isCompleting || !mounted) {
      return false;
    }
    if (await _checkPendingQqAuthCallback()) {
      return true;
    }
    if (await _checkClipboardQqReturnedUrl(silent: true)) {
      return true;
    }
    await _recoverQqAfterExternalAuthorization();
    return false;
  }

  Future<bool> _checkPendingQqAuthCallback() async {
    final url = await TronclassQqAuthCallbackBridge.getPendingReturnedUrl();
    if (url != null) {
      await _handleReturnedBrowserUrl(url, source: 'native');
      return true;
    }
    return false;
  }

  Future<void> _handleReturnedBrowserUrl(
    String url, {
    required String source,
  }) async {
    if (!widget.qqLoginMode || _isCompleting || !mounted) {
      return;
    }
    final returned = parseQqReturnedBrowserUrl(url);
    if (returned.type == QqReturnedBrowserUrlType.invalid) {
      if (source == 'manual') {
        setState(() {
          _statusMessage = '剪贴板里没有可用的畅课 QQ 授权回调链接。请复制浏览器地址栏中的回调链接后重试。';
        });
      }
      return;
    }
    if (!_handledReturnedBrowserUrls.add(returned.url)) {
      return;
    }
    final uri = Uri.tryParse(returned.url);
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] returned source=$source type=${returned.type.name} host=${uri?.host ?? ''} path=${uri?.path ?? ''} hasCode=${returned.hasCode} finalCallbackAccepted=${returned.isFinalTronclassCallback}',
    );
    if (returned.type == QqReturnedBrowserUrlType.casQqCallback) {
      _recordQqStage(
        returned.url,
        stage: 'casCodeReturned',
        extra: 'hasCode=true casCallbackRejected=true',
      );
      if (mounted) {
        setState(() {
          _statusMessage =
              '这是 QQ 回 CAS 的中间回调，不是畅课最终回调。请先等浏览器继续跳到 mobile.guet.edu.cn/cas-callback 或 identity 回调；如果浏览器不再跳转，请用同一浏览器重新发起 QQ 登录。';
          _isLoading = false;
        });
      }
      return;
    }
    if (returned.type == QqReturnedBrowserUrlType.portalOnly) {
      setState(() {
        _statusMessage =
            '这是智慧校园回调，不是畅课授权回调。请复制或分享 mobile.guet.edu.cn/cas-callback 或 identity 回调链接，或改用 Web 认证。';
      });
      return;
    }
    if (returned.type == QqReturnedBrowserUrlType.portalMobileHome) {
      setState(() {
        _statusMessage =
            '这是智慧校园门户首页，不是畅课授权回调。请重新点击 QQ 快捷登录，先进入畅课 OAuth/CAS 页面，再在该页面点击 QQ 登录。';
        _isLoading = false;
      });
      return;
    }
    if (returned.isFinalTronclassCallback &&
        !TronclassQqAuthCallbackBridge.hasActiveAttempt) {
      setState(() {
        _statusMessage =
            '这是过期或外部复制的畅课回调，不能用于当前 QQ 登录会话。请重新点击 QQ 快捷登录后再复制/分享最新回调。';
        _isLoading = false;
      });
      return;
    }
    final code = returned.isFinalTronclassCallback
        ? returned.code
        : extractTronclassExactAuthCodeFromUrl(returned.url);
    if (code == null || code.isEmpty) {
      setState(() {
        _statusMessage = 'QQ 授权已完成，但还没有拿到畅课授权回调。请复制浏览器地址或分享给 GUETer 后重试。';
      });
      return;
    }
    _qqExternalLaunchState.clearLaunch();
    await _completeWithCode(code);
  }

  Future<bool> _checkClipboardQqReturnedUrl({bool silent = false}) async {
    if (!widget.qqLoginMode || _isCompleting || !mounted) {
      return false;
    }
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {
      data = null;
    }
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!silent) {
        setState(() {
          _statusMessage = '剪贴板为空。请先复制浏览器地址栏中的畅课回调链接。';
        });
      }
      return false;
    }
    final url = extractFirstSupportedQqReturnedUrl(text);
    if (url == null) {
      if (!silent) {
        setState(() {
          _statusMessage = '剪贴板里没有识别到畅课 QQ 授权回调链接。';
        });
      }
      return false;
    }
    if (!TronclassQqAuthCallbackBridge.consumeReturnedUrl(url)) {
      final returned = parseQqReturnedBrowserUrl(url);
      if (!silent) {
        setState(() {
          _statusMessage = returned.isFinalTronclassCallback
              ? '这是过期或已消费的畅课回调，不能用于当前 QQ 登录会话。请重新点击 QQ 快捷登录后复制/分享最新回调。'
              : '该 QQ 回调已经处理过，不能重复使用。';
        });
      }
      return false;
    }
    await _handleReturnedBrowserUrl(url, source: 'clipboard');
    return true;
  }

  Future<void> _pasteQqReturnedBrowserUrl() async {
    await _checkClipboardQqReturnedUrl(silent: false);
  }

  Future<bool> _tryRedirectQqQrPage(String url) async {
    if (!widget.qqLoginMode || !isQqQrAuthorizePage(url)) {
      return false;
    }
    final xloginUrl = buildQqClientXloginUrl(url);
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] qrPage=true xloginBuilt=${xloginUrl != null}',
    );
    if (xloginUrl == null) {
      if (mounted) {
        setState(() {
          _statusMessage = '无法自动进入 QQ 授权页，可使用系统浏览器/QQ 继续。';
        });
      }
      return false;
    }
    final target = xloginUrl.toString();
    _qqExternalLaunchState.rememberAuthorizationUrl(target);
    if (!_handledQqXloginUrls.add(target)) {
      return true;
    }
    if (mounted) {
      setState(() {
        _statusMessage = '正在进入手机 QQ 授权页...';
        _isLoading = true;
      });
    }
    await _applyQqStageUserAgentIfNeeded(target);
    await _controller.loadRequest(xloginUrl);
    return true;
  }

  Future<void> _scanQqAuthorizationTargets() async {
    if (!widget.qqLoginMode || !_controllerReady) {
      return;
    }
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null) {
      return;
    }
    final host = uri.host.toLowerCase();
    if (host != 'graph.qq.com' && !host.endsWith('ptlogin2.qq.com')) {
      return;
    }

    Object? result;
    try {
      result = await _controller.runJavaScriptReturningResult(r'''
(() => {
  const out = [];
  const push = (value) => {
    if (!value || typeof value !== 'string') return;
    if (/^(mqqapi|mqq|tencent|wtloginmqq):\/\//i.test(value) ||
        /https:\/\/xui\.ptlogin2\.qq\.com\/cgi-bin\/xlogin/i.test(value)) {
      out.push(value);
    }
  };
  document.querySelectorAll('a[href], form[action]').forEach((node) => {
    push(node.href || node.action);
  });
  document.querySelectorAll('[onclick]').forEach((node) => {
    push(node.getAttribute('onclick'));
  });
  const html = document.documentElement ? document.documentElement.innerHTML : '';
  const matches = html.match(/(?:mqqapi|mqq|tencent|wtloginmqq):\/\/[^'"<>\s]+|https:\/\/xui\.ptlogin2\.qq\.com\/cgi-bin\/xlogin[^'"<>\s]+/ig) || [];
  matches.forEach(push);
  return Array.from(new Set(out)).slice(0, 8).join('\n');
})()
''');
    } catch (_) {
      return;
    }
    final targets = result
        .toString()
        .replaceAll(RegExp(r'^"|"$'), '')
        .split(RegExp(r'\\n|\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    for (final target in targets) {
      final cleaned = target
          .replaceAll(r'\u0026', '&')
          .replaceAll(r'\/', '/')
          .trim();
      if (isTronclassExternalQqScheme(cleaned)) {
        if (_handledQqClientUrls.add(cleaned)) {
          _recordQqStage(cleaned, stage: 'externalSchemeDetected');
          await _launchExternalQqAuthorization(cleaned);
        }
        return;
      }
      final xloginUri = Uri.tryParse(cleaned);
      if (xloginUri != null &&
          xloginUri.host.toLowerCase() == 'xui.ptlogin2.qq.com' &&
          xloginUri.path.toLowerCase() == '/cgi-bin/xlogin' &&
          _handledQqXloginUrls.add(cleaned)) {
        _qqExternalLaunchState.rememberAuthorizationUrl(cleaned);
        ApiService.appendExternalConsoleLog(
          '畅课',
          '[qqLogin] jsTarget=xlogin host=${xloginUri.host} path=${xloginUri.path}',
        );
        if (mounted) {
          setState(() {
            _statusMessage = '正在进入手机 QQ 授权页...';
            _isLoading = true;
          });
        }
        await _applyQqStageUserAgentIfNeeded(cleaned);
        await _controller.loadRequest(xloginUri);
        return;
      }
    }
  }

  // ignore: unused_element
  Future<void> _continueInSystemBrowserOrQq({Uri? preferredTarget}) async {
    final browser = await _resolveQqOAuthBrowser();
    final currentUri = Uri.tryParse(_currentUrl);
    final target =
        preferredTarget ??
        (currentUri?.hasScheme == true ? currentUri! : _casQqLoginUri);
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] openBrowser strategy=$_qqStrategyName externalBrowserOnly=true scheme=${target.scheme} host=${target.host} path=${target.path}',
    );
    final opened = await _openExternalAuthTarget(target, browser: browser);
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = opened
          ? _qqRecoveryInstructionMessage()
          : '无法打开 ${browser.displayName} 或 QQ，请检查浏览器/QQ 安装状态，或改用内置网页兜底。';
    });
  }

  Future<QqRedirectCapability> _probeQqRedirectCapability() async {
    final verified =
        await TronclassQqAuthCallbackBridge.isHttpsCallbackAppLinkVerified();
    var customAccepted = false;
    final probeUri = TCLoginApi.buildAuthUri(
      redirectUriOverride: tronclassQqCustomRedirectUri,
    );
    try {
      final resp = await ApiService.sendRequest(
        probeUri.toString(),
        responseType: ResponseType.plain,
        allowRedirects: false,
        skipCredentialValidation: true,
      );
      customAccepted = classifyCustomRedirectAccepted(
        statusCode: resp.statusCode,
        responseUri: resp.requestOptions.uri.toString(),
        location: resp.headers.value('location'),
        body: resp.data?.toString(),
      );
    } catch (_) {
      customAccepted = false;
    }
    final capability = resolveQqRedirectCapability(
      customRedirectAccepted: customAccepted,
      appLinkVerified: verified,
    );
    ApiService.appendExternalConsoleLog(
      '畅课',
      '[qqLogin] redirectCapability=${capability.name} customRedirectAccepted=$customAccepted appLinkVerified=$verified',
    );
    return capability;
  }

  Future<bool> _openExternalAuthTarget(
    Uri target, {
    QqOAuthBrowserChoice? browser,
  }) async {
    final selected = browser ?? await _resolveQqOAuthBrowser();
    if (!selected.isSystemDefault) {
      final opened =
          await TronclassQqAuthCallbackBridge.openUrlInQqOAuthBrowser(
            target,
            selected,
          );
      if (opened) {
        return true;
      }
    }
    return launchUrl(target, mode: LaunchMode.externalApplication);
  }

  void _handlePortalOnlyCallback(String url) {
    if (!widget.qqLoginMode ||
        _didShowPortalOnlyCallbackTip ||
        !isTronclassPortalCallbackWithoutAuthCode(url)) {
      return;
    }
    _didShowPortalOnlyCallbackTip = true;
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessage = 'QQ 授权已回到智慧校园，但尚未获得畅课授权回调。请返回后使用 Web 认证或账号密码登录。';
    });
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
    return extractTronclassExactAuthCodeFromUrl(url);
  }

  Future<void> _completeIfReady(String url) async {
    final code = _extractCode(url);
    if (code != null) {
      _qqExternalLaunchState.clearLaunch();
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
      if (widget.qqLoginMode) {
        TronclassQqAuthCallbackBridge.completeQqLoginAttempt();
      }
      if (_isQqExternalRecoveryOnly) {
        setState(() {
          _statusMessage = '畅课登录已完成，正在刷新会话...';
          _isCompleting = false;
        });
        Navigator.of(context).pop(result);
        return;
      }
      final sessionId = (result['sessionId'] ?? '').toString();
      final accountId = widget.accountId;
      if (accountId != null && accountId.isNotEmpty) {
        if (sessionId.isNotEmpty) {
          await TronclassAuthManager.setSessionIdForUser(accountId, sessionId);
        } else {
          await TronclassAuthManager.clearSessionIdForUser(accountId);
        }
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

    final modeText = widget.qqLoginMode
        ? 'QQ 快捷登录'
        : (_isPortalMode ? '门户预览' : '登录认证');
    final uaText = _isMobileMode ? '移动端 UA' : '桌面端 UA';
    final currentPage = _isQqExternalRecoveryOnly
        ? '等待浏览器回调'
        : (_pageTitle?.trim().isNotEmpty == true
              ? _pageTitle!.trim()
              : (_currentUrl.isNotEmpty ? _currentUrl : '等待网页加载'));
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
                      _statusMessage ?? _qqDefaultStatusMessage,
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
                _buildInfoChip(
                  label: '模式',
                  value: modeText,
                  color: Colors.white,
                ),
                _buildInfoChip(label: 'UA', value: uaText, color: Colors.white),
                if (widget.qqLoginMode)
                  _buildInfoChip(
                    label: '回调',
                    value: _qqLoginStrategyResolved
                        ? (_qqLoginStrategy ==
                                  QqLoginStrategy.browserReturnRequired
                              ? '浏览器回收'
                              : '可尝试回 App')
                        : '检测中',
                    color: Colors.white,
                  ),
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
                if (_shouldShowQqAction)
                  _buildQuickActionButton(
                    label: _isQqExternalRecoveryOnly
                        ? '重新打开浏览器/QQ'
                        : '打开浏览器/QQ 授权',
                    icon: Icons.chat_bubble_outline,
                    onPressed: _controllerReady
                        ? (_isQqExternalRecoveryOnly
                              ? _startQqAuthorizationInSystemBrowser
                              : _startQqAuthorization)
                        : null,
                  ),
                if (widget.qqLoginMode)
                  _buildQuickActionButton(
                    label: '内置网页兜底',
                    icon: Icons.web_asset,
                    onPressed: _controllerReady
                        ? _startQqAuthorizationInWebView
                        : null,
                  ),
                _buildQuickActionButton(
                  label: '我已复制浏览器地址，完成登录',
                  icon: Icons.content_paste_go_outlined,
                  onPressed: _controllerReady
                      ? _pasteQqReturnedBrowserUrl
                      : null,
                ),
                if (!_isQqExternalRecoveryOnly) ...[
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
          title: Text(
            _isQqExternalRecoveryOnly ? 'QQ 授权回收' : (_pageTitle ?? '畅课网页登录'),
          ),
          actions: [
            if (!_isQqExternalRecoveryOnly) ...[
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
            ],
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
