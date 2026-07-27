import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import '../../error/failure.dart';
import '../../models/file_item.dart';
import '../../repositories/wallpaper_repository.dart';
import 'file_item_mapper.dart';

class FirestoreWallpaperRepository implements WallpaperRepository {
  FirestoreWallpaperRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _wallpapers =>
      _firestore.collection('wallpapers');

  @override
  Stream<List<FileItem>> watchWallpapers(String ownerId) {
    return _wallpapers
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(fileItemFromSnapshot).toList());
  }

  @override
  Future<Either<Failure, FileItem?>> findExisting({
    required String ownerId,
    required String name,
    required int size,
  }) async {
    try {
      final snapshot = await _wallpapers
          .where('ownerId', isEqualTo: ownerId)
          .where('name', isEqualTo: name)
          .where('size', isEqualTo: size)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return const Right(null);
      return Right(fileItemFromSnapshot(snapshot.docs.first));
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FileItem>> saveWallpaper({
    required String name,
    required String ownerId,
    required String storageKey,
    required int size,
  }) async {
    try {
      final docRef = _wallpapers.doc();
      final item = FileItem(
        id: docRef.id,
        name: name,
        parentFolderId: null,
        ownerId: ownerId,
        type: FileItemType.image,
        storageKey: storageKey,
        size: size,
      );
      await docRef.set(item.toFirestore());
      return Right(item);
    } catch (e) {
      // ignore: avoid_print
      print('saveWallpaper failed: $e');
      return Left(FileSystemFailure(e.toString()));
    }
  }
}
