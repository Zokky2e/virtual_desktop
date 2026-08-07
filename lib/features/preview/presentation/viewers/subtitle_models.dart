import 'package:equatable/equatable.dart';

/// A single subtitle cue — a span of time with the text shown during it.
class SubtitleCue extends Equatable {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;

  bool contains(Duration position) => position >= start && position <= end;

  @override
  List<Object?> get props => [start, end, text];
}

/// One selectable subtitle track (e.g. "English", "Croatian").
class SubtitleTrack extends Equatable {
  const SubtitleTrack({required this.label, required this.cues, this.language});

  final String label;
  final String? language;
  final List<SubtitleCue> cues;

  /// The cue active at [position], or null if none. Cues are assumed
  /// sorted by start time (parseSubtitleContent guarantees this).
  SubtitleCue? cueAt(Duration position) {
    for (final cue in cues) {
      if (cue.contains(position)) return cue;
      if (cue.start > position) break;
    }
    return null;
  }

  @override
  List<Object?> get props => [label, language, cues];
}

/// Parses subtitle file content into a [SubtitleTrack]. Format is
/// auto-detected: content starting with "WEBVTT" is parsed as WebVTT,
/// everything else is assumed to be SRT.
SubtitleTrack parseSubtitleContent({
  required String content,
  required String label,
  String? language,
}) {
  final isVtt = content.trimLeft().startsWith('WEBVTT');
  final cues = isVtt ? _parseVtt(content) : _parseSrt(content);
  return SubtitleTrack(label: label, language: language, cues: cues);
}

final _srtTimestampPattern = RegExp(
  r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
);

// WebVTT timestamps may omit the hours component when under an hour, so
// this pattern makes the hour groups optional rather than reusing the SRT one.
final _vttTimestampPattern = RegExp(
  r'(?:(\d{2}):)?(\d{2}):(\d{2})[.,](\d{3})\s*-->\s*(?:(\d{2}):)?(\d{2}):(\d{2})[.,](\d{3})',
);

List<SubtitleCue> _parseSrt(String content) {
  final cues = <SubtitleCue>[];
  final blocks = content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
  for (final block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.isEmpty) continue;
    final tsIndex = lines.indexWhere((l) => l.contains('-->'));
    if (tsIndex == -1) continue;
    final match = _srtTimestampPattern.firstMatch(lines[tsIndex]);
    if (match == null) continue;

    Duration parse(int offset) => Duration(
      hours: int.parse(match.group(offset)!),
      minutes: int.parse(match.group(offset + 1)!),
      seconds: int.parse(match.group(offset + 2)!),
      milliseconds: int.parse(match.group(offset + 3)!),
    );

    final text = lines.sublist(tsIndex + 1).join('\n').trim();
    if (text.isEmpty) continue;
    cues.add(SubtitleCue(start: parse(1), end: parse(5), text: text));
  }
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}

List<SubtitleCue> _parseVtt(String content) {
  final cues = <SubtitleCue>[];
  final blocks = content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));
  for (final block in blocks) {
    final lines = block.trim().split('\n');
    if (lines.isEmpty) continue;
    final tsIndex = lines.indexWhere((l) => l.contains('-->'));
    if (tsIndex == -1) continue;
    final match = _vttTimestampPattern.firstMatch(lines[tsIndex]);
    if (match == null) continue;

    Duration parse(int hOffset, int mOffset, int sOffset, int msOffset) {
      final hours = match.group(hOffset) != null
          ? int.parse(match.group(hOffset)!)
          : 0;
      return Duration(
        hours: hours,
        minutes: int.parse(match.group(mOffset)!),
        seconds: int.parse(match.group(sOffset)!),
        milliseconds: int.parse(match.group(msOffset)!),
      );
    }

    final text = lines.sublist(tsIndex + 1).join('\n').trim();
    if (text.isEmpty) continue;
    cues.add(
      SubtitleCue(start: parse(1, 2, 3, 4), end: parse(5, 6, 7, 8), text: text),
    );
  }
  cues.sort((a, b) => a.start.compareTo(b.start));
  return cues;
}
