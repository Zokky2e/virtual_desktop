// lib/core/providers/local/local_wallpaper_repository_stub.dart
import 'package:fpdart/fpdart.dart';
import '../../error/failure.dart';
import '../../models/wallpaper_item.dart';
import '../../repositories/wallpaper_repository.dart';

/// Web-side placeholder for the desktop-only [LocalWallpaperRepository].
///
/// The web build registers FirestoreWallpaperRepository instead (see
/// injector.dart's `kIsWeb` branch), so nothing should ever construct this.
/// It exists so the conditional export in local_wallpaper_repository.dart
/// keeps `dart:io` out of the web compilation unit entirely, instead of
/// relying on a runtime `kIsWeb` check to stay correct.
class LocalWallpaperRepository implements WallpaperRepository {
  LocalWallpaperRepository() {
    throw UnsupportedError(_message);
  }

  static const _message =
      'LocalWallpaperRepository is desktop-only. On web, resolve '
      'WallpaperRepository from getIt (wallpaperInstanceName), which is '
      'registered to FirestoreWallpaperRepository.';

  @override
  Stream<List<WallpaperItem>> watchWallpapers(String ownerId) =>
      throw UnsupportedError(_message);

  @override
  Future<Either<Failure, WallpaperItem?>> findExisting({
    required String ownerId,
    required String name,
    required int size,
  }) => throw UnsupportedError(_message);

  @override
  Future<Either<Failure, WallpaperItem>> saveWallpaper({
    required String name,
    required String ownerId,
    required String storageKey,
    required int size,
  }) => throw UnsupportedError(_message);

  @override
  Future<Either<Failure, Unit>> updateWallpaper({
    required String itemId,
    required String ownerId,
  }) => throw UnsupportedError(_message);
}
