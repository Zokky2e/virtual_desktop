import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import '../../error/failure.dart';
import '../../models/file_item.dart';
import '../../repositories/file_system_repository.dart';

class FakeFileSystemRepository implements FileSystemRepository {
  final Map<String, FileItem> _items = {};
  final _controller = StreamController<List<FileItem>>.broadcast();
  final _uuid = const Uuid();

  List<FileItem> _childrenOf(String? folderId) => _items.values
      .where((i) => i.parentFolderId == folderId && !i.isDeleted)
      .toList();

  void _emit(String? folderId) => _controller.add(_childrenOf(folderId));

  @override
  Future<Either<Failure, List<FileItem>>> getFolder(String? folderId) async {
    return Right(_childrenOf(folderId));
  }

  @override
  Stream<List<FileItem>> watchFolder(String? folderId) {
    // Seed the first event, then let future mutations push more.
    Future.microtask(() => _emit(folderId));
    return _controller.stream;
  }

  @override
  Future<Either<Failure, FileItem>> createFolder({
    required String name,
    required String? parentFolderId,
    required String ownerId,
  }) async {
    final item = FileItem(
      id: _uuid.v4(),
      name: name,
      parentFolderId: parentFolderId,
      ownerId: ownerId,
      type: FileItemType.folder,
      storageKey: null,
      size: 0,
    );
    _items[item.id] = item;
    _emit(parentFolderId);
    return Right(item);
  }

  @override
  Future<Either<Failure, FileItem>> createFile({
    required String name,
    required String? parentFolderId,
    required String ownerId,
    required FileItemType type,
    required String storageKey,
    required int size,
  }) async {
    final item = FileItem(
      id: _uuid.v4(),
      name: name,
      parentFolderId: parentFolderId,
      ownerId: ownerId,
      type: type,
      storageKey: storageKey,
      size: size,
    );
    _items[item.id] = item;
    _emit(parentFolderId);
    return Right(item);
  }

  @override
  Future<Either<Failure, Unit>> rename(String itemId, String newName) async {
    final item = _items[itemId];
    if (item == null) return Left(FileSystemFailure('Item not found: $itemId'));
    _items[itemId] = item.copyWith(name: newName, updatedAt: DateTime.now());
    _emit(item.parentFolderId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> move(
    String itemId,
    String? newParentFolderId,
  ) async {
    final item = _items[itemId];
    if (item == null) return Left(FileSystemFailure('Item not found: $itemId'));
    final oldParent = item.parentFolderId;
    _items[itemId] = item.copyWith(
      parentFolderId: newParentFolderId,
      updatedAt: DateTime.now(),
    );
    _emit(oldParent);
    _emit(newParentFolderId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteFolder(String folderId) async {
    final item = _items[folderId];
    if (item == null) {
      return Left(FileSystemFailure('Folder not found: $folderId'));
    }
    _items[folderId] = item.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
    );
    _emit(item.parentFolderId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteFile(String fileId) async {
    return deleteFolder(fileId); // same soft-delete logic for now
  }
}
