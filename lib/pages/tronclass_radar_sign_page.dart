import 'package:flutter/material.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:uuid/uuid.dart';

import '../api/tronclass_sign_api.dart';
import 'widget/baidu_map.dart';

enum _RadarSignState { radar, success, failure }

class TronclassRadarSignPage extends StatefulWidget {
  final String rollcallId;
  final String? activityName;

  const TronclassRadarSignPage({super.key, required this.rollcallId, this.activityName});

  @override
  State<TronclassRadarSignPage> createState() => _TronclassRadarSignPageState();
}

class _TronclassRadarSignPageState extends State<TronclassRadarSignPage> {
  _RadarSignState _currentState = _RadarSignState.radar;
  bool _isScanning = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF01b9bb), Color(0xFF29cbcd)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                child: Column(
                  children: [
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                '雷达签到',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                left: 40,
                right: 40,
                top: 100,
                bottom: 100 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: _buildBottomButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case _RadarSignState.radar:
        return _buildRadarContent();
      case _RadarSignState.success:
        return Center(child: _buildSuccessContent());
      case _RadarSignState.failure:
        return Center(child: _buildFailureContent());
    }
  }

  Widget _buildRadarContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          _isScanning ? '正在签到...' : '',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 240,
          child: Icon(
            Icons.radar,
            size: 240,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 200,
          child: Icon(
            Icons.check_circle,
            size: 120,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          '签到成功',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          DateTime.now().toString().substring(0, 16),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildFailureContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 200,
          child: Icon(
            Icons.error,
            size: 120,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          '签到失败',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _errorMessage.isEmpty ? '签到失败，点名已结束' : _errorMessage,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    switch (_currentState) {
      case _RadarSignState.radar:
        return Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: ElevatedButton(
              onPressed: _isScanning ? null : _openLocationPicker,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20bec8),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 0,
                disabledBackgroundColor: const Color(0xFF20bec8).withValues(alpha: 0.8),
              ),
              child: Text(
                _isScanning ? '签到中' : '签到',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      case _RadarSignState.success:
        return Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20bec8),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 0,
              ),
              child: const Text(
                '完成',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      case _RadarSignState.failure:
        return Center(
          child: SizedBox(
            width: 120,
            height: 120,
            child: ElevatedButton(
              onPressed: () {
                _restartRadar();
                _openLocationPicker();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF20bec8),
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 0,
              ),
              child: const Text(
                '重试',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
    }
  }

  Future<void> _openLocationPicker() async {
    BMFCoordinate? selectedCoordinate;
    String? selectedAddress;

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
              final address = (selectedAddress == null || selectedAddress!.trim().isEmpty)
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
                      autoLocateOnInit: true,
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
                                      await _performRollcallWithLocation(
                                        latitude: selectedCoordinate!.latitude,
                                        longitude: selectedCoordinate!.longitude,
                                        accuracy: 20,
                                      );
                                      if (pickerContext.mounted) {
                                        Navigator.pop(pickerContext);
                                      }
                                    },
                              child: const Text('确认定位并签到'),
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
      final deviceId = const Uuid().v4();

      final response = await TronclassSignApi.signRadar(
        rollcallId: widget.rollcallId,
        deviceId: deviceId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );

      final responseData = response.data;
      final isSuccessful = TronclassSignApi.isSignSuccess(responseData);

      if (mounted) {
        if (isSuccessful) {
          setState(() {
            _currentState = _RadarSignState.success;
          });
        } else {
          setState(() {
            _errorMessage = TronclassSignApi.getSignMessage(responseData);
            _currentState = _RadarSignState.failure;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '签到失败，请重试';
          _currentState = _RadarSignState.failure;
        });
      }
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
}
