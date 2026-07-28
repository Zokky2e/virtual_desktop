import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import 'package:virtual_desktop/core/models/wallpaper_item.dart';
import 'package:virtual_desktop/core/providers/firebase/wallpaper_item_mapper.dart';
import '../../error/failure.dart';
import '../../models/file_item.dart';
import '../../repositories/wallpaper_repository.dart';

class FirestoreWallpaperRepository implements WallpaperRepository {
  FirestoreWallpaperRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _wallpapers =>
      _firestore.collection('wallpapers');

  @override
  Stream<List<WallpaperItem>> watchWallpapers(String ownerId) {
    return _wallpapers
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(wallpaperItemFromSnapshot).toList(),
        );
  }

  @override
  Future<Either<Failure, WallpaperItem?>> findExisting({
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
      return Right(wallpaperItemFromSnapshot(snapshot.docs.first));
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WallpaperItem>> saveWallpaper({
    required String name,
    required String ownerId,
    required String storageKey,
    required int size,
  }) async {
    try {
      final docRef = _wallpapers.doc();
      final item = WallpaperItem(
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

  @override
  Future<Either<Failure, Unit>> updateWallpaper({
    required String itemId,
    required String ownerId,
  }) async {
    try {
      final batch = _firestore.batch();
      final current = await _wallpapers
          .where('isSet', isEqualTo: true)
          .where('ownerId', isEqualTo: ownerId)
          .get();
      for (final doc in current.docs) {
        batch.update(doc.reference, {
          'isSet': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(_wallpapers.doc(itemId), {
        'isSet': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }
}
