import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/nasa_api.dart';

class ApodDetailPage extends StatelessWidget {
  const ApodDetailPage({super.key, required this.apod});

  final NasaApodData apod;

  void _openImagePreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ApodImagePreviewPage(apod: apod),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.apodDetailTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: apod.isImage
                      ? Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('apodDetailImageTapTarget'),
                            onTap: () => _openImagePreview(context),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _ApodNetworkImage(url: apod.url),
                                Positioned(
                                  right: 14,
                                  bottom: 14,
                                  child: DecoratedBox(
                                    key: const Key('apodImageZoomHint'),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.52),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Icon(
                                        Icons.zoom_in_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Image.asset(
                          'images/placeholder.png',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              if (!apod.isImage) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.apodNonImageNotice,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                apod.title,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.apodDateLabel}: ${apod.date}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.apodAboutLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                apod.explanation,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApodNetworkImage extends StatelessWidget {
  const _ApodNetworkImage({required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (context, progress) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      errorWidget: (context, imageUrl, error) => Image.asset(
        'images/placeholder.png',
        fit: fit,
      ),
    );
  }
}

class _ApodImagePreviewPage extends StatefulWidget {
  const _ApodImagePreviewPage({required this.apod});

  final NasaApodData apod;

  @override
  State<_ApodImagePreviewPage> createState() => _ApodImagePreviewPageState();
}

class _ApodImagePreviewPageState extends State<_ApodImagePreviewPage> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isZoomed = false;

  static const double _doubleTapScale = 2.4;
  static const double _zoomThreshold = 1.05;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final isCurrentlyZoomed =
        _transformationController.value.getMaxScaleOnAxis() > _zoomThreshold;
    _transformationController.value = isCurrentlyZoomed
        ? Matrix4.identity()
        : Matrix4.diagonal3Values(_doubleTapScale, _doubleTapScale, 1);
    setState(() {
      _isZoomed = !isCurrentlyZoomed;
    });
  }

  void _syncZoomState() {
    final isZoomed =
        _transformationController.value.getMaxScaleOnAxis() > _zoomThreshold;
    if (isZoomed == _isZoomed) {
      return;
    }
    setState(() {
      _isZoomed = isZoomed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('apodImagePreviewPage'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isZoomed ? null : () => Navigator.of(context).pop(),
              onDoubleTap: _toggleZoom,
              onVerticalDragEnd: (details) {
                if (_isZoomed) {
                  return;
                }
                if (details.velocity.pixelsPerSecond.dy.abs() > 220) {
                  Navigator.of(context).pop();
                }
              },
              child: Center(
                child: InteractiveViewer(
                  key: const Key('apodImagePreviewInteractiveViewer'),
                  transformationController: _transformationController,
                  minScale: 1,
                  maxScale: 5,
                  onInteractionEnd: (_) => _syncZoomState(),
                  child: _ApodNetworkImage(
                    url: widget.apod.url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    widget.apod.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
