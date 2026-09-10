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

  /// Non-null once the video is known to be unplayable. Without this the
  /// viewer sat on its spinner forever: a 404, an expired stream token or
  /// a codec the browser can't decode never sets [_isInitialized], and
  /// nothing else was watching for the failure. The desktop viewer has
  /// always rendered `value.errorDescription`; this is the same behaviour
  /// on the web variant.
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(false);
    // Two different failure shapes: a rejected initialize() future (bad
    // URL, network error) and a later value.hasError (browser refuses the
    // codec, stream dies mid-load). Both have to be caught.
    _controller
        .initialize()
        .then((_) {
          if (mounted) setState(() => _isInitialized = true);
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e.toString());
        });
    _controller.addListener(_onControllerChanged);
    _playback = VideoPlaybackController(
      controller: _controller,
      subtitleTracks: widget.subtitleTracks,
    );
  }

  void _onControllerChanged() {
    if (!mounted || _error != null) return;
    final value = _controller.value;
    if (value.hasError) {
      setState(() => _error = value.errorDescription ?? 'Unable to play video');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
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
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white)),
      );
    }
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
