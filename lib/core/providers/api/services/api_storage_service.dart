import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../error/failure.dart';
import '../../../services/storage_service.dart';
import '../client/api_client.dart';
import '../client/files_api.dart';

class ApiStorageService implements StorageService {
  ApiStorageService({
    required FilesApi filesApi,
    required ApiClient client,
    this.basePath = '/desktop',
  }) : _filesApi = filesApi,
       _client = client;

  final FilesApi _filesApi;
  final ApiClient _client;
  final String basePath;

  /// Performs the real POST /desktop/upload — bytes and metadata are
  /// created together server-side. Returns the new item's id, which
  /// ApiFileSystemRepository.createFile() treats as [storageKey] and
  /// fetches rather than re-creating (see that class's docstring).
  @override
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String ownerId,
    String? parentFolderId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final json = await _filesApi.upload(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        parentFolderId: parentFolderId,
        onProgress: onProgress,
      );
      return Right(json['id'] as String);
    } catch (e) {
      return Left(StorageFailure(_describe(e)));
    }
  }

  /// A no-op here: bytes and metadata are deleted together server-side by
  /// FileSystemRepository.deleteFile/hardDeleteItem. Kept as a harmless
  /// success so any caller that still invokes this directly doesn't break.
  @override
  Future<Either<Failure, Unit>> deleteFile(String path) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Uint8List>> downloadFile(String path) async {
    try {
      final bytes = await _filesApi.download(path); // path === item id
      return Right(bytes);
    } catch (e) {
      return Left(StorageFailure(_describe(e)));
    }
  }

  /// A token still goes in the query string — Image.network,
  /// VideoPlayerController and the PDF iframe can't attach an
  /// Authorization header — but it's an item-scoped stream token minted
  /// by the server, not the caller's Firebase ID token.
  ///
  /// The ID token lasted an hour and was resolved once when the preview
  /// opened, so a long film's range requests started 401ing partway
  /// through: silently on web, as a generic decoder error on Windows. It
  /// was also a credential for the whole API sitting in a URL. A stream
  /// token outlives a viewing session and, if it leaks, exposes one file.
  @override
  Future<Either<Failure, String>> getDownloadUrl(String path) async {
    try {
      String? token;
      try {
        token = await _filesApi.streamToken(path); // path === item id
      } on DioException catch (e) {
        // A server that predates the stream-token endpoint 404s here.
        // Fall back to the old ID-token URL so previews keep working
        // through a rolling deploy — the endpoints accept both.
        if (e.response?.statusCode != 404) rethrow;
        token = await _client.currentIdToken;
      }
      return Right('${_client.baseUrl}$basePath/stream/$path?token=$token');
    } catch (e) {
      return Left(StorageFailure(_describe(e)));
    }
  }

  String _describe(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail = data is Map ? data['detail'] : null;
      return detail?.toString() ?? e.message ?? 'Network error';
    }
    return e.toString();
  }
}
