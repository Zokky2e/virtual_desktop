import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/di/injector.dart';
import '../../../core/models/file_item.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/repositories/file_system_repository.dart';
import '../../../core/services/storage_service.dart';

/// The Recycle Bin, for both trees.
///
/// It used to hardcode the unnamed (personal) registration, so it only
/// ever listed `/desktop/recycle-bin`. Deleting anything in the Shared
/// folder soft-deleted it under `owner_id = "shared"`, where nothing in
/// the UI could reach it — the item was not gone, just invisible and
/// unrestorable, while the confirm dialog promised a recycle bin.
/// `shared.py` now has the three matching routes, so the shared
/// registration works here too and the window offers a tree switch.
class RecycleBinWindowContent extends StatefulWidget {
  const RecycleBinWindowContent({super.key});

  @override
  State<RecycleBinWindowContent> createState() =>
      _RecycleBinWindowContentState();
}

class _RecycleBinWindowContentState extends State<RecycleBinWindowContent> {
  static const _background = Color(0xFF25344A);

  bool _isShared = false;

  /// Built once per tree rather than per build — `watchDeletedItems`
  /// creates a fresh StreamController on every call, so building it in
  /// `build()` would resubscribe and refetch on each rebuild.
  Stream<List<FileItem>>? _deletedStream;
  String? _ownerId;

  FileSystemRepository get _repo => _isShared
      ? getIt<FileSystemRepository>(instanceName: sharedInstanceName)
      : getIt<FileSystemRepository>();

  StorageService get _storage => _isShared
      ? getIt<StorageService>(instanceName: sharedInstanceName)
      : getIt<StorageService>();

  @override
  void initState() {
    super.initState();
    _ownerId = getIt<AuthRepository>().currentUser?.uid;
    _watchCurrentTree();
  }

  void _watchCurrentTree() {
    final uid = _ownerId;
    if (uid == null) return;
    // The shared tree's deleted rows are owned by the sentinel, not by
    // the caller — providers that filter on ownerId need the right one.
    _deletedStream = _repo.watchDeletedItems(_isShared ? sharedOwnerId : uid);
  }

  void _selectTree(bool shared) {
    if (shared == _isShared) return;
    setState(() {
      _isShared = shared;
      _watchCurrentTree();
    });
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 64),
      ),
    );
  }

  Future<void> _restore(FileItem item) async {
    final result = await _repo.restoreItem(item.id);
    result.match((failure) => _report('Restore failed: ${failure.message}'), (
      _,
    ) {});
  }

  Future<void> _deleteForever(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete forever'),
        content: Text(
          'Permanently delete "${item.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (item.storageKey != null) {
      await _storage.deleteFile(item.storageKey!);
    }
    final result = await _repo.hardDeleteItem(item.id);
    result.match((failure) => _report('Delete failed: ${failure.message}'), (
      _,
    ) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_ownerId == null) {
      // Signed out with the window still open — the router is about to send
      // us back to login, so don't subscribe to a tree we can't read.
      return const ColoredBox(
        color: _background,
        child: Center(
          child: Text(
            'Sign in to view the Recycle Bin',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Container(
      color: _background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('My files'),
                  icon: Icon(Icons.person_outline, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Shared'),
                  icon: Icon(Icons.folder_shared_outlined, size: 16),
                ),
              ],
              selected: {_isShared},
              onSelectionChanged: (selection) => _selectTree(selection.first),
              showSelectedIcon: false,
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<FileItem>>(
      stream: _deletedStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <FileItem>[];
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return Center(
            child: Text(
              _isShared
                  ? 'The shared Recycle Bin is empty'
                  : 'Recycle Bin is empty',
              style: const TextStyle(color: Colors.white70),
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
    );
  }
}
