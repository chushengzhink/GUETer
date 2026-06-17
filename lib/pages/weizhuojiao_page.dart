import 'package:flutter/material.dart';

import '../api/weizhuojiao.dart';
import '../models/user.dart';
import '../platform.dart';
import '../services/sign_network_gate.dart';
import '../services/sign_platform_context.dart';
import '../services/sign_run_console.dart';
import '../session/sign_record_store.dart';
import '../widgets/platform_sign_log_card.dart';
import '../widgets/sign_run_console_panel.dart';

class WeizhuojiaoPage extends StatefulWidget {
  const WeizhuojiaoPage({super.key});

  @override
  State<WeizhuojiaoPage> createState() => _WeizhuojiaoPageState();
}

class _WeizhuojiaoPageState extends State<WeizhuojiaoPage> {
  final TextEditingController _openidController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final SignRunConsoleController _consoleController = SignRunConsoleController(
    platformContext: SignPlatformContext.weizhuojiao,
  );

  WZJSignData? _signData;
  bool _loading = false;
  String _message = '粘贴微助教签到链接或 openid，加载后即可提交签到。';

  @override
  void dispose() {
    _openidController.dispose();
    _longitudeController.dispose();
    _latitudeController.dispose();
    _consoleController.dispose();
    super.dispose();
  }

  Future<void> _loadSignPage() async {
    final input = _openidController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _message = '请输入微助教签到链接或 openid';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = '正在加载签到页...';
    });

    final signData = await WZJApi.loadSignData(input);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _signData = signData;
      _message = signData == null
          ? '加载失败，请确认链接或 openid 是否正确'
          : '已加载签到页，可直接提交签到';
      if (signData != null) {
        _openidController.text = signData.openid;
      }
    });
  }

  Future<void> _submitSignIn() async {
    final signData = _signData;
    if (signData == null) {
      setState(() {
        _message = '请先加载签到页';
      });
      return;
    }

    double? longitude;
    double? latitude;
    if (signData.applyGps) {
      longitude = double.tryParse(_longitudeController.text.trim());
      latitude = double.tryParse(_latitudeController.text.trim());
      if (longitude == null || latitude == null) {
        setState(() {
          _message = '当前签到需要经纬度，请先输入经度和纬度';
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _message = '正在提交签到...';
    });
    _consoleController.resetForPlatform(SignPlatformContext.weizhuojiao);

    final user = User(
      name: signData.openid,
      avatar: '',
      phone: '',
      uid: signData.openid,
      school: '',
      platform: 'weizhuojiao',
    );

    final gateResult = await SignNetworkGate().run<Map<String, dynamic>>(
      context: context,
      platformLabel: '微助教',
      user: user,
      console: _consoleController,
      action: () =>
          WZJApi.submitSign(signData, longitude: longitude, latitude: latitude),
    );

    if (!mounted) return;
    if (gateResult.skipped) {
      final reason = gateResult.reason ?? '用户跳过';
      await SignRecordStore().append(
        platform: '微助教',
        platformType: PlatformType.weizhuojiao,
        courseName: signData.courseId ?? '微助教签到',
        account: signData.openid,
        status: '失败',
        detail: reason,
      );
      setState(() {
        _loading = false;
        _message = reason;
      });
      return;
    }

    final result = gateResult.value ?? const <String, dynamic>{};
    final message = (result['message'] ?? '签到完成').toString();
    final success =
        result['success'] == true ||
        result['code'] == 0 ||
        message.contains('成功');
    _consoleController.add(
      platform: '微助教',
      accountName: user.name,
      accountId: user.uid,
      stage: success ? SignRunStage.signSuccess : SignRunStage.signFailure,
      message: message,
    );
    await SignRecordStore().append(
      platform: '微助教',
      platformType: PlatformType.weizhuojiao,
      courseName: signData.courseId ?? '微助教签到',
      account: signData.openid,
      status: success ? '成功' : '失败',
      detail: message,
    );

    setState(() {
      _loading = false;
      _message = message;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_message)));
    }
  }

  Widget _infoChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signData = _signData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('微助教'),
        backgroundColor: const Color(0xFF8E5C2C),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8E5C2C).withValues(alpha: 0.10),
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8E5C2C), Color(0xFFCD8B42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '微助教轻量工具',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '支持粘贴 openid 或签到链接，加载隐藏参数后提交一次签到。GPS 签到时需要手动输入经纬度。',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _openidController,
              decoration: InputDecoration(
                labelText: 'openid / 签到链接',
                hintText: '粘贴微助教签到页面链接或 openid',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '经度',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '纬度',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _loadSignPage,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('加载签到页'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _submitSignIn,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('提交签到'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const PlatformSignLogCard(
              platform: '微助教',
              platformType: PlatformType.weizhuojiao,
              title: '微助教签到日志',
              subtitle: '查看微助教签到结果和失败原因',
            ),
            const SizedBox(height: 16),
            SignRunConsolePanel(controller: _consoleController),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Text(
                _message,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            if (signData != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '签到信息',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      children: [
                        _infoChip('openid', signData.openid),
                        _infoChip('courseId', signData.courseId ?? '未知'),
                        _infoChip('signId', signData.signId ?? '未知'),
                        _infoChip('GPS', signData.applyGps ? '需要' : '不需要'),
                        _infoChip('字段数', signData.fields.length.toString()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('提交时会自动回填表单隐藏字段；如果需要 GPS 签到，请先输入经纬度。'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
