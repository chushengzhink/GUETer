import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/course.dart';
import '../models/active.dart';
import '../models/course.dart';
import '../utils/tronclass_qr_parser.dart';
import 'widget/scan.dart';
import 'widget/baidu_map.dart';
import 'tronclass_sign_logs.dart';

class TronclassSignInPage extends StatefulWidget {
  final Course course;

  const TronclassSignInPage({super.key, required this.course});

  @override
  State<TronclassSignInPage> createState() => _TronclassSignInPageState();
}

class _TronclassSignInPageState extends State<TronclassSignInPage> {
  static const Color _tcPrimary = Color(0xFF1DB6C2);
  static const Color _tcSecondary = Color(0xFF0EA9C7);
  static const Color _tcBg = Color(0xFFF4FBFC);

  final TextEditingController _numberCodeController = TextEditingController();
  final TextEditingController _debugQrRawController = TextEditingController();
  final List<TronclassSignLogItem> _logs = [];
  final Set<String> _signedActivityIds = <String>{};
  List<Active> _activities = [];
  Active? _currentActivity;
  String _currentMode = 'unknown';
  String? _qrPayload;
  double? _radarLatitude;
  double? _radarLongitude;
  double? _radarAccuracy;
  String? _radarAddress;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _debugLocalMockMode = false;
  String _debugMode = 'qrcode';
  String _debugSelectedQrSample = 'json';
  String _listFilter = 'all';

  static const String _tcRadarLatitudeKey = 'tronclass_sign_radar_latitude';
  static const String _tcRadarLongitudeKey = 'tronclass_sign_radar_longitude';
  static const String _tcRadarAccuracyKey = 'tronclass_sign_radar_accuracy';
  static const String _tcRadarAddressKey = 'tronclass_sign_radar_address';

  final List<Map<String, String>> _debugQrSampleItems = const [
    {
      'id': 'json',
      'label': 'JSON 原文样例',
      'value': '{"rollcallId":123456,"data":"mock_data_token"}',
    },
    {
      'id': 'url_packed_json',
      'label': '/j?_p=... 样例',
      'value':
          'https://courses.guet.edu.cn/j?_p=%7B%22rollcallId%22%3A123456%2C%22data%22%3A%22mock_data_token%22%7D',
    },
    {
      'id': 'url_packed_p',
      'label': '/j?p=... 样例',
      'value':
          'https://courses.guet.edu.cn/j?p=4~123456%213~mock_data_token%21',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRadarUiPrefs();
    _loadActivities();
  }

  @override
  void dispose() {
    _numberCodeController.dispose();
    _debugQrRawController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
    });

    final activities = await TCCourseApi.getSignActivities(
      widget.course.courseId,
    );
    if (!mounted) return;

    final sortedActivities = List<Active>.from(activities)
      ..sort(_compareActivities);

    setState(() {
      _activities = sortedActivities;
      for (final active in sortedActivities) {
        if (_isAlreadySigned(active)) {
          _signedActivityIds.add(active.id);
        }
      }
      _currentActivity = _pickCurrentActivity(sortedActivities);
      _currentMode = _currentActivity?.extras['_mode']?.toString() ?? 'unknown';
      if (_currentMode != 'qrcode') {
        _qrPayload = null;
      }
      _isLoading = false;
    });
  }

  void _resetRadarSelection() {
    _radarLatitude = null;
    _radarLongitude = null;
    _radarAccuracy = null;
    _radarAddress = null;
  }

  void _resetInputsForMode(String mode) {
    if (mode != 'number') {
      _numberCodeController.clear();
    }
    if (mode != 'qrcode') {
      _qrPayload = null;
    }
  }

  String _numberCodeForCurrentMode() {
    return _currentMode == 'number' ? _numberCodeController.text.trim() : '';
  }

  String? _qrPayloadForCurrentMode() {
    return _currentMode == 'qrcode' ? _qrPayload : null;
  }

  bool _hasRadarSelection() {
    return _radarLatitude != null && _radarLongitude != null;
  }

  String? _validateCurrentSignInput() {
    switch (_currentMode) {
      case 'number':
        if (_numberCodeForCurrentMode().isEmpty) {
          return '请输入数字签到码';
        }
        return null;
      case 'qrcode':
        if (_qrPayload == null || _qrPayload!.isEmpty) {
          return '请先扫码获取二维码数据';
        }
        return null;
      case 'radar':
        if (!_hasRadarSelection()) {
          return '请先选择签到位置';
        }
        return null;
      default:
        return null;
    }
  }

  Future<void> _handleSignResult(
    Active active,
    Map<String, dynamic> result,
  ) async {
    if (!mounted) return;

    final ok = result['ok'] == true;
    final message = result['message'].toString();
    _addLog(active: active, success: ok, message: message);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (ok) {
      setState(() {
        _signedActivityIds.add(active.id);
      });
    }

    if (!_debugLocalMockMode) {
      await _loadActivities();
    }
  }

  Future<void> _applyRadarSelection(
    BMFCoordinate coordinate, {
    String? address,
    double accuracy = 20,
  }) async {
    _radarLatitude = coordinate.latitude;
    _radarLongitude = coordinate.longitude;
    _radarAccuracy = accuracy;
    _radarAddress = (address == null || address.trim().isEmpty)
        ? '地图选点'
        : address.trim();
    await _saveRadarUiPrefs();
  }

  Future<void> _clearRadarSelection() async {
    _resetRadarSelection();
    await _saveRadarUiPrefs();
    if (!mounted) return;
    setState(() {});
  }

  String _radarSelectionSummary() {
    if (_radarLatitude == null || _radarLongitude == null) {
      return '尚未选择位置';
    }

    final address = _radarAddress?.trim().isNotEmpty == true
        ? _radarAddress!.trim()
        : '上次使用的百度定位';
    final accuracyText = _radarAccuracy == null
        ? ''
        : '，精度约 ${_radarAccuracy!.toStringAsFixed(0)} 米';
    return '$address\n纬度：${_radarLatitude!.toStringAsFixed(6)}，经度：${_radarLongitude!.toStringAsFixed(6)}$accuracyText';
  }

  Future<void> _loadRadarUiPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble(_tcRadarLatitudeKey);
    final longitude = prefs.getDouble(_tcRadarLongitudeKey);
    final accuracy = prefs.getDouble(_tcRadarAccuracyKey);
    final address = prefs.getString(_tcRadarAddressKey);

    if (!mounted) return;
    if (latitude == null || longitude == null) return;

    setState(() {
      _radarLatitude = latitude;
      _radarLongitude = longitude;
      _radarAccuracy = accuracy ?? 20;
      _radarAddress = (address == null || address.trim().isEmpty)
          ? '上次使用的百度定位'
          : address.trim();
    });
  }

  Future<void> _saveRadarUiPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    if (_radarLatitude == null || _radarLongitude == null) {
      await prefs.remove(_tcRadarLatitudeKey);
      await prefs.remove(_tcRadarLongitudeKey);
      await prefs.remove(_tcRadarAccuracyKey);
      await prefs.remove(_tcRadarAddressKey);
      return;
    }

    await prefs.setDouble(_tcRadarLatitudeKey, _radarLatitude!);
    await prefs.setDouble(_tcRadarLongitudeKey, _radarLongitude!);
    await prefs.setDouble(_tcRadarAccuracyKey, _radarAccuracy ?? 20);
    if (_radarAddress != null && _radarAddress!.trim().isNotEmpty) {
      await prefs.setString(_tcRadarAddressKey, _radarAddress!.trim());
    } else {
      await prefs.remove(_tcRadarAddressKey);
    }
  }

  Active? _pickCurrentActivity(List<Active> activities) {
    for (final active in activities) {
      if (active.status && !_isAlreadySigned(active)) {
        return active;
      }
    }
    return activities.isNotEmpty ? activities.first : null;
  }

  int _activityPriority(Active active) {
    final label = _statusLabel(active);
    if (label == '进行中') return 0;
    if (_isAlreadySigned(active)) return 2;
    return 1;
  }

  int _compareActivities(Active a, Active b) {
    final pa = _activityPriority(a);
    final pb = _activityPriority(b);
    if (pa != pb) {
      return pa.compareTo(pb);
    }

    final ta = _extractRollcallTime(a);
    final tb = _extractRollcallTime(b);
    if (ta != null && tb != null) {
      return tb.compareTo(ta);
    }
    if (ta != null) return -1;
    if (tb != null) return 1;

    return b.id.compareTo(a.id);
  }

  bool _isAlreadySigned(Active active) {
    if (_signedActivityIds.contains(active.id)) {
      return true;
    }
    final dynamic signed = active.extras['_signed'];
    if (signed == true) return true;
    if (signed is num && signed > 0) return true;
    final text = signed?.toString().toLowerCase() ?? '';
    return text == 'true' ||
        text == '1' ||
        text == 'signed' ||
        text == 'checked';
  }

  void _addLog({
    required Active active,
    required bool success,
    required String message,
  }) {
    _logs.insert(
      0,
      TronclassSignLogItem(
        time: DateTime.now(),
        activityId: active.id,
        activityTitle: active.name,
        mode: _modeLabel(active.extras['_mode']?.toString() ?? 'unknown'),
        message: message,
        success: success,
      ),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'qrcode':
        return '二维码签到';
      case 'radar':
        return '雷达签到';
      case 'number':
        return '数字签到';
      default:
        return '未知模式';
    }
  }

  String _statusLabel(Active active) {
    if (_isAlreadySigned(active)) {
      return '已签到';
    }

    final rollcallStatus =
        active.extras['rollcall_status']?.toString().toLowerCase() ?? '';
    final rawStatus = active.extras['status']?.toString().toLowerCase() ?? '';

    if (rawStatus == 'present' || rawStatus == 'on_call_fine') {
      return '已签到';
    }
    if (rawStatus == 'late') {
      return '迟到';
    }
    if (rawStatus == 'excused') {
      return '请假';
    }
    if (rawStatus == 'absent') {
      return '缺席';
    }

    if (rollcallStatus == 'in_progress') {
      return '进行中';
    }
    if (rawStatus == 'on_call') {
      return '进行中';
    }
    if (rollcallStatus == 'ended' || rollcallStatus == 'closed') {
      return '已结束';
    }

    return active.status ? '进行中' : '已结束';
  }

  Color _statusColor(Active active) {
    final label = _statusLabel(active);
    switch (label) {
      case '已签到':
        return const Color(0xFF1DB6C2);
      case '进行中':
        return const Color(0xFF59BE30);
      case '迟到':
        return const Color(0xFFF6A23A);
      case '请假':
        return const Color(0xFF5B90EF);
      case '缺席':
        return const Color(0xFFF56C6C);
      default:
        return Colors.grey;
    }
  }

  IconData _modeIcon(Active active) {
    final mode = active.extras['_mode']?.toString() ?? 'unknown';
    if (mode == 'qrcode') return Icons.qr_code_scanner;
    if (mode == 'number') return Icons.pin_outlined;
    if (mode == 'radar') return Icons.radar_outlined;
    return Icons.how_to_reg_outlined;
  }

  Color _modeColor(String mode) {
    switch (mode) {
      case 'qrcode':
        return const Color(0xFF59BE30);
      case 'radar':
        return const Color(0xFF5B90EF);
      case 'number':
        return const Color(0xFF00B8D4);
      default:
        return _tcPrimary;
    }
  }

  String _modeHint(String mode) {
    switch (mode) {
      case 'qrcode':
        return '请扫描老师展示的二维码，系统会自动解析并提交签到参数。';
      case 'radar':
        return '请在地图上选择你当前位置附近坐标，签到会附带定位信息。';
      case 'number':
        return '请输入老师发布的数字签到码后提交。';
      default:
        return '请选择一个可用签到会话后操作。';
    }
  }

  String _modeBadgeText(String mode) {
    switch (mode) {
      case 'qrcode':
        return '二维码';
      case 'radar':
        return '雷达';
      case 'number':
        return '数字';
      default:
        return '未知';
    }
  }

  Widget _buildSectionTitle(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  int get _inProgressCount {
    return _activities.where((a) => _statusLabel(a) == '进行中').length;
  }

  int get _signedCount {
    return _activities.where((a) => _isAlreadySigned(a)).length;
  }

  List<Active> get _visibleActivities {
    if (_listFilter == 'in_progress') {
      return _activities.where((a) => _statusLabel(a) == '进行中').toList();
    }
    if (_listFilter == 'signed') {
      return _activities.where((a) => _isAlreadySigned(a)).toList();
    }
    return _activities;
  }

  String get _filterLabel {
    switch (_listFilter) {
      case 'in_progress':
        return '进行中';
      case 'signed':
        return '已签到';
      default:
        return '全部';
    }
  }

  Widget _buildOverviewChip({
    required String label,
    required String value,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.24)
                : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: color.withValues(alpha: 0.75), width: 1.1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: color, fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setListFilter(String filter) {
    if (_listFilter == filter) return;
    setState(() {
      _listFilter = filter;
    });

    final target = _visibleActivities.isNotEmpty
        ? _visibleActivities.first
        : null;
    if (target != null) {
      _selectActivity(target);
    }
  }

  void _ensureCurrentActivityVisible() {
    if (_currentActivity == null) return;
    final exists = _visibleActivities.any((a) => a.id == _currentActivity!.id);
    if (!exists && _visibleActivities.isNotEmpty) {
      _selectActivity(_visibleActivities.first);
    }
  }

  Widget _buildFilterHint() {
    if (_listFilter == 'all') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        '当前仅显示「$_filterLabel」会话',
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }

  Widget _buildNoFilteredResult() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '当前筛选条件下没有会话，点击顶部统计项可切换筛选。',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewHeader() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_tcPrimary, _tcSecondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x331DB6C2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.course.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '畅课签到概览',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewChip(
                  label: '进行中',
                  value: '$_inProgressCount',
                  color: Colors.white,
                  selected: _listFilter == 'in_progress',
                  onTap: () => _setListFilter('in_progress'),
                ),
                _buildOverviewChip(
                  label: '已签到',
                  value: '$_signedCount',
                  color: Colors.white,
                  selected: _listFilter == 'signed',
                  onTap: () => _setListFilter('signed'),
                ),
                _buildOverviewChip(
                  label: '总数',
                  value: '${_activities.length}',
                  color: Colors.white,
                  selected: _listFilter == 'all',
                  onTap: () => _setListFilter('all'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedRollcallList() {
    _ensureCurrentActivityVisible();

    if (_visibleActivities.isEmpty) {
      return _buildNoFilteredResult();
    }

    return Column(
      children: _visibleActivities.asMap().entries.map((entry) {
        final index = entry.key;
        final active = entry.value;
        final delay = 80 * index;
        return TweenAnimationBuilder<double>(
          key: ValueKey('rollcall_${active.id}'),
          duration: Duration(milliseconds: 240 + delay.clamp(0, 360)),
          curve: Curves.easeOut,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 8),
                child: child,
              ),
            );
          },
          child: _buildRollcallListCard(active),
        );
      }).toList(),
    );
  }

  DateTime? _extractRollcallTime(Active active) {
    final raw =
        active.extras['rollcall_time'] ??
        active.extras['updated_at'] ??
        active.extras['created_at'];
    if (raw == null) return null;

    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _formatRollcallTime(Active active) {
    final dateTime = _extractRollcallTime(active);
    if (dateTime == null) return '';

    final local = dateTime.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _buildCardMeta(Active active) {
    final teacher = (active.extras['created_by_name'] ?? '').toString().trim();
    final className = (active.extras['class_name'] ?? '').toString().trim();
    final timeText = _formatRollcallTime(active);

    final parts = <String>[];
    if (teacher.isNotEmpty) {
      parts.add(teacher);
    } else if (className.isNotEmpty) {
      parts.add(className);
    }
    if (timeText.isNotEmpty) {
      parts.add(timeText);
    }
    return parts.join(' · ');
  }

  void _selectActivity(Active active) {
    setState(() {
      _currentActivity = active;
      _currentMode = active.extras['_mode']?.toString() ?? 'unknown';
      _resetInputsForMode(_currentMode);
      if (_currentMode != 'radar') {
        _resetRadarSelection();
      }
    });
  }

  Widget _buildRollcallListCard(Active active) {
    final isCurrent = _currentActivity?.id == active.id;
    final statusLabel = _statusLabel(active);
    final statusColor = _statusColor(active);
    final metaText = _buildCardMeta(active);
    final mode = active.extras['_mode']?.toString() ?? 'unknown';
    final modeColor = _modeColor(mode);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: isCurrent ? _tcPrimary.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCurrent
              ? const Color(0xFF1DB6C2).withValues(alpha: 0.45)
              : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectActivity(active),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_modeIcon(active), color: statusColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _modeLabel(mode),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        if (metaText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            metaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: modeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _modeBadgeText(mode),
                          style: TextStyle(
                            color: modeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isCurrent ? '当前面板' : '点此切换',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      '状态：$statusLabel',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isCurrent ? '已选中' : '可切换',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ScanPage(onScanResult: (_) {})),
    );

    if (!mounted || result == null || result.isEmpty) return;

    final parsed = _parseQrScanContent(result);
    final scannedRollcallId = parsed['rollcallId']?.toString();
    if (_currentActivity != null &&
        scannedRollcallId != null &&
        scannedRollcallId.isNotEmpty &&
        scannedRollcallId != _currentActivity!.id) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该二维码不属于当前签到，请重新扫描')));
      return;
    }

    final payload = parsed['data']?.toString() ?? result;
    setState(() {
      _qrPayload = payload;
    });
  }

  Map<String, dynamic> _parseQrScanContent(String raw) {
    final parsed = TronclassQrParser.parse(raw);
    if (parsed != null && parsed.isNotEmpty) {
      return parsed;
    }
    return {'data': raw.trim()};
  }

  Future<void> _sign(Active active) async {
    if (_isAlreadySigned(active)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该活动已签到，无需重复签到')));
      return;
    }

    if (_isSubmitting) return;

    final validationMessage = _validateCurrentSignInput();
    if (validationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationMessage)));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = _debugLocalMockMode
          ? await _mockSign(active)
          : await TCCourseApi.sign(
              active.id,
              mode: _currentMode,
              signCode: _numberCodeForCurrentMode().isEmpty
                  ? null
                  : _numberCodeForCurrentMode(),
              numberCode: _numberCodeForCurrentMode().isEmpty
                  ? null
                  : _numberCodeForCurrentMode(),
              qrPayload: _qrPayloadForCurrentMode(),
              radarLatitude: _hasRadarSelection() ? _radarLatitude : null,
              radarLongitude: _hasRadarSelection() ? _radarLongitude : null,
              radarAccuracy: _currentMode == 'radar'
                  ? (_radarAccuracy ?? 20)
                  : null,
            );

      await _handleSignResult(active, result);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _mockSign(Active active) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final mode = active.extras['_mode']?.toString() ?? _currentMode;
    return {'ok': true, 'message': '模拟签到成功（$mode，未请求服务器）'};
  }

  void _createDebugActivity() {
    final mockId = DateTime.now().millisecondsSinceEpoch.toString();
    final mock = Active(
      type: 2,
      id: mockId,
      name: '本地模拟签到会话',
      description: '用于无现场联调，不会影响真实签到记录',
      startTime: 0,
      url: '',
      status: true,
      extras: {'_mode': _debugMode, '_signed': false, '_debug_mock': true},
    );

    final raw = _debugQrRawController.text.trim();
    final parsed = raw.isEmpty ? null : _parseQrScanContent(raw);

    setState(() {
      _activities = [mock];
      _currentActivity = mock;
      _currentMode = _debugMode;
      _resetInputsForMode(_debugMode);

      if (_debugMode == 'qrcode') {
        _qrPayload = parsed?['data']?.toString() ?? (raw.isEmpty ? null : raw);
      }

      if (_debugMode == 'radar') {
        _radarLatitude ??= 25.2736;
        _radarLongitude ??= 110.2900;
        _radarAccuracy ??= 20;
        _radarAddress ??= '默认模拟坐标（桂林）';
      }
    });
  }

  void _applyDebugQrSample() {
    String value = '';
    for (final item in _debugQrSampleItems) {
      if (item['id'] == _debugSelectedQrSample) {
        value = item['value'] ?? '';
        break;
      }
    }

    if (value.isEmpty) return;

    setState(() {
      _debugQrRawController.text = value;
      if (_debugMode == 'qrcode') {
        final parsed = _parseQrScanContent(value);
        _qrPayload = parsed['data']?.toString() ?? value;
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已填充样例二维码内容')));
  }

  Widget _buildDebugPanel() {
    if (!kDebugMode) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '开发调试模式（无现场可用）',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('本地模拟签到（不请求服务器）'),
              value: _debugLocalMockMode,
              onChanged: (v) {
                setState(() {
                  _debugLocalMockMode = v;
                });
              },
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _debugMode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '模拟模式',
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'qrcode', child: Text('二维码签到')),
                DropdownMenuItem(value: 'radar', child: Text('雷达签到')),
                DropdownMenuItem(value: 'number', child: Text('数字签到')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _debugMode = v;
                });
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _debugQrRawController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '可选：粘贴二维码原文用于解析（/j?p=... 或 JSON）',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _debugSelectedQrSample,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '样例二维码',
                      isDense: true,
                    ),
                    items: _debugQrSampleItems
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['id'],
                            child: Text(e['label'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _debugSelectedQrSample = v;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _applyDebugQrSample,
                  child: const Text('填充样例'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _createDebugActivity,
                icon: const Icon(Icons.build_outlined),
                label: const Text('创建本地模拟会话'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignCard(Active active) {
    final alreadySigned = _isAlreadySigned(active);
    final statusText = _statusLabel(active);
    final mode = active.extras['_mode']?.toString() ?? 'unknown';
    final modeColor = _modeColor(mode);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(active.getIcon(), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    active.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(color: _statusColor(active), fontSize: 12),
                ),
              ],
            ),
            if (active.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                active.description,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: modeColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前模式: ${_modeLabel(mode)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: modeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _modeHint(mode),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_currentMode == 'number')
              TextField(
                controller: _numberCodeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '请输入数字签到码',
                  isDense: true,
                ),
              ),
            if (_currentMode == 'qrcode')
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _qrPayload == null ? '尚未扫码' : '已扫码，可提交二维码签到',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _openQrScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('扫码'),
                  ),
                ],
              ),
            if (_currentMode == 'radar')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _radarSelectionSummary(),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _pickRadarLocation,
                          icon: const Icon(Icons.location_on_outlined),
                          label: Text(
                            _radarAddress == null ? '选择签到位置' : '重新选择位置',
                          ),
                        ),
                      ),
                      if (_radarLatitude != null &&
                          _radarLongitude != null) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : _clearRadarSelection,
                          icon: const Icon(Icons.clear_outlined),
                          label: const Text('清除'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: modeColor,
                  disabledBackgroundColor: modeColor.withValues(alpha: 0.45),
                ),
                onPressed: active.status && !_isSubmitting && !alreadySigned
                    ? () => _sign(active)
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  alreadySigned ? '已签到' : (_isSubmitting ? '签到中...' : '手动签到'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.course.name} - 签到'),
        backgroundColor: _tcPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '签到日志',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TronclassSignLogsPage(logs: List.unmodifiable(_logs)),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              color: _tcPrimary,
              onRefresh: _loadActivities,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _activities.isEmpty
                  ? ListView(
                      children: [
                        _buildDebugPanel(),
                        _buildOverviewHeader(),
                        const SizedBox(height: 100),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Center(
                            child: Text(
                              '当前课程暂无可识别签到活动\n下拉可以刷新；也可以先去畅课门户确认老师是否已发起签到。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        _buildDebugPanel(),
                        _buildOverviewHeader(),
                        const SizedBox(height: 4),
                        _buildSectionTitle(
                          '签到列表（进行中优先）',
                          trailing:
                              '$_filterLabel ${_visibleActivities.length}/${_activities.length}',
                        ),
                        _buildFilterHint(),
                        _buildAnimatedRollcallList(),
                        const SizedBox(height: 8),
                        _buildSectionTitle('签到面板'),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1,
                                child: child,
                              ),
                            );
                          },
                          child: _currentActivity != null
                              ? KeyedSubtree(
                                  key: ValueKey(_currentActivity!.id),
                                  child: _buildSignCard(_currentActivity!),
                                )
                              : const ListTile(
                                  key: ValueKey('no_current_activity'),
                                  title: Text('未找到当前可用签到会话'),
                                  subtitle: Text('请下拉刷新后重试'),
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
      backgroundColor: _tcBg,
    );
  }

  Future<void> _pickRadarLocation() async {
    BMFCoordinate? selectedCoordinate;
    String? selectedAddress;
    final hasSavedSelection = _radarLatitude != null && _radarLongitude != null;

    if (hasSavedSelection) {
      selectedCoordinate = BMFCoordinate(_radarLatitude!, _radarLongitude!);
      selectedAddress = _radarAddress;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pickerContext) => StatefulBuilder(
          builder: (context, setPickerState) {
            String selectionText() {
              if (selectedCoordinate == null) {
                return '地图会优先使用百度定位结果；也可以手动点选微调。';
              }

              final coordinate = selectedCoordinate!;
              final address =
                  (selectedAddress == null || selectedAddress!.trim().isEmpty)
                  ? '地图选点'
                  : selectedAddress!.trim();
              return '$address\n纬度：${coordinate.latitude.toStringAsFixed(6)}，经度：${coordinate.longitude.toStringAsFixed(6)}';
            }

            return Scaffold(
              appBar: AppBar(title: const Text('选择雷达签到位置')),
              body: Column(
                children: [
                  Expanded(
                    child: BaiduMapWidget(
                      initialCoordinate: selectedCoordinate,
                      initialAddress: selectedAddress,
                      autoLocateOnInit: !hasSavedSelection,
                      onLocationSelectedWithAddress: (coordinate, address) {
                        setPickerState(() {
                          selectedCoordinate = coordinate;
                          selectedAddress = address;
                        });
                      },
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectionText(),
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: selectedCoordinate == null
                                  ? null
                                  : () async {
                                      await _applyRadarSelection(
                                        selectedCoordinate!,
                                        address: selectedAddress,
                                      );
                                      if (pickerContext.mounted) {
                                        Navigator.pop(pickerContext);
                                      }
                                    },
                              child: const Text('确认百度定位'),
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
}
