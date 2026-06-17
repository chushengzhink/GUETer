import 'package:flutter/material.dart';

import '../platform.dart';
import '../services/session_health_service.dart';

class SessionHealthBanner extends StatelessWidget {
  const SessionHealthBanner({
    super.key,
    required this.issue,
    required this.totalCount,
    required this.onReLogin,
    required this.onDismiss,
  });

  final SessionHealthIssue issue;
  final int totalCount;
  final VoidCallback onReLogin;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extraCount = totalCount - 1;
    final extraText = extraCount > 0 ? '，另有 $extraCount 个账号需要处理' : '';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          elevation: 10,
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_platformLabel(issue.platform)} · ${issue.accountName} 登录态失效，请重新登录$extraText',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: onReLogin, child: const Text('重新登录')),
                IconButton(
                  tooltip: '暂不提醒',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                  color: theme.colorScheme.onErrorContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _platformLabel(PlatformType platform) {
    return switch (platform) {
      PlatformType.chaoxing => '学习通',
      PlatformType.rainClassroom => '雨课堂',
      PlatformType.tronclass => '畅课',
      PlatformType.ketangpai => '课堂派',
      PlatformType.weizhuojiao => '微助教',
    };
  }
}
