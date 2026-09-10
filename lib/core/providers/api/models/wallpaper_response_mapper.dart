import '../../../models/file_item.dart';
import '../../../models/wallpaper_item.dart';

/// Maps a `WallpaperResponse` JSON body (see app/schemas/wallpaper.py)
/// onto WallpaperItem.
///
/// Same `storage_key` rule as fileItemFromApiJson: the server never
/// exposes it, so we put the record's own id in WallpaperItem.storageKey.
/// Every wallpaper StorageService call for this provider — getDownloadUrl,
/// downloadFile — is id-keyed, which is exactly what those need.
WallpaperItem wallpaperItemFromApiJson(Map<String, dynamic> json) {
  final id = json['id'] as String;
  return WallpaperItem(
    id: id,
    name: json['name'] as String,
    // Constant server-side: a wallpaper is never in the file tree.
    parentFolderId: null,
    ownerId: json['owner_id'] as String,
    type: FileItemType.image,
    storageKey: id,
    size: json['size'] as int? ?? 0,
    isSet: json['is_set'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
  );
}
