import 'api_client.dart';

/// Talks to the folder/tree endpoints under [basePath] — '/desktop' for
/// the caller's own tree, '/desktop/shared' for the shared tree (see
/// shared-folder-flutter-implementation.md). Both trees use the exact
/// same REST shape server-side, just a different path prefix.
class FoldersApi {
  FoldersApi(this._client, {this.basePath = '/desktop'});
  final ApiClient _client;
  final String basePath;

  Future<List<Map<String, dynamic>>> listRoot() async {
    final res = await _client.dio.get(basePath);
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<List<Map<String, dynamic>>> listFolder(String folderId) async {
    final res = await _client.dio.get('$basePath/folder/$folderId');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<Map<String, dynamic>> createFolder({
    required String name,
    required String? parentFolderId,
  }) async {
    final res = await _client.dio.post(
      '$basePath/folder',
      data: {'name': name, 'parent_folder_id': parentFolderId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final res = await _client.dio.get(
      '$basePath/search',
      queryParameters: {'q': query},
    );
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<List<Map<String, dynamic>>> listRecycleBin() async {
    final res = await _client.dio.get('$basePath/recycle-bin');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<void> restoreItem(String itemId) =>
      _client.dio.post('$basePath/recycle-bin/$itemId/restore');

  Future<void> purgeItem(String itemId) =>
      _client.dio.delete('$basePath/recycle-bin/$itemId');

  /// Shared-tree only — POST {basePath}/sync (see app/api/shared.py).
  /// Scans the server's shared storage folder for files dropped in
  /// out-of-band (scp, wget, etc.) and creates FileRecords for them.
  Future<void> sync() => _client.dio.post('$basePath/sync');
}
