import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../constants.dart';
import '../../../error/failure.dart';
import '../../../models/file_item.dart';
import '../../../repositories/file_system_repository.dart';
import '../client/api_websocket_client.dart';
import '../client/files_api.dart';
import '../client/folders_api.dart';
import '../models/file_response_mapper.dart';

class ApiFileSystemRepository implements FileSystemRepository {
  ApiFileSystemRepository({
    required FoldersApi foldersApi,
    required FilesApi filesApi,
    required ApiWebSocketClient wsClient,
    bool isSharedTree = false,
  }) : _foldersApi = foldersApi,
       _filesApi = filesApi,
       _wsClient = wsClient,
       _isSharedTree = isSharedTree;
  // Deliberately does not connect() here. This is a lazy singleton, so the
  // constructor runs once for the life of the process — a socket opened
  // from it is bound to whichever uid was signed in at that moment and can
  // never be reopened for the next one. The composition root owns the
  // socket's lifecycle against authStateChanges instead; see
  // core/di/injector.dart.

  final FoldersApi _foldersApi;
  final FilesApi _filesApi;
  final ApiWebSocketClient _wsClient;

  /// Which tree this instance serves. Only used to filter the shared
  /// event feed — see [_isForThisTree].
  final bool _isSharedTree;

  /// Shared-tree mutations are broadcast to every connected client, so
  /// both registrations see them on the one socket. Without a tree
  /// marker, a create in the shared root (parent_folder_id null) looked
  /// exactly like one in the caller's own root, and every personal root
  /// watcher re-fetched for a change it could not see.
  ///
  /// A server that predates the marker omits `owner_id`; then this
  /// returns true for everything, which is the old behaviour rather than
  /// a feed that silently goes dead.
  bool _isForThisTree(Map<String, dynamic> event) {
    final eventOwner = event['owner_id'] as String?;
    if (eventOwner == null) return true;
    return (eventOwner == sharedOwnerId) == _isSharedTree;
  }

  @override
  Future<Either<Failure, List<FileItem>>> getFolder(String? folderId) async {
    try {
      final json = folderId == null
          ? await _foldersApi.listRoot()
          : await _foldersApi.listFolder(folderId);
      return Right(json.map(fileItemFromApiJson).toList());
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  @override
  Stream<List<FileItem>> watchFolder(String? folderId) {
    late StreamController<List<FileItem>> controller;
    StreamSubscription? sub;

    Future<void> refresh() async {
      final result = await getFolder(folderId);
      result.match((_) {}, (items) => controller.add(items));
    }

    controller = StreamController<List<FileItem>>.broadcast(
      onListen: () {
        refresh();
        sub = _wsClient.events.listen((event) {
          if (!_isForThisTree(event)) return;
          final eventParent = event['parent_folder_id'] as String?;
          final oldParent = event['old_parent_folder_id'] as String?;
          if (eventParent == folderId || oldParent == folderId) refresh();
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Either<Failure, FileItem>> createFolder({
    required String name,
    required String? parentFolderId,
    required String ownerId,
  }) async {
    try {
      final json = await _foldersApi.createFolder(
        name: name,
        parentFolderId: parentFolderId,
      );
      return Right(fileItemFromApiJson(json));
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  /// See ApiStorageService.uploadFile — the server's /desktop/upload
  /// endpoint already created bytes + this exact metadata record
  /// atomically, and handed back its id as [storageKey]. This just
  /// fetches and returns that record instead of creating a duplicate.
  @override
  Future<Either<Failure, FileItem>> createFile({
    required String name,
    required String? parentFolderId,
    required String ownerId,
    required FileItemType type,
    required String storageKey,
    required int size,
  }) async {
    try {
      final json = await _filesApi.getItem(storageKey);
      return Right(fileItemFromApiJson(json));
    } catch (e) {
      return Left(
        FileSystemFailure(
          'Upload finished but metadata lookup failed: ${_describe(e)}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> rename(String itemId, String newName) async {
    try {
      await _filesApi.rename(itemId, newName);
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> move(
    String itemId,
    String? newParentFolderId,
  ) async {
    try {
      await _filesApi.move(itemId, newParentFolderId);
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFolder(String folderId) =>
      _softDelete(folderId);

  @override
  Future<Either<Failure, Unit>> deleteFile(String fileId) =>
      _softDelete(fileId);

  Future<Either<Failure, Unit>> _softDelete(String itemId) async {
    try {
      await _filesApi.deleteItem(itemId);
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  @override
  Stream<List<FileItem>> watchDeletedItems(String ownerId) {
    late StreamController<List<FileItem>> controller;
    StreamSubscription? sub;

    Future<void> refresh() async {
      try {
        final json = await _foldersApi.listRecycleBin();
        controller.add(json.map(fileItemFromApiJson).toList());
      } catch (_) {
        // transient failure — next WS event or listener will retry
      }
    }

    controller = StreamController<List<FileItem>>.broadcast(
      onListen: () {
        refresh();
        sub = _wsClient.events.listen((event) {
          if (!_isForThisTree(event)) return;
          final name = event['event'] as String? ?? '';
          if (name.endsWith('_deleted') || name.endsWith('_restored')) {
            refresh();
          }
        });
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Either<Failure, Unit>> restoreItem(String itemId) async {
    try {
      await _foldersApi.restoreItem(itemId);
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  @override
  Future<Either<Failure, Unit>> hardDeleteItem(String itemId) async {
    try {
      await _foldersApi.purgeItem(itemId);
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  @override
  Future<Either<Failure, List<FileItem>>> searchItems(
    String ownerId,
    String query,
  ) async {
    try {
      final json = await _foldersApi.search(query);
      return Right(json.map(fileItemFromApiJson).toList());
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  /// No dedicated endpoint for this — create/rename/move already 409 on
  /// the server for a genuine conflict, so this is a best-effort client
  /// side check (reuses getFolder) rather than a new API call.
  @override
  Future<Either<Failure, bool>> nameExistsInFolder({
    required String ownerId,
    required String? parentFolderId,
    required String name,
  }) async {
    final result = await getFolder(parentFolderId);
    return result.match(
      Left.new,
      (items) => Right(items.any((i) => i.name == name)),
    );
  }

  /// Backed by `POST {basePath}/sync`, which the backend only defines under
  /// `/desktop/shared`. On the personal registration this resolves to
  /// `/desktop/sync`, which does not exist, and comes back as a Failure.
  @override
  Future<Either<Failure, Unit>> sync() async {
    try {
      await _foldersApi.sync();
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  String _describe(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail'] : null;
      return detail?.toString() ?? e.message ?? 'Network error';
    }
    return e.toString();
  }

  @override
  Future<Either<Failure, Unit>> reorder({
    required String itemId,
    required double newSortIndex,
  }) async {
    // The FastAPI backend has no reorder route yet (no /desktop/reorder in
    // app/api/folders.py or files.py, and sort_index is never mapped in
    // file_response_mapper.dart). Report it the way every other method on
    // this interface reports failure — throwing escaped the Either contract
    // and surfaced as an unhandled async error from the drag handler, so a
    // drop on the desktop silently did nothing.
    return Left(
      FileSystemFailure('Reordering is not supported by this backend yet.'),
    );
  }
}
