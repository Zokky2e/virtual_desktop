import 'package:flutter/foundation.dart';
import 'package:vlc_player/vlc_player.dart';

import 'subtitle_models.dart';

class VlcVideoPlaybackController extends ChangeNotifier {
  VlcVideoPlaybackController({
    required this.controller,
    this.subtitleTracks = const [],
  }) {
    controller.addListener(_onControllerChanged);
  }

  final VlcPlayerController controller;
  final List<SubtitleTrack> subtitleTracks;

  double _volumeBeforeMute = 1.0;
  SubtitleTrack? _activeSubtitleTrack;

  SubtitleTrack? get activeSubtitleTrack => _activeSubtitleTrack;

  bool get isMuted => controller.value.volume == 0;

  VlcPlayerValue get value => controller.value;

  void _onControllerChanged() {
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> toggleMute() async {
    if (isMuted) {
      final volume = _volumeBeforeMute == 0 ? 1.0 : _volumeBeforeMute;
      await setVolume(volume);
    } else {
      _volumeBeforeMute = controller.value.volume / 100.0;
      await controller.setVolume(0);
    }
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);

    if (clamped > 0) {
      _volumeBeforeMute = clamped;
    }

    // VLC uses 0..200 while our UI uses 0..1.
    await controller.setVolume((clamped * 100).round());
  }

  Future<void> skip(Duration delta) async {
    await seekTo(controller.value.position + delta);
  }

  Future<void> seekTo(Duration position) async {
    final duration = controller.value.duration;

    final clamped = position < Duration.zero
        ? Duration.zero
        : position > duration
        ? duration
        : position;

    await controller.seekTo(clamped);
  }

  void setSubtitleTrack(SubtitleTrack? track) {
    _activeSubtitleTrack = track;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }
}
