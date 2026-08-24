// lib/core/providers/local/local_wallpaper_storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../error/failure.dart';
import '../../services/storage_service.dart';

/// Desktop-only StorageService, used exclusively for the wallpaper feature
/// (see injector.dart's `wallpaperInstanceName` registration — regular
/// file uploads still go through ApiStorageService against the FastAPI
/// server). Writes bytes to a folder under the app's local support
/// directory; the "storage key" returned is the absolute file path.
class LocalWallpaperStorageService implements StorageService {
  final _uuid = const Uuid();

  Future<Directory> _wallpapersDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'wallpapers'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String path,
    required String mimeType,
    String? parentFolderId,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = await _wallpapersDir();
      final name = fileName ?? path.split('/').last;
      final storedName = '${_uuid.v4()}${p.extension(name)}';
      final file = File(p.join(dir.path, storedName));
      await file.writeAsBytes(bytes);
      onProgress?.call(1.0);
      return Right(file.path);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
      return const Right(unit);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Uint8List>> downloadFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return Left(StorageFailure('File not found: $path'));
      }
      return Right(await file.readAsBytes());
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  /// No separate URL to sign or resolve — the "storage key" already IS
  /// the local path. Widgets must render this via [adaptiveImageProvider]
  /// (FileImage), not Image.network — see shared/widgets/adaptive_image.dart.
  @override
  Future<Either<Failure, String>> getDownloadUrl(String path) async {
    if (!await File(path).exists()) {
      return Left(StorageFailure('File not found: $path'));
    }
    return Right(path);
  }
}
