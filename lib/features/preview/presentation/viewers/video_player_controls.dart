import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'subtitle_models.dart';
import 'video_playback_controller.dart';

/// The video surface + all playback chrome (controls, subtitles,
/// auto-hide, keyboard shortcuts). Used identically inline and in
/// [VideoFullscreenPage] — only [isFullscreen] and the close callback
/// differ between the two.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.playback,
    required this.fileName,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onRequestClose,
  });

  final VideoPlaybackController playback;
  final String fileName;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  /// Only meaningful in fullscreen mode — closes the fullscreen page.
  final VoidCallback? onRequestClose;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  static const _skipAmount = Duration(seconds: 10);
  static const _autoHideDelay = Duration(seconds: 3);

  bool _controlsVisible = true;
  Timer? _hideTimer;
  final _focusNode = FocusNode();

  VideoPlayerController get _controller => widget.playback.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Keep controls visible whenever paused/ended — only the "hide after
    // 3s while playing" path is allowed to hide them. Deliberately does
    // NOT reschedule the hide timer here — this listener fires on every
    // position tick during playback, so rescheduling here would mean
    // controls never hide.
    if (!_controller.value.isPlaying && !_controlsVisible) {
      setState(() => _controlsVisible = true);
    } else {
      setState(() {}); // cheap refresh for time/progress display
    }
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (!_controller.value.isPlaying) return;
    _hideTimer = Timer(_autoHideDelay, () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleAutoHide();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        widget.playback.togglePlayPause();
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        widget.playback.skip(-_skipAmount);
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        widget.playback.skip(_skipAmount);
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        widget.onToggleFullscreen();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        widget.playback.toggleMute();
        _showControls();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeCue = widget.playback.activeSubtitleTrack?.cueAt(
      _controller.value.position,
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
              widget.playback.togglePlayPause();
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
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio == 0
                        ? 16 / 9
                        : _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
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
                          showClose: widget.isFullscreen,
                          onClose: widget.onRequestClose,
                        ),
                        const Spacer(),
                        _BottomBar(
                          playback: widget.playback,
                          isFullscreen: widget.isFullscreen,
                          onToggleFullscreen: widget.onToggleFullscreen,
                          onInteract: _showControls,
                        ),
                      ],
                    ),
                  ),
                ),
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
    required this.showClose,
    this.onClose,
  });

  final String fileName;
  final bool showClose;
  final VoidCallback? onClose;

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
          if (showClose)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              tooltip: 'Exit fullscreen',
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.playback,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onInteract,
  });

  final VideoPlaybackController playback;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onInteract;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _showVolumeSlider = false;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.playback.controller;
    final value = controller.value;
    final duration = value.duration;
    final position = value.position;
    final sliderMax = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final sliderValue = position.inMilliseconds
        .clamp(0, sliderMax.toInt())
        .toDouble();

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
                      widget.onInteract();
                      widget.playback.seekTo(Duration(milliseconds: v.toInt()));
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
                  widget.playback.togglePlayPause();
                  widget.onInteract();
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
                  widget.playback.skip(const Duration(seconds: -10));
                  widget.onInteract();
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
                  widget.playback.skip(const Duration(seconds: 10));
                  widget.onInteract();
                },
              ),
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              if (widget.playback.subtitleTracks.isNotEmpty)
                PopupMenuButton<SubtitleTrack?>(
                  tooltip: 'Subtitles',
                  icon: const Icon(
                    Icons.subtitles,
                    color: Colors.white,
                    size: 20,
                  ),
                  onSelected: (track) {
                    widget.playback.setSubtitleTrack(track);
                    widget.onInteract();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: null,
                      child: Text(
                        'Off',
                        style: TextStyle(
                          fontWeight:
                              widget.playback.activeSubtitleTrack == null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    for (final track in widget.playback.subtitleTracks)
                      PopupMenuItem(
                        value: track,
                        child: Text(
                          track.label,
                          style: TextStyle(
                            fontWeight:
                                widget.playback.activeSubtitleTrack == track
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              MouseRegion(
                onEnter: (_) => setState(() => _showVolumeSlider = true),
                onExit: (_) => setState(() => _showVolumeSlider = false),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        widget.playback.isMuted
                            ? Icons.volume_off
                            : value.volume > 0.5
                            ? Icons.volume_up
                            : Icons.volume_down,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () {
                        widget.playback.toggleMute();
                        widget.onInteract();
                      },
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _showVolumeSlider ? 120 : 0,
                      child: _showVolumeSlider
                          ? Slider(
                              value: value.volume.clamp(0.0, 1.0),
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                              onChanged: (v) {
                                widget.playback.setVolume(v);
                                widget.onInteract();
                              },
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  widget.isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: widget.isFullscreen ? 'Exit fullscreen' : 'Fullscreen',
                onPressed: widget.onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
