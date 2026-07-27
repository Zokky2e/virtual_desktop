import 'package:flutter/material.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../../core/services/storage_service.dart';

class RecycleBinWindowContent extends StatelessWidget {
  const RecycleBinWindowContent({super.key});

  Future<void> _restore(FileItem item) async {
    await getIt<FileSystemRepository>().restoreItem(item.id);
  }

  Future<void> _deleteForever(FileItem item) async {
    if (item.storageKey != null) {
      await getIt<StorageService>().deleteFile(item.storageKey!);
    }
    await getIt<FileSystemRepository>().hardDeleteItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final uid = getIt<AuthRepository>().currentUser!.uid;
    return Container(
      color: const Color(0xFF25344A),
      child: StreamBuilder<List<FileItem>>(
        stream: getIt<FileSystemRepository>().watchDeletedItems(uid),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Recycle Bin is empty',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(
                  item.isFolder ? Icons.folder : Icons.insert_drive_file,
                  color: Colors.white70,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Restore',
                      icon: const Icon(Icons.restore, color: Colors.white70),
                      onPressed: () => _restore(item),
                    ),
                    IconButton(
                      tooltip: 'Delete Forever',
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteForever(item),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
