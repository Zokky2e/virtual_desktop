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

  List<FileItem> _childrenOf(String? folderId) {
    final items = _items.values
        .where((i) => i.parentFolderId == folderId && !i.isDeleted)
        .toList();
    items.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return items;
  }

  double _nextSortIndex(String? parentFolderId) {
    final siblings = _childrenOf(parentFolderId);
    if (siblings.isEmpty) return 0;
    return siblings.map((i) => i.sortIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

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
      sortIndex: _nextSortIndex(parentFolderId),
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
      sortIndex: _nextSortIndex(parentFolderId),
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
    final newIndex = _nextSortIndex(newParentFolderId);
    _items[itemId] = FileItem(
      id: item.id,
      name: item.name,
      parentFolderId: newParentFolderId,
      ownerId: item.ownerId,
      type: item.type,
      storageKey: item.storageKey,
      size: item.size,
      sortIndex: newIndex,
      isDeleted: item.isDeleted,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    _emit(oldParent);
    _emit(newParentFolderId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> reorder({
    required String itemId,
    required double newSortIndex,
  }) async {
    final item = _items[itemId];
    if (item == null) return Left(FileSystemFailure('Item not found: $itemId'));
    _items[itemId] = FileItem(
      id: item.id,
      name: item.name,
      parentFolderId: item.parentFolderId,
      ownerId: item.ownerId,
      type: item.type,
      storageKey: item.storageKey,
      size: item.size,
      sortIndex: newSortIndex,
      isDeleted: item.isDeleted,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
    );
    _emit(item.parentFolderId);
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

  @override
  Stream<List<FileItem>> watchDeletedItems(String ownerId) {
    final controller = StreamController<List<FileItem>>.broadcast();
    void emitDeleted() => controller.add(
      _items.values.where((i) => i.ownerId == ownerId && i.isDeleted).toList(),
    );
    _controller.stream.listen((_) => emitDeleted());
    Future.microtask(emitDeleted);
    return controller.stream;
  }

  @override
  Future<Either<Failure, Unit>> restoreItem(String itemId) async {
    final item = _items[itemId];
    if (item == null) return Left(FileSystemFailure('Item not found: $itemId'));
    _items[itemId] = item.copyWith(isDeleted: false, updatedAt: DateTime.now());
    _emit(item.parentFolderId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> hardDeleteItem(String itemId) async {
    _items.remove(itemId);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<FileItem>>> searchItems(
    String ownerId,
    String query,
  ) async {
    final lowerQuery = query.toLowerCase();
    return Right(
      _items.values
          .where(
            (i) =>
                i.ownerId == ownerId &&
                !i.isDeleted &&
                i.name.toLowerCase().contains(lowerQuery),
          )
          .toList(),
    );
  }

  @override
  Future<Either<Failure, bool>> nameExistsInFolder({
    required String ownerId,
    required String? parentFolderId,
    required String name,
  }) async {
    final exists = _items.values.any(
      (i) =>
          i.ownerId == ownerId &&
          i.parentFolderId == parentFolderId &&
          !i.isDeleted &&
          i.name == name,
    );
    return Right(exists);
  }
}
