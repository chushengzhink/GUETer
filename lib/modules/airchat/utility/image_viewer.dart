import 'dart:io';

import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatefulWidget {
  const FullScreenImageViewer({
    super.key,
    required this.filePaths,
    this.initialIndex = 0,
    this.tag,
  });

  final List<String> filePaths;
  final int initialIndex;
  final String? tag;

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _controllers =
      <int, TransformationController>{};
  final Map<int, bool> _isZoomed = <int, bool>{};

  static const double _minScale = 0.8;
  static const double _maxScale = 5;
  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    for (int index = 0; index < widget.filePaths.length; index += 1) {
      _controllers[index] = TransformationController();
      _isZoomed[index] = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final TransformationController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleDoubleTap(int index, Offset position) {
    final controller = _controllers[index]!;
    if (_isZoomed[index] == true) {
      controller.value = Matrix4.identity();
      _isZoomed[index] = false;
    } else {
      controller.value = Matrix4.diagonal3Values(
        _doubleTapScale,
        _doubleTapScale,
        1,
      );
      _isZoomed[index] = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        title: const Text('图片预览'),
      ),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        physics: _isZoomed[_currentIndex] == true
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        itemCount: widget.filePaths.length,
        onPageChanged: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (BuildContext context, int index) {
          final filePath = widget.filePaths[index];
          final controller = _controllers[index]!;
          return Hero(
            tag: widget.tag != null && index == widget.initialIndex
                ? widget.tag!
                : filePath,
            child: GestureDetector(
              onDoubleTapDown: (TapDownDetails details) {
                _handleDoubleTap(index, details.localPosition);
              },
              onVerticalDragEnd: (DragEndDetails details) {
                if (_isZoomed[index] != true &&
                    details.velocity.pixelsPerSecond.dy > 200) {
                  Navigator.of(context).pop();
                }
              },
              child: InteractiveViewer(
                transformationController: controller,
                minScale: _minScale,
                maxScale: _maxScale,
                onInteractionEnd: (_) {
                  final scale = controller.value.getMaxScaleOnAxis();
                  setState(() {
                    _isZoomed[index] = scale > 1.05;
                  });
                },
                child: Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (BuildContext context, Object error, StackTrace? _) {
                    return Center(
                      child: Text(
                        '图片无法加载: $error',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
