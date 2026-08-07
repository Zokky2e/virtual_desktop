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
    var query = _files
        .where('ownerId', isEqualTo: _getCurrentOwnerId())
        .where('isDeleted', isEqualTo: false);

    if (folderId == null) {
      query = query.where('parentFolderId', isNull: true);
    } else {
      query = query.where('parentFolderId', isEqualTo: folderId);
    }

    return query.orderBy('sortIndex');
  }

  Future<double> _nextSortIndex(String? parentFolderId) async {
    final snapshot = await _folderQuery(parentFolderId).limitToLast(1).get();
    if (snapshot.docs.isEmpty) return 0;
    final maxIndex = (snapshot.docs.first.data()['sortIndex'] as num?) ?? 0;
    return maxIndex.toDouble() + 1;
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
    return _folderQuery(folderId).snapshots().map((snapshot) {
      return snapshot.docs.map(fileItemFromSnapshot).toList();
    });
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
      final sortIndex = await _nextSortIndex(parentFolderId);
      final item = FileItem(
        id: docRef.id,
        name: name,
        parentFolderId: parentFolderId,
        ownerId: ownerId,
        type: type,
        storageKey: storageKey,
        size: size,
        sortIndex: sortIndex,
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
      final sortIndex = await _nextSortIndex(newParentFolderId);
      await _files.doc(itemId).update({
        'parentFolderId': newParentFolderId,
        'sortIndex': sortIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> reorder({
    required String itemId,
    required double newSortIndex,
  }) async {
    try {
      await _files.doc(itemId).update({
        'sortIndex': newSortIndex,
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

  @override
  Stream<List<FileItem>> watchDeletedItems(String ownerId) {
    return _files
        .where('ownerId', isEqualTo: ownerId)
        .where('isDeleted', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fileItemFromSnapshot).toList());
  }

  @override
  Future<Either<Failure, Unit>> restoreItem(String itemId) async {
    try {
      await _files.doc(itemId).update({
        'isDeleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> hardDeleteItem(String itemId) async {
    try {
      await _files.doc(itemId).delete();
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FileItem>>> searchItems(
    String ownerId,
    String query,
  ) async {
    try {
      final snapshot = await _files
          .where('ownerId', isEqualTo: ownerId)
          .where('isDeleted', isEqualTo: false)
          .get();
      final lowerQuery = query.toLowerCase();
      final matches = snapshot.docs
          .map(fileItemFromSnapshot)
          .where((item) => item.name.toLowerCase().contains(lowerQuery))
          .toList();
      return Right(matches);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> nameExistsInFolder({
    required String ownerId,
    required String? parentFolderId,
    required String name,
  }) async {
    try {
      var query = _files
          .where('ownerId', isEqualTo: ownerId)
          .where('isDeleted', isEqualTo: false)
          .where('name', isEqualTo: name);
      if (parentFolderId == null) {
        query = query.where('parentFolderId', isNull: true);
      } else {
        query = query.where('parentFolderId', isEqualTo: parentFolderId);
      }
      final snapshot = await query.limit(1).get();
      return Right(snapshot.docs.isNotEmpty);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }
}
