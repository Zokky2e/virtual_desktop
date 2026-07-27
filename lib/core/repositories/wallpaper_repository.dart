import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';
import '../models/file_item.dart';

abstract class WallpaperRepository {
  /// Live list of this user's previously uploaded wallpapers.
  Stream<List<FileItem>> watchWallpapers(String ownerId);

  /// Looks for an existing wallpaper matching [name] and [size] for this
  /// owner — used to avoid re-uploading a file that's already been saved.
  Future<Either<Failure, FileItem?>> findExisting({
    required String ownerId,
    required String name,
    required int size,
  });

  Future<Either<Failure, FileItem>> saveWallpaper({
    required String name,
    required String ownerId,
    required String storageKey,
    required int size,
  });
}
