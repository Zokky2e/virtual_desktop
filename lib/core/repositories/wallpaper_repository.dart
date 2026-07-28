import 'package:fpdart/fpdart.dart';
import 'package:virtual_desktop/core/models/wallpaper_item.dart';
import '../error/failure.dart';

abstract class WallpaperRepository {
  /// Live list of this user's previously uploaded wallpapers.
  Stream<List<WallpaperItem>> watchWallpapers(String ownerId);

  /// Looks for an existing wallpaper matching [name] and [size] for this
  /// owner — used to avoid re-uploading a file that's already been saved.
  Future<Either<Failure, WallpaperItem?>> findExisting({
    required String ownerId,
    required String name,
    required int size,
  });

  Future<Either<Failure, WallpaperItem>> saveWallpaper({
    required String name,
    required String ownerId,
    required String storageKey,
    required int size,
  });

  Future<Either<Failure, Unit>> updateWallpaper({
    required String itemId,
    required String ownerId,
  });
}
