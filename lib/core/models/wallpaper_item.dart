import 'package:virtual_desktop/core/models/file_item.dart';

class WallpaperItem extends FileItem {
  final bool isSet;

  const WallpaperItem({
    required super.id,
    required super.name,
    required super.parentFolderId,
    required super.ownerId,
    required super.type,
    required super.storageKey,
    required super.size,
    super.sortIndex = 0,
    super.isDeleted = false,
    super.createdAt,
    super.updatedAt,
    this.isSet = false,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    parentFolderId,
    ownerId,
    type,
    storageKey,
    size,
    isDeleted,
    createdAt,
    updatedAt,
    isSet,
  ];
}
