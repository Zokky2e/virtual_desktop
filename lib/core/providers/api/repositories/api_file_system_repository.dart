import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
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
  }) : _foldersApi = foldersApi,
       _filesApi = filesApi,
       _wsClient = wsClient {
    _wsClient.connect();
  }

  final FoldersApi _foldersApi;
  final FilesApi _filesApi;
  final ApiWebSocketClient _wsClient;

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
  }) {
    // TODO: implement reorder
    throw UnimplementedError();
  }
}
