import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoViewer extends StatefulWidget {
  const VideoViewer({
    super.key,
    required this.filePaths,
    this.initialIndex = 0,
    this.tag,
  });

  final List<String> filePaths;
  final int initialIndex;
  final String? tag;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};
  final Map<int, Future<void>> _initFutures = <int, Future<void>>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    for (int index = 0; index < widget.filePaths.length; index += 1) {
      final controller = VideoPlayerController.file(
        File(widget.filePaths[index]),
      );
      _controllers[index] = controller;
      _initFutures[index] = controller.initialize();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final VideoPlayerController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _playPause(int index) {
    final controller = _controllers[index]!;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        title: const Text('视频预览'),
      ),
      body: PageView.builder(
        controller: _pageController,
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
              onVerticalDragEnd: (DragEndDetails details) {
                if (details.velocity.pixelsPerSecond.dy > 200) {
                  Navigator.of(context).pop();
                }
              },
              child: Center(
                child: FutureBuilder<void>(
                  future: _initFutures[index],
                  builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CircularProgressIndicator();
                    }
                    return Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                        GestureDetector(
                          onTap: () => _playPause(index),
                          child: AnimatedOpacity(
                            opacity: controller.value.isPlaying ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              color: Colors.black26,
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 24,
                          right: 24,
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.blue,
                              backgroundColor: Colors.white24,
                              bufferedColor: Colors.white38,
                            ),
                          ),
                        ),
                      ],
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

class VideoThumbnailWidget extends StatefulWidget {
  const VideoThumbnailWidget({super.key, required this.filePath});

  final String filePath;

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (!mounted) {
          return;
        }
        _controller.pause();
        setState(() {
          _initialized = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      );
    }
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.grey, size: 48),
      ),
    );
  }
}
