import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/login.dart';
import '../models/user.dart';
import '../platform.dart';
import '../session/account.dart';
import '../session/app_settings.dart';
import '../session/tronclass_auth.dart';
import 'tronclass_web_login.dart';

class QRCodeLoginState {
  String? qrImageUrl;
  String? _uuid;
  String? _enc;
  String? _state;

  bool isLoading = false;
  bool isRefreshing = false;
  bool isLoginActive = true;

  Timer? _pollTimer;

  Future<bool> initialize() async {
    isLoading = true;
    try {
      if (PlatformManager().isChaoxing) {
        final qrData = await CXLoginApi.getQRCodeData();
        final uuid = qrData?['uuid']?.toString();
        final enc = qrData?['enc']?.toString();
        if (uuid == null || uuid.isEmpty || enc == null || enc.isEmpty) {
          return false;
        }
        _uuid = uuid;
        _enc = enc;
        qrImageUrl = 'https://passport2.chaoxing.com/createqr?uuid=$uuid';
        return true;
      }

      if (PlatformManager().isRainClassroom) {
        final data = await RCLoginApi.getQRCodeUuid();
        if (data == null || data.length < 2) {
          return false;
        }
        _uuid = data[0];
        _state = data[1];
        qrImageUrl =
            'https://lp.open.weixin.qq.com/connect/qrcode/${_uuid!}?dark=000000&light=ffffff';
        return true;
      }

      return false;
    } finally {
      isLoading = false;
    }
  }

  Future<void> refreshQRCode() async {
    dispose();
    isLoginActive = true;
    await initialize();
  }

  void startPolling(Future<void> Function(bool success) onResult) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!isLoginActive) {
        timer.cancel();
        return;
      }

      try {
        bool success = false;
        if (PlatformManager().isChaoxing && _uuid != null && _enc != null) {
          final result = await CXLoginApi.checkQRAuthStatus(_uuid!, _enc!);
          success = result?['status'] == true || result?['result'] == 1;
        } else if (PlatformManager().isRainClassroom &&
            _uuid != null &&
            _state != null) {
          final status = await RCLoginApi.checkQRAuthStatus(_uuid!, _state!);
          success = status == '405';
        }

        if (success) {
          isLoginActive = false;
          timer.cancel();
          await onResult(true);
        }
      } catch (_) {
        // keep polling until timeout or success
      }
    });
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}

Future<bool> handleLoginSuccess(BuildContext context) async {
  try {
    User? user;
    if (PlatformManager().isChaoxing) {
      user = await CXLoginApi.getUserInfo();
    } else if (PlatformManager().isRainClassroom) {
      user = await RCLoginApi.getUserInfo();
    }

    if (user == null || user.uid.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('扫码后未获取到用户信息')));
      }
      return false;
    }

    await AccountManager.addAccount(user);
    await AccountManager.setCurrentSession(user.uid);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('扫码登录失败：$e')));
    }
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

  @override
  void initState() {
    super.initState();
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
          title: const Text('请输入动态验证码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tip?.isNotEmpty == true ? tip! : '已发送动态码，请输入短信验证码'),
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
                  labelText: '动态码',
                  hintText: '请输入短信动态码',
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
              child: const Text('取消'),
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

  Future<String?> _showKetangpaiCaptchaDialog(Uint8List imageBytes) async {
    final captchaController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('请输入课堂派图形验证码'),
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
                decoration: const InputDecoration(hintText: '请输入图中结果'),
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

  Future<void> _sendCaptcha() async {
    final account = _usernameController.text.trim();
    if (account.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入账号')));
      }
      return;
    }

    try {
      if (PlatformManager().isChaoxing) {
        final result = await CXLoginApi.sendCaptcha(account);
        final ok = result?['result'] == 1 || result?['status'] == true;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? '验证码已发送' : (result?['msg'] ?? '发送失败').toString(),
            ),
          ),
        );
        return;
      }

      if (PlatformManager().isRainClassroom) {
        final result = await RCLoginApi.sendCaptcha(account, '', '');
        final code = (result?['code'] ?? -1).toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              code == '0'
                  ? '验证码已发送'
                  : (result?['message'] ?? result?['msg'] ?? '发送失败').toString(),
            ),
          ),
        );
        return;
      }

      if (PlatformManager().isKetangpai) {
        final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
        final imageBytes = await KTLoginApi.getCaptchaImage(sessionId);
        if (imageBytes == null || imageBytes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('获取图形验证码失败')));
          }
          return;
        }

        final verify = await _showKetangpaiCaptchaDialog(imageBytes);
        if (verify == null || verify.isEmpty) {
          return;
        }

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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text((result['message'] ?? '畅课登录失败').toString()),
              ),
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

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('畅课登录成功')));
          Navigator.pop(context, true);
        }
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
        final loginType = _currentLoginType == '2'
            ? 3
            : (username.contains('@') ? 2 : 1);
        final code = _currentLoginType == '2'
            ? _captchaController.text.trim()
            : _passwordController.text;

        loginResult = await RCLoginApi.login(loginType, username, code, '', '');

        final success =
            loginResult?['status'] == 1 ||
            loginResult?['success'] == true ||
            loginResult?['code']?.toString() == '0';
        if (!success) {
          throw Exception(
            (loginResult?['msg'] ?? loginResult?['message'] ?? '雨课堂登录失败')
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
