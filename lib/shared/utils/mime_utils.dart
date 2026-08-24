/// Best-effort extension → MIME type mapping.
/// file_picker doesn't reliably expose MIME type on web, only the file
/// extension, so this fills that gap for upload classification.
const Map<String, String> _extensionToMimeType = {
  // images
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  // video
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'mkv': 'video/x-matroska',
  // audio
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'm4a': 'audio/mp4',
  // documents
  'pdf': 'application/pdf',
  'json': 'application/json',
  'md': 'text/markdown',
  'markdown': 'text/markdown',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'srt': 'application/x-subrip',
  'vtt': 'text/vtt',
};

/// Returns a best-guess MIME type for [fileName] based on its extension,
/// falling back to 'application/octet-stream' for anything unrecognized.
String mimeTypeForFileName(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == fileName.length - 1) {
    return 'application/octet-stream';
  }
  final extension = fileName.substring(dotIndex + 1).toLowerCase();
  return _extensionToMimeType[extension] ?? 'application/octet-stream';
}
