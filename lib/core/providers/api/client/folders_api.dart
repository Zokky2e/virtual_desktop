import 'api_client.dart';

class FoldersApi {
  FoldersApi(this._client);
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> listRoot() async {
    final res = await _client.dio.get('/desktop');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<List<Map<String, dynamic>>> listFolder(String folderId) async {
    final res = await _client.dio.get('/desktop/folder/$folderId');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<Map<String, dynamic>> createFolder({
    required String name,
    required String? parentFolderId,
  }) async {
    final res = await _client.dio.post(
      '/desktop/folder',
      data: {'name': name, 'parent_folder_id': parentFolderId},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final res = await _client.dio.get(
      '/desktop/search',
      queryParameters: {'q': query},
    );
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<List<Map<String, dynamic>>> listRecycleBin() async {
    final res = await _client.dio.get('/desktop/recycle-bin');
    return List<Map<String, dynamic>>.from(res.data as List);
  }

  Future<void> restoreItem(String itemId) =>
      _client.dio.post('/desktop/recycle-bin/$itemId/restore');

  Future<void> purgeItem(String itemId) =>
      _client.dio.delete('/desktop/recycle-bin/$itemId');
}
