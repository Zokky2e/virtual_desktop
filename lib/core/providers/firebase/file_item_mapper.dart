import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/file_item.dart';

extension FileItemMapper on FileItem {
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'parentFolderId': parentFolderId,
      'ownerId': ownerId,
      'type': type.name,
      'storageKey': storageKey,
      'size': size,
      'sortIndex': sortIndex,
      'isDeleted': isDeleted,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

FileItem fileItemFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data()!;
  return FileItem(
    id: doc.id,
    name: data['name'] as String,
    parentFolderId: data['parentFolderId'] as String?,
    ownerId: data['ownerId'] as String,
    type: FileItemType.values.byName(data['type'] as String),
    storageKey: data['storageKey'] as String?,
    size: data['size'] as int? ?? 0,
    sortIndex: (data['sortIndex'] as num?)?.toDouble() ?? 0,
    isDeleted: data['isDeleted'] as bool? ?? false,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
  );
}
