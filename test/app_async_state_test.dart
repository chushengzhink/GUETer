import 'package:course_helper/core/async/app_async_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transitions expose idle/loading/data/empty/error flags', () {
    const idle = AppAsyncState<int>.idle();
    expect(idle.isIdle, isTrue);

    const loading = AppAsyncState<int>.loading();
    expect(loading.isLoading, isTrue);
    expect(loading.isRefreshing, isFalse);

    const data = AppAsyncState<int>.data(7);
    expect(data.hasData, isTrue);
    expect(data.data, 7);

    const empty = AppAsyncState<int>.empty();
    expect(empty.isEmpty, isTrue);

    final error = AppAsyncState<int>.error(StateError('failed'), data: 7);
    expect(error.hasError, isTrue);
    expect(error.data, 7);
    expect(error.error, isA<StateError>());
  });

  test('refreshing keeps existing data and marks refresh state', () {
    final refreshing = const AppAsyncState<int>.data(7).refreshing();

    expect(refreshing.isLoading, isTrue);
    expect(refreshing.isRefreshing, isTrue);
    expect(refreshing.data, 7);
  });
}
