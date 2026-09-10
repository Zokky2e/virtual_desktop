import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';

/// Talks to the wallpaper endpoints under [basePath] (see
/// ../virtual-api/app/api/wallpapers.py).
///
/// Deliberately a separate client from FilesApi rather than another
/// basePath on it: wallpapers are not file-tree items, so they have no
/// parent folder, no move/rename/recycle-bin, and no WebSocket events.
/// Routing them through FilesApi is what previously dropped a wallpaper
/// into the root of the user's personal tree on every upload.
class WallpapersApi {
  WallpapersApi(this._client, {this.basePath = '/desktop/wallpapers'});

  final ApiClient _client;
  final String basePath;

  Future<List<Map<String, dynamic>>> list() async {
    final res = await _client.dio.get<List<dynamic>>(basePath);
    return (res.data ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getItem(String wallpaperId) async {
    final res = await _client.dio.get('$basePath/$wallpaperId');
    return res.data as Map<String, dynamic>;
  }

  /// Bytes and metadata row are created together server-side; the
  /// returned body is the new record.
  Future<Map<String, dynamic>> upload({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    });
    final res = await _client.dio.post(
      '$basePath/upload',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) onProgress(sent / total);
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Applies one wallpaper. The server clears whichever was previously
  /// set in the same transaction, so this is single-selection, not a
  /// per-row toggle.
  Future<Map<String, dynamic>> setActive(String wallpaperId) async {
    final res = await _client.dio.patch('$basePath/$wallpaperId/active');
    return res.data as Map<String, dynamic>;
  }
}
