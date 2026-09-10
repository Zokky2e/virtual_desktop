// lib/core/providers/local/local_wallpaper_storage_service_stub.dart
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import '../../error/failure.dart';
import '../../services/storage_service.dart';

/// Web-side placeholder for the desktop-only [LocalWallpaperStorageService].
///
/// The web build registers the API-backed StorageService under
/// `wallpaperInstanceName` instead (see injector.dart's `kIsWeb` branch), so
/// nothing should ever construct this. It exists so the conditional export in
/// local_wallpaper_storage_service.dart keeps `dart:io` out of the web
/// compilation unit entirely.
class LocalWallpaperStorageService implements StorageService {
  LocalWallpaperStorageService() {
    throw UnsupportedError(_message);
  }

  static const _message =
      'LocalWallpaperStorageService is desktop-only. On web, the '
      "wallpaper-named StorageService registration resolves to the app's "
      'ApiStorageService instead.';

  @override
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String ownerId,
    String? parentFolderId,
    void Function(double progress)? onProgress,
  }) => throw UnsupportedError(_message);

  @override
  Future<Either<Failure, Unit>> deleteFile(String path) =>
      throw UnsupportedError(_message);

  @override
  Future<Either<Failure, Uint8List>> downloadFile(String path) =>
      throw UnsupportedError(_message);

  @override
  Future<Either<Failure, String>> getDownloadUrl(String path) =>
      throw UnsupportedError(_message);
}
