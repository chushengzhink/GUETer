import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GuetEmailApplyPage extends StatelessWidget {
  const GuetEmailApplyPage({super.key});

  static const String _targetUrl = 'https://www.guet.edu.cn/xjzx/main.htm';

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _targetUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已经复制到粘贴板，请在电脑端操作并找到学生邮箱申请入口')),
    );
  }

  Widget _buildRecommendCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: iconBg,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('桂电邮箱申请入口')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
            ),
            child: const Text(
              '温馨提示，邮箱申请表在手机端无法正常显示完全，请点击下方复制链接后在电脑浏览器界面进行操作。',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _copyLink(context),
            icon: const Icon(Icons.content_copy_outlined),
            label: const Text('一键复制链接'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '推荐认证应用/网站',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _buildRecommendCard(
                    context: context,
                    icon: Icons.business_center_outlined,
                    iconBg: const Color(0xFF1274E7),
                    title: 'Microsoft 365 Education',
                    subtitle: '邮箱开通后可优先绑定校园教育订阅。',
                  ),
                  const SizedBox(height: 10),
                  _buildRecommendCard(
                    context: context,
                    icon: Icons.code_outlined,
                    iconBg: const Color(0xFF24292E),
                    title: 'GitHub Student Developer Pack（推荐，ai挺好用的）',
                    subtitle: '建议使用学校邮箱完成学生认证，获取开发权益。',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
