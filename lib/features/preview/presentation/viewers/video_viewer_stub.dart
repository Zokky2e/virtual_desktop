import 'package:flutter/material.dart';
import 'package:virtual_desktop/features/preview/presentation/viewers/subtitle_models.dart';

/// Should never actually be selected — every real Flutter target exposes
/// either dart:html (web) or dart:io (everything else). Exists only
/// because conditional exports require a default fallback file.
class VideoViewer extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Video preview is not supported on this platform.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
