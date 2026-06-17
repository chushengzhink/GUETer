import 'package:flutter/material.dart';

import 'app_async_state.dart';

class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.state,
    required this.dataBuilder,
    this.onRefresh,
    this.onRetry,
    this.emptyTitle = '暂无内容',
    this.emptySubtitle,
    this.errorTitle = '加载失败',
    this.loadingLabel,
    this.padding = const EdgeInsets.all(24),
  });

  final AppAsyncState<T> state;
  final Widget Function(BuildContext context, T data, bool isRefreshing)
  dataBuilder;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptySubtitle;
  final String errorTitle;
  final String? loadingLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final data = state.data;
    if (data != null &&
        (state.status == AppAsyncStatus.data ||
            state.status == AppAsyncStatus.loading ||
            state.status == AppAsyncStatus.error)) {
      final content = dataBuilder(context, data, state.isRefreshing);
      if (onRefresh == null) return content;
      return RefreshIndicator(onRefresh: onRefresh!, child: content);
    }

    return switch (state.status) {
      AppAsyncStatus.idle ||
      AppAsyncStatus.loading => _LoadingState(label: loadingLabel),
      AppAsyncStatus.empty => _EmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        padding: padding,
        onRetry: onRetry,
      ),
      AppAsyncStatus.error => _ErrorState(
        title: errorTitle,
        message: state.error?.toString(),
        padding: padding,
        onRetry: onRetry,
      ),
      AppAsyncStatus.data => _EmptyState(
        title: emptyTitle,
        subtitle: emptySubtitle,
        padding: padding,
        onRetry: onRetry,
      ),
    };
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.padding,
    this.subtitle,
    this.onRetry,
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.padding,
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
