import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api/tronclass_sign_api.dart';
import '../api/platform_read_exception.dart';
import '../api/api_service.dart';
import '../models/tronclass_rollcalls.dart';
import '../session/sign_execution_context.dart';
import '../widgets/account_context_header.dart';
import 'tronclass_number_sign_page.dart';
import 'tronclass_qr_sign_page.dart';
import 'tronclass_radar_sign_page.dart';
import 'widget/tronclass_liquid_glass.dart';

class TronclassSignInListPage extends StatefulWidget {
  const TronclassSignInListPage({super.key, this.loadRollcalls});
  final Future<RollcallsResponse> Function()? loadRollcalls;

  @override
  State<TronclassSignInListPage> createState() =>
      _TronclassSignInListPageState();
}

class _TronclassSignInListPageState extends State<TronclassSignInListPage> {
  final _scroll = ScrollController();
  late final _identity = SignExecutionContext.capture();
  List<Rollcalls> _rollcalls = [];
  Future<void>? _pending;
  bool _loading = true;
  bool _opening = false;
  PlatformReadException? _error;
  DateTime? _updatedAt;

  bool _actionable(Rollcalls call) =>
      call.isInProgress && !call.isExpired && call.status != 'on_call_fine';
  List<Rollcalls> get _active => _rollcalls.where(_actionable).toList();
  List<Rollcalls> get _history =>
      _rollcalls.where((call) => !_actionable(call)).toList();
  bool get _sameIdentity => _identity.key == SignExecutionContext.capture().key;
  String _text(String zh, String en) => contextText(context, zh, en);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      _pending ??= _load().whenComplete(() => _pending = null);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_sameIdentity) {
        throw const PlatformReadException(PlatformReadFailure.auth);
      }
      final result = await _identity.run(
        widget.loadRollcalls ?? TronclassSignApi.getRollcalls,
      );
      if (!mounted) return;
      if (!_sameIdentity) {
        throw const PlatformReadException(PlatformReadFailure.auth);
      }
      setState(() {
        _rollcalls = result.rollcalls;
        _updatedAt = DateTime.now();
      });
    } catch (error) {
      ApiService.appendExternalConsoleLog('tronclass', 'rollcall list: $error');
      if (mounted) {
        setState(() {
          if (!_sameIdentity) _rollcalls = [];
          _error = PlatformReadException.from(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Rollcalls call) async {
    if (_opening || !_actionable(call) || !_sameIdentity) return;
    setState(() => _opening = true);
    try {
      final Widget page = call.isNumber && !call.isRadar
          ? TronclassNumberSignPage(rollcallId: '${call.rollcallId}')
          : call.isRadar && !call.isNumber
          ? TronclassRadarSignPage(rollcallId: '${call.rollcallId}')
          : TronclassQrSignPage(rollcallId: '${call.rollcallId}');
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      if (mounted) await _refresh();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  _ModeData _mode(Rollcalls call) {
    final scheme = Theme.of(context).colorScheme;
    if (call.mode == 'number') {
      return _ModeData(
        label: _text('数字签到', 'Code check-in'),
        asset: 'assets/images/number_rollcalls.svg',
        color: scheme.primary,
      );
    }
    if (call.mode == 'radar') {
      return _ModeData(
        label: _text('雷达签到', 'Radar check-in'),
        asset: 'assets/images/rollcalls_icon-radar.svg',
        color: scheme.tertiary,
      );
    }
    return _ModeData(
      label: _text('二维码签到', 'QR check-in'),
      asset: 'assets/images/qr_rollcalls.svg',
      color: scheme.secondary,
    );
  }

  (String, Color, IconData) _status(Rollcalls call) {
    final colors = Theme.of(context).colorScheme;
    if (call.status == 'on_call_fine') {
      return (
        _text('已签到', 'Checked in'),
        colors.secondary,
        Icons.check_circle_outline,
      );
    }
    if (!_actionable(call)) {
      return (_text('已结束', 'Ended'), colors.onSurfaceVariant, Icons.schedule);
    }
    return (_text('进行中', 'In progress'), colors.primary, Icons.bolt);
  }

  Widget _section(String title, List<Rollcalls> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (items.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '$title · ${items.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final call in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RollcallCard(
              rollcall: call,
              modeData: _mode(call),
              statusData: _status(call),
              onTap: !_opening && _actionable(call) ? () => _open(call) : null,
            ),
          ),
      ],
    ],
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Image.asset(
          'assets/images/rollcalls_empty.png',
          height: 120,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            _error == null
                ? _text('暂无签到', 'No check-ins')
                : _text('签到列表加载失败', 'Could not load check-ins'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _error?.message(
                english: Localizations.localeOf(context).languageCode == 'en',
              ) ??
              _text(
                '老师发起签到后，下拉刷新即可查看。',
                'Pull to refresh after your teacher starts a check-in.',
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
          label: Text(_text('重试 / 刷新', 'Retry / refresh')),
        ),
        if (_error?.kind == PlatformReadFailure.auth)
          TextButton(
            onPressed: () =>
                selectAccountFromSheet(context, platform: _identity.platform),
            child: Text(_text('重新登录', 'Sign in again')),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_loading && _rollcalls.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_text('正在获取签到列表…', 'Loading check-ins…')),
                ],
              ),
            )
          else if (_rollcalls.isEmpty)
            _empty()
          else ...[
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_updatedAt != null)
              Text(
                _text('更新于 ', 'Updated ') +
                    MaterialLocalizations.of(
                      context,
                    ).formatTimeOfDay(TimeOfDay.fromDateTime(_updatedAt!)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(
                        '刷新失败，已保留原有签到列表',
                        'Refresh failed. Previous check-ins retained.',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    Text(
                      _error!.message(
                        english:
                            Localizations.localeOf(context).languageCode ==
                            'en',
                      ),
                    ),
                    TextButton(
                      onPressed: _loading ? null : _refresh,
                      child: Text(_text('重试', 'Retry')),
                    ),
                  ],
                ),
              ),
            _section(_text('正在进行', 'In progress'), _active),
            _section(_text('签到记录', 'History'), _history),
          ],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(_text('签到列表', 'Check-ins')),
        actions: [
          IconButton(
            tooltip: _text('刷新签到列表', 'Refresh check-ins'),
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Theme.of(context).brightness == Brightness.dark
          ? ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: body,
            )
          : TronclassGlassBackground(child: body),
    );
  }
}

class _ModeData {
  const _ModeData({
    required this.label,
    required this.asset,
    required this.color,
  });
  final String label, asset;
  final Color color;
}

class _RollcallCard extends StatelessWidget {
  const _RollcallCard({
    required this.rollcall,
    required this.modeData,
    required this.statusData,
    required this.onTap,
  });

  final Rollcalls rollcall;
  final _ModeData modeData;
  final (String, Color, IconData) statusData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TronclassGlassCard(
      onTap: onTap,
      tintColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainer
          : null,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 48,
              height: 56,
              color: modeData.color.withValues(alpha: 0.08),
              child: Image.asset(
                'assets/images/rollcalls_item.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rollcall.courseTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GlassLabel(
                      text: modeData.label,
                      color: modeData.color,
                      icon: SvgPicture.asset(
                        modeData.asset,
                        width: 12,
                        height: 12,
                        colorFilter: ColorFilter.mode(
                          modeData.color,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    _GlassLabel(
                      text: statusData.$1,
                      color: statusData.$2,
                      icon: Icon(statusData.$3, size: 14, color: statusData.$2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (rollcall.createdByName.isNotEmpty)
                  _MetaLine(
                    icon: Icons.person_outline_rounded,
                    text: rollcall.createdByName,
                  ),
                if (rollcall.departmentName.isNotEmpty)
                  _MetaLine(
                    icon: Icons.apartment_rounded,
                    text: rollcall.departmentName,
                  ),
                if (rollcall.className.isNotEmpty)
                  _MetaLine(
                    icon: Icons.groups_rounded,
                    text: rollcall.className,
                  ),
                if (rollcall.rollcallTime.isNotEmpty)
                  _MetaLine(
                    icon: Icons.schedule_rounded,
                    text: rollcall.rollcallTime,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            onTap == null
                ? Icons.lock_outline_rounded
                : Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
