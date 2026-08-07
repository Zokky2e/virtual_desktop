import 'package:equatable/equatable.dart';

enum FileItemType {
  folder,
  image,
  video,
  audio,
  pdf,
  text,
  json,
  markdown,
  other,
}

class FileItem extends Equatable {
  const FileItem({
    required this.id,
    required this.name,
    required this.parentFolderId,
    required this.ownerId,
    required this.type,
    required this.storageKey,
    required this.size,
    this.sortIndex = 0,
    this.isDeleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? parentFolderId; // null = root
  final String ownerId;
  final FileItemType type;
  final String? storageKey; // null for folders
  final int size; // bytes, 0 for folders
  final double sortIndex;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFolder => type == FileItemType.folder;

  FileItem copyWith({
    String? name,
    String? parentFolderId,
    double? sortIndex,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return FileItem(
      id: id,
      name: name ?? this.name,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      ownerId: ownerId,
      type: type,
      storageKey: storageKey,
      size: size,
      sortIndex: sortIndex ?? this.sortIndex,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    parentFolderId,
    ownerId,
    type,
    storageKey,
    size,
    sortIndex,
    isDeleted,
    createdAt,
    updatedAt,
  ];
}
