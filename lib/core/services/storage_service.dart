import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import '../error/failure.dart';

abstract class StorageService {
  /// Uploads [bytes] and returns an opaque storage key.
  ///
  /// The key layout belongs to the implementation, never to the caller.
  /// Three call sites used to hand in a pre-built
  /// `users/<owner>/<millis>_<name>` path, which the API providers then
  /// ignored except as a filename fallback — which is how pasted files
  /// and wallpapers ended up named `1712345678901_photo.jpg`. Callers now
  /// say what the file *is* ([fileName], [ownerId], [parentFolderId]) and
  /// each provider derives whatever key it needs.
  ///
  /// There is deliberately no `isShared` flag. Which tree an upload lands
  /// in is decided by which registration the caller resolved — the
  /// unnamed personal one, or `sharedInstanceName` with
  /// `basePath: '/desktop/shared'`. Two mechanisms for one fact meant
  /// they could disagree, and they did.
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,

    /// Tree owner — a user's uid, or `sharedOwnerId` for the shared tree.
    /// Providers that generate their own owner-scoped keys (Firebase)
    /// need it; providers whose server derives the owner from the bearer
    /// token and the base path (the API providers) ignore it.
    required String ownerId,

    /// Only meaningful to providers whose upload endpoint creates the
    /// file-tree record atomically with the bytes (the API provider).
    /// Ignored by providers whose metadata record is created separately
    /// by FileSystemRepository.createFile after upload returns.
    String? parentFolderId,
    void Function(double progress)? onProgress,
  });

  Future<Either<Failure, Unit>> deleteFile(String path);

  Future<Either<Failure, Uint8List>> downloadFile(String path);

  Future<Either<Failure, String>> getDownloadUrl(String path);
}
