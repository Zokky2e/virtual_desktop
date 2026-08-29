import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vlc_player/vlc_player.dart';

import 'subtitle_models.dart';
import 'vlc_video_playback_controller.dart';

class VideoViewer extends StatefulWidget {
  const VideoViewer({
    super.key,
    required this.url,
    this.fileName = 'Video',
    this.subtitleTracks = const [],
  });

  final String url;
  final String fileName;
  final List<SubtitleTrack> subtitleTracks;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late final VlcPlayerController _controller;
  late final VlcVideoPlaybackController _playback;

  final OverlayPortalController _fullscreenOverlayController =
      OverlayPortalController(debugLabel: 'video-viewer-fullscreen');

  final GlobalKey<_DesktopVideoPlayerViewState> _playerKey =
      GlobalKey<_DesktopVideoPlayerViewState>();

  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();

    _controller = VlcPlayerController(
      mediaSource: VlcMediaSource(uri: Uri.parse(widget.url)),
      autoPlay: true,
    );

    _playback = VlcVideoPlaybackController(
      controller: _controller,
      subtitleTracks: widget.subtitleTracks,
    );
  }

  @override
  void dispose() {
    _fullscreenOverlayController.hide();
    _playback.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _enterFullscreen() {
    if (_isFullscreen || !mounted) return;

    _fullscreenOverlayController.show();

    setState(() {
      _isFullscreen = true;
    });
  }

  void _exitFullscreen() {
    if (!_isFullscreen || !mounted) return;

    _fullscreenOverlayController.hide();

    setState(() {
      _isFullscreen = false;
    });
  }

  Widget _buildPlayer() {
    return _DesktopVideoPlayerView(
      key: _playerKey,
      playback: _playback,
      fileName: widget.fileName,
      isFullscreen: _isFullscreen,
      onToggleFullscreen: _toggleFullscreen,
      onRequestClose: _exitFullscreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      overlayLocation: OverlayChildLocation.rootOverlay,
      controller: _fullscreenOverlayController,
      overlayChildBuilder: (_) {
        return Positioned.fill(child: _buildPlayer());
      },
      child: _isFullscreen ? const SizedBox.shrink() : _buildPlayer(),
    );
  }
}

class _DesktopVideoPlayerView extends StatefulWidget {
  const _DesktopVideoPlayerView({
    super.key,
    required this.playback,
    required this.fileName,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onRequestClose,
  });

  final VlcVideoPlaybackController playback;
  final String fileName;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onRequestClose;

  @override
  State<_DesktopVideoPlayerView> createState() =>
      _DesktopVideoPlayerViewState();
}

class _DesktopVideoPlayerViewState extends State<_DesktopVideoPlayerView> {
  static const _skipAmount = Duration(seconds: 10);
  static const _autoHideDelay = Duration(seconds: 3);

  bool _controlsVisible = true;
  bool _showVolumeSlider = false;

  Timer? _hideTimer;
  final _focusNode = FocusNode();

  VlcPlayerController get _controller => widget.playback.controller;

  VlcPlayerValue get _value => _controller.value;

  @override
  void initState() {
    super.initState();

    _controller.addListener(_onControllerChanged);
    widget.playback.addListener(_onPlaybackChanged);

    // The native VLC controller must be attached before subtitle discovery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.playback.loadEmbeddedSubtitleTracks());
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    widget.playback.removeListener(_onPlaybackChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (!_value.isPlaying && !_controlsVisible) {
      setState(() => _controlsVisible = true);
    } else {
      setState(() {});
    }

    if (_value.isReady) {
      unawaited(widget.playback.loadEmbeddedSubtitleTracks());
    }
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();

    if (!_value.isPlaying) return;

    _hideTimer = Timer(_autoHideDelay, () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleAutoHide();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        unawaited(widget.playback.togglePlayPause());
        _showControls();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
        unawaited(widget.playback.skip(-_skipAmount));
        _showControls();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        unawaited(widget.playback.skip(_skipAmount));
        _showControls();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyF:
        widget.onToggleFullscreen();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.escape:
        if (widget.isFullscreen) {
          widget.onRequestClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;

      case LogicalKeyboardKey.keyM:
        unawaited(widget.playback.toggleMute());
        _showControls();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final videoSize = value.videoSize;

    final aspectRatio =
        videoSize != null && videoSize.width > 0 && videoSize.height > 0
        ? videoSize.width / videoSize.height
        : 16 / 9;

    if (value.hasError) {
      return Center(
        child: Text(
          value.errorDescription ?? 'Unable to play video',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    final activeCue = widget.playback.activeSubtitleTrack?.cueAt(
      value.position,
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: MouseRegion(
        onHover: (_) => _showControls(),
        child: GestureDetector(
          onTap: () {
            if (_controlsVisible) {
              unawaited(widget.playback.togglePlayPause());
              _scheduleAutoHide();
            } else {
              _showControls();
            }
          },
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(child: ColoredBox(color: Colors.black)),

                Center(
                  child: AspectRatio(
                    aspectRatio: aspectRatio,
                    child: VlcPlayer(
                      controller: _controller,
                      backgroundColor: Colors.black,
                      fit: VlcVideoFit.fill,
                    ),
                  ),
                ),

                if (activeCue != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: _controlsVisible ? 76 : 24,
                    child: _SubtitleText(text: activeCue.text),
                  ),

                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: Column(
                      children: [
                        _TopBar(
                          fileName: widget.fileName,
                          isFullscreen: widget.isFullscreen,
                          onExitFullscreen: widget.onRequestClose,
                        ),
                        const Spacer(),
                        _BottomBar(
                          playback: widget.playback,
                          isFullscreen: widget.isFullscreen,
                          onToggleFullscreen: widget.onToggleFullscreen,
                          formatDuration: _formatDuration,
                          showVolumeSlider: _showVolumeSlider,
                          onShowVolumeSlider: (show) {
                            setState(() => _showVolumeSlider = show);
                          },
                          onInteract: _showControls,
                        ),
                      ],
                    ),
                  ),
                ),

                if (!value.isReady && !value.hasError)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.fileName,
    required this.isFullscreen,
    required this.onExitFullscreen,
  });

  final String fileName;
  final bool isFullscreen;
  final VoidCallback onExitFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          if (isFullscreen)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              tooltip: 'Exit fullscreen',
              onPressed: onExitFullscreen,
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.playback,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.formatDuration,
    required this.showVolumeSlider,
    required this.onShowVolumeSlider,
    required this.onInteract,
  });

  final VlcVideoPlaybackController playback;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final String Function(Duration) formatDuration;
  final bool showVolumeSlider;
  final ValueChanged<bool> onShowVolumeSlider;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    final value = playback.value;
    final duration = value.duration;
    final position = value.position;

    final sliderMax = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;

    final sliderValue = position.inMilliseconds
        .clamp(0, sliderMax.toInt())
        .toDouble();

    final volume = (value.volume / 200).clamp(0.0, 1.0);

    final hasSubtitles =
        playback.subtitleTracks.isNotEmpty ||
        playback.embeddedSubtitleTracks.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: sliderValue,
              min: 0,
              max: sliderMax,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: duration.inMilliseconds > 0
                  ? (v) {
                      onInteract();
                      unawaited(
                        playback.seekTo(Duration(milliseconds: v.toInt())),
                      );
                    }
                  : null,
            ),
          ),

          Row(
            children: [
              IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  unawaited(playback.togglePlayPause());
                  onInteract();
                },
              ),

              IconButton(
                icon: const Icon(
                  Icons.replay_10,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Back 10 seconds',
                onPressed: () {
                  unawaited(playback.skip(const Duration(seconds: -10)));
                  onInteract();
                },
              ),

              IconButton(
                icon: const Icon(
                  Icons.forward_10,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Forward 10 seconds',
                onPressed: () {
                  unawaited(playback.skip(const Duration(seconds: 10)));
                  onInteract();
                },
              ),

              Text(
                '${formatDuration(position)} / ${formatDuration(duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),

              const Spacer(),

              if (hasSubtitles)
                _SubtitleMenu(playback: playback, onInteract: onInteract),

              MouseRegion(
                onEnter: (_) => onShowVolumeSlider(true),
                onExit: (_) => onShowVolumeSlider(false),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        playback.isMuted
                            ? Icons.volume_off
                            : volume > 0.5
                            ? Icons.volume_up
                            : Icons.volume_down,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        unawaited(playback.toggleMute());
                        onInteract();
                      },
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: showVolumeSlider ? 120 : 0,
                      child: showVolumeSlider
                          ? Slider(
                              value: volume,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                              onChanged: (v) {
                                unawaited(playback.setVolume(v));
                                onInteract();
                              },
                            )
                          : null,
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: Icon(
                  isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                onPressed: onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubtitleMenu extends StatelessWidget {
  const _SubtitleMenu({required this.playback, required this.onInteract});

  final VlcVideoPlaybackController playback;
  final VoidCallback onInteract;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SubtitleSelection>(
      tooltip: 'Subtitles',
      icon: const Icon(Icons.subtitles, color: Colors.white, size: 20),
      onSelected: (selection) {
        switch (selection.type) {
          case _SubtitleSelectionType.off:
            unawaited(playback.disableSubtitles());

          case _SubtitleSelectionType.external:
            unawaited(playback.setSubtitleTrack(selection.externalTrack));

          case _SubtitleSelectionType.embedded:
            unawaited(
              playback.setEmbeddedSubtitleTrack(selection.embeddedTrack),
            );

          case _SubtitleSelectionType.section:
            return;
        }

        onInteract();
      },
      itemBuilder: (context) => [
        PopupMenuItem<_SubtitleSelection>(
          value: const _SubtitleSelection.off(),
          child: Text(
            'Off',
            style: TextStyle(
              fontWeight:
                  playback.activeSubtitleTrack == null &&
                      playback.activeEmbeddedSubtitleTrack == null
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),

        if (playback.subtitleTracks.isNotEmpty)
          const PopupMenuItem<_SubtitleSelection>(
            enabled: false,
            value: _SubtitleSelection.section(),
            child: Text('External'),
          ),

        for (final track in playback.subtitleTracks)
          PopupMenuItem<_SubtitleSelection>(
            value: _SubtitleSelection.external(track),
            child: Row(
              children: [
                if (playback.activeSubtitleTrack == track)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(track.label)),
              ],
            ),
          ),

        if (playback.embeddedSubtitleTracks.isNotEmpty)
          const PopupMenuItem<_SubtitleSelection>(
            enabled: false,
            value: _SubtitleSelection.section(),
            child: Text('Embedded'),
          ),

        for (final track in playback.embeddedSubtitleTracks)
          PopupMenuItem<_SubtitleSelection>(
            value: _SubtitleSelection.embedded(track),
            child: Row(
              children: [
                if (playback.activeEmbeddedSubtitleTrack?.id == track.id)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(track.label)),
              ],
            ),
          ),
      ],
    );
  }
}

enum _SubtitleSelectionType { off, external, embedded, section }

class _SubtitleSelection {
  const _SubtitleSelection._({
    required this.type,
    this.externalTrack,
    this.embeddedTrack,
  });

  const _SubtitleSelection.off() : this._(type: _SubtitleSelectionType.off);

  const _SubtitleSelection.external(SubtitleTrack track)
    : this._(type: _SubtitleSelectionType.external, externalTrack: track);

  const _SubtitleSelection.embedded(VlcEmbeddedSubtitleTrack track)
    : this._(type: _SubtitleSelectionType.embedded, embeddedTrack: track);

  const _SubtitleSelection.section()
    : this._(type: _SubtitleSelectionType.section);

  final _SubtitleSelectionType type;
  final SubtitleTrack? externalTrack;
  final VlcEmbeddedSubtitleTrack? embeddedTrack;
}
