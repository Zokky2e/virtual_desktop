import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import '../../../error/failure.dart';
import '../../../models/wallpaper_item.dart';
import '../../../repositories/wallpaper_repository.dart';
import '../client/wallpapers_api.dart';
import '../models/wallpaper_response_mapper.dart';

/// API-backed WallpaperRepository, talking to /desktop/wallpapers on the
/// virtual-api backend.
///
/// This exists because the web build previously had no real wallpaper
/// provider: the injector aliased the wallpaper-scoped StorageService
/// straight to the personal-tree one, so uploading a wallpaper wrote a
/// file-tree record at the root of the user's desktop. Wallpapers now
/// have their own table and their own storage prefix server-side.
///
/// Note on [ownerId] parameters: the server derives the owner from the
/// bearer token and scopes every query to it, so the ids passed in here
/// are unused — same as ApiFileSystemRepository.searchItems. They stay in
/// the signatures because the interface is shared with the Firestore and
/// local-disk providers, which do need them.
class ApiWallpaperRepository implements WallpaperRepository {
  ApiWallpaperRepository({required WallpapersApi wallpapersApi})
    : _api = wallpapersApi;

  final WallpapersApi _api;

  /// Wallpapers get no WebSocket events — they aren't file-tree items, so
  /// the server pushes nothing for them (see app/api/wallpapers.py). The
  /// mutations below are therefore the only change signal there is:
  /// poking this re-runs every live watchWallpapers stream.
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<WallpaperItem>> watchWallpapers(String ownerId) {
    late StreamController<List<WallpaperItem>> controller;
    StreamSubscription? sub;

    Future<void> refresh() async {
      try {
        final json = await _api.list();
        if (controller.isClosed) return;
        controller.add(json.map(wallpaperItemFromApiJson).toList());
      } catch (_) {
        // Transient failure — the gallery keeps its last list rather than
        // flashing an error; the next mutation or listener retries.
      }
    }

    controller = StreamController<List<WallpaperItem>>.broadcast(
      onListen: () {
        refresh();
        sub = _changes.stream.listen((_) => refresh());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Either<Failure, WallpaperItem?>> findExisting({
    required String ownerId,
    required String name,
    required int size,
  }) async {
    try {
      final json = await _api.list();
      final items = json.map(wallpaperItemFromApiJson);
      final match = items.where((w) => w.name == name && w.size == size);
      return Right(match.isEmpty ? null : match.first);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
    }
  }

  /// See ApiWallpaperStorageService.uploadFile — POST /desktop/wallpapers/
  /// upload already wrote the bytes and created this exact record
  /// atomically, and handed back its id as [storageKey]. This fetches that
  /// record rather than creating a second one, the same contract
  /// ApiFileSystemRepository.createFile honours.
  @override
  Future<Either<Failure, WallpaperItem>> saveWallpaper({
    required String name,
    required String ownerId,
    required String storageKey,
    required int size,
  }) async {
    try {
      final json = await _api.getItem(storageKey);
      // The upload is what made this record exist, so this is the moment
      // the gallery has something new to show — poke it here rather than
      // relying on the updateWallpaper that usually follows, which can
      // fail on its own.
      _changes.add(null);
      return Right(wallpaperItemFromApiJson(json));
    } catch (e) {
      return Left(
        FileSystemFailure(
          'Wallpaper uploaded but metadata lookup failed: ${_describe(e)}',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> updateWallpaper({
    required String itemId,
    required String ownerId,
  }) async {
    try {
      await _api.setActive(itemId);
      _changes.add(null);
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(_describe(e)));
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
