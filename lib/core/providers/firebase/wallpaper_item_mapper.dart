import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:virtual_desktop/core/models/wallpaper_item.dart';
import '../../models/file_item.dart';

extension WallpaperItemMapper on WallpaperItem {
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'parentFolderId': parentFolderId,
      'ownerId': ownerId,
      'type': type.name,
      'storageKey': storageKey,
      'size': size,
      'isDeleted': isDeleted,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isSet': isSet,
    };
  }
}

WallpaperItem wallpaperItemFromSnapshot(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data()!;
  return WallpaperItem(
    id: doc.id,
    name: data['name'] as String,
    parentFolderId: data['parentFolderId'] as String?,
    ownerId: data['ownerId'] as String,
    type: FileItemType.values.byName(data['type'] as String),
    storageKey: data['storageKey'] as String?,
    size: data['size'] as int? ?? 0,
    isDeleted: data['isDeleted'] as bool? ?? false,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    isSet: data['isSet'] as bool? ?? false,
  );
}
