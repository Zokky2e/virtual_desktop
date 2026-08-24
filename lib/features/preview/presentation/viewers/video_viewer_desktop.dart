import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

/// Desktop (Windows/Linux/macOS) video preview — backed by libVLC via
/// flutter_vlc_player instead of the platform-native <video> tag
/// video_player relies on. This is what lets .mkv (and other
/// browser-unfriendly codecs/containers) play without the ffmpeg
/// transcode pipeline described in Browser-Compatible-Video-Streaming.md.
///
/// NOTE: flutter_vlc_player had a breaking API refactor at v5 — if any
/// call below doesn't match your installed version, check the package's
/// example app on pub.dev before assuming something else is wrong.
/// See Windows-Desktop-Video-Player-VLC-Plan.md for the fallback plan
/// if this ends up using too much CPU.
class VideoViewer extends StatefulWidget {
  const VideoViewer({super.key, required this.url});
  final String url;

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late final VlcPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(
      widget.url,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
  }

  @override
  void dispose() {
    _controller.stopRendererScanning();
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VlcPlayer(
              controller: _controller,
              aspectRatio: 16 / 9,
              placeholder: const Center(child: CircularProgressIndicator()),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final value = _controller.value;
                if (!value.isInitialized) return const SizedBox.shrink();
                final durationMs = value.duration.inMilliseconds;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.black45,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: () => value.isPlaying
                            ? _controller.pause()
                            : _controller.play(),
                      ),
                      Text(
                        _formatDuration(value.position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: value.position.inMilliseconds
                              .clamp(0, durationMs == 0 ? 1 : durationMs)
                              .toDouble(),
                          max: (durationMs == 0 ? 1 : durationMs).toDouble(),
                          onChanged: (v) => _controller.seekTo(
                            Duration(milliseconds: v.toInt()),
                          ),
                        ),
                      ),
                      Text(
                        _formatDuration(value.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
