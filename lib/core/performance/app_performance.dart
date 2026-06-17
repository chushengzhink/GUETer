import 'dart:async';
import 'dart:isolate';

import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppPerformanceMode {
  balanced('balanced'),
  lowPower('lowPower');

  const AppPerformanceMode(this.id);

  final String id;

  static AppPerformanceMode fromId(String? id) {
    return values.firstWhere(
      (mode) => mode.id == id,
      orElse: () => AppPerformanceMode.balanced,
    );
  }
}

class PerformanceSettings {
  const PerformanceSettings({
    this.mode = AppPerformanceMode.balanced,
    this.deferredThumbnails = true,
    this.batchSize = 24,
    this.showDiagnostics = false,
  });

  final AppPerformanceMode mode;
  final bool deferredThumbnails;
  final int batchSize;
  final bool showDiagnostics;

  bool get lowPower => mode == AppPerformanceMode.lowPower;

  PerformanceSettings copyWith({
    AppPerformanceMode? mode,
    bool? deferredThumbnails,
    int? batchSize,
    bool? showDiagnostics,
  }) {
    return PerformanceSettings(
      mode: mode ?? this.mode,
      deferredThumbnails: deferredThumbnails ?? this.deferredThumbnails,
      batchSize: batchSize ?? this.batchSize,
      showDiagnostics: showDiagnostics ?? this.showDiagnostics,
    );
  }
}

class PerformanceSettingsStore {
  PerformanceSettingsStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static const String modeKey = 'performance_mode_v1';
  static const String deferredThumbnailsKey =
      'performance_deferred_thumbnails_v1';
  static const String batchSizeKey = 'performance_batch_size_v1';
  static const String showDiagnosticsKey = 'performance_show_diagnostics_v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<PerformanceSettings> load() async {
    final prefs = await _preferencesLoader();
    return PerformanceSettings(
      mode: AppPerformanceMode.fromId(prefs.getString(modeKey)),
      deferredThumbnails: prefs.getBool(deferredThumbnailsKey) ?? true,
      batchSize: _normalizeBatchSize(prefs.getInt(batchSizeKey)),
      showDiagnostics: prefs.getBool(showDiagnosticsKey) ?? false,
    );
  }

  Future<void> save(PerformanceSettings settings) async {
    final prefs = await _preferencesLoader();
    await prefs.setString(modeKey, settings.mode.id);
    await prefs.setBool(deferredThumbnailsKey, settings.deferredThumbnails);
    await prefs.setInt(batchSizeKey, _normalizeBatchSize(settings.batchSize));
    await prefs.setBool(showDiagnosticsKey, settings.showDiagnostics);
  }

  Future<void> setMode(AppPerformanceMode mode) async {
    final settings = await load();
    await save(
      settings.copyWith(
        mode: mode,
        batchSize: mode == AppPerformanceMode.lowPower ? 8 : 24,
        deferredThumbnails: true,
      ),
    );
  }

  int _normalizeBatchSize(int? value) {
    if (value == null || value <= 0) return 24;
    if (value < 4) return 4;
    if (value > 128) return 128;
    return value;
  }
}

class BackgroundTaskRunner {
  const BackgroundTaskRunner({this.useIsolate = true});

  final bool useIsolate;

  Future<T> run<T>(FutureOr<T> Function() task) async {
    if (!useIsolate) {
      return task();
    }
    try {
      return Isolate.run(task);
    } catch (_) {
      return task();
    }
  }
}

class CooperativeYield {
  CooperativeYield({required int batchSize, Future<void> Function()? yielder})
    : _yielder =
          yielder ?? (() => Future<void>.delayed(Duration.zero)),
      _batchSize = batchSize <= 0 ? 24 : batchSize;

  final int _batchSize;
  final Future<void> Function() _yielder;
  int _count = 0;

  Future<void> tick() async {
    _count++;
    if (_count % _batchSize == 0) {
      await _yielder();
    }
  }
}

class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }

  void throwIfCancelled() {
    if (_cancelled) {
      throw const TaskCancelledException();
    }
  }
}

class TaskCancelledException implements Exception {
  const TaskCancelledException();

  @override
  String toString() => 'Task cancelled';
}

class PerformanceTaskProgress {
  const PerformanceTaskProgress({
    required this.message,
    this.done,
    this.total,
  });

  final String message;
  final int? done;
  final int? total;
}

class FrameJankSnapshot {
  const FrameJankSnapshot({
    required this.totalFrames,
    required this.uiJankFrames,
    required this.rasterJankFrames,
    required this.worstFrameMs,
  });

  final int totalFrames;
  final int uiJankFrames;
  final int rasterJankFrames;
  final double worstFrameMs;
}

class FrameJankMonitor {
  FrameJankMonitor({this.jankThreshold = const Duration(milliseconds: 16)});

  final Duration jankThreshold;
  int _totalFrames = 0;
  int _uiJankFrames = 0;
  int _rasterJankFrames = 0;
  double _worstFrameMs = 0;
  bool _started = false;

  void start() {
    if (_started) return;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _started = true;
  }

  void stop() {
    if (!_started) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _started = false;
  }

  void reset() {
    _totalFrames = 0;
    _uiJankFrames = 0;
    _rasterJankFrames = 0;
    _worstFrameMs = 0;
  }

  FrameJankSnapshot snapshot() {
    return FrameJankSnapshot(
      totalFrames: _totalFrames,
      uiJankFrames: _uiJankFrames,
      rasterJankFrames: _rasterJankFrames,
      worstFrameMs: _worstFrameMs,
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _totalFrames++;
      final uiMs = timing.buildDuration.inMicroseconds / 1000;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000;
      if (timing.buildDuration > jankThreshold) _uiJankFrames++;
      if (timing.rasterDuration > jankThreshold) _rasterJankFrames++;
      final worst = uiMs > rasterMs ? uiMs : rasterMs;
      if (worst > _worstFrameMs) _worstFrameMs = worst;
    }
  }
}
