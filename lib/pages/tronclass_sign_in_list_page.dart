import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../api/tronclass_sign_api.dart';
import '../models/tronclass_rollcalls.dart';
import 'tronclass_number_sign_page.dart';
import 'tronclass_qr_sign_page.dart';
import 'tronclass_radar_sign_page.dart';
import 'widget/tronclass_liquid_glass.dart';

class TronclassSignInListPage extends StatefulWidget {
  const TronclassSignInListPage({super.key});

  @override
  State<TronclassSignInListPage> createState() =>
      _TronclassSignInListPageState();
}

class _TronclassSignInListPageState extends State<TronclassSignInListPage> {
  List<Rollcalls> _rollcalls = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<Rollcalls> get _activeRollcalls => _rollcalls
      .where((rollcall) => rollcall.isInProgress && !rollcall.isExpired)
      .toList();

  List<Rollcalls> get _historyRollcalls => _rollcalls
      .where((rollcall) => !_activeRollcalls.contains(rollcall))
      .toList();

  @override
  void initState() {
    super.initState();
    _loadRollcalls();
  }

  Future<void> _loadRollcalls() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await TronclassSignApi.getRollcalls();
      if (!mounted) return;
      setState(() {
        _rollcalls = response.rollcalls;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rollcalls = [];
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _openRollcall(Rollcalls rollcall) async {
    if (rollcall.isNumber && !rollcall.isRadar) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TronclassNumberSignPage(
            rollcallId: rollcall.rollcallId.toString(),
          ),
        ),
      );
      if (mounted) {
        await _loadRollcalls();
      }
      return;
    }

    if (rollcall.isRadar && !rollcall.isNumber) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TronclassRadarSignPage(
            rollcallId: rollcall.rollcallId.toString(),
          ),
        ),
      );
      if (mounted) {
        await _loadRollcalls();
      }
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TronclassQrSignPage(rollcallId: rollcall.rollcallId.toString()),
      ),
    );
    if (mounted) {
      await _loadRollcalls();
    }
  }

  _ModeData _modeData(Rollcalls rollcall) {
    if (rollcall.isNumber) {
      return const _ModeData(
        label: '数字签到',
        asset: 'assets/images/number_rollcalls.svg',
        color: TronclassGlassPalette.accent,
      );
    }
    if (rollcall.isRadar) {
      return const _ModeData(
        label: '雷达签到',
        asset: 'assets/images/rollcalls_icon-radar.svg',
        color: Color(0xFF5B90EF),
      );
    }
    return const _ModeData(
      label: '二维码签到',
      asset: 'assets/images/qr_rollcalls.svg',
      color: TronclassGlassPalette.success,
    );
  }

  (String, Color, IconData) _statusData(Rollcalls rollcall) {
    if (rollcall.status == 'on_call_fine') {
      return ('已签到', TronclassGlassPalette.success, Icons.check_circle_rounded);
    }
    if (rollcall.isExpired || !rollcall.isInProgress) {
      return ('已结束', TronclassGlassPalette.warning, Icons.schedule_rounded);
    }
    return ('进行中', TronclassGlassPalette.accentDeep, Icons.bolt_rounded);
  }

  Widget _buildSection(String title, String subtitle, List<Rollcalls> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TronclassSectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        ...items.map(
          (rollcall) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RollcallCard(
              rollcall: rollcall,
              modeData: _modeData(rollcall),
              statusData: _statusData(rollcall),
              onTap: () => _openRollcall(rollcall),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        TronclassGlassCard(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Image.asset('assets/images/rollcalls_empty.png'),
              ),
              const SizedBox(height: 18),
              const Text(
                '目前没有可处理的签到',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: TronclassGlassPalette.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage == null
                    ? '老师发起签到后，下拉刷新即可同步最新活动。'
                    : '获取签到列表失败：$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TronclassGlassPalette.mutedText,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('签到列表'),
        actions: [
          Tooltip(
            message: '刷新签到列表',
            child: IconButton(
              onPressed: _loadRollcalls,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: TronclassGlassBackground(
        child: RefreshIndicator(
          onRefresh: _loadRollcalls,
          child: _isLoading
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: const [SizedBox(height: 120), _LoadingCard()],
                )
              : _rollcalls.isEmpty
              ? _buildEmptyView()
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          TronclassGlassCard(
                            child: Row(
                              children: [
                                const TronclassGlassIconOrb(
                                  icon: Icons.layers_rounded,
                                  color: TronclassGlassPalette.accent,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '按状态分组展示',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: TronclassGlassPalette.text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '共 ${_rollcalls.length} 个签到活动，保留原进入逻辑与签到结果判断。',
                                        style: const TextStyle(
                                          color:
                                              TronclassGlassPalette.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildSection(
                            '正在进行',
                            '优先展示可立即处理的签到活动。',
                            _activeRollcalls,
                          ),
                          if (_activeRollcalls.isNotEmpty &&
                              _historyRollcalls.isNotEmpty)
                            const SizedBox(height: 12),
                          _buildSection(
                            '签到记录',
                            '包含已签到或已结束的活动。',
                            _historyRollcalls,
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ModeData {
  const _ModeData({
    required this.label,
    required this.asset,
    required this.color,
  });

  final String label;
  final String asset;
  final Color color;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return TronclassGlassCard(
      child: Column(
        children: const [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            '正在同步畅课签到列表',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: TronclassGlassPalette.text,
            ),
          ),
        ],
      ),
    );
  }
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TronclassGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 92,
              height: 108,
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
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: TronclassGlassPalette.text,
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
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: TronclassGlassPalette.mutedText.withValues(alpha: 0.8),
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
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
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
          Icon(icon, size: 14, color: TronclassGlassPalette.mutedText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: TronclassGlassPalette.mutedText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
