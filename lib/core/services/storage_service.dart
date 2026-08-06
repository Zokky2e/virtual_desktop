import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';

abstract class StorageService {
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
  });

  Future<Either<Failure, Unit>> deleteFile(String path);

  Future<Either<Failure, Uint8List>> downloadFile(String path);

  Future<Either<Failure, String>> getDownloadUrl(String path);
}
