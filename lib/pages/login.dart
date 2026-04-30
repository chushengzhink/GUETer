import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tencent_captcha/flutter_tencent_captcha.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';
import '../api/login.dart';
import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../session/cookie.dart';
import '../session/login_context.dart';
import '../session/tronclass_auth.dart';
import '../utils/encrypt.dart';
import '../utils/global_palette.dart';
import '../theme/design_tokens.dart';
import '../theme/animations.dart';
import 'accounts.dart';
import 'tronclass_web_login.dart';

class QRCodeLoginState {
  String? qrImageUrl;
  String? _uuid;
  String? _enc;
  String? _state;
  final _isChaoxing = PlatformManager().isChaoxing;

  bool isLoading = false;
  bool isRefreshing = false;
  bool isLoginActive = true;

  Timer? _pollTimer;
  Future<void>? _pollingFuture;

  Future<bool> initialize() async {
    isLoading = true;
    try {
      // 清除临时 Cookie，避免旧登录残留
      CookieManager.clearTempCookies();

      if (!_isChaoxing) {
        final data = await RCLoginApi.getQRCodeUuid();
        if (data == null || data.length < 2) {
          return false;
        }
        _uuid = data[0];
        _state = data[1];
        qrImageUrl = 'https://open.weixin.qq.com/connect/qrcode/$_uuid';
        return true;
      }

      if (PlatformManager().isChaoxing) {
        final qrData = await CXLoginApi.getQRCodeData();
        final uuid = qrData?['uuid']?.toString();
        final enc = qrData?['enc']?.toString();
        if (uuid == null || uuid.isEmpty || enc == null || enc.isEmpty) {
          return false;
        }
        _uuid = uuid;
        _enc = enc;
        qrImageUrl =
            'https://passport2.chaoxing.com/createqr?uuid=$uuid&fid=-1';
        return true;
      }

      return false;
    } finally {
      isLoading = false;
    }
  }

  Future<void> refreshQRCode() async {
    if (isRefreshing) return;

    isRefreshing = true;
    try {
      if (!_isChaoxing) {
        final data = await RCLoginApi.getQRCodeUuid();
        if (data != null && data.length == 2) {
          _uuid = data[0];
          _state = data[1];
          qrImageUrl = 'https://open.weixin.qq.com/connect/qrcode/$_uuid';
        }
      } else {
        final qrData = await CXLoginApi.getQRCodeData();
        if (qrData != null) {
          _uuid = qrData['uuid']?.toString();
          _enc = qrData['enc']?.toString();
          qrImageUrl =
              'https://passport2.chaoxing.com/createqr?uuid=$_uuid&fid=-1';
        }
      }
    } catch (_) {
      // keep old QR if refresh fails
    } finally {
      isRefreshing = false;
    }
  }

  void startPolling(Future<void> Function(bool success) onResult) {
    _pollTimer?.cancel();
    _pollingFuture?.ignore();
    if (!_isChaoxing) {
      _pollingFuture = _pollRainClassroom(onResult);
      return;
    }

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!isLoginActive || _uuid == null || _enc == null) {
        timer.cancel();
        return;
      }

      try {
        final result = await CXLoginApi.checkQRAuthStatus(_uuid!, _enc!);
        if (result != null) {
          if (result['status'] == true || result['result'] == 1) {
            timer.cancel();
            isLoginActive = false;
            await onResult(true);
          } else if (result['type']?.toString() == '2') {
            timer.cancel();
            await refreshQRCode();
            if (isLoginActive) {
              startPolling(onResult);
            }
          }
        }
      } catch (_) {
        // keep polling
      }
    });
  }

  Future<void> _pollRainClassroom(Future<void> Function(bool success) onResult) async {
    while (isLoginActive && _uuid != null && _state != null) {
      await Future.delayed(const Duration(seconds: 2));

      if (!isLoginActive) return;

      try {
        final status = await RCLoginApi.checkQRAuthStatus(_uuid!, _state!);
        if (status == '405') {
          isLoginActive = false;
          await onResult(true);
          return;
        } else if (status == '402') {
          await refreshQRCode();
          if (!isLoginActive || _uuid == null) return;
        }
      } catch (_) {
        // Continue polling on error
      }
    }
  }

  void dispose() {
    isLoginActive = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingFuture?.ignore();
  }
}

Future<bool> handleLoginSuccess(BuildContext context) async {
  try {
    final wasAlreadyLoggingIn = CookieManager.isLoggingIn;
    if (!wasAlreadyLoggingIn) {
      CookieManager.isLoggingIn = true;
    }

    final platformName = PlatformManager().currentPlatformName;

    late User? user;
    if (PlatformManager().isChaoxing) {
      user = await CXLoginApi.getUserInfo();
    } else {
      user = await RCLoginApi.getUserInfo();
    }

    if (user == null || user.uid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('获取用户信息失败')));
      }
      CookieManager.isLoggingIn = false;
      return false;
    }

    await AccountManager.addAccount(user);
    await AccountManager.setCurrentSession(user.uid);
    await CookieManager.saveTempCookies(user.uid);

    // Wait for session to be fully persisted
    await Future.delayed(const Duration(milliseconds: 150));

    ApiService.appendExternalConsoleLog(
      platformName,
      '登录成功，已自动返回账号页',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.name} 登录成功')));
    }

    // DO NOT call Navigator.pop here - let the caller handle navigation
    // This prevents double-pop that causes black screen

    CookieManager.isLoggingIn = false;

    // Notify account change after session is ready
    AccountChangeNotifier().notifyAccountChanged(user.uid);

    return true;
  } catch (e) {
    final platformName = PlatformManager().currentPlatformName;
    ApiService.appendExternalConsoleLog(
      platformName,
      '登录处理失败：$e',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录处理失败')));
    }
    CookieManager.isLoggingIn = false;
    return false;
  }
}

class LoginPage extends StatefulWidget {
  final String initialLoginType;
  final String? initialUsername;
  final String? initialPassword;

  const LoginPage({
    super.key,
    this.initialLoginType = 'password',
    this.initialUsername,
    this.initialPassword,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  String _currentLoginType = '1'; // 1: 密码, 2: 验证码
  String? _ticket;
  String? _randstr;
  LoginContext? _loginContext; // 新增：登录上下文

  /// 清除当前平台的旧 Cookie 和临时 Cookie，避免多账号登录冲突
  Future<void> _clearPlatformCookiesBeforeLogin() async {
    try {
      final platformName = PlatformManager().currentPlatformName;

      debugPrint('[LoginPage] 开始清除 $platformName 的旧 Cookie 和临时 Cookie');

      // 清除临时 Cookie（登录流程中的临时存储）
      CookieManager.clearTempCookies();

      // 清除全局 Dio 实例的 Cookie（如果有）
      // 注意：不清除已登录用户的 Cookie，只清除可能残留的临时 Cookie

      ApiService.appendExternalConsoleLog(
        platformName,
        '已清除临时 Cookie，准备开始新登录流程',
      );

      debugPrint('[LoginPage] $platformName Cookie 清理完成');
    } catch (e) {
      debugPrint('[LoginPage] 清除 Cookie 失败: $e');
    }
  }

  bool get _supportsTencentCaptcha {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String _normalizeMainlandPhone(String input) {
    var value = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (value.startsWith('+86')) {
      value = value.substring(3);
    }
    if (value.startsWith('86') && value.length > 11) {
      value = value.substring(2);
    }
    return value;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername?.isNotEmpty == true) {
      _usernameController.text = widget.initialUsername!;
    }
    if (widget.initialPassword?.isNotEmpty == true) {
      _passwordController.text = widget.initialPassword!;
    }
    if (PlatformManager().isRainClassroom && _supportsTencentCaptcha) {
      TencentCaptcha.init(Constant.tCaptchaAppId);
    }

    if (PlatformManager().isTronclass) {
      _currentLoginType = '1';
      return;
    }

    if (widget.initialLoginType == 'captcha' ||
        widget.initialLoginType == 'qrcode') {
      _currentLoginType = '2';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();

    // 清理登录上下文（如果存在）
    if (_loginContext != null) {
      LoginContextManager.instance.removeContext(_loginContext!.contextId);
      _loginContext = null;
    }

    super.dispose();
  }

  String get _pageTitle {
    if (PlatformManager().isTronclass) return '畅课登录';
    if (PlatformManager().isKetangpai) return '课堂派登录';
    if (PlatformManager().isRainClassroom) return '雨课堂登录';
    return '学习通登录';
  }

  Future<String?> _showTronclassCaptchaDialog(Uint8List imageBytes) async {
    final captchaController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('请输入畅课图形验证码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(imageBytes, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: captchaController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  hintText: '请输入图片中的字符',
                ),
                onSubmitted: (_) {
                  Navigator.of(
                    dialogContext,
                  ).pop(captchaController.text.trim());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(captchaController.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    captchaController.dispose();
    return result;
  }


  Future<void> _showTronclassDebugDialog({
    required String message,
    String? debug,
  }) async {
    if (!mounted) return;
    final detail = (debug?.trim().isNotEmpty == true)
        ? debug!.trim()
        : '暂无详细链路日志';
    const guide = '提示：请求过快，请重试；多次重试仍无法连接，请根据设置中的邮箱联系开发者。';
    final merged = '错误信息:\n$message\n\n$guide\n\n链路日志:\n$detail';
    final detailPreview = detail.length > 1200
        ? '${detail.substring(0, 1200)}\n\n...(日志较长，已截断显示，点击复制可获取完整链路)'
        : detail;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('畅课登录诊断信息'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText('错误信息:\n$message\n\n$guide'),
                  const SizedBox(height: 12),
                  const Text(
                    '链路日志预览',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(detailPreview),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: merged));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('诊断信息已复制')));
              },
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('我知道了'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _completeTronclassLoginWithSession({
    required String username,
    String? sessionId,
  }) async {
    debugPrint('[TC] 步骤A: 开始完成登录');

    try {
      // 立即关闭页面，避免阻塞UI
      if (mounted) {
        debugPrint('[TC] 步骤B: 立即关闭登录页面');
        Navigator.of(context).pop(true);
      }

      // 使用 scheduleMicrotask 确保后台任务完全不阻塞当前帧
      scheduleMicrotask(() {
        _completeLoginInBackground(username, sessionId);
      });

      debugPrint('[TC] 步骤C: 已启动后台登录流程，立即返回');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[TC] 登录启动异常: $e');
      debugPrint('[TC] StackTrace: $stackTrace');
      return false;
    }
  }

  Future<void> _completeLoginInBackground(String username, String? sessionId) async {
    try {
      debugPrint('[TC][后台] 开始获取用户信息');

      // 使用 WithContext 方法获取用户信息
      final userInfo = _loginContext != null
          ? await TCLoginApiWithContext.getUserInfoWithContext(
              _loginContext!,
              sessionId ?? '',
            )
          : await TCLoginApi.getUserInfo(fallbackUid: username);

      debugPrint('[TC][后台] getUserInfo 完成');

      final user = (userInfo ??
              User(
                uid: username,
                name: username,
                avatar: '',
                phone: '未知手机号',
                school: '桂林电子科技大学',
                platform: 'tronclass',
              ))
          .copyWith(password: _passwordController.text);
      debugPrint('[TC][后台] user 对象创建完成');

      await AccountManager.addAccount(user);
      debugPrint('[TC][后台] addAccount 完成');

      await AccountManager.setCurrentSession(user.uid);
      debugPrint('[TC][后台] setCurrentSession 完成');

      AccountChangeNotifier().notifyAccountChanged(user.uid);
      debugPrint('[TC][后台] notifyAccountChanged 完成');

      final sid = sessionId?.trim();
      if (sid != null && sid.isNotEmpty) {
        await TronclassAuthManager.setSessionIdForUser(user.uid, sid);
        debugPrint('[TC][后台] setSessionIdForUser 完成');
        await TCLoginApi.bootstrapPortalSession(sessionId: sid);
        debugPrint('[TC][后台] bootstrapPortalSession 完成');
      }

      debugPrint('[TC][后台] 登录流程完成');
    } catch (e, stackTrace) {
      debugPrint('[TC][后台] 登录完成异常: $e');
      debugPrint('[TC][后台] StackTrace: $stackTrace');
    }
  }

  Future<String?> _showKetangpaiCaptchaDialog(Uint8List imageBytes) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _KetangpaiCaptchaDialog(imageBytes: imageBytes),
    );
    return result;
  }

  Future<void> _sendCaptcha() async {
    final account = _usernameController.text.trim();
    if (account.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入手机号')));
      }
      return;
    }

    if (PlatformManager().isRainClassroom && _supportsTencentCaptcha) {
      final captchaResult = await _showTencentCaptcha();
      if (captchaResult != true) {
        return;
      }

      if (_ticket == null || _randstr == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('验证码验证失败，请重试')));
        }
        return;
      }
    } else if (PlatformManager().isRainClassroom) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前运行平台不支持雨课堂验证码验证，请在 Android/iOS 上使用验证码登录'),
          ),
        );
      }
      return;
    }

    try {
      if (PlatformManager().isChaoxing) {
        final result = await CXLoginApi.sendCaptcha(account);
        if (result == null) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('发送验证码失败，请重试')));
          }
          return;
        }

        final ok = result['status'] == true;
        final code = result['code'];

        // Check if verification code limit reached
        if (!ok && (code == false || code == 'false')) {
          if (!mounted) return;
          final shouldSwitchToQR = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('验证码获取次数已达上限'),
                content: const Text('今日验证码获取次数已达上限，建议使用二维码扫码登录。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('我知道了'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('切换到二维码登录'),
                  ),
                ],
              );
            },
          );

          if (shouldSwitchToQR == true && mounted) {
            Navigator.pop(context);
            // User will use QR code login from accounts page
          }
          return;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? '验证码已发送' : (result['mes'] ?? '发送验证码失败').toString(),
            ),
          ),
        );
        return;
      }

      if (PlatformManager().isRainClassroom) {
        final phone = _normalizeMainlandPhone(account);
        if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('雨课堂验证码登录仅支持11位手机号')));
          }
          return;
        }

        // Terminal diagnostics for captcha send failures.
        debugPrint(
          '[RC][sendCaptcha][request] phone=$phone ticketLen=${_ticket?.length ?? 0} randLen=${_randstr?.length ?? 0}',
        );

        final result = await RCLoginApi.sendCaptcha(phone, _ticket!, _randstr!);
        if (result == null) {
          debugPrint('[RC][sendCaptcha][response] null result');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('发送验证码失败，请重试')));
          }
          return;
        }

        debugPrint('[RC][sendCaptcha][response] $result');

        final code = (result['code'] ?? -1).toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              code == '0' ? '验证码已发送' : (result['msg'] ?? '发送验证码失败').toString(),
            ),
          ),
        );
        return;
      }

      if (PlatformManager().isKetangpai) {
        final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
        debugPrint(
          '[KT][sendCaptcha][request] sessionId=$sessionId account=$account',
        );
        final imageBytes = await KTLoginApi.getCaptchaImage(sessionId);
        if (imageBytes == null || imageBytes.isEmpty) {
          debugPrint('[KT][sendCaptcha][response] captcha image empty');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('获取图形验证码失败')));
          }
          return;
        }

        final verify = await _showKetangpaiCaptchaDialog(imageBytes);
        if (verify == null || verify.isEmpty) {
          debugPrint('[KT][sendCaptcha][dialog] user cancelled captcha input');
          return;
        }

        debugPrint(
          '[KT][sendCaptcha][submit] verifyLen=${verify.length} sessionId=$sessionId',
        );
        final result = await KTLoginApi.sendCaptcha(
          account,
          verify: verify,
          sessionId: sessionId,
        );

        if (!mounted) return;
        final msg = (result?['msg'] ?? result?['message'] ?? '').toString();
        final success =
            (result?['status'] == 1) ||
            (result?['code']?.toString() == '0') ||
            msg.contains('成功');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '验证码已发送' : (msg.isEmpty ? '发送失败' : msg)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送验证码失败：$e')));
      }
    }
  }

  Future<bool?> _showTencentCaptcha() async {
    if (!_supportsTencentCaptcha) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前运行平台未集成腾讯验证码插件，请在 Android/iOS 上重试')),
        );
      }
      return false;
    }

    final config = TencentCaptchaConfig(
      bizState: 'tencent-captcha',
      enableDarkMode: Theme.of(context).brightness == Brightness.dark,
    );

    try {
      late Map<dynamic, dynamic>? verifyResult;
      final completer = Completer<bool?>();

      await TencentCaptcha.verify(
        config: config,
        onSuccess: (data) {
          verifyResult = data;
          if (verifyResult != null) {
            _ticket = verifyResult!['ticket']?.toString();
            _randstr = verifyResult!['randstr']?.toString();
            completer.complete(true);
          } else {
            completer.complete(false);
          }
        },
        onFail: (data) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '验证失败：${(data['errorMessage'] ?? '未知错误').toString()}',
                ),
              ),
            );
          }
          completer.complete(false);
        },
      );

      return completer.future;
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('腾讯验证码插件未正确加载，请使用 Android/iOS 真机运行后重试')),
        );
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('验证异常：$e')));
      }
      return false;
    }
  }

  Future<void> _openTronclassPortalPreview() async {
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

    final currentUserId = AccountManager.currentSessionId;
    final currentUser = currentUserId == null
        ? null
        : AccountManager.getAccountById(currentUserId);
    final typedName = _usernameController.text.trim();
    final accountName = (currentUser?.name.isNotEmpty == true)
        ? currentUser!.name
        : (typedName.isNotEmpty ? typedName : '畅课账号');

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TronclassWebLoginPage(
          accountName: accountName,
          accountId: currentUserId,
          initialUrl: Uri.parse(PlatformManager().tronclassBaseUrl),
          initialMessage: '可在此查看畅课门户，必要时可点“重新登录”刷新会话',
          autoCloseOnAuthSuccess: false,
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (PlatformManager().isRainClassroom && _supportsTencentCaptcha) {
      if (_ticket == null || _randstr == null) {
        final captchaResult = await _showTencentCaptcha();
        if (captchaResult != true) {
          return;
        }
      }
    } else if (PlatformManager().isRainClassroom) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前运行平台不支持雨课堂验证码验证，请在 Android/iOS 上登录')),
        );
      }
      return;
    }

    if (!mounted) return;

    // 清除当前平台的旧 Cookie 和临时 Cookie，避免多账号登录冲突
    await _clearPlatformCookiesBeforeLogin();

    // 创建登录上下文
    _loginContext = LoginContextManager.instance.createContext(
      PlatformManager().currentPlatform,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();

      if (PlatformManager().isTronclass) {
        try {
          final result = await TCLoginApiWithContext.loginWithContext(
            _loginContext!,
            username,
            _passwordController.text,
            captchaProvider: (imageBytes) async {
              final captcha = await _showTronclassCaptchaDialog(imageBytes);
              return captcha ?? '';
            },
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              return {
                'ok': false,
                'message': '畅课登录超时，请检查网络连接后重试',
              };
            },
          );

          final resultSessionId = (result['sessionId'] ?? '').toString();
          final loginSucceeded = result['ok'] == true || resultSessionId.isNotEmpty;

          if (!loginSucceeded) {
            final message = (result['message'] ?? '畅课登录失败').toString();
            if (mounted) {
              await _showTronclassDebugDialog(
                message: message,
                debug: result['debug']?.toString() ?? '',
              );
            }
            return;
          }

          await _completeTronclassLoginWithSession(
            username: username,
            sessionId: resultSessionId.isEmpty ? null : resultSessionId,
          );
          return;
        } catch (e, stackTrace) {
          if (mounted) {
            await _showTronclassDebugDialog(
              message: '畅课登录异常: ${e.toString()}',
              debug: 'Error: $e\nStackTrace: $stackTrace',
            );
          }
          return;
        }
      }

      Map<String, dynamic>? loginResult;
      User? user;

      if (PlatformManager().isKetangpai) {
        if (_currentLoginType == '2') {
          loginResult = await KTLoginApi.loginByMobile(
            username,
            _captchaController.text.trim(),
          );
        } else {
          loginResult = await KTLoginApi.loginPassword(
            username,
            _passwordController.text,
            _captchaController.text.trim(),
          );
        }

        final data =
            loginResult?['data'] as Map<String, dynamic>? ?? loginResult;
        final token = (data?['token'] ?? data?['access_token'] ?? '')
            .toString();
        if (token.isEmpty) {
          throw Exception(
            (loginResult?['msg'] ?? loginResult?['message'] ?? '课堂派登录失败')
                .toString(),
          );
        }

        final tokenHealthy = await KTLoginApi.checkTokenStatus(token);
        if (!tokenHealthy) {
          throw Exception('课堂派登录成功但 token 无效，请重试或改用短信登录');
        }

        user =
            await KTLoginApi.getUserInfo(token, fallbackUid: username) ??
            User(
              uid: username,
              name: username,
              avatar: '',
              phone: '未知手机号',
              school: '未知学校',
              platform: 'ketangpai',
              token: token,
              password: _currentLoginType == '1'
                  ? _passwordController.text
                  : '',
            );
      } else if (PlatformManager().isRainClassroom) {
        final accountForLogin = _currentLoginType == '2'
            ? _normalizeMainlandPhone(username)
            : username;
        if (_currentLoginType == '2' &&
            !RegExp(r'^1\d{10}$').hasMatch(accountForLogin)) {
          throw Exception('雨课堂验证码登录仅支持11位手机号');
        }

        final code = _currentLoginType == '2'
            ? _captchaController.text.trim()
            : _passwordController.text;

        // 使用带 context 的新方法
        if (_currentLoginType == '2') {
          // 手机号登录
          loginResult = await RCLoginApiWithContext.loginByMobileWithContext(
            _loginContext!,
            accountForLogin,
            code,
          );
        } else {
          // 密码登录
          loginResult = await RCLoginApiWithContext.loginPasswordWithContext(
            _loginContext!,
            accountForLogin,
            code,
          );
        }

        _ticket = null;
        _randstr = null;

        final success = loginResult?['code'] == 0;
        if (!success) {
          throw Exception((loginResult?['msg'] ?? '雨课堂登录失败').toString());
        }

        user = await RCLoginApiWithContext.getUserInfoWithContext(_loginContext!) ??
            User(
              uid: username,
              name: username,
              avatar: '',
              phone: '未知手机号',
              school: '未知学校',
              platform: 'yuketang',
              password: _currentLoginType == '2'
                  ? ''
                  : _passwordController.text,
            );
      } else {
        // Chaoxing login: type='1' for password, type='2' for captcha
        // 使用带 context 的新方法
        if (_currentLoginType == '1') {
          // Password login
          loginResult = await CXLoginApiWithContext.loginAPPWithContext(
            _loginContext!,
            '1',
            username,
            _passwordController.text,
          );
        } else {
          // Captcha login
          loginResult = await CXLoginApiWithContext.loginAPPWithContext(
            _loginContext!,
            '2',
            username,
            _captchaController.text.trim(),
          );
        }
        final success =
            loginResult?['status'] == true ||
            loginResult?['result'] == 1 ||
            loginResult?['code']?.toString() == '1';
        if (!success) {
          throw Exception(
            (loginResult?['msg'] ?? loginResult?['mes'] ?? '学习通登录失败')
                .toString(),
          );
        }

        user = await CXLoginApiWithContext.getUserInfoWithContext(_loginContext!);

        if (user == null) {
          throw Exception('获取用户信息失败，请重试');
        }

        debugPrint('[学习通] 登录成功，用户信息: uid=${user.uid}, name=${user.name}');
      }

      // 迁移 Cookie 从 context 到用户 jar
      await CookieManager.saveTempCookiesFromContext(user.uid, _loginContext!);

      await AccountManager.addAccount(user);
      await AccountManager.setCurrentSession(user.uid);

      final platformName = PlatformManager().currentPlatformName;
      ApiService.appendExternalConsoleLog(
        platformName,
        '登录成功，已自动返回账号页',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${user.name} 登录成功')));
        Navigator.pop(context, true);
      }

      // Notify account change immediately - no delay needed
      AccountChangeNotifier().notifyAccountChanged(user.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录失败：$e')));
      }
    } finally {
      // 清理登录上下文
      if (_loginContext != null) {
        LoginContextManager.instance.removeContext(_loginContext!.contextId);
        _loginContext = null;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTronclass = PlatformManager().isTronclass;
    final isCaptchaMode = !isTronclass && _currentLoginType == '2';
    final theme = Theme.of(context);
    final palette = resolvePlatformPalette(
      PlatformManager().currentPlatform,
      fallback: resolveGlobalPalette(AppSettings.globalColorSchemeNotifier.value),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.primary.withValues(alpha: 0.1),
              palette.secondary.withValues(alpha: 0.05),
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xxxl),
                    // Logo/Icon
                    AppAnimations.scaleIn(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [palette.primary, palette.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: palette.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppAnimations.fadeSlideIn(
                      child: Text(
                        _pageTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: palette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppAnimations.fadeSlideIn(
                      child: Text(
                        isTronclass
                            ? '输入账号和密码后直接走后端登录'
                            : '可使用密码或验证码登录',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    // Login Card
                    AppAnimations.fadeSlideIn(
                      begin: const Offset(0, 0.2),
                      child: Card(
                        elevation: 8,
                        shadowColor: palette.primary.withValues(alpha: 0.2),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: const InputDecoration(
                                    labelText: '账号',
                                    hintText: '学号/手机号/邮箱',
                                    prefixIcon: Icon(Icons.person_outline),
                                    filled: true,
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty ? '请输入账号' : null,
                                ),
                                if (!isCaptchaMode) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_showPassword,
                                    decoration: InputDecoration(
                                      labelText: '密码',
                                      hintText: '输入密码',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      filled: true,
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _showPassword = !_showPassword;
                                          });
                                        },
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (_currentLoginType == '2' && !isTronclass) {
                                        return null;
                                      }
                                      return v == null || v.isEmpty ? '请输入密码' : null;
                                    },
                                  ),
                                ],
                                if (!isTronclass) ...[
                                  const SizedBox(height: AppSpacing.lg),
                                  TextFormField(
                                    controller: _captchaController,
                                    decoration: InputDecoration(
                                      labelText: '验证码',
                                      hintText: '短信验证码/图形码',
                                      prefixIcon: const Icon(Icons.verified_user_outlined),
                                      filled: true,
                                      suffixIcon: TextButton(
                                        onPressed: _isLoading ? null : _sendCaptcha,
                                        child: const Text('获取'),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (_currentLoginType == '2' &&
                                          (v == null || v.trim().isEmpty)) {
                                        return '请输入验证码';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.lg),
                                if (!isTronclass)
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('密码登录'),
                                        selected: _currentLoginType == '1',
                                        onSelected: _isLoading
                                            ? null
                                            : (_) {
                                                setState(() {
                                                  _currentLoginType = '1';
                                                });
                                              },
                                      ),
                                      ChoiceChip(
                                        label: const Text('验证码登录'),
                                        selected: _currentLoginType == '2',
                                        onSelected: _isLoading
                                            ? null
                                            : (_) {
                                                setState(() {
                                                  _currentLoginType = '2';
                                                });
                                              },
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: AppSpacing.xl),
                                SizedBox(
                                  height: 52,
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: palette.primary,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            isTronclass
                                                ? '登录'
                                                : (_currentLoginType == '2'
                                                      ? '验证码登录'
                                                      : '登录'),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                                if (isTronclass) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : _openTronclassPortalPreview,
                                    child: const Text('仅查看畅课门户'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KetangpaiCaptchaDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const _KetangpaiCaptchaDialog({required this.imageBytes});

  @override
  State<_KetangpaiCaptchaDialog> createState() =>
      _KetangpaiCaptchaDialogState();
}

class _KetangpaiCaptchaDialogState extends State<_KetangpaiCaptchaDialog> {
  late final TextEditingController _captchaController;

  @override
  void initState() {
    super.initState();
    _captchaController = TextEditingController();
  }

  @override
  void dispose() {
    _captchaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('请输入课堂派图形验证码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(widget.imageBytes, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captchaController,
            autofocus: true,
            decoration: const InputDecoration(hintText: '请输入图中结果'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_captchaController.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
