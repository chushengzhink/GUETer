import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';

import '../api/tronclass_sign_api.dart';
import '../utils/coord_transform.dart';
import 'widget/baidu_map.dart';
import 'widget/tronclass_liquid_glass.dart';

enum _RadarSignState { radar, success, failure }

class TronclassRadarSignPage extends StatefulWidget {
  const TronclassRadarSignPage({
    super.key,
    required this.rollcallId,
    this.activityName,
  });

  final String rollcallId;
  final String? activityName;

  @override
  State<TronclassRadarSignPage> createState() => _TronclassRadarSignPageState();
}

class _TronclassRadarSignPageState extends State<TronclassRadarSignPage>
    with SingleTickerProviderStateMixin {
  _RadarSignState _currentState = _RadarSignState.radar;
  bool _isScanning = false;
  String _errorMessage = '';
  late final AnimationController _radarAnimationController;
  late final Animation<double> _radarRotation;

  @override
  void initState() {
    super.initState();
    _radarAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _radarRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _radarAnimationController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _radarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _openLocationPicker() async {
    BMFCoordinate? selectedCoordinate;
    String? selectedAddress;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pickerContext) => StatefulBuilder(
          builder: (context, setPickerState) {
            final locationText = selectedCoordinate == null
                ? '地图会优先使用百度定位结果，也可以手动选点微调。'
                : '${(selectedAddress == null || selectedAddress!.trim().isEmpty) ? '地图选点' : selectedAddress!.trim()}\n'
                      '纬度：${selectedCoordinate!.latitude.toStringAsFixed(6)}  经度：${selectedCoordinate!.longitude.toStringAsFixed(6)}';

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  Positioned.fill(
                    child: BaiduMapWidget(
                      initialCoordinate: selectedCoordinate,
                      initialAddress: selectedAddress,
                      autoLocateOnInit: true,
                      onLocationSelectedWithAddress: (coordinate, address) {
                        setPickerState(() {
                          selectedCoordinate = coordinate;
                          selectedAddress = address;
                        });
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.22),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TronclassGlassCard(
                                padding: EdgeInsets.zero,
                                borderRadius: BorderRadius.circular(999),
                                boxShadows: const [],
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '选择雷达签到位置',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TronclassGlassCard(
                            tintColor: const Color(0x33FFFFFF),
                            boxShadows: const [],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const TronclassSectionHeader(
                                  title: '位置确认',
                                  subtitle: '保留原坐标转换和提交流程，仅更新信息层布局。',
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  locationText,
                                  style: const TextStyle(
                                    color: TronclassGlassPalette.text,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TronclassGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '确认后立即提交签到',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: TronclassGlassPalette.text,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '若无法定位到准确位置，请在地图上继续微调后再提交。',
                                  style: TextStyle(
                                    color: TronclassGlassPalette.mutedText,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: selectedCoordinate == null
                                        ? null
                                        : () async {
                                            await _performRollcallWithLocation(
                                              latitude:
                                                  selectedCoordinate!.latitude,
                                              longitude:
                                                  selectedCoordinate!.longitude,
                                              accuracy: 20,
                                            );
                                            if (pickerContext.mounted) {
                                              Navigator.pop(pickerContext);
                                            }
                                          },
                                    style: tronclassPrimaryButtonStyle(context),
                                    child: const Text('确认位置并签到'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _performRollcallWithLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
    });

    try {
      final gcj02 = CoordTransform.bd09ToGcj02(latitude, longitude);
      final response = await TronclassSignApi.signRadar(
        rollcallId: widget.rollcallId,
        deviceId: const Uuid().v4(),
        latitude: gcj02[0],
        longitude: gcj02[1],
        accuracy: accuracy,
      );

      if (!mounted) return;
      if (TronclassSignApi.isSignSuccess(response)) {
        setState(() {
          _currentState = _RadarSignState.success;
        });
      } else {
        setState(() {
          _errorMessage = TronclassSignApi.getSignMessage(response.data);
          _currentState = _RadarSignState.failure;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '签到失败，请重试';
        _currentState = _RadarSignState.failure;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _restartRadar() {
    setState(() {
      _currentState = _RadarSignState.radar;
      _errorMessage = '';
    });
  }

  (String, Color, IconData) _stateData() {
    switch (_currentState) {
      case _RadarSignState.success:
        return (
          '签到成功',
          TronclassGlassPalette.success,
          Icons.check_circle_rounded,
        );
      case _RadarSignState.failure:
        return ('签到失败', TronclassGlassPalette.danger, Icons.error_rounded);
      case _RadarSignState.radar:
        return (
          _isScanning ? '正在提交' : '等待选点',
          _isScanning
              ? TronclassGlassPalette.warning
              : TronclassGlassPalette.accent,
          _isScanning ? Icons.hourglass_top_rounded : Icons.radar_rounded,
        );
    }
  }

  Widget _buildRadarVisual() {
    return Center(
      child: TronclassGlassCard(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 320,
          height: 320,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final diameter in [280.0, 210.0, 140.0])
                Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: TronclassGlassPalette.accent.withValues(
                        alpha: diameter == 140 ? 0.28 : 0.18,
                      ),
                    ),
                    gradient: RadialGradient(
                      colors: [
                        TronclassGlassPalette.accent.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              AnimatedBuilder(
                animation: _radarRotation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _radarRotation.value * 2 * math.pi,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            TronclassGlassPalette.accent.withValues(alpha: 0),
                            TronclassGlassPalette.accent.withValues(
                              alpha: 0.08,
                            ),
                            TronclassGlassPalette.mint.withValues(alpha: 0.42),
                            TronclassGlassPalette.accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      TronclassGlassPalette.accent.withValues(alpha: 0.18),
                      TronclassGlassPalette.mint.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/rollcalls_icon-radar.svg',
                    width: 54,
                    height: 54,
                    colorFilter: const ColorFilter.mode(
                      TronclassGlassPalette.accentDeep,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(bool success) {
    return Center(
      child: TronclassGlassCard(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TronclassGlassPill(
              label: success ? '签到成功' : '签到失败',
              icon: success ? Icons.check_rounded : Icons.close_rounded,
              color: success
                  ? TronclassGlassPalette.success
                  : TronclassGlassPalette.danger,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 200,
              child: Image.asset(
                success
                    ? 'assets/images/radar-rollcall-success.png'
                    : 'assets/images/radar-rollcall-failed.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              success ? '雷达签到已完成' : '本次签到未通过',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: TronclassGlassPalette.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              success
                  ? DateTime.now().toString().substring(0, 16)
                  : (_errorMessage.isEmpty ? '签到失败，点名已结束' : _errorMessage),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                color: TronclassGlassPalette.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    switch (_currentState) {
      case _RadarSignState.radar:
        return TronclassGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择地图位置后提交',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: TronclassGlassPalette.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isScanning
                    ? '正在按照当前选点位置提交签到，请稍候。'
                    : '雷达签到会沿用当前定位提交逻辑，页面仅更新信息层与结果卡。',
                style: const TextStyle(
                  color: TronclassGlassPalette.mutedText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isScanning ? null : _openLocationPicker,
                  style: tronclassPrimaryButtonStyle(context),
                  icon: Icon(
                    _isScanning
                        ? Icons.hourglass_top_rounded
                        : Icons.place_rounded,
                  ),
                  label: Text(_isScanning ? '提交中...' : '选择位置并签到'),
                ),
              ),
            ],
          ),
        );
      case _RadarSignState.success:
        return TronclassGlassCard(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: tronclassPrimaryButtonStyle(
                context,
                color: TronclassGlassPalette.success,
              ),
              child: const Text('完成'),
            ),
          ),
        );
      case _RadarSignState.failure:
        return TronclassGlassCard(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                _restartRadar();
                _openLocationPicker();
              },
              style: tronclassPrimaryButtonStyle(
                context,
                color: TronclassGlassPalette.danger,
              ),
              child: const Text('重新选择位置'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateData = _stateData();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: TronclassGlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TronclassGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TronclassGlassCard(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(999),
                            boxShadows: const [],
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '雷达签到',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: TronclassGlassPalette.text,
                              ),
                            ),
                          ),
                          TronclassGlassPill(
                            label: stateData.$1,
                            icon: stateData.$3,
                            color: stateData.$2,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '保留原位置选点、坐标转换和提交链路，只把状态与反馈整理成统一的 Liquid Glass 界面。',
                        style: TextStyle(
                          color: TronclassGlassPalette.mutedText,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: tronclassMotionDuration(context),
                    child: switch (_currentState) {
                      _RadarSignState.radar => _buildRadarVisual(),
                      _RadarSignState.success => _buildResultCard(true),
                      _RadarSignState.failure => _buildResultCard(false),
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildBottomPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
