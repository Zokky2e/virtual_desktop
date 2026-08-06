import '../../../models/file_item.dart';

/// Maps a `FileResponse` JSON body (see app/schemas/file.py) onto FileItem.
///
/// The server deliberately never exposes `storage_key` (it's an internal
/// pointer into StorageRepository — see storage/base.py's docstring). For
/// non-folder items we set FileItem.storageKey to the item's own id
/// instead: every StorageService method for this provider (download,
/// getDownloadUrl) is id-keyed, not path-keyed, so re-using `id` here is
/// exactly what those calls need.
FileItem fileItemFromApiJson(Map<String, dynamic> json) {
  final id = json['id'] as String;
  final type = FileItemType.values.byName(json['type'] as String);
  return FileItem(
    id: id,
    name: json['name'] as String,
    parentFolderId: json['parent_folder_id'] as String?,
    ownerId: json['owner_id'] as String,
    type: type,
    storageKey: type == FileItemType.folder ? null : id,
    size: json['size'] as int? ?? 0,
    isDeleted: json['is_deleted'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
  );
}
