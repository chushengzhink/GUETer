enum AppAsyncStatus { idle, loading, data, empty, error }

class AppAsyncState<T> {
  const AppAsyncState._({
    required this.status,
    this.data,
    this.error,
    this.stackTrace,
    this.isRefreshing = false,
  });

  const AppAsyncState.idle() : this._(status: AppAsyncStatus.idle);

  const AppAsyncState.loading({T? previousData, bool isRefreshing = false})
    : this._(
        status: AppAsyncStatus.loading,
        data: previousData,
        isRefreshing: isRefreshing,
      );

  const AppAsyncState.data(T data, {bool isRefreshing = false})
    : this._(
        status: AppAsyncStatus.data,
        data: data,
        isRefreshing: isRefreshing,
      );

  const AppAsyncState.empty() : this._(status: AppAsyncStatus.empty);

  const AppAsyncState.error(Object error, {StackTrace? stackTrace, T? data})
    : this._(
        status: AppAsyncStatus.error,
        data: data,
        error: error,
        stackTrace: stackTrace,
      );

  final AppAsyncStatus status;
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isRefreshing;

  bool get isIdle => status == AppAsyncStatus.idle;
  bool get isLoading => status == AppAsyncStatus.loading;
  bool get hasData => status == AppAsyncStatus.data && data != null;
  bool get isEmpty => status == AppAsyncStatus.empty;
  bool get hasError => status == AppAsyncStatus.error;

  AppAsyncState<T> refreshing() {
    return AppAsyncState<T>.loading(
      previousData: data,
      isRefreshing: data != null,
    );
  }
}
