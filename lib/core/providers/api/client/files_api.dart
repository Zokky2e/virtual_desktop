import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';

/// Talks to the file-content endpoints under [basePath] — see
/// FoldersApi's docstring for the personal-vs-shared split.
class FilesApi {
  FilesApi(this._client, {this.basePath = '/desktop'});
  final ApiClient _client;
  final String basePath;

  Future<Map<String, dynamic>> getItem(String itemId) async {
    final res = await _client.dio.get('$basePath/file/$itemId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upload({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String? parentFolderId,
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
      queryParameters: parentFolderId != null
          ? {'parent_folder_id': parentFolderId}
          : null,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) onProgress(sent / total);
      },
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Uint8List> download(String itemId) async {
    final res = await _client.dio.get<List<int>>(
      '$basePath/download/$itemId',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data!);
  }

  Future<Map<String, dynamic>> rename(String itemId, String newName) async {
    final res = await _client.dio.patch(
      '$basePath/file/$itemId',
      data: {'name': newName},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> move(
    String itemId,
    String? newParentFolderId,
  ) async {
    final res = await _client.dio.patch(
      '$basePath/move',
      data: {'item_id': itemId, 'parent_folder_id': newParentFolderId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteItem(String itemId) =>
      _client.dio.delete('$basePath/file/$itemId');
}
