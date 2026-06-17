import 'package:course_helper/core/performance/app_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('performance settings store loads defaults and saves values', () async {
    final store = PerformanceSettingsStore();

    final defaults = await store.load();
    expect(defaults.mode, AppPerformanceMode.balanced);
    expect(defaults.deferredThumbnails, isTrue);
    expect(defaults.batchSize, 24);
    expect(defaults.showDiagnostics, isFalse);

    await store.save(
      const PerformanceSettings(
        mode: AppPerformanceMode.lowPower,
        deferredThumbnails: false,
        batchSize: 6,
        showDiagnostics: true,
      ),
    );

    final loaded = await store.load();
    expect(loaded.mode, AppPerformanceMode.lowPower);
    expect(loaded.deferredThumbnails, isFalse);
    expect(loaded.batchSize, 6);
    expect(loaded.showDiagnostics, isTrue);
  });

  test('setMode applies low power defaults', () async {
    final store = PerformanceSettingsStore();

    await store.setMode(AppPerformanceMode.lowPower);

    final loaded = await store.load();
    expect(loaded.mode, AppPerformanceMode.lowPower);
    expect(loaded.batchSize, 8);
    expect(loaded.deferredThumbnails, isTrue);
  });

  test('background runner returns results and propagates errors in fallback mode', () async {
    const runner = BackgroundTaskRunner(useIsolate: false);

    expect(await runner.run(() => 42), 42);
    expect(
      runner.run<int>(() => throw StateError('boom')),
      throwsStateError,
    );
  });

  test('cooperative yield triggers after batch threshold', () async {
    var yields = 0;
    final cooperativeYield = CooperativeYield(
      batchSize: 2,
      yielder: () async {
        yields++;
      },
    );

    await cooperativeYield.tick();
    expect(yields, 0);
    await cooperativeYield.tick();
    expect(yields, 1);
  });
}
