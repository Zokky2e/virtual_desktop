import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import '../../error/failure.dart';
import '../../models/file_item.dart';
import '../../repositories/file_system_repository.dart';
import 'file_item_mapper.dart';

class FirestoreFileSystemRepository implements FileSystemRepository {
  FirestoreFileSystemRepository({
    required String Function() getCurrentOwnerId,
    FirebaseFirestore? firestore,
  }) : _getCurrentOwnerId = getCurrentOwnerId,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String Function() _getCurrentOwnerId;

  CollectionReference<Map<String, dynamic>> get _files =>
      _firestore.collection('files');

  Query<Map<String, dynamic>> _folderQuery(String? folderId) {
    return _files
        .where('ownerId', isEqualTo: _getCurrentOwnerId())
        .where('parentFolderId', isEqualTo: folderId)
        .where('isDeleted', isEqualTo: false);
  }

  @override
  Future<Either<Failure, List<FileItem>>> getFolder(String? folderId) async {
    try {
      final snapshot = await _folderQuery(folderId).get();
      return Right(snapshot.docs.map(fileItemFromSnapshot).toList());
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Stream<List<FileItem>> watchFolder(String? folderId) {
    return _folderQuery(folderId).snapshots().map(
      (snapshot) => snapshot.docs.map(fileItemFromSnapshot).toList(),
    );
  }

  @override
  Future<Either<Failure, FileItem>> createFolder({
    required String name,
    required String? parentFolderId,
    required String ownerId,
  }) async {
    return _create(
      name: name,
      parentFolderId: parentFolderId,
      ownerId: ownerId,
      type: FileItemType.folder,
      storageKey: null,
      size: 0,
    );
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
    return _create(
      name: name,
      parentFolderId: parentFolderId,
      ownerId: ownerId,
      type: type,
      storageKey: storageKey,
      size: size,
    );
  }

  Future<Either<Failure, FileItem>> _create({
    required String name,
    required String? parentFolderId,
    required String ownerId,
    required FileItemType type,
    required String? storageKey,
    required int size,
  }) async {
    try {
      final docRef = _files.doc();
      final item = FileItem(
        id: docRef.id,
        name: name,
        parentFolderId: parentFolderId,
        ownerId: ownerId,
        type: type,
        storageKey: storageKey,
        size: size,
      );
      await docRef.set(item.toFirestore());
      return Right(item);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> rename(String itemId, String newName) async {
    try {
      await _files.doc(itemId).update({
        'name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> move(
    String itemId,
    String? newParentFolderId,
  ) async {
    try {
      await _files.doc(itemId).update({
        'parentFolderId': newParentFolderId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFolder(String folderId) async {
    // Soft delete — same as the fake repository's behavior. A hard-delete
    // "empty recycle bin" action can be added in Phase 12 alongside the
    // recycle bin UI itself.
    try {
      await _files.doc(folderId).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFile(String fileId) async {
    return deleteFolder(fileId); // same soft-delete logic
  }
}
