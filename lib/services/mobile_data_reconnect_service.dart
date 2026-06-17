import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum MobileDataReconnectMode { privilegedAuto, manualAssist, unsupported }

class MobileDataCapability {
  const MobileDataCapability({
    required this.mode,
    required this.message,
    this.canOpenSettings = false,
  });

  final MobileDataReconnectMode mode;
  final String message;
  final bool canOpenSettings;

  bool get canAutoRestart => mode == MobileDataReconnectMode.privilegedAuto;

  factory MobileDataCapability.fromMap(Map<dynamic, dynamic>? raw) {
    final modeName = raw?['mode']?.toString() ?? 'unsupported';
    return MobileDataCapability(
      mode: switch (modeName) {
        'privilegedAuto' => MobileDataReconnectMode.privilegedAuto,
        'manualAssist' => MobileDataReconnectMode.manualAssist,
        _ => MobileDataReconnectMode.unsupported,
      },
      message: raw?['message']?.toString() ?? '当前设备不支持自动重启移动数据',
      canOpenSettings: raw?['canOpenSettings'] == true,
    );
  }
}

class MobileDataReconnectResult {
  const MobileDataReconnectResult({
    required this.success,
    required this.mode,
    required this.message,
    this.ipBefore,
    this.ipAfter,
    this.ipChanged = false,
    this.requiresManualAction = false,
  });

  final bool success;
  final MobileDataReconnectMode mode;
  final String message;
  final String? ipBefore;
  final String? ipAfter;
  final bool ipChanged;
  final bool requiresManualAction;

  MobileDataReconnectResult copyWith({
    bool? success,
    MobileDataReconnectMode? mode,
    String? message,
    String? ipBefore,
    String? ipAfter,
    bool? ipChanged,
    bool? requiresManualAction,
  }) {
    return MobileDataReconnectResult(
      success: success ?? this.success,
      mode: mode ?? this.mode,
      message: message ?? this.message,
      ipBefore: ipBefore ?? this.ipBefore,
      ipAfter: ipAfter ?? this.ipAfter,
      ipChanged: ipChanged ?? this.ipChanged,
      requiresManualAction: requiresManualAction ?? this.requiresManualAction,
    );
  }
}

class MobileDataReconnectService {
  MobileDataReconnectService({
    MethodChannel? channel,
    Dio? dio,
    this.ipTimeout = const Duration(seconds: 3),
  }) : _channel = channel ?? _defaultChannel,
       _dio = dio ?? Dio();

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.gueter.cszm/network_control',
  );

  final MethodChannel _channel;
  final Dio _dio;
  final Duration ipTimeout;

  @visibleForTesting
  static Future<MobileDataCapability> Function()? debugCapabilityOverride;

  @visibleForTesting
  static Future<MobileDataReconnectResult> Function()? debugRestartOverride;

  @visibleForTesting
  static Future<String?> Function()? debugPublicIpOverride;

  Future<MobileDataCapability> getCapability() async {
    final override = debugCapabilityOverride;
    if (override != null) {
      return override();
    }
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getCapability',
      );
      return MobileDataCapability.fromMap(raw);
    } catch (e) {
      return MobileDataCapability(
        mode: MobileDataReconnectMode.unsupported,
        message: '无法检测移动数据控制能力: $e',
      );
    }
  }

  Future<void> openNetworkSettings() async {
    try {
      await _channel.invokeMethod<void>('openNetworkSettings');
    } catch (_) {
      // Opening settings is best effort; the caller still owns the workflow.
    }
  }

  Future<String?> getPublicIp() async {
    final override = debugPublicIpOverride;
    if (override != null) {
      return override();
    }

    final endpoints = <String>[
      'https://api.ipify.org?format=json',
      'https://ifconfig.me/ip',
    ];
    for (final endpoint in endpoints) {
      try {
        final response = await _dio.get<dynamic>(endpoint).timeout(ipTimeout);
        final data = response.data;
        if (data is Map && data['ip'] != null) {
          final ip = data['ip'].toString().trim();
          if (ip.isNotEmpty) return ip;
        }
        final text = data?.toString().trim() ?? '';
        if (text.isNotEmpty && text.length <= 80) {
          return text;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<MobileDataReconnectResult> restartForSign() async {
    final override = debugRestartOverride;
    if (override != null) {
      return override();
    }

    final capability = await getCapability();
    final ipBefore = await getPublicIp();

    if (!capability.canAutoRestart) {
      return MobileDataReconnectResult(
        success: false,
        mode: capability.mode,
        message: capability.message,
        ipBefore: ipBefore,
        requiresManualAction: capability.canOpenSettings,
      );
    }

    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'restartMobileData',
      );
      final ok = raw?['success'] == true;
      final nativeMessage =
          raw?['message']?.toString() ?? (ok ? '移动数据已重启' : '移动数据重启失败');
      final ipAfter = await getPublicIp();
      return MobileDataReconnectResult(
        success: ok,
        mode: capability.mode,
        message: nativeMessage,
        ipBefore: ipBefore,
        ipAfter: ipAfter,
        ipChanged:
            ipBefore != null &&
            ipAfter != null &&
            ipBefore.trim() != ipAfter.trim(),
      );
    } catch (e) {
      return MobileDataReconnectResult(
        success: false,
        mode: capability.mode,
        message: '移动数据重启异常: $e',
        ipBefore: ipBefore,
      );
    }
  }

  Future<MobileDataReconnectResult> verifyManualReconnect({
    String? ipBefore,
  }) async {
    final before = ipBefore ?? await getPublicIp();
    final after = await getPublicIp();
    return MobileDataReconnectResult(
      success: before != null && after != null && before.trim() != after.trim(),
      mode: MobileDataReconnectMode.manualAssist,
      message: before == null || after == null
          ? '无法确认公网 IP 是否变化'
          : before == after
          ? '公网 IP 未变化'
          : '已确认公网 IP 变化',
      ipBefore: before,
      ipAfter: after,
      ipChanged:
          before != null && after != null && before.trim() != after.trim(),
    );
  }
}
