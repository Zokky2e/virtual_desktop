import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioViewer extends StatefulWidget {
  const AudioViewer({super.key, required this.url});
  final String url;

  @override
  State<AudioViewer> createState() => _AudioViewerState();
}

class _AudioViewerState extends State<AudioViewer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// Held so they can be cancelled. Previously these three were fire-and-
  /// forget: closing the preview window disposed the State but left the
  /// listeners attached, so the next position tick called setState on a
  /// defunct element.
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll([
      _player.onDurationChanged.listen(
        (d) => _apply(() => _duration = d),
      ),
      _player.onPositionChanged.listen(
        (p) => _apply(() => _position = p),
      ),
      _player.onPlayerStateChanged.listen(
        (state) => _apply(() => _isPlaying = state == PlayerState.playing),
      ),
    ]);
    _player.setSourceUrl(widget.url);
  }

  /// A tick can still be in flight between cancel() and disposal, so the
  /// mounted check stays even with the subscriptions owned.
  void _apply(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audiotrack, size: 64, color: Colors.white70),
            const SizedBox(height: 16),
            Slider(
              value: _position.inMilliseconds
                  .clamp(
                    0,
                    _duration.inMilliseconds == 0
                        ? 1
                        : _duration.inMilliseconds,
                  )
                  .toDouble(),
              max: _duration.inMilliseconds == 0
                  ? 1
                  : _duration.inMilliseconds.toDouble(),
              onChanged: (value) =>
                  _player.seek(Duration(milliseconds: value.toInt())),
            ),
            IconButton(
              iconSize: 48,
              color: Colors.white,
              icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
              onPressed: () => _isPlaying ? _player.pause() : _player.resume(),
            ),
          ],
        ),
      ),
    );
  }
}
