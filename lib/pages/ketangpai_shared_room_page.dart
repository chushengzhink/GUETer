import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/kt_sign.dart';
import '../session/account.dart';
import 'widget/scan.dart';

class KetangpaiSharedRoomPage extends StatefulWidget {
  const KetangpaiSharedRoomPage({super.key});

  @override
  State<KetangpaiSharedRoomPage> createState() => _KetangpaiSharedRoomPageState();
}

class _KetangpaiSharedRoomPageState extends State<KetangpaiSharedRoomPage> {
  static const String _wsUrl = 'ws://172.16.0.108:9745/connection';

  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  bool _connected = false;
  int _onlineUsers = 0;
  String _lastText = '扫码结果';

  String get _token {
    final currentId = AccountManager.currentSessionId;
    if (currentId == null || currentId.isEmpty) {
      return '';
    }
    return AccountManager.getAccountById(currentId)?.token ?? '';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  void _connect() {
    if (_connected) {
      return;
    }

    try {
      final channel = IOWebSocketChannel.connect(_wsUrl);
      _channel = channel;
      setState(() {
        _connected = true;
      });
      _subscription = channel.stream.listen(
        (event) async {
          try {
            final message = jsonDecode(event as String) as Map<String, dynamic>;
            final type = message['type']?.toString() ?? '';
            final content = message['content']?.toString() ?? '';
            if (type == 'sign' && content.isNotEmpty && _token.isNotEmpty) {
              await KTSignApi.scanToSign(content, _token);
            } else if (type == 'onlineNums') {
              setState(() {
                _onlineUsers = int.tryParse(content) ?? 0;
              });
            } else if (type == 'judge_status' && content == '1') {
              setState(() {
                _connected = true;
              });
            }
            setState(() {
              _lastText = content.isEmpty ? _lastText : content;
            });
          } catch (_) {}
        },
        onDone: () {
          setState(() {
            _connected = false;
            _onlineUsers = 0;
          });
          _reconnect();
        },
        onError: (_) {
          setState(() {
            _connected = false;
            _onlineUsers = 0;
          });
          _reconnect();
        },
      );
    } catch (_) {
      setState(() {
        _connected = false;
      });
    }
  }

  void _reconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) {
        return;
      }
      _connect();
    });
  }

  Future<void> _scanAndSend() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (result == null || result.isEmpty) {
      return;
    }
    setState(() {
      _lastText = result;
    });
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({'content': result, 'type': 'sign'}));
    }
    if (_token.isNotEmpty) {
      await KTSignApi.scanToSign(result, _token);
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    _channel?.sink.add(text);
    setState(() {
      _lastText = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共享签到房间'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipOval(
                    child: Container(
                      width: 20,
                      height: 20,
                      color: _connected ? Colors.greenAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('连接状态: ${_connected ? '正常连接' : '未连接'}', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _connect,
                    icon: const Icon(Icons.refresh_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text('在线人数: $_onlineUsers', style: const TextStyle(fontSize: 20)),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _scanAndSend,
                child: const Text('点击扫码'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_lastText),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: TextField(controller: _controller),
                  ),
                  ElevatedButton(
                    onPressed: _sendMessage,
                    child: const Text('发送消息'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
