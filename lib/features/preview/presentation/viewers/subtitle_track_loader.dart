import 'dart:convert';
import 'package:virtual_desktop/core/models/file_item.dart';
import 'package:virtual_desktop/core/repositories/file_system_repository.dart';
import 'package:virtual_desktop/core/services/storage_service.dart';

import 'subtitle_models.dart';

/// Small, non-exhaustive lookup for a friendlier subtitle-menu label —
/// falls back to the raw code uppercased for anything not listed.
const _languageNames = {
  'en': 'English',
  'eng': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ar': 'Arabic',
  'hr': 'Croatian',
  'hrv': 'Croatian',
  'sr': 'Serbian',
  'nl': 'Dutch',
  'pl': 'Polish',
  'tr': 'Turkish',
  'sv': 'Swedish',
  'no': 'Norwegian',
  'fi': 'Finnish',
  'da': 'Danish',
};

String _stem(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// "movie" + "movie.en" -> "en". "movie" + "movie" -> null (no code).
/// "movie" + "other-file" -> null (not a sibling at all).
String? _extractLanguageCode(String videoStem, String subtitleStem) {
  final v = videoStem.toLowerCase();
  final s = subtitleStem.toLowerCase();
  if (s == v) return null;
  if (!s.startsWith(v)) return null;
  final remainder = subtitleStem
      .substring(videoStem.length)
      .replaceFirst(RegExp(r'^[._-]+'), '');
  return remainder.isEmpty ? null : remainder;
}

String _labelFor(String? code) {
  if (code == null) return 'Subtitles';
  return _languageNames[code.toLowerCase()] ?? code.toUpperCase();
}

/// Looks for .srt/.vtt files sitting next to [video] in the same folder,
/// matched by filename convention (movie.mp4 <-> movie.srt / movie.en.srt
/// / movie.hr.vtt, etc — the same convention Plex/Jellyfin use). No
/// schema link is needed: FileSystemRepository already scopes by
/// parentFolderId, so this is just a filtered getFolder() call plus a
/// download+parse per match. Works identically for personal and shared
/// trees since it's called with whichever repository/service the caller
/// (PreviewWindowContent) is already using.
Future<List<SubtitleTrack>> loadSiblingSubtitleTracks({
  required FileItem video,
  required FileSystemRepository fileSystemRepository,
  required StorageService storageService,
}) async {
  final folderResult = await fileSystemRepository.getFolder(
    video.parentFolderId,
  );
  final siblings = folderResult.getOrElse((_) => const []);
  final videoStem = _stem(video.name);
  final matches = siblings.where((item) {
    if (item.type != FileItemType.subtitle || item.storageKey == null) {
      return false;
    }
    final lowerName = item.name.toLowerCase();
    if (!(lowerName.endsWith('.srt') || lowerName.endsWith('.vtt'))) {
      return false;
    }
    return _stem(item.name).toLowerCase().startsWith(videoStem.toLowerCase());
  });

  final tracks = <SubtitleTrack>[];
  for (final sub in matches) {
    final downloadResult = await storageService.downloadFile(sub.storageKey!);
    downloadResult.match((_) {}, (bytes) {
      try {
        final code = _extractLanguageCode(videoStem, _stem(sub.name));
        tracks.add(
          parseSubtitleContent(
            content: utf8.decode(bytes),
            label: _labelFor(code),
            language: code,
          ),
        );
      } catch (_) {
        // Malformed subtitle file — skip it, don't fail the video preview.
      }
    });
  }
  return tracks;
}
