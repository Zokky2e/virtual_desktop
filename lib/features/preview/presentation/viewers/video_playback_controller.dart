import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'subtitle_models.dart';

/// Shared playback state for a single video — created once by VideoViewer
/// and handed to both the inline VideoPlayerView and the fullscreen page,
/// so entering/exiting fullscreen never tears down or recreates the
/// underlying VideoPlayerController. Position, volume, and subtitle
/// selection all survive the transition.
class VideoPlaybackController extends ChangeNotifier {
  VideoPlaybackController({
    required this.controller,
    this.subtitleTracks = const [],
  });

  final VideoPlayerController controller;
  final List<SubtitleTrack> subtitleTracks;

  double _volumeBeforeMute = 1.0;
  SubtitleTrack? _activeSubtitleTrack;

  SubtitleTrack? get activeSubtitleTrack => _activeSubtitleTrack;
  bool get isMuted => controller.value.volume == 0;

  void setSubtitleTrack(SubtitleTrack? track) {
    _activeSubtitleTrack = track;
    notifyListeners();
  }

  void togglePlayPause() {
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void toggleMute() {
    if (isMuted) {
      controller.setVolume(_volumeBeforeMute == 0 ? 1.0 : _volumeBeforeMute);
    } else {
      _volumeBeforeMute = controller.value.volume;
      controller.setVolume(0);
    }
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped > 0) _volumeBeforeMute = clamped;
    controller.setVolume(clamped);
  }

  /// Skips playback by [delta] (negative to skip back), clamped to
  /// [0, duration] per the "clamp seeking within the video duration"
  /// requirement.
  void skip(Duration delta) => seekTo(controller.value.position + delta);

  void seekTo(Duration position) {
    final duration = controller.value.duration;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > duration ? duration : position);
    controller.seekTo(clamped);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
