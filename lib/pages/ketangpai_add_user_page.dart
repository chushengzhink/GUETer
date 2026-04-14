import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../api/api_service.dart';
import '../api/login.dart';
import '../session/account.dart';

class KetangpaiAddUserPage extends StatefulWidget {
  const KetangpaiAddUserPage({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<KetangpaiAddUserPage> createState() => _KetangpaiAddUserPageState();
}

class _KetangpaiAddUserPageState extends State<KetangpaiAddUserPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final GlobalKey<FormState> _accountLoginKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _phoneLoginKey = GlobalKey<FormState>();

  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();

  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  bool _loadingDialogShown = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 1));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmUpdate(String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确定')),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _showLoading() {
    if (!mounted) {
      return;
    }
    _loadingDialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _hideLoading() {
    if (!mounted || !_loadingDialogShown) {
      return;
    }
    _loadingDialogShown = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownSeconds = 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
        });
        return;
      }
      setState(() {
        _countdownSeconds--;
      });
    });
  }

  Future<void> _addByAccount() async {
    if (!(_accountLoginKey.currentState?.validate() ?? false)) {
      return;
    }

    _showLoading();
    try {
      final result = await KTLoginApi.loginPassword(
        _accountController.text.trim(),
        _passwordController.text,
        '',
      );
      if (result == null) {
        _showMessage('添加失败');
        return;
      }

      if (result['status'] != 1) {
        _showMessage((result['message'] ?? result['msg'] ?? '登录失败').toString());
        return;
      }

      final token = result['data']?['token']?.toString() ?? '';
      if (token.isEmpty) {
        _showMessage('登录失败');
        return;
      }

      final user = await KTLoginApi.getUserInfo(token);
      if (user == null) {
        _showMessage('获取用户信息失败');
        return;
      }

      final existed = AccountManager.getAccountById(user.uid) != null;
      _hideLoading();
      if (existed) {
        final confirm = await _confirmUpdate('该用户已存在，点击确定更新用户信息');
        if (!confirm) {
          return;
        }
      }

      await AccountManager.addAccount(user);
      _showMessage(existed ? '更新成功' : '添加成功');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showMessage('添加失败：$e');
    } finally {
      _hideLoading();
    }
  }

  Future<void> _requestSmsCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      _showMessage('电话号码格式不对');
      return;
    }

    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    Uint8List? imageData;

    try {
      final response = await ApiService.sendRequest(
        '/UserApi/verify',
        method: 'GET',
        params: {'sessionid': sessionId},
        responseType: ResponseType.bytes,
      );
      imageData = Uint8List.fromList(response.data as List<int>);
    } catch (e) {
      _showMessage('获取验证码失败：$e');
      return;
    }

    if (!mounted) {
      return;
    }

    final captchaController = TextEditingController();
    final sendResult = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('验证码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(imageData!),
              const SizedBox(height: 10),
              TextField(
                controller: captchaController,
                decoration: const InputDecoration(
                  labelText: '请输入计算结果',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (sendResult != true) {
      return;
    }

    final code = captchaController.text.trim();
    if (code.isEmpty) {
      _showMessage('验证码不能为空');
      return;
    }

    try {
      final response = await ApiService.sendRequest(
        '/UserApi/sendCode',
        method: 'POST',
        body: {
          'mobile': phone,
          'type': 'login',
          'verify': code,
          'sessionid': sessionId,
        },
      );
      if (response.data['status'] == 1) {
        _startCountdown();
        _showMessage('发送成功');
      } else {
        _showMessage('发送失败');
      }
    } catch (e) {
      _showMessage('发送失败：$e');
    } finally {
      captchaController.dispose();
    }
  }

  Future<void> _addByPhone() async {
    if (!(_phoneLoginKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_smsCodeController.text.trim().isEmpty) {
      _showMessage('验证码不能为空');
      return;
    }

    _showLoading();
    try {
      final result = await KTLoginApi.loginByMobile(
        _phoneController.text.trim(),
        _smsCodeController.text.trim(),
      );
      if (result == null) {
        _showMessage('添加失败');
        return;
      }

      if (result['status'] != 1) {
        _showMessage((result['message'] ?? result['msg'] ?? '登录失败').toString());
        return;
      }

      final token = result['data']?['token']?.toString() ?? '';
      if (token.isEmpty) {
        _showMessage('登录失败');
        return;
      }

      final user = await KTLoginApi.getUserInfo(token);
      if (user == null) {
        _showMessage('获取用户信息失败');
        return;
      }

      final existed = AccountManager.getAccountById(user.uid) != null;
      _hideLoading();
      if (existed) {
        final confirm = await _confirmUpdate('该用户已存在，点击确定更新用户信息');
        if (!confirm) {
          return;
        }
      }

      await AccountManager.addAccount(user);
      _showMessage(existed ? '更新成功' : '添加成功');
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showMessage('添加失败：$e');
    } finally {
      _hideLoading();
    }
  }

  Widget _buildAccountTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _accountLoginKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: '账号',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value != null && value.trim().isNotEmpty ? null : '账号不能为空',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value != null && value.trim().isNotEmpty ? null : '密码不能为空',
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 45,
              child: ElevatedButton(
                onPressed: _addByAccount,
                child: const Text('添加用户', style: TextStyle(fontSize: 16, letterSpacing: 5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _phoneLoginKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '电话号码',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value != null && value.trim().length == 11 ? null : '电话号码不符合格式',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _smsCodeController,
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value != null && value.trim().isNotEmpty ? null : '验证码不能为空',
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 120,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _countdownSeconds > 0 ? null : _requestSmsCode,
                    child: Text(_countdownSeconds > 0 ? '$_countdownSeconds s' : '发送验证码'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 45,
              child: ElevatedButton(
                onPressed: _addByPhone,
                child: const Text('添加用户', style: TextStyle(fontSize: 16, letterSpacing: 5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加用户'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '账号密码'),
            Tab(text: '手机验证码'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountTab(),
          _buildPhoneTab(),
        ],
      ),
    );
  }
}