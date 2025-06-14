import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ServiceVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const ServiceVideoPlayer({super.key, required this.videoUrl});

  @override
  State<ServiceVideoPlayer> createState() => _ServiceVideoPlayerState();
}

class _ServiceVideoPlayerState extends State<ServiceVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
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
    return _isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          _ControlsOverlay(controller: _controller),
          VideoProgressIndicator(_controller, allowScrubbing: true),
        ],
      ),
    )
        : const Center(child: CircularProgressIndicator());
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _ControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        controller.value.isPlaying ? controller.pause() : controller.play();
      },
      child: Center(
        child: Icon(
          controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
          size: 50,
          color: Colors.white70,
        ),
      ),
    );
  }
}
