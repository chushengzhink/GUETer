import 'package:flutter/material.dart';

import '../pages/sign_records_page.dart';
import '../platform.dart';
import '../services/sign_platform_context.dart';
import '../session/sign_record_store.dart';

class PlatformSignLogCard extends StatefulWidget {
  const PlatformSignLogCard({
    super.key,
    required this.platform,
    this.platformType,
    this.title,
    this.subtitle,
  });

  final String platform;
  final PlatformType? platformType;
  final String? title;
  final String? subtitle;

  @override
  State<PlatformSignLogCard> createState() => _PlatformSignLogCardState();
}

class _PlatformSignLogCardState extends State<PlatformSignLogCard> {
  final SignRecordStore _store = SignRecordStore();
  Map<String, dynamic>? _latest;
  int _failureCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlatformSignLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.platform != widget.platform) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final platformContext = widget.platformType == null
        ? SignPlatformContext.tryParse(widget.platform)
        : SignPlatformContext.fromType(widget.platformType!);
    final records = await _store.loadForPlatform(
      platformContext?.platformKey ?? widget.platform,
    );
    if (!mounted) return;
    setState(() {
      _latest = records.isEmpty ? null : records.first;
      _failureCount = records
          .where((record) => (record['status'] ?? '').toString() != '成功')
          .length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = _latest;
    final status = latest?['status']?.toString();
    final course = latest?['courseName']?.toString();
    final account = latest?['account']?.toString();
    final ts = int.tryParse(latest?['timestamp']?.toString() ?? '');
    final time = ts == null
        ? '暂无记录'
        : _format(DateTime.fromMillisecondsSinceEpoch(ts));
    final ok = status == '成功';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final platformContext = widget.platformType == null
              ? SignPlatformContext.tryParse(widget.platform)
              : SignPlatformContext.fromType(widget.platformType!);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SignRecordsPage(
                initialPlatform:
                    platformContext?.platformKey ?? widget.platform,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (ok ? Colors.green : theme.colorScheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ok
                      ? Icons.check_circle_outline_rounded
                      : Icons.receipt_long_outlined,
                  color: ok ? Colors.green : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? '${widget.platform}签到日志',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _loading
                          ? '正在读取签到记录...'
                          : latest == null
                          ? (widget.subtitle ?? '点击查看该平台签到历史')
                          : '$time | ${account ?? '未知账号'} | ${course ?? '未知课程'} | ${status ?? '未知状态'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_failureCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '失败 $_failureCount',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(DateTime dateTime) {
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  }
}
