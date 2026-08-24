import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:virtual_desktop/features/preview/presentation/video_fullscreen_page.dart';
import 'subtitle_models.dart';
import 'video_playback_controller.dart';
import 'video_player_controls.dart';

class VideoViewer extends StatefulWidget {
  const VideoViewer({
    super.key,
    required this.url,
    this.fileName = 'Video',
    this.subtitleTracks = const [],
  });

  final String url;
  final String fileName;

  /// Subtitle tracks available for this video, pre-parsed via
  /// [parseSubtitleContent]. Empty by default — no subtitle source is
  /// wired up in FileItem yet (SRT/WebVTT attachment is a later addition
  /// per Video-Viewer-Enhancements.md's "Future Enhancements"), but the
  /// picker in the controls is ready to use as soon as one is.
  final List<SubtitleTrack> subtitleTracks;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late final VideoPlayerController _controller;
  late final VideoPlaybackController _playback;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(false)
      ..initialize().then((_) {
        if (mounted) setState(() => _isInitialized = true);
      });
    _playback = VideoPlaybackController(
      controller: _controller,
      subtitleTracks: widget.subtitleTracks,
    );
  }

  @override
  void dispose() {
    _playback.dispose(); // also disposes _controller
    super.dispose();
  }

  Future<void> _openFullscreen() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            VideoFullscreenPage(playback: _playback, fileName: widget.fileName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    _controller.setPreventsDisplaySleepDuringVideoPlayback(true);
    return VideoPlayerView(
      playback: _playback,
      fileName: widget.fileName,
      isFullscreen: false,
      onToggleFullscreen: _openFullscreen,
    );
  }
}
