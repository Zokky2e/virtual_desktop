import 'package:flutter/foundation.dart';
import 'package:vlc_player/vlc_player.dart';

import 'subtitle_models.dart';

/// A subtitle track discovered directly inside the media by VLC.
///
/// External .srt/.vtt tracks remain [SubtitleTrack]s because those are
/// rendered by Flutter. Embedded tracks are native VLC tracks and therefore
/// only need the native VLC track id plus the metadata VLC reports.
class VlcEmbeddedSubtitleTrack {
  const VlcEmbeddedSubtitleTrack({
    required this.id,
    required this.label,
    this.language,
  });

  final int id;
  final String label;
  final String? language;
}

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
  VlcEmbeddedSubtitleTrack? _activeEmbeddedSubtitleTrack;

  List<VlcEmbeddedSubtitleTrack> _embeddedSubtitleTracks = const [];
  bool _loadingEmbeddedSubtitleTracks = false;
  bool _embeddedSubtitleTracksLoaded = false;

  SubtitleTrack? get activeSubtitleTrack => _activeSubtitleTrack;

  VlcEmbeddedSubtitleTrack? get activeEmbeddedSubtitleTrack =>
      _activeEmbeddedSubtitleTrack;

  List<VlcEmbeddedSubtitleTrack> get embeddedSubtitleTracks =>
      _embeddedSubtitleTracks;

  bool get isLoadingEmbeddedSubtitleTracks => _loadingEmbeddedSubtitleTracks;

  bool get isMuted => controller.value.volume == 0;

  VlcPlayerValue get value => controller.value;

  void _onControllerChanged() {
    notifyListeners();
  }

  /// Reads the subtitle tracks that VLC found inside the currently loaded
  /// media. This must be called after [VlcPlayer] has attached the controller.
  Future<void> loadEmbeddedSubtitleTracks() async {
    if (_embeddedSubtitleTracksLoaded ||
        _loadingEmbeddedSubtitleTracks ||
        !controller.value.isReady) {
      return;
    }

    _loadingEmbeddedSubtitleTracks = true;
    notifyListeners();

    try {
      final tracks = await controller.getSubtitleTracks();

      _embeddedSubtitleTracks = tracks
          .map(
            (track) => VlcEmbeddedSubtitleTrack(
              id: track.id,
              label: _subtitleLabel(track),
              language: track.language,
            ),
          )
          .toList(growable: false);

      _embeddedSubtitleTracksLoaded = true;
    } catch (_) {
      // Subtitle discovery is optional. A media file without usable native
      // subtitle metadata must not make the video preview fail.
      _embeddedSubtitleTracks = const [];
      _embeddedSubtitleTracksLoaded = true;
    } finally {
      _loadingEmbeddedSubtitleTracks = false;
      notifyListeners();
    }
  }

  String _subtitleLabel(VlcTrackDescription track) {
    final name = track.name.trim();
    final language = track.language?.trim();

    if (name.isNotEmpty) {
      return name;
    }

    if (language != null && language.isNotEmpty) {
      return language.toUpperCase();
    }

    return 'Subtitle ${track.id}';
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

    // Keep the UI abstraction at 0..1 while VLC uses 0..200.
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

  /// Selects an external parsed subtitle track.
  ///
  /// External tracks are rendered by Flutter, so any native VLC subtitle
  /// track must be disabled first.
  Future<void> setSubtitleTrack(SubtitleTrack? track) async {
    if (track != null) {
      await controller.disableSubtitle();
    }

    _activeEmbeddedSubtitleTrack = null;
    _activeSubtitleTrack = track;
    notifyListeners();
  }

  /// Selects an embedded subtitle track supplied by VLC.
  Future<void> setEmbeddedSubtitleTrack(VlcEmbeddedSubtitleTrack? track) async {
    if (track == null) {
      await controller.disableSubtitle();
    } else {
      await controller.setSubtitleTrack(track.id);
    }

    _activeSubtitleTrack = null;
    _activeEmbeddedSubtitleTrack = track;
    notifyListeners();
  }

  /// Turns every subtitle source off.
  Future<void> disableSubtitles() async {
    await controller.disableSubtitle();

    _activeSubtitleTrack = null;
    _activeEmbeddedSubtitleTrack = null;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }
}
