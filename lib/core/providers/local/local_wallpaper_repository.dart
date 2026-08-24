// lib/core/providers/local/local_wallpaper_repository.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../error/failure.dart';
import '../../models/file_item.dart';
import '../../models/wallpaper_item.dart';
import '../../repositories/wallpaper_repository.dart';

/// Desktop-only WallpaperRepository — stores metadata as a JSON index
/// file under the app's local support directory instead of Firestore,
/// which has no official Windows support (see
/// Windows-Desktop-Video-Player-VLC-Plan.md's "Related, larger blocker").
/// Image bytes are handled separately by LocalWallpaperStorageService;
/// this class only ever deals with the metadata index, mirroring the
/// metadata-vs-bytes split every other provider already follows.
class LocalWallpaperRepository implements WallpaperRepository {
  static const _indexFileName = 'wallpapers_index.json';
  final _uuid = const Uuid();
  final _controller = StreamController<List<WallpaperItem>>.broadcast();
  List<WallpaperItem>? _cache;
  Future<Directory>? _dirFuture;

  Future<Directory> _wallpapersDir() {
    return _dirFuture ??= () async {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'wallpapers'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  Future<File> _indexFile() async {
    final dir = await _wallpapersDir();
    return File(p.join(dir.path, _indexFileName));
  }

  Future<List<WallpaperItem>> _load() async {
    if (_cache != null) return _cache!;
    final file = await _indexFile();
    if (!await file.exists()) return _cache = [];
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List;
      _cache = list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // Corrupt index — start fresh rather than crash the Settings window.
      _cache = [];
    }
    return _cache!;
  }

  Future<void> _persist() async {
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(_cache!.map(_toJson).toList()));
  }

  void _emit(String ownerId) =>
      _controller.add(_cache!.where((w) => w.ownerId == ownerId).toList());

  Map<String, dynamic> _toJson(WallpaperItem item) => {
    'id': item.id,
    'name': item.name,
    'ownerId': item.ownerId,
    'storageKey': item.storageKey,
    'size': item.size,
    'isSet': item.isSet,
    'createdAt': item.createdAt?.toIso8601String(),
    'updatedAt': item.updatedAt?.toIso8601String(),
  };

  WallpaperItem _fromJson(Map<String, dynamic> json) => WallpaperItem(
    id: json['id'] as String,
    name: json['name'] as String,
    parentFolderId: null,
    ownerId: json['ownerId'] as String,
    type: FileItemType.image,
    storageKey: json['storageKey'] as String?,
    size: json['size'] as int? ?? 0,
    isSet: json['isSet'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );

  @override
  Stream<List<WallpaperItem>> watchWallpapers(String ownerId) {
    _load().then((items) {
      _controller.add(items.where((w) => w.ownerId == ownerId).toList());
    });
    return _controller.stream;
  }

  @override
  Future<Either<Failure, WallpaperItem?>> findExisting({
    required String ownerId,
    required String name,
    required int size,
  }) async {
    try {
      final items = await _load();
      final match = items.where(
        (w) => w.ownerId == ownerId && w.name == name && w.size == size,
      );
      return Right(match.isEmpty ? null : match.first);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, WallpaperItem>> saveWallpaper({
    required String name,
    required String ownerId,
    required String storageKey,
    required int size,
  }) async {
    try {
      await _load();
      final item = WallpaperItem(
        id: _uuid.v4(),
        name: name,
        parentFolderId: null,
        ownerId: ownerId,
        type: FileItemType.image,
        storageKey: storageKey,
        size: size,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _cache!.add(item);
      await _persist();
      _emit(ownerId);
      return Right(item);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updateWallpaper({
    required String itemId,
    required String ownerId,
  }) async {
    try {
      await _load();
      for (var i = 0; i < _cache!.length; i++) {
        final w = _cache![i];
        if (w.ownerId != ownerId) continue;
        if (w.id == itemId && !w.isSet) {
          _cache![i] = _withIsSet(w, true);
        } else if (w.id != itemId && w.isSet) {
          _cache![i] = _withIsSet(w, false);
        }
      }
      await _persist();
      _emit(ownerId);
      return const Right(unit);
    } catch (e) {
      return Left(FileSystemFailure(e.toString()));
    }
  }

  WallpaperItem _withIsSet(WallpaperItem item, bool isSet) => WallpaperItem(
    id: item.id,
    name: item.name,
    parentFolderId: item.parentFolderId,
    ownerId: item.ownerId,
    type: item.type,
    storageKey: item.storageKey,
    size: item.size,
    isDeleted: item.isDeleted,
    createdAt: item.createdAt,
    updatedAt: DateTime.now(),
    isSet: isSet,
  );
}
