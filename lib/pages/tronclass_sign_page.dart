import 'package:flutter/material.dart';
import '../api/tronclass_sign_api.dart';
import '../models/active.dart';
import 'tronclass_sign_detail_page.dart';

class TronclassSignPage extends StatefulWidget {
  const TronclassSignPage({super.key});

  @override
  State<TronclassSignPage> createState() => _TronclassSignPageState();
}

class _TronclassSignPageState extends State<TronclassSignPage> {
  List<Active> _signActivities = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSignActivities();
  }

  Future<void> _loadSignActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await TronclassSignApi.getRollcalls();
      final data = response.data;

      if (!mounted) return;

      if (data == null || data['rollcalls'] is! List) {
        setState(() {
          _signActivities = [];
        });
        return;
      }

      final List<dynamic> rollcalls = data['rollcalls'];
      final List<Active> activities = [];

      for (final item in rollcalls) {
        if (item is! Map<String, dynamic>) continue;

        final rollcallId = (item['rollcall_id'] ?? item['id'] ?? '').toString();
        if (rollcallId.isEmpty) continue;

        final title = (item['course_title'] ?? '课堂签到').toString();
        final description =
            (item['class_name'] ?? item['created_by_name'] ?? '').toString();

        final signTypeIndex =
            int.tryParse((item['sign_type'] ?? 0).toString()) ?? 0;
        final bool signed = _detectSigned(item);
        final String mode = _detectSignMode(item);

        final rollcallStatus = (item['rollcall_status'] ?? '')
            .toString()
            .toLowerCase();
        final bool isExpired = item['is_expired'] == true;
        final bool isOpenByStatus =
            rollcallStatus == 'in_progress' ||
            rollcallStatus == 'open' ||
            rollcallStatus == 'opened';
        final bool open = !isExpired && isOpenByStatus;

        activities.add(
          Active(
            type: 2,
            id: rollcallId,
            name: title,
            description: description,
            startTime: 0,
            url: '',
            status: open,
            extras: {...item, '_signed': signed, '_open': open, '_mode': mode},
            signType: getSignTypeFromIndex(signTypeIndex),
          ),
        );
      }

      activities.sort((a, b) => b.id.compareTo(a.id));

      setState(() {
        _signActivities = activities;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '加载失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _detectSigned(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString().toLowerCase();
    if (status == 'on_call_fine' || status == 'present' || status == 'late') {
      return true;
    }
    return false;
  }

  String _detectSignMode(Map<String, dynamic> item) {
    final isNumber = item['is_number'] == true;
    if (isNumber) return 'number';

    final isRadar = item['is_radar'] == true;
    if (isRadar) return 'radar';

    return 'qrcode';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('畅课签到', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1DB6C2),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSignActivities,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSignActivities,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_signActivities.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadSignActivities,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      '目前尚未开放签到',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '老师说要签到？下拉刷新试试吧',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSignActivities,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _signActivities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildSignCard(_signActivities[index]);
        },
      ),
    );
  }

  Widget _buildSignCard(Active activity) {
    final extras = activity.extras;
    final mode = extras['_mode'] ?? 'qrcode';
    final signed = extras['_signed'] == true;
    final open = extras['_open'] == true;

    Color modeColor;
    IconData modeIcon;
    String modeText;

    switch (mode) {
      case 'number':
        modeColor = const Color(0xFF5ABBC6);
        modeIcon = Icons.dialpad;
        modeText = '数字点名';
        break;
      case 'radar':
        modeColor = const Color(0xFF5B90EF);
        modeIcon = Icons.radar;
        modeText = '雷达点名';
        break;
      default:
        modeColor = const Color(0xFF74BC49);
        modeIcon = Icons.qr_code;
        modeText = '二维码点名';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: open ? () => _navigateToSignDetail(activity) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activity.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (signed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '已签到',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                ],
              ),
              if (activity.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: modeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(modeIcon, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          modeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!open)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '已结束',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSignDetail(Active activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TronclassSignDetailPage(activity: activity),
      ),
    ).then((_) => _loadSignActivities());
  }
}
