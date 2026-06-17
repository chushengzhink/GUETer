class DiagnosticIssue {
  const DiagnosticIssue({
    required this.id,
    required this.title,
    required this.severity,
    required this.description,
    required this.actionLabel,
  });

  final String id;
  final String title;
  final DiagnosticSeverity severity;
  final String description;
  final String actionLabel;
}

enum DiagnosticSeverity { info, warning, error }

class DiagnosticsService {
  const DiagnosticsService();

  List<DiagnosticIssue> buildIssues({
    required List<Map<String, String>> logs,
    required bool? notificationAllowed,
    required bool hasNetwork,
    required bool hasCurrentAccount,
    required bool localTransferRunning,
  }) {
    final issues = <DiagnosticIssue>[];
    final failureCount = logs.where((log) => log['level'] == 'error').length;
    final retryableCount = logs
        .where((log) => log['retryable'] == 'true')
        .length;
    final joined = logs
        .map((log) => '${log['platform'] ?? ''} ${log['message'] ?? ''}')
        .join('\n')
        .toLowerCase();
    final staleCacheCount = logs
        .where((log) => (log['staleReason'] ?? '').isNotEmpty)
        .length;
    final authFailureCount = logs
        .where((log) => log['failureCategory'] == 'auth')
        .length;
    final rateLimitedCount = logs
        .where((log) => log['failureCategory'] == 'rateLimited')
        .length;
    final schemaFailureCount = logs
        .where(
          (log) =>
              log['failureCategory'] == 'schema' ||
              log['failureCategory'] == 'empty',
        )
        .length;

    if (!hasNetwork) {
      issues.add(
        const DiagnosticIssue(
          id: 'network',
          title: '网络不可用',
          severity: DiagnosticSeverity.error,
          description: '当前没有可用网络连接，请切换网络后重新检测。',
          actionLabel: '重新检测网络',
        ),
      );
    }
    if (notificationAllowed == false) {
      issues.add(
        const DiagnosticIssue(
          id: 'notification',
          title: '通知权限关闭',
          severity: DiagnosticSeverity.warning,
          description: '待办提醒和重要失败通知可能无法显示。',
          actionLabel: '打开权限设置',
        ),
      );
    }
    if (!hasCurrentAccount) {
      issues.add(
        const DiagnosticIssue(
          id: 'account',
          title: '未选择当前账号',
          severity: DiagnosticSeverity.warning,
          description: '平台接口需要先在账号页选择有效账号。',
          actionLabel: '去重新登录',
        ),
      );
    }
    if (failureCount >= 3 || retryableCount >= 3) {
      issues.add(
        DiagnosticIssue(
          id: 'request-failures',
          title: '平台接口失败较多',
          severity: DiagnosticSeverity.warning,
          description: '最近有 $failureCount 个失败请求，其中 $retryableCount 个可能可重试。',
          actionLabel: '刷新状态',
        ),
      );
    }
    if (staleCacheCount > 0) {
      issues.add(
        DiagnosticIssue(
          id: 'platform-cache-fallback',
          title: '\u5e73\u53f0\u63a5\u53e3\u5df2\u4f7f\u7528\u65e7\u7f13\u5b58',
          severity: DiagnosticSeverity.info,
          description:
              '\u6700\u8fd1\u6709 $staleCacheCount \u6b21\u8bf7\u6c42\u5728\u7f51\u7edc\u6ce2\u52a8\u6216\u9650\u6d41\u65f6\u8fd4\u56de\u4e86\u672c\u5730\u65e7\u7f13\u5b58\uff0c\u9875\u9762\u6570\u636e\u53ef\u7528\u4f46\u53ef\u80fd\u4e0d\u662f\u6700\u65b0\u3002',
          actionLabel: '\u7f51\u7edc\u7a33\u5b9a\u540e\u5237\u65b0',
        ),
      );
    }
    if (authFailureCount > 0) {
      issues.add(
        const DiagnosticIssue(
          id: 'platform-auth-failure',
          title: '\u5e73\u53f0\u767b\u5f55\u6001\u5931\u6548',
          severity: DiagnosticSeverity.error,
          description:
              '\u8bf7\u6c42\u5206\u7c7b\u663e\u793a\u6388\u6743\u5931\u6548\uff0c\u5efa\u8bae\u91cd\u65b0\u767b\u5f55\u5bf9\u5e94\u5e73\u53f0\u3002',
          actionLabel: '\u91cd\u65b0\u767b\u5f55',
        ),
      );
    }
    if (rateLimitedCount > 0) {
      issues.add(
        const DiagnosticIssue(
          id: 'platform-rate-limited',
          title: '\u5e73\u53f0\u53ef\u80fd\u6b63\u5728\u9650\u6d41',
          severity: DiagnosticSeverity.warning,
          description:
              '\u8bf7\u6c42\u5206\u7c7b\u663e\u793a\u9650\u6d41\uff0c\u5efa\u8bae\u51cf\u5c11\u9891\u7e41\u5237\u65b0\uff0c\u7a0d\u540e\u518d\u8bd5\u3002',
          actionLabel: '\u7a0d\u540e\u5237\u65b0',
        ),
      );
    }
    if (schemaFailureCount > 0) {
      issues.add(
        const DiagnosticIssue(
          id: 'platform-schema-failure',
          title: '\u5e73\u53f0\u8fd4\u56de\u7ed3\u6784\u5f02\u5e38',
          severity: DiagnosticSeverity.warning,
          description:
              '\u68c0\u6d4b\u5230\u63a5\u53e3\u8fd4\u56de\u7ed3\u6784\u6216\u7a7a\u54cd\u5e94\u5f02\u5e38\uff0c\u53ef\u80fd\u662f\u5e73\u53f0\u6539\u7248\u6216\u767b\u5f55\u6001\u5f02\u5e38\u3002',
          actionLabel: '\u67e5\u770b\u65e5\u5fd7',
        ),
      );
    }
    if (joined.contains('401') ||
        joined.contains('cookie') ||
        joined.contains('credential')) {
      issues.add(
        const DiagnosticIssue(
          id: 'credential',
          title: '登录态可能失效',
          severity: DiagnosticSeverity.error,
          description: '检测到授权或 Cookie 相关错误，建议重新登录对应平台。',
          actionLabel: '重新登录',
        ),
      );
    }
    if (joined.contains('openlist')) {
      issues.add(
        const DiagnosticIssue(
          id: 'openlist',
          title: '云盘请求需要检查',
          severity: DiagnosticSeverity.warning,
          description: '云盘连接或权限异常时，可刷新云盘会话并检查当前账号。',
          actionLabel: '打开云盘',
        ),
      );
    }
    if (!localTransferRunning && joined.contains('local')) {
      issues.add(
        const DiagnosticIssue(
          id: 'local-transfer',
          title: '局域网发现未运行',
          severity: DiagnosticSeverity.info,
          description: '需要传输文件时可重新打开局域网快传并启动发现。',
          actionLabel: '打开局域网快传',
        ),
      );
    }
    return _deduplicate(issues);
  }

  List<DiagnosticIssue> _deduplicate(List<DiagnosticIssue> issues) {
    final seen = <String>{};
    return issues.where((issue) => seen.add(issue.id)).toList(growable: false);
  }
}
