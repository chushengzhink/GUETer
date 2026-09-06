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
      final body = onRefresh == null
          ? content
          : RefreshIndicator(onRefresh: onRefresh!, child: content);
      if (!state.hasError) return body;
      final en = Localizations.localeOf(context).languageCode == 'en';
      return Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.sync_problem_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        en
                            ? 'Refresh failed. Showing previous content.'
                            : '刷新失败，已保留原有内容。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      child: Text(en ? 'Retry' : '重试'),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
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
                label: Text(
                  Localizations.localeOf(context).languageCode == 'en'
                      ? 'Refresh'
                      : '刷新',
                ),
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
                label: Text(
                  Localizations.localeOf(context).languageCode == 'en'
                      ? 'Retry'
                      : '重试',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
