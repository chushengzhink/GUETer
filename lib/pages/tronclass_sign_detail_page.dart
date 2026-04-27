import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/course.dart';
import '../models/active.dart';
import '../utils/encrypt.dart';

class TronclassSignDetailPage extends StatefulWidget {
  final Active activity;

  const TronclassSignDetailPage({super.key, required this.activity});

  @override
  State<TronclassSignDetailPage> createState() => _TronclassSignDetailPageState();
}

class _TronclassSignDetailPageState extends State<TronclassSignDetailPage> {
  bool _isSigning = false;
  String? _resultMessage;
  bool? _signSuccess;

  final TextEditingController _numberCodeController = TextEditingController();

  @override
  void dispose() {
    _numberCodeController.dispose();
    super.dispose();
  }

  String get _signMode {
    return widget.activity.extras?['_mode'] ?? 'qrcode';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.name, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1DB6C2),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildSignArea(),
            if (_resultMessage != null) ...[
              const SizedBox(height: 16),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.activity.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (widget.activity.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.activity.description,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '签到ID: ${widget.activity.id}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignArea() {
    switch (_signMode) {
      case 'number':
        return _buildNumberSignArea();
      case 'radar':
        return _buildRadarSignArea();
      case 'qrcode':
      default:
        return _buildQrCodeSignArea();
    }
  }

  Widget _buildNumberSignArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数字签到码',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numberCodeController,
              decoration: const InputDecoration(
                labelText: '请输入签到码',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dialpad),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSigning ? null : _performNumberSign,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB6C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSigning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('提交签到', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarSignArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '雷达签到',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '雷达签到需要获取您的位置信息',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSigning ? null : _performRadarSign,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB6C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSigning
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('开始签到', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCodeSignArea() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '二维码签到',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '请扫描教师展示的二维码进行签到',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('二维码扫描功能开发中')),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('扫描二维码', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB6C2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      color: _signSuccess == true ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _signSuccess == true ? Icons.check_circle : Icons.error,
              color: _signSuccess == true ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _resultMessage!,
                style: TextStyle(
                  color: _signSuccess == true ? Colors.green[900] : Colors.red[900],
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performNumberSign() async {
    final code = _numberCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入签到码')),
      );
      return;
    }

    setState(() {
      _isSigning = true;
      _resultMessage = null;
      _signSuccess = null;
    });

    try {
      final result = await TCCourseApi.sign(
        widget.activity.id,
        mode: 'number',
        numberCode: code,
      );

      if (!mounted) return;

      setState(() {
        _signSuccess = result['ok'] == true;
        _resultMessage = result['message'] ?? (_signSuccess! ? '签到成功' : '签到失败');
        _isSigning = false;
      });

      if (_signSuccess!) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signSuccess = false;
        _resultMessage = '签到失败: $e';
        _isSigning = false;
      });
    }
  }

  Future<void> _performRadarSign() async {
    setState(() {
      _isSigning = true;
      _resultMessage = null;
      _signSuccess = null;
    });

    try {
      // 模拟位置（实际应用中应使用真实位置）
      final result = await TCCourseApi.sign(
        widget.activity.id,
        mode: 'radar',
        radarLatitude: 25.2916,
        radarLongitude: 110.3397,
        radarAccuracy: 10.0,
      );

      if (!mounted) return;

      setState(() {
        _signSuccess = result['ok'] == true;
        _resultMessage = result['message'] ?? (_signSuccess! ? '签到成功' : '签到失败');
        _isSigning = false;
      });

      if (_signSuccess!) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signSuccess = false;
        _resultMessage = '签到失败: $e';
        _isSigning = false;
      });
    }
  }
}
