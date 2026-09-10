import 'api_client.dart';

/// Talks to `POST /desktop/transfer` (see ../virtual-api/app/api/transfers.py).
///
/// Unlike FoldersApi and FilesApi there is no `basePath` variant here:
/// the endpoint takes the source and destination trees as fields,
/// because it is the one operation that spans both. The server resolves
/// each name to an owner id from the bearer token and its
/// SHARED_OWNER_ID sentinel — a client never sends an owner id.
class TransfersApi {
  TransfersApi(this._client, {this.basePath = '/desktop'});

  final ApiClient _client;
  final String basePath;

  static String _tree({required bool isShared}) =>
      isShared ? 'shared' : 'personal';

  Future<Map<String, dynamic>> transfer({
    required String itemId,
    required bool fromShared,
    required bool toShared,
    required String? parentFolderId,
    required bool move,
    String? name,
  }) async {
    final res = await _client.dio.post(
      '$basePath/transfer',
      data: {
        'item_id': itemId,
        'source': _tree(isShared: fromShared),
        'destination': _tree(isShared: toShared),
        'parent_folder_id': parentFolderId,
        'move': move,
        'name': ?name,
      },
    );
    return res.data as Map<String, dynamic>;
  }
}
