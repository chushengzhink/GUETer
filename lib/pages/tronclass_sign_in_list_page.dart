import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/active.dart';
import 'tronclass_qr_sign_page.dart';
import 'tronclass_number_sign_page.dart';
import 'tronclass_radar_sign_page.dart';

class TronclassSignInListPage extends StatelessWidget {
  final List<Active> activities;

  const TronclassSignInListPage({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('签到列表'),
        backgroundColor: const Color(0xFF1DB6C2),
        foregroundColor: Colors.white,
      ),
      body: activities.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '暂无签到活动',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                return _buildActivityCard(context, activity);
              },
            ),
    );
  }

  Widget _buildActivityCard(BuildContext context, Active activity) {
    final mode = activity.extras?['_mode']?.toString() ?? 'unknown';
    final signed = activity.extras?['_signed'] == true;
    final open = activity.status;

    IconData icon;
    Color color;
    String modeLabel;

    switch (mode.toLowerCase()) {
      case 'qrcode':
        icon = Icons.qr_code_scanner;
        color = const Color(0xFF00BBBD);
        modeLabel = '二维码签到';
        break;
      case 'number':
        icon = Icons.pin;
        color = const Color(0xFF59BE30);
        modeLabel = '数字签到';
        break;
      case 'radar':
        icon = Icons.location_on;
        color = const Color(0xFFFF6B6B);
        modeLabel = '位置签到';
        break;
      default:
        icon = Icons.check_circle_outline;
        color = Colors.grey;
        modeLabel = '签到';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: open && !signed
            ? () => _handleSignIn(context, activity, mode)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          modeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (signed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已签到',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (!open)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已结束',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (activity.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  activity.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleSignIn(BuildContext context, Active activity, String mode) {
    final rollcallId = activity.id;

    switch (mode.toLowerCase()) {
      case 'qrcode':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TronclassQrSignPage(
              rollcallId: rollcallId,
              activityName: activity.name,
            ),
          ),
        );
        break;
      case 'number':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TronclassNumberSignPage(
              rollcallId: rollcallId,
              activityName: activity.name,
            ),
          ),
        );
        break;
      case 'radar':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TronclassRadarSignPage(
              rollcallId: rollcallId,
              activityName: activity.name,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('不支持的签到类型')),
        );
    }
  }
}
