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

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerStateChanged.listen(
      (state) => setState(() => _isPlaying = state == PlayerState.playing),
    );
    _player.setSourceUrl(widget.url);
  }

  @override
  void dispose() {
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
