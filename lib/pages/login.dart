import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tencent_captcha/flutter_tencent_captcha.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/login.dart';
import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../session/cookie.dart';
import '../session/tronclass_auth.dart';
import '../utils/encrypt.dart';
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

  Future<bool> initialize() async {
    isLoading = true;
    try {
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
        qrImageUrl = 'https://passport2.chaoxing.com/createqr?uuid=$uuid&fid=-1';
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
          qrImageUrl = 'https://passport2.chaoxing.com/createqr?uuid=$_uuid&fid=-1';
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
    if (!_isChaoxing) {
      () async {
        while (isLoginActive && _uuid != null && _state != null) {
          try {
            final status = await RCLoginApi.checkQRAuthStatus(_uuid!, _state!);
            if (status == '405') {
              isLoginActive = false;
              await onResult(true);
              return;
            } else if (status == '402') {
              await refreshQRCode();
              if (!isLoginActive || _uuid == null) {
                return;
              }
            }
          } catch (_) {
            // keep polling
          }

          if (!isLoginActive) {
            return;
          }
          await Future.delayed(const Duration(seconds: 5));
        }
      }();
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

  void dispose() {
    isLoginActive = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

Future<bool> handleLoginSuccess(BuildContext context) async {
  try {
    CookieManager.isLoggingIn = true;
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

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${user.name} 登录成功')));
    }
    CookieManager.isLoggingIn = false;
    return true;
  } catch (e) {
    debugPrint('处理登录成功失败：$e');
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

  const LoginPage({super.key, this.initialLoginType = 'password'});

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

  Future<String?> _showTronclassMfaDialog(
    String? mobileHint,
    String? tip,
  ) async {
    final codeController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('请输入短信动态验证码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip?.isNotEmpty == true
                    ? tip!
                    : '验证码已发送，请输入收到的短信动态码',
              ),
              if (mobileHint != null && mobileHint.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('接收号码：$mobileHint'),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '短信动态码',
                  hintText: '请输入手机收到的验证码',
                ),
                onSubmitted: (_) {
                  Navigator.of(dialogContext).pop(codeController.text.trim());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('暂不验证'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(codeController.text.trim()),
              child: const Text('验证'),
            ),
          ],
        );
      },
    );

    codeController.dispose();
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
    const guide =
        '提示：请求过快，请重试；多次重试仍无法连接，请根据设置中的邮箱联系开发者。';
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('诊断信息已复制')),
                );
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
    required String sessionId,
  }) async {
    final user =
        await TCLoginApi.getUserInfo(fallbackUid: username) ??
        User(
          uid: username,
          name: username,
          avatar: '',
          phone: '未知手机号',
          school: '桂林电子科技大学',
          platform: 'tronclass',
        );

    await AccountManager.addAccount(user);
    await AccountManager.setCurrentSession(user.uid);
    await TronclassAuthManager.setSessionIdForUser(user.uid, sessionId);
    await TCLoginApi.bootstrapPortalSession(sessionId: sessionId);

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('畅课登录成功')));
    Navigator.pop(context, true);
    return true;
  }

  Future<String?> _showKetangpaiCaptchaDialog(Uint8List imageBytes) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _KetangpaiCaptchaDialog(imageBytes: imageBytes),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('发送验证码失败，请重试')),
            );
          }
          return;
        }

        final ok = result['status'] == true;
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('雨课堂验证码登录仅支持11位手机号')),
            );
          }
          return;
        }

        // Terminal diagnostics for captcha send failures.
        debugPrint('[RC][sendCaptcha][request] phone=$phone ticketLen=${_ticket?.length ?? 0} randLen=${_randstr?.length ?? 0}');

        final result = await RCLoginApi.sendCaptcha(phone, _ticket!, _randstr!);
        if (result == null) {
          debugPrint('[RC][sendCaptcha][response] null result');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('发送验证码失败，请重试')),
            );
          }
          return;
        }

        debugPrint('[RC][sendCaptcha][response] $result');

        final code = (result['code'] ?? -1).toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              code == '0'
                  ? '验证码已发送'
                  : (result['msg'] ?? '发送验证码失败').toString(),
            ),
          ),
        );
        return;
      }

      if (PlatformManager().isKetangpai) {
        final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
        debugPrint('[KT][sendCaptcha][request] sessionId=$sessionId account=$account');
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

        debugPrint('[KT][sendCaptcha][submit] verifyLen=${verify.length} sessionId=$sessionId');
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
          const SnackBar(
            content: Text('当前运行平台未集成腾讯验证码插件，请在 Android/iOS 上重试'),
          ),
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
          const SnackBar(
            content: Text('腾讯验证码插件未正确加载，请使用 Android/iOS 真机运行后重试'),
          ),
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
          const SnackBar(
            content: Text('当前运行平台不支持雨课堂验证码验证，请在 Android/iOS 上登录'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();

      if (PlatformManager().isTronclass) {
        final result = await TCLoginApi.login(
          username,
          _passwordController.text,
          captchaProvider: _showTronclassCaptchaDialog,
          mfaCodeProvider: _showTronclassMfaDialog,
        );

        if (result['ok'] != true) {
          final message = (result['message'] ?? '畅课登录失败').toString();
          final cancelledMfa = result['cancelledMfa'] == true ||
              message.contains('取消了输入') ||
              message.contains('取消了验证');

          if (cancelledMfa) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('你已取消本次短信验证，可稍后重新登录继续验证'),
                  backgroundColor: Color(0xFF2F3A4A),
                ),
              );
            }
            return;
          }

          if (mounted) {
            await _showTronclassDebugDialog(
              message: message,
              debug: result['debug']?.toString() ?? TCLoginApi.lastLoginTrace,
            );
          }
          return;
        }

        final sessionId = (result['sessionId'] ?? '').toString();
        if (sessionId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('未获取到畅课会话')));
          }
          return;
        }
        await _completeTronclassLoginWithSession(
          username: username,
          sessionId: sessionId,
        );
        return;
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
            );
      } else if (PlatformManager().isRainClassroom) {
        final loginType = _currentLoginType == '2' ? 3 : 2;
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

        loginResult = await RCLoginApi.login(
          loginType,
          accountForLogin,
          code,
          _ticket!,
          _randstr!,
        );

        _ticket = null;
        _randstr = null;

        final success = loginResult?['code'] == 0;
        if (!success) {
          throw Exception(
            (loginResult?['msg'] ?? '雨课堂登录失败')
                .toString(),
          );
        }

        user =
            await RCLoginApi.getUserInfo() ??
            User(
              uid: username,
              name: username,
              avatar: '',
              phone: '未知手机号',
              school: '未知学校',
              platform: 'rainClassroom',
            );
      } else {
        final code = _currentLoginType == '2'
            ? _captchaController.text.trim()
            : _passwordController.text;
        final loginType = _currentLoginType == '2' ? '2' : '1';

        loginResult = await CXLoginApi.loginAPP(loginType, username, code);
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

        user =
            await CXLoginApi.getUserInfo() ??
            User(
              uid: username,
              name: username,
              avatar: '',
              phone: '未知手机号',
              school: '未知学校',
              platform: 'chaoxing',
            );
      }

      await AccountManager.addAccount(user);
      await AccountManager.setCurrentSession(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('登录成功')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录失败：$e')));
      }
    } finally {
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

    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isTronclass ? '登录畅课账户' : '登录账号',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isTronclass
                              ? '输入账号和密码后直接走后端登录，若需要验证码会自动弹窗。'
                              : '可使用密码或验证码登录。',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: '账号',
                            hintText: '学号/手机号/邮箱',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? '请输入账号' : null,
                        ),
                        if (!isCaptchaMode) ...[
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              labelText: '密码',
                              hintText: '输入密码',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _captchaController,
                            decoration: InputDecoration(
                              labelText: '验证码',
                              hintText: '短信验证码/图形码',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.verified_user),
                              suffixIcon: TextButton(
                                onPressed: _isLoading ? null : _sendCaptcha,
                                child: const Text('获取验证码'),
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
                        const SizedBox(height: 16),
                        if (!isTronclass)
                          Row(
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
                              const SizedBox(width: 8),
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
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isTronclass
                                        ? '登录'
                                        : (_currentLoginType == '2'
                                              ? '验证码登录'
                                              : '登录'),
                                  ),
                          ),
                        ),
                        if (isTronclass)
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : _openTronclassPortalPreview,
                            child: const Text('仅查看畅课门户'),
                          ),
                      ],
                    ),
                  ),
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
  State<_KetangpaiCaptchaDialog> createState() => _KetangpaiCaptchaDialogState();
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
          onPressed: () => Navigator.of(context).pop(_captchaController.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
