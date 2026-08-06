import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import '../../error/failure.dart';
import '../../services/storage_service.dart';

class FakeStorageService implements StorageService {
  final Map<String, Uint8List> _store = {};

  @override
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String path,
    required String mimeType,

    /// Only used by providers whose upload endpoint creates the file-tree
    /// record atomically with the bytes (e.g. the API provider). Firebase
    /// ignores this — its metadata record is created separately by
    /// FileSystemRepository.createFile, after upload returns.
    String? parentFolderId,

    /// Same story as [parentFolderId] — ignored by providers that don't
    /// need it.
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1.0);
    _store[path] = bytes;
    return Right(path);
  }

  @override
  Future<Either<Failure, Unit>> deleteFile(String path) async {
    _store.remove(path);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Uint8List>> downloadFile(String path) async {
    final bytes = _store[path];
    if (bytes == null) return Left(StorageFailure('File not found: $path'));
    return Right(bytes);
  }

  @override
  Future<Either<Failure, String>> getDownloadUrl(String path) async {
    if (!_store.containsKey(path)) {
      return Left(StorageFailure('File not found: $path'));
    }
    return Right('fake://storage/$path');
  }
}
