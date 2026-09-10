import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../error/failure.dart';
import '../../../services/storage_service.dart';
import '../client/api_client.dart';
import '../client/wallpapers_api.dart';

/// StorageService for the wallpaper-scoped registration, backed by
/// /desktop/wallpapers.
///
/// The web build used to register the personal-tree ApiStorageService
/// under `wallpaperInstanceName` — literally `() => getIt<StorageService>()`
/// — which made the "kept separate so this swap can't affect the personal
/// file tree" split in CLAUDE.md untrue, and put every uploaded wallpaper
/// in the user's file tree. This is the real implementation that alias
/// was standing in for.
class ApiWallpaperStorageService implements StorageService {
  ApiWallpaperStorageService({
    required WallpapersApi wallpapersApi,
    required ApiClient client,
    this.basePath = '/desktop/wallpapers',
  }) : _api = wallpapersApi,
       _client = client;

  final WallpapersApi _api;
  final ApiClient _client;
  final String basePath;

  /// Returns the new wallpaper record's id, which
  /// ApiWallpaperRepository.saveWallpaper treats as [storageKey] and
  /// fetches rather than re-creating.
  ///
  /// [path], [parentFolderId] and [isShared] are all ignored: wallpapers
  /// have no folder tree to be placed in and no shared variant. [path] is
  /// only consulted as a last-resort source of a filename, matching
  /// ApiStorageService.
  @override
  Future<Either<Failure, String>> uploadFile({
    required Uint8List bytes,
    required String path,
    required String mimeType,
    String? parentFolderId,
    String? fileName,
    void Function(double progress)? onProgress,
    bool isShared = false,
  }) async {
    try {
      final json = await _api.upload(
        bytes: bytes,
        fileName: fileName ?? path.split('/').last,
        mimeType: mimeType,
        onProgress: onProgress,
      );
      return Right(json['id'] as String);
    } catch (e) {
      return Left(StorageFailure(_describe(e)));
    }
  }

  /// No route for this yet — the backend intentionally exposes no
  /// wallpaper delete (nothing in the UI offers one). Reported as a
  /// failure rather than a silent success so that if a caller ever does
  /// appear, it finds out instead of believing bytes were removed.
  @override
  Future<Either<Failure, Unit>> deleteFile(String path) async {
    return Left(
      StorageFailure('Deleting wallpapers is not supported by this backend.'),
    );
  }

  @override
  Future<Either<Failure, Uint8List>> downloadFile(String path) async {
    try {
      final res = await _client.dio.get<List<int>>(
        '$basePath/stream/$path', // path === wallpaper id
        options: Options(responseType: ResponseType.bytes),
      );
      return Right(Uint8List.fromList(res.data!));
    } catch (e) {
      return Left(StorageFailure(_describe(e)));
    }
  }

  /// Token goes in the query string because Image.network can't attach an
  /// Authorization header — same arrangement as
  /// ApiStorageService.getDownloadUrl and the /ws handshake.
  @override
  Future<Either<Failure, String>> getDownloadUrl(String path) async {
    try {
      final token = await _client.currentIdToken;
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
