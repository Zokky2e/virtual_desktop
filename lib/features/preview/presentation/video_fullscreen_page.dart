import 'package:flutter/material.dart';
import 'package:virtual_desktop/features/preview/presentation/viewers/video_playback_controller.dart';
import 'package:virtual_desktop/features/preview/presentation/viewers/video_player_controls.dart';
import 'video_browser_fullscreen.dart';

/// Dedicated fullscreen page — pushed on top of the preview window,
/// reusing the same [VideoPlaybackController] (and therefore the same
/// [VideoPlayerController]) so playback is seamless across the
/// transition.
class VideoFullscreenPage extends StatefulWidget {
  const VideoFullscreenPage({
    super.key,
    required this.playback,
    required this.fileName,
  });

  final VideoPlaybackController playback;
  final String fileName;

  @override
  State<VideoFullscreenPage> createState() => _VideoFullscreenPageState();
}

class _VideoFullscreenPageState extends State<VideoFullscreenPage> {
  @override
  void initState() {
    super.initState();
    requestBrowserFullscreen();
  }

  @override
  void dispose() {
    exitBrowserFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: VideoPlayerView(
          playback: widget.playback,
          fileName: widget.fileName,
          isFullscreen: true,
          onToggleFullscreen: () => Navigator.of(context).pop(),
          onRequestClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
