import 'dart:async';

import 'package:flutter/services.dart';

class TronclassQqAuthCallbackBridge {
  TronclassQqAuthCallbackBridge._();

  static const Duration _attemptTimeout = Duration(minutes: 10);
  static const MethodChannel _channel = MethodChannel(
    'com.gueter.cszm/tronclass_qq_auth_callback',
  );
  static final StreamController<String> _callbackController =
      StreamController<String>.broadcast();
  static bool _initialized = false;
  static final Set<String> _consumedUrls = <String>{};
  static QqLoginAttempt? _activeAttempt;

  static Stream<String> get onCallbackStream {
    _ensureInitialized();
    return _callbackController.stream;
  }

  static Future<String?> getInitialCallback() async {
    return getPendingReturnedUrl();
  }

  static Future<String?> getPendingReturnedUrl() async {
    _ensureInitialized();
    try {
      final url = await _channel.invokeMethod<String>(
        'consumePendingReturnedUrl',
      );
      if (url == null || url.isEmpty) {
        return null;
      }
      return consumeReturnedUrl(url) ? url : null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isHttpsCallbackAppLinkVerified() async {
    _ensureInitialized();
    try {
      return await _channel.invokeMethod<bool>(
            'isTronclassQqCallbackAppLinkVerified',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<QqOAuthBrowserChoice>>
  getInstalledQqOAuthBrowsers() async {
    _ensureInitialized();
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getInstalledQqOAuthBrowsers',
      );
      if (raw == null) {
        return const <QqOAuthBrowserChoice>[];
      }
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(QqOAuthBrowserChoice.fromPlatformMap)
          .where((browser) => browser.isInstalled)
          .toList(growable: false);
    } catch (_) {
      return const <QqOAuthBrowserChoice>[];
    }
  }

  static Future<bool> openUrlInQqOAuthBrowser(
    Uri url,
    QqOAuthBrowserChoice browser,
  ) async {
    _ensureInitialized();
    try {
      return await _channel.invokeMethod<bool>('openUrlInBrowserPackage', {
            'url': url.toString(),
            'packageName': browser.packageName,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static bool consumeCallbackUrl(String url) {
    if (!isTronclassQqAuthCallbackUrl(url)) {
      return false;
    }
    final returned = parseQqReturnedBrowserUrl(url);
    if (!_canConsumeReturnedUrl(returned)) {
      return false;
    }
    return _markReturnedUrlConsumed(returned);
  }

  static bool consumeReturnedUrl(String url) {
    final returned = parseQqReturnedBrowserUrl(url);
    if (returned.type == QqReturnedBrowserUrlType.invalid) {
      return false;
    }
    if (!_canConsumeReturnedUrl(returned)) {
      return false;
    }
    return _markReturnedUrlConsumed(returned);
  }

  static String? consumeReturnedText(String text) {
    final url = extractFirstSupportedQqReturnedUrl(text);
    if (url == null) {
      return null;
    }
    return consumeReturnedUrl(url) ? url : null;
  }

  static void resetForTests() {
    _consumedUrls.clear();
    _activeAttempt = null;
  }

  static QqLoginAttempt beginQqLoginAttempt({
    String? browserPackage,
    String launchSource = 'externalBrowser',
    DateTime? now,
  }) {
    final startedAt = now ?? DateTime.now();
    final attempt = QqLoginAttempt(
      attemptId: startedAt.microsecondsSinceEpoch.toString(),
      startedAt: startedAt,
      browserPackage: browserPackage,
      launchSource: launchSource,
    );
    _activeAttempt = attempt;
    return attempt;
  }

  static bool get hasActiveAttempt => _currentAttempt() != null;

  static QqLoginAttempt? get activeAttempt => _currentAttempt();

  static void completeQqLoginAttempt() {
    final current = _currentAttempt();
    if (current == null) {
      _activeAttempt = null;
      return;
    }
    _activeAttempt = current.copyWith(completedOnce: true);
    _activeAttempt = null;
  }

  static void cancelQqLoginAttempt() {
    _activeAttempt = null;
  }

  static bool canConsumeReturnedUrlForActiveAttempt(String url) {
    final returned = parseQqReturnedBrowserUrl(url);
    return _canConsumeReturnedUrl(returned);
  }

  static QqLoginAttempt? _currentAttempt({DateTime? now}) {
    final current = _activeAttempt;
    if (current == null) {
      return null;
    }
    final elapsed = (now ?? DateTime.now()).difference(current.startedAt);
    if (elapsed > _attemptTimeout || current.completedOnce) {
      _activeAttempt = null;
      return null;
    }
    return current;
  }

  static bool _canConsumeReturnedUrl(QqReturnedBrowserUrl returned) {
    if (returned.type == QqReturnedBrowserUrlType.invalid) {
      return false;
    }
    if (!returned.isFinalTronclassCallback) {
      return true;
    }
    final current = _currentAttempt();
    return current != null && !current.recoveredOnce && !current.completedOnce;
  }

  static bool _markReturnedUrlConsumed(QqReturnedBrowserUrl returned) {
    if (!_consumedUrls.add(returned.url)) {
      return false;
    }
    if (returned.isFinalTronclassCallback) {
      final current = _currentAttempt();
      if (current != null) {
        _activeAttempt = current.copyWith(recoveredOnce: true);
      }
    }
    return true;
  }

  static void _ensureInitialized() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onCallback') {
        return;
      }
      final url = call.arguments?.toString();
      if (url == null || url.isEmpty) {
        return;
      }
      if (consumeReturnedUrl(url)) {
        _callbackController.add(url);
      }
    });
  }
}

const String tronclassQqCustomRedirectUri = 'gueter://tronclass-qq-callback';

class QqLoginAttempt {
  const QqLoginAttempt({
    required this.attemptId,
    required this.startedAt,
    this.browserPackage,
    this.launchSource = 'externalBrowser',
    this.recoveredOnce = false,
    this.completedOnce = false,
  });

  final String attemptId;
  final DateTime startedAt;
  final String? browserPackage;
  final String launchSource;
  final bool recoveredOnce;
  final bool completedOnce;

  QqLoginAttempt copyWith({bool? recoveredOnce, bool? completedOnce}) {
    return QqLoginAttempt(
      attemptId: attemptId,
      startedAt: startedAt,
      browserPackage: browserPackage,
      launchSource: launchSource,
      recoveredOnce: recoveredOnce ?? this.recoveredOnce,
      completedOnce: completedOnce ?? this.completedOnce,
    );
  }
}

class QqOAuthBrowserChoice {
  const QqOAuthBrowserChoice({
    required this.packageName,
    required this.displayName,
    required this.isInstalled,
    required this.isRecommended,
    this.isDefault = false,
  });

  factory QqOAuthBrowserChoice.fromPlatformMap(Map<dynamic, dynamic> map) {
    return QqOAuthBrowserChoice(
      packageName: map['packageName']?.toString(),
      displayName: map['displayName']?.toString() ?? '系统默认浏览器',
      isInstalled: map['isInstalled'] == true,
      isRecommended: map['isRecommended'] == true,
      isDefault: map['isDefault'] == true,
    );
  }

  static const systemDefault = QqOAuthBrowserChoice(
    packageName: null,
    displayName: '系统默认浏览器',
    isInstalled: true,
    isRecommended: false,
    isDefault: true,
  );

  final String? packageName;
  final String displayName;
  final bool isInstalled;
  final bool isRecommended;
  final bool isDefault;

  bool get isSystemDefault => packageName == null || packageName!.isEmpty;
}

QqOAuthBrowserChoice resolvePreferredQqOAuthBrowser(
  List<QqOAuthBrowserChoice> installedBrowsers,
) {
  for (final browser in installedBrowsers) {
    if (browser.packageName == 'com.android.chrome') {
      return QqOAuthBrowserChoice(
        packageName: browser.packageName,
        displayName: browser.displayName.isEmpty
            ? 'Chrome'
            : browser.displayName,
        isInstalled: true,
        isRecommended: true,
        isDefault: browser.isDefault,
      );
    }
  }
  for (final browser in installedBrowsers) {
    if (browser.isDefault) {
      return browser;
    }
  }
  for (final browser in installedBrowsers) {
    if (browser.isInstalled && !browser.isSystemDefault) {
      return browser;
    }
  }
  return QqOAuthBrowserChoice.systemDefault;
}

enum QqLoginStrategy {
  nativeRedirectSupported,
  verifiedHttpsSupported,
  browserReturnRequired,
}

enum QqRedirectCapability {
  customRedirectAccepted,
  verifiedAppLink,
  browserRecoveryOnly,
}

QqRedirectCapability resolveQqRedirectCapability({
  required bool customRedirectAccepted,
  required bool appLinkVerified,
}) {
  if (customRedirectAccepted) {
    return QqRedirectCapability.customRedirectAccepted;
  }
  if (appLinkVerified) {
    return QqRedirectCapability.verifiedAppLink;
  }
  return QqRedirectCapability.browserRecoveryOnly;
}

bool classifyCustomRedirectAccepted({
  required int? statusCode,
  required String? responseUri,
  required String? location,
  required String? body,
}) {
  final haystack = <String>[
    responseUri ?? '',
    location ?? '',
    body ?? '',
  ].join(' ').toLowerCase();
  if (haystack.contains('invalid_redirect_uri') ||
      haystack.contains('invalid redirect') ||
      haystack.contains('redirect_uri') && haystack.contains('invalid')) {
    return false;
  }
  if (haystack.contains('gueter://tronclass-qq-callback')) {
    return true;
  }
  if ((statusCode == 302 || statusCode == 303) &&
      (location ?? '').isNotEmpty &&
      !haystack.contains('invalid')) {
    return true;
  }
  return false;
}

QqLoginStrategy resolveQqLoginStrategy({
  required bool appLinkVerified,
  bool nativeRedirectSupported = false,
}) {
  if (nativeRedirectSupported) {
    return QqLoginStrategy.nativeRedirectSupported;
  }
  if (appLinkVerified) {
    return QqLoginStrategy.verifiedHttpsSupported;
  }
  return QqLoginStrategy.browserReturnRequired;
}

enum QqReturnedBrowserUrlType {
  tronclassCallback,
  identityEndpoint,
  customSchemeCallback,
  casQqCallback,
  portalOnly,
  portalMobileHome,
  invalid,
}

class QqReturnedBrowserUrl {
  const QqReturnedBrowserUrl({
    required this.type,
    required this.url,
    this.code,
  });

  final QqReturnedBrowserUrlType type;
  final String url;
  final String? code;

  bool get hasCode => code != null && code!.isNotEmpty;
  bool get isFinalTronclassCallback =>
      type == QqReturnedBrowserUrlType.tronclassCallback ||
      type == QqReturnedBrowserUrlType.identityEndpoint ||
      type == QqReturnedBrowserUrlType.customSchemeCallback;
}

QqReturnedBrowserUrl parseQqReturnedBrowserUrl(String raw) {
  final url = extractFirstSupportedQqReturnedUrl(raw) ?? raw.trim();
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return QqReturnedBrowserUrl(
      type: QqReturnedBrowserUrlType.invalid,
      url: url,
    );
  }
  final scheme = uri.scheme.toLowerCase();
  final code = uri.queryParameters['code'];
  final cleanCode = code == null || code.isEmpty ? null : code;
  if (scheme == 'gueter' && uri.host.toLowerCase() == 'tronclass-qq-callback') {
    return QqReturnedBrowserUrl(
      type: cleanCode == null
          ? QqReturnedBrowserUrlType.invalid
          : QqReturnedBrowserUrlType.customSchemeCallback,
      url: url,
      code: cleanCode,
    );
  }
  if (scheme != 'https') {
    return QqReturnedBrowserUrl(
      type: QqReturnedBrowserUrlType.invalid,
      url: url,
    );
  }
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();

  if (host == 'mobile.guet.edu.cn' && path == '/cas-callback') {
    return QqReturnedBrowserUrl(
      type: cleanCode == null
          ? QqReturnedBrowserUrlType.invalid
          : QqReturnedBrowserUrlType.tronclassCallback,
      url: url,
      code: cleanCode,
    );
  }
  if (host == 'identity.guet.edu.cn' &&
      path.contains('/broker/cas-client/endpoint')) {
    return QqReturnedBrowserUrl(
      type: cleanCode == null
          ? QqReturnedBrowserUrlType.invalid
          : QqReturnedBrowserUrlType.identityEndpoint,
      url: url,
      code: cleanCode,
    );
  }
  if (host == 'cas.guet.edu.cn' && path.endsWith('/authserver/callback')) {
    return QqReturnedBrowserUrl(
      type: cleanCode == null
          ? QqReturnedBrowserUrlType.invalid
          : QqReturnedBrowserUrlType.casQqCallback,
      url: url,
      code: cleanCode,
    );
  }
  if (host == 'portal.guet.edu.cn' && path == '/ywtbcallback') {
    return QqReturnedBrowserUrl(
      type: cleanCode == null
          ? QqReturnedBrowserUrlType.invalid
          : QqReturnedBrowserUrlType.portalOnly,
      url: url,
      code: cleanCode,
    );
  }
  if (host == 'portal.guet.edu.cn' &&
      path == '/sopplus/_web/customized/portalwechat/app/mobile/index.jsp') {
    return QqReturnedBrowserUrl(
      type: QqReturnedBrowserUrlType.portalMobileHome,
      url: url,
    );
  }
  return QqReturnedBrowserUrl(type: QqReturnedBrowserUrlType.invalid, url: url);
}

String? extractFirstSupportedQqReturnedUrl(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final candidates = <String>[
    trimmed,
    ...RegExp(
      "gueter://[^\\s<>\"']+",
    ).allMatches(trimmed).map((m) => m.group(0)!),
    ...RegExp(
      "https://[^\\s<>\"']+",
    ).allMatches(trimmed).map((m) => m.group(0)!),
  ];
  for (final candidate in candidates) {
    final cleaned = _trimUrlBoundary(candidate);
    final uri = Uri.tryParse(cleaned);
    if (uri == null) {
      continue;
    }
    if (uri.scheme.toLowerCase() == 'gueter' &&
        uri.host.toLowerCase() == 'tronclass-qq-callback' &&
        uri.queryParameters['code']?.isNotEmpty == true) {
      return cleaned;
    }
    if (uri.scheme.toLowerCase() != 'https') {
      continue;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final supported =
        (host == 'mobile.guet.edu.cn' && path == '/cas-callback') ||
        (host == 'identity.guet.edu.cn' &&
            path.contains('/broker/cas-client/endpoint')) ||
        (host == 'cas.guet.edu.cn' && path.endsWith('/authserver/callback')) ||
        (host == 'portal.guet.edu.cn' && path == '/ywtbcallback') ||
        (host == 'portal.guet.edu.cn' &&
            path ==
                '/sopplus/_web/customized/portalwechat/app/mobile/index.jsp');
    if (supported &&
        (uri.queryParameters['code']?.isNotEmpty == true ||
            (host == 'portal.guet.edu.cn' &&
                path ==
                    '/sopplus/_web/customized/portalwechat/app/mobile/index.jsp'))) {
      return cleaned;
    }
  }
  return null;
}

String _trimUrlBoundary(String value) {
  var cleaned = value
      .trim()
      .replaceAll(RegExp("^[\\s\\(<\\[\"']+"), '')
      .replaceAll(RegExp("[\\s\\)>\\].,\"']+\$"), '');
  final boundary = cleaned.indexOf(RegExp(r'[，。；、]'));
  if (boundary >= 0) {
    cleaned = cleaned.substring(0, boundary);
  }
  return cleaned;
}

bool isTronclassQqAuthCallbackUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  if (uri.scheme.toLowerCase() == 'gueter') {
    return uri.host.toLowerCase() == 'tronclass-qq-callback' &&
        uri.queryParameters['code']?.isNotEmpty == true;
  }
  if (uri.scheme.toLowerCase() != 'https') {
    return false;
  }
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  return (host == 'mobile.guet.edu.cn' && path == '/cas-callback') ||
      (host == 'cas.guet.edu.cn' && path == '/authserver/callback') ||
      (host == 'identity.guet.edu.cn' &&
          path.contains('/broker/cas-client/endpoint'));
}
